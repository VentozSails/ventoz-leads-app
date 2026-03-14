import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductImageService {
  static final ProductImageService _instance = ProductImageService._();
  factory ProductImageService() => _instance;
  ProductImageService._();

  final _client = Supabase.instance.client;
  static const _bucket = 'product-images';

  String _getExtension(String url) {
    final match = RegExp(r'\.(\w{3,4})(?:[?#]|$)').firstMatch(url);
    return match?.group(1)?.toLowerCase() ?? 'jpg';
  }

  String _getMimeType(String ext) {
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
    };
    return map[ext] ?? 'image/jpeg';
  }

  bool isExternalUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host == 'ventoz.nl' || host == 'www.ventoz.nl';
  }

  bool isStorageUrl(String url) {
    return url.contains('supabase.co/storage');
  }

  Future<String?> downloadAndUpload(String imageUrl, int productId, String filename) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) return null;
      return await uploadBytes(response.bodyBytes, productId, filename);
    } catch (e) {
      if (kDebugMode) debugPrint('ProductImageService.downloadAndUpload error: $e');
      return null;
    }
  }

  Future<String?> uploadBytes(Uint8List bytes, int productId, String filename) async {
    try {
      final ext = _getExtension(filename);
      final storagePath = 'products/$productId/$filename';

      await _client.storage.from(_bucket).uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(
          contentType: _getMimeType(ext),
          upsert: true,
        ),
      );

      return _client.storage.from(_bucket).getPublicUrl(storagePath);
    } catch (e) {
      if (kDebugMode) debugPrint('ProductImageService.uploadBytes error: $e');
      return null;
    }
  }

  /// Migrates a single image URL: if it's a ventoz.nl URL, downloads and uploads
  /// to Storage, returning the new URL. Otherwise returns the original.
  Future<String> migrateUrl(String url, int productId, String filename) async {
    if (!isExternalUrl(url) || isStorageUrl(url)) return url;
    final ext = _getExtension(url);
    final newUrl = await downloadAndUpload(url, productId, '$filename.$ext');
    return newUrl ?? url;
  }

  /// Migrates main + extra images for a product before saving.
  Future<Map<String, dynamic>> migrateProductImages({
    required int productId,
    String? mainImageUrl,
    List<String> extraImageUrls = const [],
  }) async {
    final result = <String, dynamic>{};

    if (mainImageUrl != null && isExternalUrl(mainImageUrl)) {
      final newUrl = await migrateUrl(mainImageUrl, productId, 'main');
      if (newUrl != mainImageUrl) result['afbeelding_url'] = newUrl;
    }

    if (extraImageUrls.isNotEmpty) {
      final newExtras = <String>[];
      bool changed = false;
      for (int i = 0; i < extraImageUrls.length; i++) {
        final url = extraImageUrls[i];
        if (isExternalUrl(url)) {
          final newUrl = await migrateUrl(url, productId, 'extra-${i + 1}');
          newExtras.add(newUrl);
          if (newUrl != url) changed = true;
        } else {
          newExtras.add(url);
        }
      }
      if (changed) result['extra_afbeeldingen'] = newExtras;
    }

    return result;
  }

  Future<void> deleteProductImages(int productId) async {
    try {
      final files = await _client.storage.from(_bucket).list(path: 'products/$productId');
      if (files.isNotEmpty) {
        final paths = files.map((f) => 'products/$productId/${f.name}').toList();
        await _client.storage.from(_bucket).remove(paths);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ProductImageService.deleteProductImages error: $e');
    }
  }
}
