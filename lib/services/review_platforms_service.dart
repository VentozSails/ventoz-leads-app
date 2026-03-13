import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewPlatform {
  final String name;
  final String url;
  final String score;
  final String description;
  final String icon;
  final String embedUrl;

  const ReviewPlatform({
    required this.name,
    required this.url,
    this.score = '',
    this.description = '',
    this.icon = 'star',
    this.embedUrl = '',
  });

  /// The URL to use for the inline webview preview.
  /// Falls back to [url] when [embedUrl] is empty.
  String get effectiveEmbedUrl => embedUrl.isNotEmpty ? embedUrl : url;

  factory ReviewPlatform.fromJson(Map<String, dynamic> json) => ReviewPlatform(
        name: json['name'] as String? ?? '',
        url: json['url'] as String? ?? '',
        score: json['score'] as String? ?? '',
        description: json['description'] as String? ?? '',
        icon: json['icon'] as String? ?? 'star',
        embedUrl: json['embed_url'] as String? ?? '',
      );

  ReviewPlatform copyWith({
    String? name,
    String? url,
    String? score,
    String? description,
    String? icon,
    String? embedUrl,
  }) => ReviewPlatform(
    name: name ?? this.name,
    url: url ?? this.url,
    score: score ?? this.score,
    description: description ?? this.description,
    icon: icon ?? this.icon,
    embedUrl: embedUrl ?? this.embedUrl,
  );

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'score': score,
        'description': description,
        'icon': icon,
        'embed_url': embedUrl,
      };
}

class ReviewPlatformsService {
  static final ReviewPlatformsService _instance = ReviewPlatformsService._();
  factory ReviewPlatformsService() => _instance;
  ReviewPlatformsService._();

  static const _key = 'review_platforms';
  final _supabase = Supabase.instance.client;

  List<ReviewPlatform>? _cache;

  Future<List<ReviewPlatform>> getPlatforms() async {
    if (_cache != null) return _cache!;
    try {
      final rows = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', _key)
          .limit(1);
      if (rows.isEmpty) return [];
      final raw = rows.first['value'];
      final list = raw is String ? jsonDecode(raw) as List : raw as List;
      _cache = list.map((e) => ReviewPlatform.fromJson(e as Map<String, dynamic>)).toList();
      return _cache!;
    } catch (_) {
      return [];
    }
  }

  Future<void> savePlatforms(List<ReviewPlatform> platforms) async {
    final json = platforms.map((p) => p.toJson()).toList();
    await _supabase.from('app_settings').upsert({
      'key': _key,
      'value': json,
    }, onConflict: 'key');
    _cache = platforms;
  }

  void invalidateCache() => _cache = null;
}
