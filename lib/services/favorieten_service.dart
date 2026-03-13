import 'package:supabase_flutter/supabase_flutter.dart';

class FavorietenService {
  final _client = Supabase.instance.client;
  static const _table = 'favorieten';

  Set<String> _cache = {};
  Set<String> get cachedIds => _cache;
  bool _loaded = false;

  Future<Set<String>> fetchFavorieten() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return {};

    try {
      final List<dynamic> rows = await _client
          .from(_table)
          .select('product_id')
          .eq('user_id', uid);
      _cache = rows.map((r) => r['product_id'] as String).toSet();
      _loaded = true;
    } catch (_) {}
    return _cache;
  }

  bool isFavoriet(String productId) => _cache.contains(productId);

  int get count => _cache.length;

  Future<void> toggleFavoriet(String productId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    if (!_loaded) await fetchFavorieten();

    if (_cache.contains(productId)) {
      _cache.remove(productId);
      try {
        await _client.from(_table)
            .delete()
            .eq('user_id', uid)
            .eq('product_id', productId);
      } catch (_) {
        _cache.add(productId);
      }
    } else {
      _cache.add(productId);
      try {
        await _client.from(_table).insert({
          'user_id': uid,
          'product_id': productId,
        });
      } catch (_) {
        _cache.remove(productId);
      }
    }
  }
}
