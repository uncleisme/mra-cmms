import 'dart:typed_data';
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

  /// Fetch a profile by user id (not necessarily the current user).
  Future<Profile?> getById(String uid) async {
    if (uid.isEmpty) return null;
    // Prefer cache first
    final cached = _box.get(uid);
    if (cached != null) {
      // fire-and-forget refresh
      _refresh(uid);
      return Profile.fromMap(Map<String, dynamic>.from(cached));
    }
    return _fetch(uid);
  }

  Future<void> updateName(String fullName) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    final res = await _client
        .from('profiles')
        .update({'full_name': fullName})
        .eq('id', uid)
        .select()
        .maybeSingle();
    if (res != null) {
      _box.put(uid, Map<String, dynamic>.from(res));
    }
  }

  Future<String?> uploadAvatar({required Uint8List bytes, required String filename, String contentType = 'image/jpeg'}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final path = '$uid/$filename';
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    final url = _client.storage.from('avatars').getPublicUrl(path);
    await _client.from('profiles').update({'avatar_url': url}).eq('id', uid);
    // refresh cache
    await _refresh(uid);
    return url;
  }
}
