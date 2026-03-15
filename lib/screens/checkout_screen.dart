import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/cart_service.dart';
import '../services/user_service.dart';
import '../services/order_service.dart';
import '../services/payment_gateway_service.dart';
import '../services/pricing_service.dart';
import '../services/shipping_service.dart';
import '../services/order_email_service.dart';
import '../services/pay_nl_service.dart';
import '../services/buckaroo_service.dart';
import '../services/vat_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../widgets/address_form_fields.dart';
import 'payment_methods_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final AppUser appUser;
  final List<CartItem> cartItems;
  final double subtotalExcl;
  final double vatRate;
  final double vatAmount;
  final bool reverseCharge;
  final double shippingCost;
  final double total;

  const CheckoutScreen({
    super.key,
    required this.appUser,
    required this.cartItems,
    required this.subtotalExcl,
    required this.vatRate,
    required this.vatAmount,
    required this.reverseCharge,
    required this.shippingCost,
    required this.total,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final OrderService _orderService = OrderService();
  final PaymentGatewayService _gatewayService = PaymentGatewayService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _naamCtrl;
  late TextEditingController _straatCtrl;
  late TextEditingController _huisnummerCtrl;
  late TextEditingController _postcodeCtrl;
  late TextEditingController _woonplaatsCtrl;
  late TextEditingController _opmerkingenCtrl;

  late TextEditingController _fStraatCtrl;
  late TextEditingController _fHuisnummerCtrl;
  late TextEditingController _fPostcodeCtrl;
  late TextEditingController _fWoonplaatsCtrl;
  bool _factuurGelijk = true;

  bool _placing = false;
  bool _loadingMethods = true;
  String? _error;
  String _lang = 'nl';
  late AppLocalizations _l = AppLocalizations(_lang);

  late String _selectedLandCode;
  late double _shippingCost;
  late double _total;
  late double _vatAmount;
  late double _vatRate;
  late bool _reverseCharge;

  List<PaymentMethod> _availableMethods = [];
  PaymentMethod? _selectedMethod;

  static final Map<String, String?> _svgCache = {};

  @override
  void initState() {
    super.initState();
    final u = widget.appUser;
    _naamCtrl = TextEditingController(text: u.volledigeNaam);
    final adresParts = _splitAdres(u.adres ?? '');
    _straatCtrl = TextEditingController(text: adresParts.$1);
    _huisnummerCtrl = TextEditingController(text: adresParts.$2);
    _postcodeCtrl = TextEditingController(text: u.postcode ?? '');
    _woonplaatsCtrl = TextEditingController(text: u.woonplaats ?? '');
    _opmerkingenCtrl = TextEditingController();
    final fParts = _splitAdres(u.factuurAdres ?? '');
    _fStraatCtrl = TextEditingController(text: u.hasFactuurAdres ? fParts.$1 : '');
    _fHuisnummerCtrl = TextEditingController(text: u.hasFactuurAdres ? fParts.$2 : '');
    _fPostcodeCtrl = TextEditingController(text: u.factuurPostcode ?? '');
    _fWoonplaatsCtrl = TextEditingController(text: u.factuurWoonplaats ?? '');
    _factuurGelijk = !u.hasFactuurAdres;
    _selectedLandCode = u.landCode;
    _shippingCost = widget.shippingCost;
    _total = widget.total;
    _vatAmount = widget.vatAmount;
    _vatRate = widget.vatRate;
    _reverseCharge = widget.reverseCharge;
    _init();
  }

  Future<void> _init() async {
    final lang = await UserService().getUserLanguage();
    if (mounted) setState(() { _lang = lang; _l = AppLocalizations(lang); });
    await _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _loadingMethods = true);
    try {
      final methods = await _gatewayService.getMethodsForCountry(_selectedLandCode);
      if (mounted) {
        setState(() {
          _availableMethods = methods;
          if (methods.isNotEmpty) _selectedMethod = methods.first;
          _loadingMethods = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Payment methods loading error: $e');
      if (mounted) setState(() => _loadingMethods = false);
    }
  }

  void _onCountryChanged(String newCode) {
    setState(() {
      _selectedLandCode = newCode;
      final shipping = ShippingService.getRate(newCode.toUpperCase());
      _shippingCost = shipping.cost;

      final isEu = VatService.isEuCountry(newCode.toUpperCase());
      if (!isEu) {
        _vatRate = 0;
        _vatAmount = 0;
        _reverseCharge = false;
      } else if (widget.appUser.isBedrijf && widget.appUser.btwGevalideerd && newCode.toUpperCase() != 'NL') {
        _vatRate = 0;
        _vatAmount = 0;
        _reverseCharge = true;
      } else {
        _vatRate = VatService.getVatRate(newCode.toUpperCase());
        _vatAmount = widget.subtotalExcl * (_vatRate / 100);
        _reverseCharge = false;
      }

      _total = widget.subtotalExcl + _vatAmount + _shippingCost;
    });

    _loadPaymentMethods();
  }

  static (String, String) _splitAdres(String adres) {
    final match = RegExp(r'^(.+?)\s+(\d+\S*)$').firstMatch(adres.trim());
    if (match != null) return (match.group(1)!, match.group(2)!);
    return (adres, '');
  }

  String get _combinedAdres {
    final straat = _straatCtrl.text.trim();
    final nr = _huisnummerCtrl.text.trim();
    return nr.isEmpty ? straat : '$straat $nr';
  }

  String get _combinedFactuurAdres {
    if (_factuurGelijk) return _combinedAdres;
    final straat = _fStraatCtrl.text.trim();
    final nr = _fHuisnummerCtrl.text.trim();
    return nr.isEmpty ? straat : '$straat $nr';
  }

  @override
  void dispose() {
    _naamCtrl.dispose();
    _straatCtrl.dispose();
    _huisnummerCtrl.dispose();
    _postcodeCtrl.dispose();
    _woonplaatsCtrl.dispose();
    _opmerkingenCtrl.dispose();
    _fStraatCtrl.dispose();
    _fHuisnummerCtrl.dispose();
    _fPostcodeCtrl.dispose();
    _fWoonplaatsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/ventoz_logo.png', width: 28, height: 28)),
          const SizedBox(width: 10),
          Text(_l.t('afrekenen')),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Form(
            key: _formKey,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                _buildSectionTitle(_l.t('bezorgadres'), icon: Icons.local_shipping_outlined),
                const SizedBox(height: 12),
                _buildAddressForm(),
                const SizedBox(height: 28),
                _buildSectionTitle(_l.t('orderoverzicht'), icon: Icons.receipt_long_outlined),
                const SizedBox(height: 12),
                _buildOrderSummary(),
                const SizedBox(height: 28),
                _buildSectionTitle(_l.t('kies_betaalmethode'), icon: Icons.payment_outlined),
                const SizedBox(height: 12),
                _buildPaymentMethodPicker(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: Color(0xFFE53935), size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFE53935), fontSize: 13))),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: _placing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline, size: 22),
                    label: Text(_placing ? _l.t('bestelling_verwerken') : _l.t('bestelling_plaatsen'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF455A64),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _placing ? null : _placeOrder,
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {IconData? icon}) {
    return Row(children: [
      if (icon != null) ...[
        Icon(icon, size: 22, color: const Color(0xFF455A64)),
        const SizedBox(width: 10),
      ],
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
    ]);
  }

  static const _countryOptions = <String, String>{
    'NL': 'Nederland', 'BE': 'België', 'DE': 'Deutschland', 'FR': 'France',
    'GB': 'United Kingdom', 'ES': 'España', 'IT': 'Italia', 'AT': 'Österreich',
    'CH': 'Schweiz', 'DK': 'Danmark', 'SE': 'Sverige', 'FI': 'Suomi',
    'PL': 'Polska', 'CZ': 'Česko', 'PT': 'Portugal', 'IE': 'Ireland',
    'LU': 'Luxembourg', 'HU': 'Magyarország', 'GR': 'Ελλάδα', 'HR': 'Hrvatska',
    'SK': 'Slovensko', 'SI': 'Slovenija', 'RO': 'România', 'BG': 'България',
    'EE': 'Eesti', 'LV': 'Latvija', 'LT': 'Lietuva', 'MT': 'Malta', 'CY': 'Κύπρος',
  };

  Widget _buildAddressForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF1)),
        boxShadow: [BoxShadow(color: const Color(0xFF455A64).withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF455A64).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.person_outline, size: 20, color: Color(0xFF455A64)),
            ),
            const SizedBox(width: 12),
            Text(_l.t('naam'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          ]),
          const SizedBox(height: 10),
          TextFormField(
            controller: _naamCtrl,
            decoration: InputDecoration(
              hintText: _l.t('naam'),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF455A64), width: 1.5)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            validator: (v) => v == null || v.isEmpty ? _l.t('verplicht') : null,
          ),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF455A64).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF455A64)),
            ),
            const SizedBox(width: 12),
            Text(_l.t('bezorgadres'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          ]),
          const SizedBox(height: 10),
          AddressFormFields(
            postcodeCtrl: _postcodeCtrl,
            huisnummerCtrl: _huisnummerCtrl,
            straatCtrl: _straatCtrl,
            woonplaatsCtrl: _woonplaatsCtrl,
            landCode: _selectedLandCode,
            t: _l.t,
          ),
          const SizedBox(height: 14),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF455A64).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.public, size: 20, color: Color(0xFF455A64)),
            ),
            const SizedBox(width: 12),
            Text(_l.t('land'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _countryOptions.containsKey(_selectedLandCode.toUpperCase()) ? _selectedLandCode.toUpperCase() : 'NL',
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF455A64), width: 1.5)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                isExpanded: true,
                items: _countryOptions.entries.map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text('${_countryFlag(e.key)}  ${e.value}', style: const TextStyle(fontSize: 14)),
                )).toList(),
                onChanged: (v) { if (v != null) _onCountryChanged(v); },
              ),
            ),
          ]),
          if (widget.appUser.isBedrijf && widget.appUser.bedrijfsnaam != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDCE5F5)),
              ),
              child: Row(children: [
                const Icon(Icons.business, size: 18, color: Color(0xFF455A64)),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.appUser.bedrijfsnaam!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ],
          if (widget.appUser.btwNummer != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDCE5F5)),
              ),
              child: Row(children: [
                const Icon(Icons.receipt_long, size: 18, color: Color(0xFF455A64)),
                const SizedBox(width: 10),
                Text('${_l.t('btw')}: ${widget.appUser.btwNummer}', style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B))),
                if (_reverseCharge) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(6)),
                    child: Text(_l.t('btw_verlegd'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1565C0))),
                  ),
                ],
              ]),
            ),
          ],
          const SizedBox(height: 20),
          CheckboxListTile(
            value: _factuurGelijk,
            onChanged: (v) => setState(() => _factuurGelijk = v ?? true),
            title: Text(_l.t('factuuradres_gelijk'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          if (!_factuurGelijk) ...[
            const SizedBox(height: 12),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.receipt_outlined, size: 20, color: Color(0xFFF57F17)),
              ),
              const SizedBox(width: 12),
              Text(_l.t('factuuradres'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
            ]),
            const SizedBox(height: 10),
            AddressFormFields(
              postcodeCtrl: _fPostcodeCtrl,
              huisnummerCtrl: _fHuisnummerCtrl,
              straatCtrl: _fStraatCtrl,
              woonplaatsCtrl: _fWoonplaatsCtrl,
              landCode: _selectedLandCode,
              t: _l.t,
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _opmerkingenCtrl,
            decoration: InputDecoration(
              hintText: _l.t('opmerkingen_optioneel'),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF455A64), width: 1.5)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              prefixIcon: const Padding(padding: EdgeInsets.only(left: 12, right: 8), child: Icon(Icons.note_outlined, size: 18, color: Color(0xFF78909C))),
            ),
            maxLines: 2,
          ),
        ]),
      ),
    );
  }

  static String _countryFlag(String code) {
    final c = code.toUpperCase();
    if (c.length != 2) return '';
    return String.fromCharCodes([c.codeUnitAt(0) + 0x1F1A5, c.codeUnitAt(1) + 0x1F1A5]);
  }

  Widget _buildOrderSummary() {
    final shipping = ShippingService.getRate(_selectedLandCode.toUpperCase());
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF1)),
        boxShadow: [BoxShadow(color: const Color(0xFF455A64).withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          ...widget.cartItems.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFFF8FAFC), border: Border.all(color: const Color(0xFFE2E8F0))),
                clipBehavior: Clip.antiAlias,
                child: item.product.displayAfbeeldingUrl != null
                    ? Image.network(item.product.displayAfbeeldingUrl!, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.sailing, size: 22, color: Color(0xFFB0C4DE)))
                    : const Icon(Icons.sailing, size: 22, color: Color(0xFFB0C4DE)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.product.naamForLang(_lang), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${item.quantity} × ${item.unitPriceFormattedExcl}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ]),
              ),
              Text(PricingService.formatEuro(item.lineTotalExclVat), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            ]),
          )),
          const Divider(height: 24),
          _row(_l.t('subtotaal_excl_btw'), PricingService.formatEuro(widget.subtotalExcl)),
          const SizedBox(height: 6),
          if (_reverseCharge)
            _row(_l.t('btw'), _l.t('verlegd_icp'), subtle: true)
          else if (_vatRate == 0)
            _row(_l.t('btw'), _l.t('geen_btw_buiten_eu'), subtle: true)
          else
            _row('${_l.t('btw')} ${_vatRate.toStringAsFixed(_vatRate == _vatRate.roundToDouble() ? 0 : 1)}%',
              PricingService.formatEuro(_vatAmount), subtle: true),
          const SizedBox(height: 6),
          _row(
            '${_l.t('verzendkosten')} (${shipping.localizedName(_lang)})',
            _shippingCost == 0 ? _l.t('gratis') : PricingService.formatEuro(_shippingCost),
            subtle: true,
            green: _shippingCost == 0,
          ),
          if (shipping.deliveryTime.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.local_shipping_outlined, size: 13, color: Color(0xFF78909C)),
                  const SizedBox(width: 4),
                  Text('${_l.t('levertijd')}: ${shipping.deliveryTime}', style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
                ]),
              ),
            ),
          const Divider(height: 24),
          _row(_l.t('totaal'), PricingService.formatEuro(_total), bold: true),
        ]),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, bool subtle = false, bool green = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: subtle ? const Color(0xFF64748B) : const Color(0xFF1E293B))),
        Text(value, style: TextStyle(fontSize: bold ? 17 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: green ? const Color(0xFF2E7D32) : (subtle ? const Color(0xFF64748B) : const Color(0xFF1E293B)))),
      ],
    );
  }

  // ─── PAYMENT METHOD PICKER ──────────────────────────────────────────

  Widget _buildPaymentMethodPicker() {
    if (_loadingMethods) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_availableMethods.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8ECF1)),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          const Icon(Icons.info_outline, size: 20, color: Color(0xFF78909C)),
          const SizedBox(width: 8),
          Expanded(child: Text(_l.t('geen_betaalmethoden'), style: const TextStyle(fontSize: 13, color: Color(0xFF78909C)))),
        ]),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF1)),
        boxShadow: [BoxShadow(color: const Color(0xFF455A64).withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            _l.t('kies_betaalmethode_beschrijving'),
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 14),
          ..._availableMethods.map((method) => _buildMethodTile(method)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsScreen())),
            child: Text(
              _l.t('alle_betaalmethoden_bekijken'),
              style: const TextStyle(fontSize: 12, color: Color(0xFF00897B), decoration: TextDecoration.underline),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildMethodTile(PaymentMethod method) {
    final isSelected = _selectedMethod?.id == method.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected ? const Color(0xFFE8F5E9) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selectedMethod = method),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? const Color(0xFF43A047) : const Color(0xFFE2E8F0),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              SizedBox(
                width: 20,
                height: 20,
                child: isSelected
                    ? const Icon(Icons.radio_button_checked, size: 20, color: Color(0xFF43A047))
                    : const Icon(Icons.radio_button_off, size: 20, color: Color(0xFFBDBDBD)),
              ),
              const SizedBox(width: 12),
              _buildMethodLogo(method),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  method.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodLogo(PaymentMethod method) {
    final url = method.imageUrl;
    if (url == null || url.isEmpty) {
      return _methodFallbackIcon(method.name);
    }

    if (url.toLowerCase().endsWith('.svg')) {
      return FutureBuilder<String?>(
        future: _fetchSvg(url),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SizedBox(width: 32, height: 22);
          }
          final svg = snap.data;
          if (svg != null && svg.isNotEmpty) {
            return SizedBox(
              width: 32,
              height: 22,
              child: SvgPicture.string(svg, width: 32, height: 22, fit: BoxFit.contain),
            );
          }
          return _methodFallbackIcon(method.name);
        },
      );
    }

    return Image.network(
      url,
      width: 32,
      height: 22,
      fit: BoxFit.contain,
      errorBuilder: (_, e, s) => _methodFallbackIcon(method.name),
    );
  }

  Widget _methodFallbackIcon(String name) {
    final lc = name.toLowerCase();
    IconData icon;
    if (lc.contains('ideal')) {
      icon = Icons.account_balance;
    } else if (lc.contains('credit') || lc.contains('debit')) {
      icon = Icons.credit_card;
    } else if (lc.contains('paypal')) {
      icon = Icons.account_balance_wallet;
    } else if (lc.contains('apple')) {
      icon = Icons.phone_iphone;
    } else if (lc.contains('google')) {
      icon = Icons.phone_android;
    } else if (lc.contains('klarna') || lc.contains('riverty')) {
      icon = Icons.schedule;
    } else {
      icon = Icons.payment;
    }
    return Icon(icon, size: 22, color: const Color(0xFF78909C));
  }

  static Future<String?> _fetchSvg(String url) async {
    if (_svgCache.containsKey(url)) return _svgCache[url];
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && response.body.contains('<svg')) {
        _svgCache[url] = response.body;
        return response.body;
      }
    } catch (_) {}
    _svgCache[url] = null;
    return null;
  }

  // ─── PAYMENT RETURN URL ──────────────────────────────────────────

  Future<String> _getPaymentReturnUrl() async {
    try {
      final rows = await Supabase.instance.client
          .from('app_settings')
          .select('value')
          .eq('key', 'payment_return_url');
      if (rows.isNotEmpty) {
        final url = rows.first['value'] as String?;
        if (url != null && url.startsWith('https://')) return url;
      }
    } catch (_) {}
    return 'https://ventoz.nl/betaling-voltooid';
  }

  // ─── PLACE ORDER ──────────────────────────────────────────────────

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedMethod == null && _availableMethods.isNotEmpty) {
      setState(() => _error = _l.t('selecteer_betaalmethode'));
      return;
    }

    setState(() { _placing = true; _error = null; });

    try {
      final updatedUser = widget.appUser.copyWith(
        voornaam: _naamCtrl.text.split(' ').first,
        achternaam: _naamCtrl.text.split(' ').skip(1).join(' '),
        adres: _combinedAdres,
        postcode: _postcodeCtrl.text,
        woonplaats: _woonplaatsCtrl.text,
        factuurAdres: _factuurGelijk ? null : _combinedFactuurAdres,
        factuurPostcode: _factuurGelijk ? null : _fPostcodeCtrl.text,
        factuurWoonplaats: _factuurGelijk ? null : _fWoonplaatsCtrl.text,
      );

      final order = await _orderService.createOrder(
        items: widget.cartItems,
        user: updatedUser,
        subtotaal: widget.subtotalExcl,
        btwBedrag: _vatAmount,
        btwPercentage: _vatRate,
        btwVerlegd: _reverseCharge,
        verzendkosten: _shippingCost,
        totaal: _total,
        opmerkingen: _opmerkingenCtrl.text.isNotEmpty ? _opmerkingenCtrl.text : null,
      );

      if (Supabase.instance.client.auth.currentUser != null) {
        try {
          final profileUpdate = updatedUser.copyWith(
            factuurAdres: _factuurGelijk ? null : _combinedFactuurAdres,
            factuurPostcode: _factuurGelijk ? null : _fPostcodeCtrl.text,
            factuurWoonplaats: _factuurGelijk ? null : _fWoonplaatsCtrl.text,
          );
          await UserService().updateOwnProfile(profileUpdate);
        } catch (_) {}
      }

      if (_selectedMethod != null) {
        try {
          final returnUrl = await _getPaymentReturnUrl();
          final result = await _gatewayService.pay(
            order: order,
            method: _selectedMethod!,
            returnUrl: returnUrl,
          );

          if (order.id != null) {
            try {
              await _orderService.updatePaymentReference(order.id!, result.transactionId);
            } catch (e) {
              if (kDebugMode) debugPrint('updatePaymentReference error (non-blocking): $e');
            }
          }

          if (result.paymentUrl.isEmpty) {
            if (mounted) {
              setState(() { _error = '${_l.t('betaling_mislukt')}: Geen betaal-URL ontvangen van ${_selectedMethod!.name}. Probeer een andere betaalmethode.'; });
            }
            return;
          }

          try {
            await launchUrl(Uri.parse(result.paymentUrl), mode: LaunchMode.externalApplication);
          } catch (e) {
            if (mounted) {
              setState(() { _error = 'Kan de betaalpagina niet openen. Kopieer deze URL handmatig:\n${result.paymentUrl}'; });
            }
            return;
          }

          if (!mounted) return;
          await _showPaymentStatusDialog(
            order,
            result.transactionId,
            _selectedMethod!.gateway,
            browserOpened: true,
          );
          return;
        } catch (e) {
          if (order.id != null) {
            try { await _orderService.updateStatus(order.id!, 'concept'); } catch (_) {}
          }
          if (mounted) {
            final errMsg = e.toString().replaceFirst('Exception: ', '');
            setState(() { _error = '${_l.t('betaling_mislukt')}: $errMsg\n\n${_l.t('bestelling_concept')}'; });
          }
          return;
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (kDebugMode) debugPrint('Error placing order: $e');
      if (mounted) {
        final errMsg = e.toString().replaceFirst('Exception: ', '');
        final isRls = errMsg.contains('row-level security') || errMsg.contains('policy') || errMsg.contains('violates');
        final displayMsg = isRls
            ? 'De bestelling kon niet worden opgeslagen. Probeer opnieuw of neem contact op met Ventoz.'
            : '${_l.t('bestelling_mislukt')}: $errMsg';
        setState(() { _error = displayMsg; });
      }
    } finally {
      if (mounted) setState(() { _placing = false; });
    }
  }

  Future<void> _showPaymentStatusDialog(
    Order order,
    String transactionId,
    String gateway, {
    bool browserOpened = true,
  }) async {
    var status = 'PENDING';
    var polling = true;
    Timer? timer;
    var pollCount = 0;
    const maxPolls = 90;
    var emailSent = false;
    String? emailError;
    var orderHandled = false;

    Future<void> handlePaidOrder(String paidStatus) async {
      if (orderHandled) return;
      orderHandled = true;
      final newStatus = paidStatus == 'PAID' ? 'betaald' : 'wacht_op_betaling';
      if (order.id == null) return;
      final updatedOrder = await _orderService.updateStatus(order.id!, newStatus);
      if (updatedOrder != null) {
        try {
          await OrderEmailService().sendOrderConfirmation(updatedOrder);
          emailSent = true;
        } catch (e) {
          emailError = _l.t('email_verzenden_mislukt');
          if (kDebugMode) debugPrint('Auto-send confirmation failed: $e');
        }
      }
    }

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          Future<void> pollOnce() async {
            try {
              pollCount++;
              String newStatus;
              if (gateway == 'buckaroo') {
                newStatus = await BuckarooService().getTransactionStatus(transactionId);
              } else {
                newStatus = await PayNlService().getTransactionStatus(transactionId);
              }
              if (!ctx.mounted) return;

              final terminal = {'PAID', 'FAILED', 'CANCELLED', 'PENDING_PROCESSING'};
              if (terminal.contains(newStatus)) {
                polling = false;
                timer?.cancel();
              }
              if (pollCount >= maxPolls) {
                polling = false;
                timer?.cancel();
              }

              final isPaid = newStatus == 'PAID' || newStatus == 'PENDING_PROCESSING';
              if (isPaid && !orderHandled) {
                setDialogState(() => status = newStatus);
                await handlePaidOrder(newStatus);
                if (ctx.mounted) setDialogState(() {});
              } else {
                setDialogState(() => status = newStatus);
              }
            } catch (e) {
              if (kDebugMode) debugPrint('Payment status poll error: $e');
            }
          }

          if (polling && timer == null) {
            pollOnce();
            timer = Timer.periodic(const Duration(seconds: 4), (_) {
              if (polling) pollOnce();
            });
          }

          IconData icon;
          Color iconColor;
          String title;
          String subtitle;
          bool showClose = false;

          switch (status) {
            case 'PAID':
            case 'PENDING_PROCESSING':
              icon = Icons.check_circle;
              iconColor = const Color(0xFF43A047);
              title = _l.t('betaling_gelukt');
              if (emailSent) {
                subtitle = _l.t('bestelling_bevestigd_email');
              } else if (emailError != null) {
                subtitle = _l.t('bestelling_bevestigd_email_fout');
              } else {
                subtitle = _l.t('bestelling_bevestigd_verwerken');
              }
              showClose = emailSent || emailError != null;
            case 'FAILED':
              icon = Icons.error;
              iconColor = const Color(0xFFE53935);
              title = _l.t('betaling_mislukt');
              subtitle = _l.t('betaling_mislukt_tekst');
              showClose = true;
            case 'CANCELLED':
              icon = Icons.cancel;
              iconColor = const Color(0xFFFF9800);
              title = _l.t('betaling_geannuleerd');
              subtitle = _l.t('betaling_geannuleerd_tekst');
              showClose = true;
            default:
              icon = Icons.hourglass_top;
              iconColor = const Color(0xFF1565C0);
              title = browserOpened
                  ? _l.t('betaling_wachten')
                  : _l.t('betaling_verwerken');
              subtitle = browserOpened
                  ? _l.t('betaling_wachten_tekst')
                  : _l.t('betaling_verwerken_tekst');
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              Icon(icon, size: 56, color: iconColor),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5)),
              if (emailError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                  child: Text(emailError!, style: const TextStyle(fontSize: 11, color: Color(0xFFE65100)), maxLines: 4, overflow: TextOverflow.ellipsis),
                ),
              ],
              if (status == 'PENDING' || (orderHandled && !emailSent && emailError == null)) ...[
                const SizedBox(height: 20),
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ]),
            actions: showClose
                ? [
                    TextButton(
                      onPressed: () {
                        timer?.cancel();
                        Navigator.pop(ctx, status);
                      },
                      child: Text(_l.t('sluiten')),
                    ),
                  ]
                : [
                    TextButton(
                      onPressed: () {
                        timer?.cancel();
                        Navigator.pop(ctx, 'MANUAL_CLOSE');
                      },
                      child: Text(_l.t('annuleren')),
                    ),
                  ],
          );
        });
      },
    );

    timer?.cancel();

    final isPaid = result == 'PAID' || result == 'PENDING_PROCESSING';
    if (isPaid) {
      if (mounted) Navigator.pop(context, true);
    } else {
      if (order.id != null && !orderHandled) {
        await _orderService.updateStatus(order.id!, 'concept');
      }
      if (mounted) setState(() => _placing = false);
    }
  }
}
