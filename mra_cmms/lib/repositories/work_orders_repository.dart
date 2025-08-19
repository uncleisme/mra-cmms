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
}
