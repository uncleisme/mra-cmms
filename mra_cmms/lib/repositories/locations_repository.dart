import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationInfo {
  final String id; // UUID primary key
  final String locationId; // human-readable code
  final String name;
  final String? block;
  final String? floor;
  final String? room;
  final String? type;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  LocationInfo({
    required this.id,
    required this.locationId,
    required this.name,
    this.block,
    this.floor,
    this.room,
    this.type,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory LocationInfo.fromMap(Map<String, dynamic> m) => LocationInfo(
        id: m['id'] as String,
        locationId: m['location_id'] as String,
        name: (m['name'] as String?) ?? '-',
        block: m['block'] as String?,
        floor: m['floor'] as String?,
        room: m['room'] as String?,
        type: m['type'] as String?,
        description: m['description'] as String?,
        createdAt: m['created_at'] != null ? DateTime.tryParse(m['created_at'].toString()) : null,
        updatedAt: m['updated_at'] != null ? DateTime.tryParse(m['updated_at'].toString()) : null,
      );
}

class LocationsRepository {
  final _client = Supabase.instance.client;
  final _box = Hive.box<Map>('locations_box');

  Future<LocationInfo?> _fetch(String locationId) async {
    final res = await _client
        .from('locations')
        .select('id, location_id, name, block, floor, room, type, description, created_at, updated_at')
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
        .select('id, location_id, name, block, floor, room, type, description, created_at, updated_at')
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
