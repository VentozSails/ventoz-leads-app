import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/cart_service.dart';
import '../services/user_service.dart';
import '../services/pricing_service.dart';
import '../services/shipping_service.dart';
import '../l10n/app_localizations.dart';
import '../models/catalog_product.dart';
import 'checkout_screen.dart';
import 'guest_checkout_screen.dart';

class CartScreen extends StatefulWidget {
  final AppUser? appUser;
  const CartScreen({super.key, this.appUser});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();
  late AppUser? _appUser;
  String _lang = 'nl';
  late AppLocalizations _l = AppLocalizations(_lang);

  @override
  void initState() {
    super.initState();
    _appUser = widget.appUser;
    if (_appUser == null) _loadUser();
    UserService().getUserLanguage().then((lang) {
      if (mounted) setState(() { _lang = lang; _l = AppLocalizations(lang); });
    });
  }

  Future<void> _loadUser() async {
    final user = await UserService().getCurrentUser();
    if (mounted) setState(() => _appUser = user);
  }

  double get _subtotalExcl => _cartService.subtotalExcl;

  double get _vatRate {
    if (_appUser == null) return 21;
    final dummyProduct = CatalogProduct(naam: '', prijs: 100);
    final bd = PricingService.calculate(product: dummyProduct, user: _appUser!);
    return bd.vatRate;
  }

  bool get _reverseCharge {
    if (_appUser == null) return false;
    final dummyProduct = CatalogProduct(naam: '', prijs: 100);
    final bd = PricingService.calculate(product: dummyProduct, user: _appUser!);
    return bd.reverseCharge;
  }

  double get _vatAmount => _reverseCharge ? 0 : _subtotalExcl * (_vatRate / 100);

  ShippingRate get _shippingRate =>
      ShippingService.getRate(_appUser?.landCode.toUpperCase() ?? 'NL');

  double get _shippingCost => _shippingRate.cost;
  double get _total => _subtotalExcl + _vatAmount + _shippingCost;

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _cartService.items;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/ventoz_logo.png', width: 28, height: 28)),
          const SizedBox(width: 10),
          Text(_l.t('winkelmand')),
          if (items.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: Text('${_cartService.totalItems}', style: const TextStyle(fontSize: 12)),
            ),
          ],
        ]),
        actions: [
          if (items.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(_l.t('leegmaken'), style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => setState(() => _cartService.clear()),
            ),
        ],
      ),
      body: items.isEmpty ? _buildEmpty() : _buildCart(items),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.shopping_cart_outlined, size: 64, color: Color(0xFFB0BEC5)),
        const SizedBox(height: 16),
        Text(_l.t('winkelmand_leeg'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.arrow_back, size: 18),
          label: Text(_l.t('naar_catalogus')),
          onPressed: _goBack,
        ),
      ]),
    );
  }

  Widget _buildCart(List<CartItem> items) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildCartItem(items[i]),
          ),
        ),
        _buildTotalSection(),
      ],
    );
  }

  Widget _buildCartItem(CartItem item) {
    final product = item.product;
    final productKey = product.artikelnummer ?? product.naam;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: product.afbeeldingUrl != null
                  ? Image.network(product.afbeeldingUrl!, width: 64, height: 64, fit: BoxFit.contain,
                      errorBuilder: (_, e, s) => _placeholder())
                  : _placeholder(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.naam, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${item.unitPriceFormattedExcl} ${_l.t('excl_btw')}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                Text('(${item.unitPriceFormattedIncl} ${_l.t('incl')})', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                if (product.artikelnummer != null)
                  Text('${_l.t('art')} ${product.artikelnummer}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              ]),
            ),
            const SizedBox(width: 8),
            _buildQuantitySelector(productKey, item.quantity),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(PricingService.formatEuro(item.lineTotalExclVat),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => setState(() => _cartService.removeFromCart(productKey)),
                  child: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFE53935)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantitySelector(String productId, int quantity) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          onTap: () => setState(() => _cartService.updateQuantity(productId, quantity - 1)),
          child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove, size: 18, color: Color(0xFF64748B))),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 32),
          alignment: Alignment.center,
          child: Text('$quantity', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        InkWell(
          onTap: () => setState(() => _cartService.updateQuantity(productId, quantity + 1)),
          child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add, size: 18, color: Color(0xFF64748B))),
        ),
      ]),
    );
  }

  Widget _buildTotalSection() {
    final rate = _shippingRate;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: Column(
        children: [
          _buildTotalRow(_l.t('subtotaal_excl_btw'), PricingService.formatEuro(_subtotalExcl)),
          const SizedBox(height: 4),
          if (_reverseCharge)
            _buildTotalRow(_l.t('btw'), _l.t('verlegd_icp'), isSubtle: true)
          else if (_vatRate == 0)
            _buildTotalRow(_l.t('btw'), _l.t('geen_btw'), isSubtle: true)
          else
            _buildTotalRow('${_l.t('btw')} ${_vatRate.toStringAsFixed(_vatRate == _vatRate.roundToDouble() ? 0 : 1)}%', PricingService.formatEuro(_vatAmount), isSubtle: true),
          const SizedBox(height: 4),
          _buildTotalRow(
            '${_l.t('verzendkosten')} (${rate.localizedName(_lang)})',
            rate.cost == 0 ? _l.t('gratis') : PricingService.formatEuro(rate.cost),
            isSubtle: true,
            isGreen: rate.cost == 0,
          ),
          if (rate.deliveryTime.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Text('${_l.t('levertijd')}: ${rate.deliveryTime}', style: const TextStyle(fontSize: 10, color: Color(0xFF78909C))),
            ),
          const Divider(height: 16),
          _buildTotalRow(_l.t('totaal'), PricingService.formatEuro(_total), isBold: true),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.payment, size: 20),
              label: Text(_l.t('afrekenen'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF455A64),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _goToCheckout(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false, bool isSubtle = false, bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          fontSize: isBold ? 16 : 14,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: isSubtle ? const Color(0xFF64748B) : const Color(0xFF1E293B),
        )),
        Text(value, style: TextStyle(
          fontSize: isBold ? 18 : 14,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          color: isGreen ? const Color(0xFF2E7D32) : (isSubtle ? const Color(0xFF64748B) : const Color(0xFF1E293B)),
        )),
      ],
    );
  }

  void _goToCheckout() {
    if (_appUser != null) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          appUser: _appUser!,
          cartItems: _cartService.items,
          subtotalExcl: _subtotalExcl,
          vatRate: _vatRate,
          vatAmount: _vatAmount,
          reverseCharge: _reverseCharge,
          shippingCost: _shippingCost,
          total: _total,
        ),
      )).then((orderPlaced) {
        if (orderPlaced == true) {
          _cartService.clear();
          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(_l.t('bestelling_succesvol')),
              backgroundColor: const Color(0xFF43A047),
            ));
          }
        }
      });
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => const GuestCheckoutScreen(),
      ));
    }
  }

  Widget _placeholder() => Container(width: 64, height: 64, color: const Color(0xFFF5F7F8), child: const Icon(Icons.sailing, color: Color(0xFFB0BEC5)));
}
