import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/work_order.dart';

List<WorkOrder> _parseWorkOrders(List raw) {
  return raw
      .map((e) => WorkOrder.fromMap(Map<String, dynamic>.from(e)))
      .toList();
}

Map<String, int> _computeKpis(List items) {
  final now = DateTime.now();
  int open = 0, inProgress = 0, overdue = 0;
  for (final w in items.map(
    (e) => WorkOrder.fromMap(Map<String, dynamic>.from(e)),
  )) {
    final st = (w.status ?? '').toLowerCase();
    if (st == 'in_progress' || st == 'in progress') {
      inProgress++;
    } else if (st == 'completed' || st == 'done') {
      // skip
    } else {
      open++;
    }
    if ((w.dueDate != null) &&
        (w.dueDate!.isBefore(now)) &&
        st != 'completed') {
      overdue++;
    }
  }
  return {'open': open, 'in_progress': inProgress, 'overdue': overdue};
}

class WorkOrdersRepository {
  /// Fetch work orders submitted for review (status = 'Review'), oldest first.
  Future<List<WorkOrder>> getPendingReviews({int limit = 20}) async {
    final res = await _client
        .from('work_orders')
        .select()
        .eq('status', 'Review')
        .order('updated_at', ascending: true, nullsFirst: true)
        .order('created_at', ascending: true)
        .limit(limit);
    final items = (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return compute(_parseWorkOrders, items);
  }

  /// Get a work order by its ID.
  Future<WorkOrder?> getById(String id) async {
    final res = await _client
        .from('work_orders')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return WorkOrder.fromMap(Map<String, dynamic>.from(res as Map));
  }

  /// Update status for a work order (for assigned user).
  Future<(bool ok, String? error)> updateStatus(
    String id,
    String status,
  ) async {
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
        return (
          false,
          'No row updated. You may not have permission to modify this work order.',
        );
      }
      return (true, null);
    } catch (e) {
      return (false, e.toString());
    }
  }

  /// Returns all work orders assigned to the current user.
  Future<List<WorkOrder>> getAssignedToMe() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final res = await _client
        .from('work_orders')
        .select()
        .eq('assigned_to', uid)
        .order('created_at', ascending: false);
    final items = (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return compute(_parseWorkOrders, items);
  }

  /// Cursor-based pagination for assigned work orders, ordered by created_at desc.
  Future<({List<WorkOrder> items, String? nextCursor})> getAssignedToMePage({
    String? cursor,
    int limit = 20,
    String? status,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return (items: const <WorkOrder>[], nextCursor: null);
    var base = _client.from('work_orders').select().eq('assigned_to', uid);
    if (status != null && status.isNotEmpty) {
      base = base.eq('status', status);
    }
    if (cursor != null && cursor.isNotEmpty) {
      base = base.lt('created_at', cursor);
    }
    final res = await base
        .order('created_at', ascending: false)
        .limit(limit + 1);
    final list = (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
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
  Future<({List<WorkOrder> items, String? nextCursor})> getByStatusPage({
    required String status,
    String? cursor,
    int limit = 20,
  }) async {
    var base = _client.from('work_orders').select();
    if (status.trim().isNotEmpty) {
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
    final res = await base
        .order('created_at', ascending: false)
        .limit(limit + 1);
    final list = (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
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

  final _client = Supabase.instance.client;
  final _box = Hive.box<Map>('work_orders_box');

  /// Returns work orders assigned to the current user that are due today (by dueDate or nextScheduledDate).
  Future<List<WorkOrder>> getTodaysAssigned() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final res = await _client
        .from('work_orders')
        .select()
        .eq('assigned_to', uid);
    final items = (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final now = DateTime.now();
    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    DateTime? effectiveDate(WorkOrder wo) {
      final status = (wo.status ?? '').toLowerCase();
      final due = wo.dueDate?.toLocal();
      final completed =
          status == 'completed' || status == 'done' || status == 'closed';
      final nextDate = wo.nextScheduledDate?.toLocal();
      if (due != null) return due;
      if (completed && nextDate != null) return nextDate; // for PM follow-up
      return null;
    }

    final parsed = await compute(_parseWorkOrders, items);
    return parsed.where((wo) {
      final d = effectiveDate(wo);
      return d != null && isSameDay(d, now);
    }).toList()..sort((a, b) => effectiveDate(a)!.compareTo(effectiveDate(b)!));
  }

  /// Returns KPIs for the current user's assigned work orders.
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

  /// Admin-only: update status for any work order by ID, bypassing assigned_to filter.
  Future<(bool ok, String? error)> updateStatusForAdmin(
    String id,
    String status,
  ) async {
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
      // Notification logic removed as per user request
      return (true, null);
    } catch (e) {
      return (false, e.toString());
    }
  }

  /// Inserts a new work order. Returns (ok, errorMessage).
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
      final dateStr =
          now.year.toString().padLeft(4, '0') +
          now.month.toString().padLeft(2, '0') +
          now.day.toString().padLeft(2, '0');
      final todayStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).toUtc().toIso8601String();
      final todayEnd = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      ).toUtc().toIso8601String();
      final countRes = await _client
          .from('work_orders')
          .select('id')
          .gte('created_date', todayStart)
          .lte('created_date', todayEnd);
      int seq = (countRes.length) + 1;
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
      map.removeWhere((key, value) => value == null);
      final inserted = await _client
          .from('work_orders')
          .insert(map)
          .select()
          .maybeSingle();
      if (inserted == null) return (false, 'Insert failed');
      final id = (inserted['id'] ?? '').toString();
      if (id.isNotEmpty) {
        await _box.put('byId:$id', Map<String, dynamic>.from(inserted));
      }
      return (true, null);
    } catch (e) {
      return (false, e.toString());
    }
  }
}
