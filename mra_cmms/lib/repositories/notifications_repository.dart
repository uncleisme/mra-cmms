import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_notification.dart';

class NotificationsRepository {
  final _client = Supabase.instance.client;

  Future<List<ActivityNotification>> getRecent({int limit = 10, int offset = 0}) async {
    // Backward-compat shim; prefer getForCurrentUser
    return getForCurrentUser(limit: limit, offset: offset);
  }

  /// Keyset-paginated fetch for ALL notifications (global feed), created_at descending.
  Future<List<ActivityNotification>> getAllPage({int limit = 20, DateTime? before}) async {
    try {
      var q = _client
          .from('notifications')
          .select('id, user_id, module, action, entity_id, message, created_at, is_read');
      if (before != null) {
        q = q.lt('created_at', before.toUtc().toIso8601String());
      }
      final res = await q.order('created_at', ascending: false).limit(limit);
      final list = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return compute(_parseNotifications, list);
    } catch (e) {
      if (e is PostgrestException) {
        dev.log(
          'getAllPage notifications PostgREST error',
          error: 'code=${e.code} message=${e.message} details=${e.details}',
          name: 'NotificationsRepository',
        );
      } else {
        dev.log('getAllPage notifications error', error: e, name: 'NotificationsRepository');
      }
      rethrow;
    }
  }

  /// Keyset-paginated fetch for the current user using created_at descending.
  /// Pass a [before] cursor (usually the last item's createdAt) to get older pages.
  Future<List<ActivityNotification>> getForCurrentUserPage({int limit = 20, DateTime? before}) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return [];
      var q = _client
          .from('notifications')
          .select('id, user_id, module, action, entity_id, message, created_at, is_read')
          .eq('user_id', uid);
      if (before != null) {
        q = q.lt('created_at', before.toUtc().toIso8601String());
      }
      final res = await q.order('created_at', ascending: false).limit(limit);
      final list = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return compute(_parseNotifications, list);
    } catch (e) {
      if (e is PostgrestException) {
        dev.log(
          'getForCurrentUserPage notifications PostgREST error',
          error: 'code=${e.code} message=${e.message} details=${e.details}',
          name: 'NotificationsRepository',
        );
      } else {
        dev.log('getForCurrentUserPage notifications error', error: e, name: 'NotificationsRepository');
      }
      rethrow;
    }
  }

  Future<List<ActivityNotification>> getForCurrentUser({int limit = 50, int offset = 0}) async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return [];
      final res = await _client
          .from('notifications')
          // Select only columns guaranteed by schema to avoid PostgREST errors
          .select('id, user_id, module, action, entity_id, message, created_at, is_read')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final list = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return compute(_parseNotifications, list);
    } catch (e) {
      // Log any PostgREST errors to help diagnose (e.g., missing columns, RLS)
      if (e is PostgrestException) {
        dev.log(
          'getForCurrentUser notifications PostgREST error',
          error: 'code=${e.code} message=${e.message} details=${e.details}',
          name: 'NotificationsRepository',
        );
      } else {
        dev.log('getForCurrentUser notifications error', error: e, name: 'NotificationsRepository');
      }
      rethrow;
    }
  }

  // Fetch all notifications regardless of user (useful for admin/testing)
  Future<List<ActivityNotification>> getAll({int limit = 50, int offset = 0}) async {
    try {
      final res = await _client
          .from('notifications')
          // Select only columns guaranteed by schema to avoid PostgREST errors
          .select('id, user_id, module, action, entity_id, message, created_at, is_read')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final list = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return compute(_parseNotifications, list);
    } catch (e) {
      if (e is PostgrestException) {
        dev.log(
          'getAll notifications PostgREST error',
          error: 'code=${e.code} message=${e.message} details=${e.details}',
          name: 'NotificationsRepository',
        );
      } else {
        dev.log('getAll notifications error', error: e, name: 'NotificationsRepository');
      }
      rethrow;
    }
  }

  Future<void> markRead(String id) async {
    try {
      final uid = _client.auth.currentUser?.id;
      final q = _client.from('notifications').update({'is_read': true}).eq('id', id);
      // Apply user filter if available for extra safety (RLS should handle this too)
      if (uid != null) {
        await q.eq('user_id', uid);
      } else {
        await q;
      }
    } catch (e) {
      dev.log('markRead error', error: e, name: 'NotificationsRepository');
      rethrow;
    }
  }

  Future<void> markAllReadForCurrentUser() async {
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return;
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', uid)
          .eq('is_read', false);
    } catch (e) {
      dev.log('markAllReadForCurrentUser error', error: e, name: 'NotificationsRepository');
      rethrow;
    }
  }

  /// Create a notification for a specific user.
  Future<void> create({
    required String userId,
    required String module,
    required String action,
    required String entityId,
    required String message,
    List<String>? recipients,
  }) async {
    try {
      // Prefer Dart List for recipients; fallback to text[] literal if needed
      try {
        await _client.from('notifications').insert({
          'user_id': userId,
          'module': module,
          'action': action,
          'entity_id': entityId,
          'message': message,
          if (recipients != null && recipients.isNotEmpty) 'recipients': recipients,
          if (recipients == null || recipients.isEmpty) 'recipients': [userId],
        });
      } on PostgrestException catch (e1) {
        dev.log('notifications.create list recipients failed, retrying with text[]',
            error: 'code=${e1.code} message=${e1.message} details=${e1.details}',
            name: 'NotificationsRepository');
        final arr = recipients != null && recipients.isNotEmpty ? '{${recipients.join(',')}}' : '{$userId}';
        await _client.from('notifications').insert({
          'user_id': userId,
          'module': module,
          'action': action,
          'entity_id': entityId,
          'message': message,
          'recipients': arr,
        });
      }
    } catch (e) {
      dev.log('create notification error', error: e, name: 'NotificationsRepository');
      rethrow;
    }
  }
}

// Perform JSON -> model mapping on a background isolate
List<ActivityNotification> _parseNotifications(List<Map<String, dynamic>> data) {
  return data.map((e) => ActivityNotification.fromMap(e)).toList();
}
