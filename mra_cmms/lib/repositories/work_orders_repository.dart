import 'package:hive_flutter/hive_flutter.dart';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/work_order.dart';

List<WorkOrder> _parseWorkOrders(List raw) {
  return raw.map((e) => WorkOrder.fromMap(Map<String, dynamic>.from(e))).toList();
}

Map<String, int> _computeKpis(List items) {
  final now = DateTime.now();
  int open = 0, inProgress = 0, overdue = 0;
  for (final w in items.map((e) => WorkOrder.fromMap(Map<String, dynamic>.from(e)))) {
    final st = (w.status ?? '').toLowerCase();
    if (st == 'in_progress' || st == 'in progress') {
      inProgress++;
    } else if (st == 'completed' || st == 'done') {
      // skip
    } else {
      open++;
    }
    if ((w.dueDate != null) && (w.dueDate!.isBefore(now)) && st != 'completed') {
      overdue++;
    }
  }
  return {'open': open, 'in_progress': inProgress, 'overdue': overdue};
}

class WorkOrdersRepository {
  final _client = Supabase.instance.client;
  final _box = Hive.box<Map>('work_orders_box');

  /// Fetch work orders submitted for review (status = 'Review'), oldest first.
  /// Intended for admin dashboard approvals.
  Future<List<WorkOrder>> getPendingReviews({int limit = 20}) async {
    final res = await _client
        .from('work_orders')
        .select()
        .eq('status', 'Review')
        // Prioritize older submissions; use updated_at if present, else created_at
        .order('updated_at', ascending: true, nullsFirst: true)
        .order('created_at', ascending: true)
        .limit(limit);
    final items = (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return compute(_parseWorkOrders, items);
  }

  /// Admin-only: update status for any work order by ID, bypassing assigned_to filter.
  Future<(bool ok, String? error)> updateStatusForAdmin(String id, String status) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final updated = await _client
          .from('work_orders')
          .update({'status': status, 'updated_at': nowIso})
          .eq('id', id)
          .select()
          .maybeSingle();
      if (updated == null) {
        return (false, 'No row updated. You may not have permission.');
      }
      final cached = _box.get('byId:$id');
      if (cached != null) {
        final map = Map<String, dynamic>.from(cached);
        map['status'] = status;
        map['updated_at'] = nowIso;
        await _box.put('byId:$id', map);
      }
      // Emit notifications to requester and assignee (best-effort)
      try {
        final reqId = (updated['requested_by'] ?? '').toString();
        final asgId = (updated['assigned_to'] ?? '').toString();
        final title = (updated['title'] ?? 'Work order').toString();
        final msg = '$title has been approved as $status';
        // Only insert notifications if at least one recipient is valid
        if (reqId.isEmpty && asgId.isEmpty) {
          dev.log('No valid recipients for notification (requested_by and assigned_to are empty)', name: 'WorkOrdersRepository.updateStatusForAdmin');
        } else {
          Future<void> ins(String uid) async {
            if (uid.isEmpty) return;
            // Try with Dart List first (maps to Postgres arrays/jsonb correctly via PostgREST)
            try {
              await _client.from('notifications').insert({
                'user_id': uid,
                'module': 'Work Orders',
                'action': 'approved',
                'entity_id': id,
                'message': msg,
                'recipients': [uid],
              });
            } on PostgrestException catch (e1) {
              // Fallback: use text[] literal for recipients (e.g., text[] column)
              dev.log('notifications insert (list) failed, retrying with text[] literal',
                  error: 'code=${e1.code} message=${e1.message} details=${e1.details}',
                  name: 'WorkOrdersRepository.updateStatusForAdmin');
              await _client.from('notifications').insert({
                'user_id': uid,
                'module': 'Work Orders',
                'action': 'approved',
                'entity_id': id,
                'message': msg,
                'recipients': '{$uid}',
              });
            }
          }
          await ins(reqId);
          if (asgId.isNotEmpty && asgId != reqId) {
            await ins(asgId);
          }
        }
      } catch (e) {
        // Log PostgREST error details for diagnostics but do not block main flow
        if (e is PostgrestException) {
          dev.log(
            'notifications insert failed',
            error: 'code=${e.code} message=${e.message} details=${e.details}',
            name: 'WorkOrdersRepository.updateStatusForAdmin',
          );
        } else {
          dev.log('notifications insert error', error: e, name: 'WorkOrdersRepository.updateStatusForAdmin');
        }
      }
      return (true, null);
    } catch (e) {
      return (false, e.toString());
    }
  }

  Future<List<WorkOrder>> getAssignedToMe() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    final cachedList = _box.get('assigned:$uid');
    if (cachedList != null && cachedList['items'] is List) {
      _refresh(uid);
      final raw = (cachedList['items'] as List);
      return compute(_parseWorkOrders, raw);
    }

    final list = await _fetch(uid);
    return list;
  }

  Future<List<WorkOrder>> _fetch(String uid) async {
    final res = await _client
        .from('work_orders')
        .select()
        .eq('assigned_to', uid)
        .order('created_at', ascending: false);

    final items = (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    await _box.put('assigned:$uid', {'items': items});
    return compute(_parseWorkOrders, items);
  }

  Future<void> _refresh(String uid) async {
    try {
      await _fetch(uid);
    } catch (_) {}
  }

  Future<List<WorkOrder>> getTodaysAssigned() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    // Build local-day boundaries then convert to UTC for consistent server filtering
    final now = DateTime.now();
    final localStart = DateTime(now.year, now.month, now.day);
    final localEnd = localStart.add(const Duration(days: 1));
    final startUtc = localStart.toUtc().toIso8601String();
    final endUtc = localEnd.toUtc().toIso8601String();

    // Include orders due today OR with next_scheduled_date today (for recurring/completed flows)
    final res = await _client
        .from('work_orders')
        .select()
        .eq('assigned_to', uid)
        .or('and(due_date.gte.$startUtc,due_date.lt.$endUtc),and(next_scheduled_date.gte.$startUtc,next_scheduled_date.lt.$endUtc)')
        .order('due_date');
    final items = (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return compute(_parseWorkOrders, items);
  }

  Future<Map<String, int>> getKpis() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return {'open': 0, 'in_progress': 0, 'overdue': 0};
    final res = await _client
        .from('work_orders')
        .select()
        .eq('assigned_to', uid);
    final items = (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return compute(_computeKpis, items);
  }

  /// Counts Active and Done work orders across ALL users (admin scope).
  /// Active includes variants: active | in_progress | in progress (case-insensitive common variants)
  /// Done includes variants: done | completed (case-insensitive common variants)
  Future<Map<String, int>> getCountsActiveDoneAllUsers() async {
    // Build OR filters similar to getByStatusPage
    final activeStatuses = ['active', 'in_progress', 'in progress', 'Active', 'In_Progress', 'In progress'];
    final doneStatuses = ['done', 'completed', 'Done', 'Completed'];

    Future<int> countFor(List<String> statuses) async {
      var base = _client.from('work_orders').select('id');
      if (statuses.length == 1) {
        base = base.eq('status', statuses.first);
      } else {
        final ors = statuses.map((v) => 'status.eq.$v').join(',');
        base = base.or(ors);
      }
      final res = await base as List;
      return res.length;
    }

    final active = await countFor(activeStatuses);
    final done = await countFor(doneStatuses);
    return {'active': active, 'done': done};
  }

  /// Update status for a work order. Returns (ok, errorMessage).
  Future<(bool ok, String? error)> updateStatus(String id, String status) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final uid = _client.auth.currentUser?.id;
      var q = _client
          .from('work_orders')
          .update({'status': status, 'updated_at': nowIso})
          .eq('id', id);
      if (uid != null && uid.isNotEmpty) {
        q = q.eq('assigned_to', uid);
      }
      final updated = await q.select().maybeSingle();

      if (updated == null) {
        // No row returned: likely RLS blocked update or ID not found
        return (false, 'No row updated. You may not have permission to modify this work order.');
      }

      // Update byId cache if present
      final cached = _box.get('byId:$id');
      if (cached != null) {
        final map = Map<String, dynamic>.from(cached);
        map['status'] = status;
        map['updated_at'] = nowIso;
        await _box.put('byId:$id', map);
      }
      return (true, null);
    } catch (e) {
      return (false, e.toString());
    }
  }

  Future<WorkOrder?> getById(String id) async {
    // Try cache first
    final cached = _box.get('byId:$id');
    if (cached != null) {
      try {
        return WorkOrder.fromMap(Map<String, dynamic>.from(cached));
      } catch (_) {}
    }

    final res = await _client
        .from('work_orders')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (res == null) return null;
    final map = Map<String, dynamic>.from(res as Map);
    await _box.put('byId:$id', map);
    return WorkOrder.fromMap(map);
  }

  /// Cursor-based pagination for assigned work orders, ordered by created_at desc.
  /// Returns up to [limit] items and a [nextCursor] (created_at ISO string) if more data exists.
  Future<({List<WorkOrder> items, String? nextCursor})> getAssignedToMePage({String? cursor, int limit = 20, String? status}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return (items: const <WorkOrder>[], nextCursor: null);

    var base = _client.from('work_orders').select().eq('assigned_to', uid);
    if (status != null && status.isNotEmpty) {
      base = base.eq('status', status);
    }
    // Apply keyset filter before transform methods
    if (cursor != null && cursor.isNotEmpty) {
      base.lt('created_at', cursor);
    }
    final res = await base.order('created_at', ascending: false).limit(limit + 1);
    final list = (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    String? next;
    List<Map<String, dynamic>> page = list;
    if (list.length > limit) {
      page = list.sublist(0, limit);
      final last = page.last;
      final createdAt = (last['created_at'] ?? '').toString();
      next = createdAt.isEmpty ? null : createdAt;
    }

    final items = await compute(_parseWorkOrders, page);
    return (items: items, nextCursor: next);
  }

  /// Cursor-based pagination by status across all users (admin scope).
  /// Accepts common synonyms: done|completed, active|in_progress, review
  Future<({List<WorkOrder> items, String? nextCursor})> getByStatusPage({
    required String status,
    String? cursor,
    int limit = 20,
  }) async {
    var base = _client.from('work_orders').select();
    if (status.trim().isNotEmpty) {
      // Normalize and map to DB values (only allowed: 'Active', 'In Progress', 'Review', 'Done')
      String s = status.toLowerCase().trim();
      String dbStatus;
      if (s == 'done' || s == 'completed') {
        dbStatus = 'Done';
      } else if (s == 'active' || s == 'in_progress' || s == 'in progress') {
        dbStatus = 'Active';
      } else if (s == 'review') {
        dbStatus = 'Review';
      } else if (s == 'in progress') {
        dbStatus = 'In Progress';
      } else {
        dbStatus = status;
      }
      base = base.eq('status', dbStatus);
    }

    if (cursor != null && cursor.isNotEmpty) {
      base = base.lt('created_at', cursor);
    }
    final res = await base.order('created_at', ascending: false).limit(limit + 1);
    final list = (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    String? next;
    List<Map<String, dynamic>> page = list;
    if (list.length > limit) {
      page = list.sublist(0, limit);
      final last = page.last;
      final createdAt = (last['created_at'] ?? '').toString();
      next = createdAt.isEmpty ? null : createdAt;
    }

    final items = await compute(_parseWorkOrders, page);
    return (items: items, nextCursor: next);
  }

}

extension WorkOrdersRepositoryCreate on WorkOrdersRepository {
  /// Inserts a new work order. Returns (ok, errorMessage).
  /// Minimal required fields: title, description, work_type, priority.
  /// Optional: due_date, location_id, asset_id, contact_person, contact_number, requested_by.
  Future<(bool ok, String? error)> createWorkOrder({
    required String title,
    required String description,
    required String workType,
    required String priority,
    DateTime? dueDate,
    String? locationId,
    String? assetId,
    String? contactPerson,
    String? contactNumber,
    String? requestedBy,
    String? assignedTo,
    String? serviceProviderId,
  }) async {
    try {
      final now = DateTime.now();
      final nowUtcIso = now.toUtc().toIso8601String();

      // Generate work_order_id: WOyyyymmddNNNN (NNNN = sequence for the day)
      final dateStr = now.year.toString().padLeft(4, '0')+
          now.month.toString().padLeft(2, '0')+
          now.day.toString().padLeft(2, '0');
      // Get count of work orders for today to increment sequence
      final todayStart = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc().toIso8601String();
      final countRes = await _client.from('work_orders')
        .select('id')
        .gte('created_date', todayStart)
        .lte('created_date', todayEnd);
      int seq = (countRes != null && countRes is List ? countRes.length : 0) + 1;
      final seqStr = seq.toString().padLeft(4, '0');
      final workOrderId = 'WO$dateStr$seqStr';

      final map = <String, dynamic>{
        'work_order_id': workOrderId,
        'title': title,
        'description': description,
        'work_type': workType,
        'priority': priority,
        'status': 'Active',
        'created_date': nowUtcIso,
        'due_date': dueDate?.toUtc().toIso8601String(),
        'location_id': locationId,
        'asset_id': assetId,
        'contact_person': contactPerson,
        'contact_number': contactNumber,
        'requested_by': requestedBy,
        'assigned_to': assignedTo,
        'service_provider_id': serviceProviderId,
        'created_at': nowUtcIso,
        'updated_at': nowUtcIso,
      };
      // Remove nulls to avoid RLS/DB complaints on some schemas
      map.removeWhere((key, value) => value == null);

      final inserted = await _client.from('work_orders').insert(map).select().maybeSingle();
      if (inserted == null) return (false, 'Insert failed');
      // Cache by id for quick subsequent read
      final id = (inserted['id'] ?? '').toString();
      if (id.isNotEmpty) {
        await _box.put('byId:$id', Map<String, dynamic>.from(inserted));
      }
      return (true, null);
    } catch (e) {
      return (false, e is PostgrestException ? e.message : e.toString());
    }
  }
}
