import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class Impression {
  final String? id;
  final String imageUrl;
  final String? caption;
  final int sortOrder;
  final DateTime? createdAt;

  const Impression({
    this.id,
    required this.imageUrl,
    this.caption,
    this.sortOrder = 0,
    this.createdAt,
  });

  factory Impression.fromJson(Map<String, dynamic> json) => Impression(
        id: json['id'] as String?,
        imageUrl: json['image_url'] as String? ?? '',
        caption: json['caption'] as String?,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'] as String)
            : null,
      );
}

class ImpressionsService {
  static final ImpressionsService _instance = ImpressionsService._();
  factory ImpressionsService() => _instance;
  ImpressionsService._();

  final _client = Supabase.instance.client;
  static const _table = 'impressions';

  List<Impression> _cache = [];
  DateTime? _lastFetch;

  Future<List<Impression>> getImpressions({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache.isNotEmpty && _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 5) {
      return _cache;
    }
    try {
      final rows = await _client
          .from(_table)
          .select()
          .order('sort_order', ascending: true);
      _cache = (rows as List)
          .map((r) => Impression.fromJson(r as Map<String, dynamic>))
          .toList();
      _lastFetch = DateTime.now();
      return _cache;
    } catch (_) {
      return _cache;
    }
  }

  Future<void> addImpression({
    required String imageUrl,
    String? caption,
  }) async {
    final maxOrder = _cache.isEmpty ? 0 : _cache.map((i) => i.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    await _client.from(_table).insert({
      'image_url': imageUrl,
      'caption': caption,
      'sort_order': maxOrder,
    });
    _lastFetch = null;
  }

  Future<void> updateCaption(String id, String? caption) async {
    await _client.from(_table).update({'caption': caption}).eq('id', id);
    _lastFetch = null;
  }

  Future<void> deleteImpression(String id) async {
    await _client.from(_table).delete().eq('id', id);
    _lastFetch = null;
  }

  Future<void> reorder(List<String> ids) async {
    for (var i = 0; i < ids.length; i++) {
      await _client.from(_table).update({'sort_order': i}).eq('id', ids[i]);
    }
    _lastFetch = null;
  }

  static const _bucket = 'impressions';

  Future<String> uploadImage(File file) async {
    final ext = file.path.split('.').last.toLowerCase();
    final name = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split(RegExp(r'[/\\]')).last}';
    final bytes = await file.readAsBytes();

    final contentType = switch (ext) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      _ => 'image/jpeg',
    };

    await _client.storage.from(_bucket).uploadBinary(
      name,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );

    return _client.storage.from(_bucket).getPublicUrl(name);
  }
}
