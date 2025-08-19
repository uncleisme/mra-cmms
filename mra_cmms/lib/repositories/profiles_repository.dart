import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

class ProfilesRepository {
  final _client = Supabase.instance.client;
  final _box = Hive.box<Map>('profiles_box');

  Future<Profile?> getMyProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    // Return cached first
    final cached = _box.get(uid);
    if (cached != null) {
      // Fire and forget refresh
      _refresh(uid);
      return Profile.fromMap(Map<String, dynamic>.from(cached));
    }

    // Otherwise fetch and cache
    final profile = await _fetch(uid);
    return profile;
  }

  Future<Profile?> _fetch(String uid) async {
    final res = await _client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (res == null) return null;
    _box.put(uid, Map<String, dynamic>.from(res));
    return Profile.fromMap(Map<String, dynamic>.from(res));
  }

  Future<void> _refresh(String uid) async {
    try {
      await _fetch(uid);
    } catch (_) {}
  }
}
