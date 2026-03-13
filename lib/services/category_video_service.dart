import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryVideo {
  final String? id;
  final String category;
  final String youtubeUrl;
  final String? title;

  const CategoryVideo({
    this.id,
    required this.category,
    required this.youtubeUrl,
    this.title,
  });

  factory CategoryVideo.fromJson(Map<String, dynamic> json) => CategoryVideo(
        id: json['id'] as String?,
        category: json['category'] as String? ?? '',
        youtubeUrl: json['youtube_url'] as String? ?? '',
        title: json['title'] as String?,
      );

  String? get youtubeVideoId {
    final uri = Uri.tryParse(youtubeUrl);
    if (uri == null) return null;
    if (uri.host.contains('youtu.be')) return uri.pathSegments.firstOrNull;
    if (uri.host.contains('youtube.com')) return uri.queryParameters['v'];
    return null;
  }

  String? get thumbnailUrl {
    final vid = youtubeVideoId;
    if (vid == null) return null;
    return 'https://img.youtube.com/vi/$vid/hqdefault.jpg';
  }

  String? get embedUrl {
    final vid = youtubeVideoId;
    if (vid == null) return null;
    return 'https://www.youtube.com/embed/$vid';
  }
}

class CategoryVideoService {
  static final CategoryVideoService _instance = CategoryVideoService._();
  factory CategoryVideoService() => _instance;
  CategoryVideoService._();

  final _client = Supabase.instance.client;
  static const _table = 'category_videos';

  Map<String, CategoryVideo>? _cache;

  Future<Map<String, CategoryVideo>> getVideos({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;
    try {
      final rows = await _client.from(_table).select();
      final map = <String, CategoryVideo>{};
      for (final row in rows) {
        final v = CategoryVideo.fromJson(row);
        map[v.category] = v;
      }
      _cache = map;
      return map;
    } catch (e) {
      if (kDebugMode) debugPrint('CategoryVideoService.getVideos error: $e');
      return _cache ?? {};
    }
  }

  Future<CategoryVideo?> getVideoForCategory(String category) async {
    final videos = await getVideos();
    return videos[category];
  }

  Future<void> saveVideo({
    required String category,
    required String youtubeUrl,
    String? title,
  }) async {
    await _client.from(_table).upsert({
      'category': category,
      'youtube_url': youtubeUrl,
      'title': title,
    }, onConflict: 'category');
    _cache = null;
  }

  Future<void> deleteVideo(String category) async {
    await _client.from(_table).delete().eq('category', category);
    _cache = null;
  }
}
