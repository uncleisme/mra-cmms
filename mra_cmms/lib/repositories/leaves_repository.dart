import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/leave.dart';

List<LeaveRequest> _parseLeaves(List raw) {
  return raw
      .map((e) => LeaveRequest.fromMap(Map<String, dynamic>.from(e)))
      .toList();
}

class LeavesRepository {
  final _client = Supabase.instance.client;
  final _box = Hive.box<Map>('leaves_box');

  Future<List<LeaveRequest>> getMyLeaves() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];

    final cachedList = _box.get(uid);
    if (cachedList != null && cachedList['items'] is List) {
      _refresh(uid);
      final raw = (cachedList['items'] as List);
      return compute(_parseLeaves, raw);
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
    return compute(_parseLeaves, items);
  }

  Future<List<LeaveRequest>> getLeavesForUser(String uid) async {
    return _fetch(uid);
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
    final items = (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return compute(_parseLeaves, items);
  }

  Future<List<LeaveRequest>> getTodaysLeavesForUser(String uid) async {
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
    final items = (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return compute(_parseLeaves, items);
  }

  /// Cursor-based pagination for leaves, ordered by start_date desc.
  /// Returns up to [limit] items and a [nextCursor] (start_date ISO string) if more data exists.
  Future<({List<LeaveRequest> items, String? nextCursor})> getMyLeavesPage({String? cursor, int limit = 20}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return (items: const <LeaveRequest>[], nextCursor: null);

    final base = _client.from('leaves').select().eq('user_id', uid);
    if (cursor != null && cursor.isNotEmpty) {
      base.lt('start_date', cursor);
    }
    final res = await base.order('start_date', ascending: false).limit(limit + 1);
    final list = (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    String? next;
    List<Map<String, dynamic>> page = list;
    if (list.length > limit) {
      page = list.sublist(0, limit);
      final last = page.last;
      final startDate = (last['start_date'] ?? '').toString();
      next = startDate.isEmpty ? null : startDate;
    }

    final items = await compute(_parseLeaves, page);
    return (items: items, nextCursor: next);
  }

  /// Cursor-based pagination for a specific user's leaves.
  Future<({List<LeaveRequest> items, String? nextCursor})> getLeavesForUserPage(String uid, {String? cursor, int limit = 20}) async {
    if (uid.isEmpty) return (items: const <LeaveRequest>[], nextCursor: null);
    final base = _client.from('leaves').select().eq('user_id', uid);
    if (cursor != null && cursor.isNotEmpty) {
      base.lt('start_date', cursor);
    }
    final res = await base.order('start_date', ascending: false).limit(limit + 1);
    final list = (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    String? next;
    List<Map<String, dynamic>> page = list;
    if (list.length > limit) {
      page = list.sublist(0, limit);
      final last = page.last;
      final startDate = (last['start_date'] ?? '').toString();
      next = startDate.isEmpty ? null : startDate;
    }
    final items = await compute(_parseLeaves, page);
    return (items: items, nextCursor: next);
  }

  /// Admin: fetch leaves with status 'pending' (needing approval)
  Future<List<LeaveRequest>> getPendingForApproval({int limit = 50}) async {
    final res = await _client
        .from('leaves')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: true, nullsFirst: true)
        .order('start_date', ascending: true)
        .limit(limit);
    final items = (res as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return compute(_parseLeaves, items);
  }

  /// Approve or reject a leave request. Returns (ok, errorMessage).
  Future<(bool ok, String? error)> updateLeaveApproval({
    required String id,
    required bool approve,
    String? reason,
  }) async {
    try {
      final uid = _client.auth.currentUser?.id;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final status = approve ? 'approved' : 'rejected';
      final payload = <String, dynamic>{
        'status': status,
        'approved_at': nowIso,
      };
      if (uid != null && uid.isNotEmpty) payload['approved_by'] = uid;
      if (reason != null) payload['reason'] = reason;
      await _client.from('leaves').update(payload).eq('id', id);
      return (true, null);
    } catch (e) {
      return (false, e.toString());
    }
  }
}
