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
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day + 1).toIso8601String();
    final res = await _client
        .from('work_orders')
        .select()
        .eq('assigned_to', uid)
        .gte('due_date', start)
        .lt('due_date', end)
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
  Future<({List<WorkOrder> items, String? nextCursor})> getAssignedToMePage({String? cursor, int limit = 20}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return (items: const <WorkOrder>[], nextCursor: null);

    final base = _client.from('work_orders').select().eq('assigned_to', uid);
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
}
