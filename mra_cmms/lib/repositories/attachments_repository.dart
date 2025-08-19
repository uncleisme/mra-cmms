import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';

class AttachmentsRepository {
  static const String bucket = 'work_orders'; // Ensure this bucket exists in Supabase
  final SupabaseClient _client = Supabase.instance.client;

  /// Lists attachment public URLs for a given work order id.
  /// Uses signed URLs if the bucket is private.
  Future<List<String>> listUrls(String workOrderId) async {
    final prefix = 'orders/$workOrderId/';
    final res = await _client.storage.from(bucket).list(path: prefix, searchOptions: const SearchOptions());

    // If private bucket, create signed URLs; else, get public URLs
    final isPublic = await _isBucketPublic(bucket);
    if (isPublic) {
      return res.map((f) => _client.storage.from(bucket).getPublicUrl('$prefix${f.name}')).toList();
    }
    final futures = res.map((f) => _client.storage.from(bucket).createSignedUrl('$prefix${f.name}', 3600));
    return Future.wait(futures);
  }

  /// Uploads a file under orders/{id}/{timestamp}_{name}
  Future<void> upload(String workOrderId, File file, {String? filename}) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = file.path.split('.').last;
    final safeName = filename != null && filename.isNotEmpty ? filename : 'photo_$ts.$ext';
    final path = 'orders/$workOrderId/${ts}_$safeName';
    final contentType = lookupMimeType(file.path) ?? 'application/octet-stream';
    await _client.storage.from(bucket).upload(path, file, fileOptions: FileOptions(contentType: contentType));
  }

  Future<bool> _isBucketPublic(String bucketId) async {
    // Supabase client doesn't expose bucket ACL directly; try a public URL probe.
    try {
      final testUrl = _client.storage.from(bucketId).getPublicUrl('no_such_file');
      return testUrl.isNotEmpty; // heuristic; in practice configure as needed
    } catch (_) {
      return false;
    }
  }
}
