import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/work_order.dart';

class WorkOrdersRepository {
  final _client = Supabase.instance.client;
  final _box = Hive.box<Map>('work_orders_box');

  Future<List<WorkOrder>> getAssignedToMe() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    final cachedList = _box.get('assigned:$uid');
    if (cachedList != null && cachedList['items'] is List) {
      _refresh(uid);
      return (cachedList['items'] as List)
          .map((e) => WorkOrder.fromMap(Map<String, dynamic>.from(e)))
          .toList();
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
    return items.map(WorkOrder.fromMap).toList();
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
    return (res as List)
        .map((e) => WorkOrder.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, int>> getKpis() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return {'open': 0, 'in_progress': 0, 'overdue': 0};
    final res = await _client
        .from('work_orders')
        .select()
        .eq('assigned_to', uid);
    final items = (res as List)
        .map((e) => WorkOrder.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    final now = DateTime.now();
    int open = 0, inProgress = 0, overdue = 0;
    for (final w in items) {
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
}
