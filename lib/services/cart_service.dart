import '../models/catalog_product.dart';
import 'pricing_service.dart';

class CartItem {
  final CatalogProduct product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  /// Catalog unit price incl. 21% NL VAT (after staffelprijs)
  double get unitPriceInclVat {
    if (product.staffelprijzen != null && product.staffelprijzen!.isNotEmpty) {
      final sorted = product.staffelprijzen!.entries.toList()
        ..sort((a, b) {
          final aq = int.tryParse(a.key.replaceAll('x', '')) ?? 0;
          final bq = int.tryParse(b.key.replaceAll('x', '')) ?? 0;
          return bq.compareTo(aq);
        });
      for (final entry in sorted) {
        final minQty = int.tryParse(entry.key.replaceAll('x', '')) ?? 0;
        if (quantity >= minQty && minQty > 0) return entry.value;
      }
    }
    return product.prijs ?? 0;
  }

  /// Unit price excl. VAT (stripping 21% NL VAT from catalog price)
  double get unitPriceExclVat => PricingService.exclVat(unitPriceInclVat);

  /// Line total excl. VAT
  double get lineTotalExclVat => unitPriceExclVat * quantity;

  /// Line total incl. catalog VAT (21% NL)
  double get lineTotalInclVat => unitPriceInclVat * quantity;

  String get unitPriceFormattedIncl =>
      PricingService.formatEuro(unitPriceInclVat);

  String get unitPriceFormattedExcl =>
      PricingService.formatEuro(unitPriceExclVat);
}

class CartService {
  static final CartService _instance = CartService._();
  factory CartService() => _instance;
  CartService._();

  final Map<String, CartItem> _items = {};

  List<CartItem> get items => _items.values.toList();
  int get totalItems => _items.values.fold(0, (sum, i) => sum + i.quantity);
  bool get isEmpty => _items.isEmpty;
  int get uniqueItems => _items.length;

  /// Subtotal excl. VAT
  double get subtotalExcl => _items.values.fold(0, (sum, i) => sum + i.lineTotalExclVat);

  /// Subtotal incl. catalog VAT
  double get subtotalIncl => _items.values.fold(0, (sum, i) => sum + i.lineTotalInclVat);

  void addToCart(CatalogProduct product, {int quantity = 1}) {
    final key = product.artikelnummer ?? product.naam;
    if (_items.containsKey(key)) {
      _items[key]!.quantity += quantity;
    } else {
      _items[key] = CartItem(product: product, quantity: quantity);
    }
  }

  void removeFromCart(String productId) {
    _items.remove(productId);
  }

  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      _items.remove(productId);
    } else if (_items.containsKey(productId)) {
      _items[productId]!.quantity = quantity;
    }
  }

  void clear() => _items.clear();
}
