import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssetInfo {
  final String id; // UUID primary key
  final String assetId; // human-readable code
  final String name;
  final String? locationId; // optional reference to locations.location_id
  AssetInfo({required this.id, required this.assetId, required this.name, this.locationId});

  factory AssetInfo.fromMap(Map<String, dynamic> m) => AssetInfo(
        id: m['id'] as String,
        assetId: m['asset_id'] as String,
        name: (m['asset_name'] as String?) ?? '-',
        locationId: m['location_id'] as String?,
      );
}

class AssetsRepository {
  final _client = Supabase.instance.client;
  final _box = Hive.box<Map>('assets_box');

  Future<AssetInfo?> _fetch(String assetId) async {
    final res = await _client
        .from('assets')
        .select('id, asset_id, asset_name, location_id')
        .eq('asset_id', assetId)
        .maybeSingle();
    if (res == null) return null;
    final map = Map<String, dynamic>.from(res);
    await _box.put(assetId, map);
    return AssetInfo.fromMap(map);
  }

  Future<void> _refresh(String assetId) async {
    try {
      await _fetch(assetId);
    } catch (_) {}
  }

  Future<AssetInfo?> getByAssetId(String assetId) async {
    if (assetId.isEmpty) return null;
    final cached = _box.get(assetId);
    if (cached != null) {
      // background refresh
      _refresh(assetId);
      return AssetInfo.fromMap(Map<String, dynamic>.from(cached));
    }
    return _fetch(assetId);
  }

  Future<AssetInfo?> getById(String id) async {
    if (id.isEmpty) return null;
    final res = await _client
        .from('assets')
        .select('id, asset_id, asset_name, location_id')
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    final map = Map<String, dynamic>.from(res);
    final info = AssetInfo.fromMap(map);
    // Cache by asset_id for consistency
    await _box.put(info.assetId, map);
    return info;
  }

  Future<List<AssetInfo>> list({String? query, int limit = 50, int offset = 0}) async {
    List data = [];
    if (query == null || query.trim().isEmpty) {
      data = await _client
          .from('assets')
          .select('id, asset_id, asset_name, location_id')
          .order('asset_name', ascending: true)
          .range(offset, offset + limit - 1);
    } else {
      final q = '%${query.trim()}%';
      final byName = await _client
          .from('assets')
          .select('id, asset_id, asset_name, location_id')
          .ilike('asset_name', q)
          .order('asset_name', ascending: true)
          .limit(limit);
      final byCode = await _client
          .from('assets')
          .select('id, asset_id, asset_name, location_id')
          .ilike('asset_id', q)
          .order('asset_id', ascending: true)
          .limit(limit);
      final map = <String, Map<String, dynamic>>{};
      for (final e in (byName as List)) {
        final m = Map<String, dynamic>.from(e);
        map[m['asset_id'] as String] = m;
      }
      for (final e in (byCode as List)) {
        final m = Map<String, dynamic>.from(e);
        map[m['asset_id'] as String] = m;
      }
      final merged = map.values.toList()
        ..sort((a, b) => (a['asset_name'] ?? '').toString().compareTo((b['asset_name'] ?? '').toString()));
      final start = offset.clamp(0, merged.length);
      final end = (start + limit).clamp(0, merged.length);
      data = merged.sublist(start, end);
    }
    final list = data.map((e) => AssetInfo.fromMap(Map<String, dynamic>.from(e))).toList();
    for (final a in list) {
      await _box.put(a.assetId, {
        'id': a.id,
        'asset_id': a.assetId,
        'asset_name': a.name,
        'location_id': a.locationId,
      });
    }
    return list;
  }
}
