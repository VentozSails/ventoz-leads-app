import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_service.dart';
import '../services/vat_service.dart';
import '../services/cart_service.dart';
import '../services/pricing_service.dart';
import '../services/shipping_service.dart';
import '../models/catalog_product.dart';
import 'checkout_screen.dart';

class GuestCheckoutScreen extends StatefulWidget {
  const GuestCheckoutScreen({super.key});

  @override
  State<GuestCheckoutScreen> createState() => _GuestCheckoutScreenState();
}

class _GuestCheckoutScreenState extends State<GuestCheckoutScreen> {
  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC8A85C);

  final _formKey = GlobalKey<FormState>();
  final _voornaamCtrl = TextEditingController();
  final _achternaamCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefoonCtrl = TextEditingController();
  final _straatCtrl = TextEditingController();
  final _huisnummerCtrl = TextEditingController();
  final _postcodeCtrl = TextEditingController();
  final _woonplaatsCtrl = TextEditingController();
  String _landCode = 'NL';

  final _cartService = CartService();

  static const _countries = [
    ('NL', 'Nederland'),
    ('BE', 'België'),
    ('DE', 'Duitsland'),
    ('FR', 'Frankrijk'),
    ('GB', 'Verenigd Koninkrijk'),
    ('AT', 'Oostenrijk'),
    ('DK', 'Denemarken'),
    ('SE', 'Zweden'),
    ('IT', 'Italië'),
    ('ES', 'Spanje'),
    ('PL', 'Polen'),
  ];

  @override
  void dispose() {
    _voornaamCtrl.dispose();
    _achternaamCtrl.dispose();
    _emailCtrl.dispose();
    _telefoonCtrl.dispose();
    _straatCtrl.dispose();
    _huisnummerCtrl.dispose();
    _postcodeCtrl.dispose();
    _woonplaatsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text('Afrekenen als gast', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/winkelwagen'),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 16, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionTitle('Uw gegevens'),
                const SizedBox(height: 16),
                _card([
                  Row(children: [
                    Expanded(child: _field(_voornaamCtrl, 'Voornaam', required: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _field(_achternaamCtrl, 'Achternaam', required: true)),
                  ]),
                  const SizedBox(height: 12),
                  _field(_emailCtrl, 'E-mailadres', required: true, keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Vereist';
                      if (!VatService.isValidEmail(v.trim())) return 'Ongeldig e-mailadres';
                      return null;
                    }),
                  const SizedBox(height: 12),
                  _field(_telefoonCtrl, 'Telefoonnummer', keyboardType: TextInputType.phone),
                ]),
                const SizedBox(height: 24),
                _sectionTitle('Verzendadres'),
                const SizedBox(height: 16),
                _card([
                  Row(children: [
                    Expanded(flex: 3, child: _field(_straatCtrl, 'Straat', required: true)),
                    const SizedBox(width: 12),
                    Expanded(flex: 1, child: _field(_huisnummerCtrl, 'Nr.', required: true)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(flex: 2, child: _field(_postcodeCtrl, 'Postcode', required: true)),
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: _field(_woonplaatsCtrl, 'Woonplaats', required: true)),
                  ]),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _landCode,
                    decoration: InputDecoration(
                      labelText: 'Land',
                      labelStyle: GoogleFonts.dmSans(fontSize: 14),
                    ),
                    items: _countries.map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2, style: GoogleFonts.dmSans(fontSize: 14)))).toList(),
                    onChanged: (v) => setState(() => _landCode = v ?? 'NL'),
                  ),
                ]),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.payment, size: 20),
                    label: Text('Verder naar betaling', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _navy,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _proceed,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/inloggen?redirect=/winkelwagen'),
                    child: Text('Heb je al een account? Log in', style: GoogleFonts.dmSans(color: _navy, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: GoogleFonts.dmSerifDisplay(fontSize: 20, color: _navy));
  }

  Widget _card(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {
    bool required = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.dmSans(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.dmSans(fontSize: 14),
      ),
      validator: validator ?? (required ? (v) => (v == null || v.trim().isEmpty) ? 'Vereist' : null : null),
    );
  }

  void _proceed() {
    if (!_formKey.currentState!.validate()) return;

    final adres = '${_straatCtrl.text.trim()} ${_huisnummerCtrl.text.trim()}';
    final guestUser = AppUser(
      email: _emailCtrl.text.trim(),
      voornaam: _voornaamCtrl.text.trim(),
      achternaam: _achternaamCtrl.text.trim(),
      adres: adres,
      postcode: _postcodeCtrl.text.trim(),
      woonplaats: _woonplaatsCtrl.text.trim(),
      telefoon: _telefoonCtrl.text.trim(),
      landCode: _landCode,
      isParticulier: true,
    );

    final subtotalExcl = _cartService.subtotalExcl;
    final dummyProduct = CatalogProduct(naam: '', prijs: 100);
    final bd = PricingService.calculate(product: dummyProduct, user: guestUser);
    final vatRate = bd.vatRate;
    final reverseCharge = bd.reverseCharge;
    final vatAmount = reverseCharge ? 0.0 : subtotalExcl * (vatRate / 100);
    final shippingRate = ShippingService.getRate(_landCode);
    final shippingCost = shippingRate.cost;
    final total = subtotalExcl + vatAmount + shippingCost;

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CheckoutScreen(
        appUser: guestUser,
        cartItems: _cartService.items,
        subtotalExcl: subtotalExcl,
        vatRate: vatRate,
        vatAmount: vatAmount,
        reverseCharge: reverseCharge,
        shippingCost: shippingCost,
        total: total,
      ),
    )).then((orderPlaced) {
      if (orderPlaced == true) {
        _cartService.clear();
        if (mounted) _showAccountOffer();
      }
    });
  }

  void _showAccountOffer() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AccountOfferDialog(
        email: _emailCtrl.text.trim(),
        voornaam: _voornaamCtrl.text.trim(),
        achternaam: _achternaamCtrl.text.trim(),
        adres: '${_straatCtrl.text.trim()} ${_huisnummerCtrl.text.trim()}'.trim(),
        postcode: _postcodeCtrl.text.trim(),
        woonplaats: _woonplaatsCtrl.text.trim(),
        telefoon: _telefoonCtrl.text.trim(),
        landCode: _landCode,
      ),
    ).then((_) {
      if (mounted) context.go('/');
    });
  }
}

class _AccountOfferDialog extends StatefulWidget {
  final String email;
  final String voornaam;
  final String achternaam;
  final String adres;
  final String postcode;
  final String woonplaats;
  final String telefoon;
  final String landCode;

  const _AccountOfferDialog({
    required this.email,
    required this.voornaam,
    required this.achternaam,
    this.adres = '',
    this.postcode = '',
    this.woonplaats = '',
    this.telefoon = '',
    this.landCode = 'NL',
  });

  @override
  State<_AccountOfferDialog> createState() => _AccountOfferDialogState();
}

class _AccountOfferDialogState extends State<_AccountOfferDialog> {
  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC8A85C);

  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _creating = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(children: [
        const Icon(Icons.check_circle, color: Color(0xFF43A047), size: 48),
        const SizedBox(height: 12),
        Text('Bestelling geplaatst!', style: GoogleFonts.dmSerifDisplay(fontSize: 22, color: _navy)),
      ]),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Wil je een account aanmaken? Dan kun je je bestellingen terugvinden en sneller afrekenen.',
            style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF64748B), height: 1.5),
          ),
          const SizedBox(height: 16),
          Text('E-mail: ${widget.email}', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            style: GoogleFonts.dmSans(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Wachtwoord',
              labelStyle: GoogleFonts.dmSans(fontSize: 14),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              helperText: 'Min. 8 tekens, hoofdletter, cijfer, speciaal teken',
              helperStyle: GoogleFonts.dmSans(fontSize: 11),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: true,
            style: GoogleFonts.dmSans(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Bevestig wachtwoord',
              labelStyle: GoogleFonts.dmSans(fontSize: 14),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.red)),
          ],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Nee, bedankt', style: GoogleFonts.dmSans(color: const Color(0xFF64748B))),
        ),
        ElevatedButton(
          onPressed: _creating ? null : _createAccount,
          style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: _navy),
          child: _creating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('Account aanmaken', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Future<void> _createAccount() async {
    final pw = _passwordCtrl.text;
    if (pw.length < 8) { setState(() => _error = 'Wachtwoord moet minimaal 8 tekens zijn'); return; }
    if (!pw.contains(RegExp(r'[A-Z]'))) { setState(() => _error = 'Voeg een hoofdletter toe'); return; }
    if (!pw.contains(RegExp(r'[0-9]'))) { setState(() => _error = 'Voeg een cijfer toe'); return; }
    if (!pw.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) { setState(() => _error = 'Voeg een speciaal teken toe'); return; }
    if (pw != _confirmCtrl.text) { setState(() => _error = 'Wachtwoorden komen niet overeen'); return; }

    setState(() { _creating = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signUp(
        email: widget.email,
        password: pw,
        data: {
          'voornaam': widget.voornaam,
          'achternaam': widget.achternaam,
        },
      );

      try {
        await Supabase.instance.client.from('ventoz_users').upsert({
          'email': widget.email,
          'voornaam': widget.voornaam,
          'achternaam': widget.achternaam,
          if (widget.adres.isNotEmpty) 'adres': widget.adres,
          if (widget.postcode.isNotEmpty) 'postcode': widget.postcode,
          if (widget.woonplaats.isNotEmpty) 'woonplaats': widget.woonplaats,
          if (widget.telefoon.isNotEmpty) 'telefoon': widget.telefoon,
          'land_code': widget.landCode,
        }, onConflict: 'email');
      } catch (_) {}
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account aangemaakt! Controleer je e-mail.'), backgroundColor: Color(0xFF43A047)),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error creating guest order: $e');
      if (mounted) setState(() { _creating = false; _error = 'Er is een fout opgetreden. Probeer het opnieuw.'; });
    }
  }
}
