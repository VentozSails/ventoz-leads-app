import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/catalog_product.dart';

class FeaturedProductsService {
  static final FeaturedProductsService _instance = FeaturedProductsService._();
  FeaturedProductsService._();
  factory FeaturedProductsService() => _instance;

  final _client = Supabase.instance.client;

  List<CatalogProduct> _cached = [];
  DateTime? _lastFetch;

  bool _tableChecked = false;

  Future<bool> _ensureTable() async {
    if (_tableChecked) return true;
    try {
      await _client.from('featured_products').select('id').limit(1);
      _tableChecked = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<CatalogProduct>> getFeatured() async {
    if (_cached.isNotEmpty && _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 5) {
      return _cached;
    }
    try {
      if (!await _ensureTable()) return [];
      final rows = await _client
          .from('featured_products')
          .select('product_id, sort_order')
          .order('sort_order', ascending: true);

      if (rows.isEmpty) return [];

      final ids = (rows as List).map((r) => r['product_id'] as int).toList();

      final products = await _client
          .from('product_catalogus')
          .select()
          .inFilter('id', ids)
          .eq('geblokkeerd', false);

      final productMap = <int, CatalogProduct>{};
      for (final Map<String, dynamic> row in products) {
        final p = CatalogProduct.fromJson(row);
        if (p.id != null) productMap[p.id!] = p;
      }

      _cached = ids.where((id) => productMap.containsKey(id)).map((id) => productMap[id]!).toList();
      _lastFetch = DateTime.now();
      return _cached;
    } catch (_) {
      return [];
    }
  }

  Future<List<int>> getFeaturedIds() async {
    try {
      if (!await _ensureTable()) return [];
      final rows = await _client
          .from('featured_products')
          .select('product_id')
          .order('sort_order', ascending: true);
      return (rows as List).map((r) => r['product_id'] as int).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> setFeatured(List<int> productIds) async {
    if (!await _ensureTable()) throw Exception('Tabel featured_products niet gevonden. Voer eerst de SQL uit.');
    await _client.from('featured_products').delete().neq('id', 0);
    if (productIds.isEmpty) return;
    final inserts = <Map<String, dynamic>>[];
    for (var i = 0; i < productIds.length; i++) {
      inserts.add({'product_id': productIds[i], 'sort_order': i});
    }
    await _client.from('featured_products').insert(inserts);
    _cached = [];
    _lastFetch = null;
  }

  Future<void> addFeatured(int productId) async {
    if (!await _ensureTable()) return;
    final current = await getFeaturedIds();
    if (current.contains(productId)) return;
    current.add(productId);
    await setFeatured(current);
  }

  Future<void> removeFeatured(int productId) async {
    if (!await _ensureTable()) return;
    final current = await getFeaturedIds();
    current.remove(productId);
    await setFeatured(current);
  }
}
