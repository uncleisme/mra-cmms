import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/leave.dart';

class LeavesRepository {
  final _client = Supabase.instance.client;
  final _box = Hive.box<Map>('leaves_box');

  Future<List<LeaveRequest>> getMyLeaves() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    final cachedList = _box.get(uid);
    if (cachedList != null && cachedList['items'] is List) {
      _refresh(uid);
      return (cachedList['items'] as List)
          .map((e) => LeaveRequest.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }

    final list = await _fetch(uid);
    return list;
  }

  Future<List<LeaveRequest>> _fetch(String uid) async {
    final res = await _client
        .from('leaves')
        .select()
        .eq('user_id', uid)
        .order('start_date', ascending: false);

    final items = (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    await _box.put(uid, {'items': items});
    return items.map(LeaveRequest.fromMap).toList();
  }

  Future<void> _refresh(String uid) async {
    try {
      await _fetch(uid);
    } catch (_) {}
  }

  Future<List<LeaveRequest>> getTodaysLeaves() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day + 1).toIso8601String();
    final res = await _client
        .from('leaves')
        .select()
        .eq('user_id', uid)
        .gte('start_date', start)
        .lt('start_date', end)
        .order('start_date');
    return (res as List)
        .map((e) => LeaveRequest.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
