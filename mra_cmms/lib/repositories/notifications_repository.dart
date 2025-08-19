import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_notification.dart';

class NotificationsRepository {
  final _client = Supabase.instance.client;

  Future<List<ActivityNotification>> getRecent({int limit = 10}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final res = await _client
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return (res as List)
        .map((e) => ActivityNotification.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
