import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationInfo {
  final String id; // UUID primary key
  final String locationId; // human-readable code
  final String name;
  LocationInfo({required this.id, required this.locationId, required this.name});

  factory LocationInfo.fromMap(Map<String, dynamic> m) => LocationInfo(
        id: m['id'] as String,
        locationId: m['location_id'] as String,
        name: (m['name'] as String?) ?? '-',
      );
}

class LocationsRepository {
  final _client = Supabase.instance.client;
  final _box = Hive.box<Map>('locations_box');

  Future<LocationInfo?> _fetch(String locationId) async {
    final res = await _client
        .from('locations')
        .select('id, location_id, name')
        .eq('location_id', locationId)
        .maybeSingle();
    if (res == null) return null;
    final map = Map<String, dynamic>.from(res);
    await _box.put(locationId, map);
    return LocationInfo.fromMap(map);
  }

  Future<void> _refresh(String locationId) async {
    try {
      await _fetch(locationId);
    } catch (_) {}
  }

  Future<LocationInfo?> getByLocationId(String locationId) async {
    if (locationId.isEmpty) return null;
    final cached = _box.get(locationId);
    if (cached != null) {
      _refresh(locationId);
      return LocationInfo.fromMap(Map<String, dynamic>.from(cached));
    }
    return _fetch(locationId);
  }

  Future<LocationInfo?> getById(String id) async {
    if (id.isEmpty) return null;
    final res = await _client
        .from('locations')
        .select('id, location_id, name')
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    final map = Map<String, dynamic>.from(res);
    final info = LocationInfo.fromMap(map);
    // Cache by location_id for consistency
    await _box.put(info.locationId, map);
    return info;
  }
}
