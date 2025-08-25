import 'package:hive_flutter/hive_flutter.dart';
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
        Future<void> ins(String uid) async {
          if (uid.isEmpty) return;
          await _client.from('notifications').insert({
            'user_id': uid,
            'module': 'Work Orders',
            'action': 'approved',
            'entity_id': id,
            'message': msg,
          });
        }
        await ins(reqId);
        if (asgId.isNotEmpty && asgId != reqId) {
          await ins(asgId);
        }
      } catch (_) {
        // Swallow to avoid blocking main update flow
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
    // Normalize and map to DB values
    String s = status.toLowerCase().trim();
    final List<String> statuses;
    if (s == 'done' || s == 'completed') {
      statuses = ['done', 'completed', 'Done', 'Completed'];
    } else if (s == 'active' || s == 'in_progress' || s == 'in progress') {
      statuses = ['active', 'in_progress', 'in progress', 'Active', 'In_Progress', 'In progress'];
    } else if (s == 'review') {
      statuses = ['Review', 'review'];
    } else {
      statuses = [status];
    }

    var base = _client.from('work_orders').select();
    // Use OR for multiple status variants
    if (statuses.length == 1) {
      base = base.eq('status', statuses.first);
    } else {
      final ors = statuses.map((v) => 'status.eq.' + v).join(',');
      base = base.or(ors);
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
