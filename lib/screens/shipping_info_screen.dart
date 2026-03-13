import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/shipping_service.dart';
import '../l10n/locale_provider.dart';
import '../widgets/site_footer.dart';

class ShippingInfoScreen extends StatefulWidget {
  const ShippingInfoScreen({super.key});

  @override
  State<ShippingInfoScreen> createState() => _ShippingInfoScreenState();
}

class _ShippingInfoScreenState extends State<ShippingInfoScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _accent = Color(0xFF1B4965);

  final _locale = LocaleProvider();

  @override
  void initState() {
    super.initState();
    _locale.addListener(_rebuild);
  }

  @override
  void dispose() {
    _locale.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = _locale.l;
    final lang = _locale.lang;
    final rates = ShippingService.allRatesLocalized(lang);
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _buildHeader(l)),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 16, vertical: 28),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA5D6A7)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.local_shipping, color: Color(0xFF2E7D32), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l.t('verzend_gratis_nl'),
                          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF2E7D32)),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  _buildTable(rates, lang, l, isWide),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.info_outline, size: 16, color: Color(0xFF78909C)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l.t('verzend_info_note'),
                          style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B), height: 1.5),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 28),
                  _buildPaymentMethods(l),
                ]),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        const SliverToBoxAdapter(child: SiteFooter()),
      ]),
    );
  }

  Widget _buildHeader(dynamic l) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, _accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/ventoz_logo.png', width: 40, height: 40),
              ),
              const SizedBox(width: 14),
              Text(
                l.t('verzend_titel'),
                style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              l.t('verzend_subtitel'),
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFFB0BEC5), height: 1.5),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildPaymentMethods(dynamic l) {
    const methods = <(String, Color)>[
      ('iDEAL', Color(0xFFCC0066)),
      ('Bancontact', Color(0xFF005498)),
      ('Creditcard', Color(0xFF1A1F71)),
      ('MasterCard', Color(0xFFEB001B)),
      ('VISA', Color(0xFF1A1F71)),
      ('Maestro', Color(0xFF0099DF)),
      ('V PAY', Color(0xFF1A1F71)),
      ('PayPal', Color(0xFF003087)),
      ('Apple Pay', Color(0xFF333333)),
      ('Google Pay', Color(0xFF4285F4)),
      ('Klarna', Color(0xFFFFB3C7)),
      ('Riverty', Color(0xFF2B7A4B)),
      ('SOFORT', Color(0xFF3B3B3B)),
      ('Giropay', Color(0xFF003A7D)),
      ('EPS', Color(0xFFC8202F)),
      ('Wero', Color(0xFF003D2E)),
      ('BLIK', Color(0xFF000000)),
      ('Przelewy24', Color(0xFFD42127)),
      ('Trustly', Color(0xFF0EBB52)),
      ('Swish', Color(0xFF00A042)),
      ('MobilePay', Color(0xFF5A78FF)),
      ('Vipps', Color(0xFFFF5B24)),
      ('Bizum', Color(0xFF05C3DD)),
      ('MB Way', Color(0xFFE40520)),
      ('MyBank', Color(0xFF1A3C6E)),
      ('Satispay', Color(0xFFE53935)),
      ('Belfius', Color(0xFF005CA9)),
      ('KBC/CBC', Color(0xFF003D6A)),
      ('Pay By Bank', Color(0xFF00897B)),
      ('SEPA', Color(0xFF2D4B8E)),
      ('Overschrijving', Color(0xFF546E7A)),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.payment, size: 20, color: _navy),
          const SizedBox(width: 10),
          Text(
            l.t('footer_payment'),
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: _navy),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: methods.map((m) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              m.$1,
              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: m.$2, letterSpacing: 0.3),
            ),
          )).toList(),
        ),
      ]),
    );
  }

  Widget _buildTable(List<ShippingRate> rates, String lang, dynamic l, bool isWide) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          color: _navy,
          padding: EdgeInsets.symmetric(horizontal: isWide ? 20 : 12, vertical: 12),
          child: Row(children: [
            Expanded(flex: 3, child: Text(l.t('land'), style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
            Expanded(flex: 2, child: Text(l.t('verzendkosten'), style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
            Expanded(flex: 2, child: Text(l.t('verzend_levertijd'), style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
          ]),
        ),
        ...rates.asMap().entries.map((entry) {
          final rate = entry.value;
          final even = entry.key.isEven;
          final isFree = rate.cost == 0;
          return Container(
            color: even ? Colors.white : const Color(0xFFF8FAFB),
            padding: EdgeInsets.symmetric(horizontal: isWide ? 20 : 12, vertical: 10),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: Text(
                  rate.localizedName(lang),
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: isFree ? FontWeight.w600 : FontWeight.w400, color: _navy),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding: isFree ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2) : EdgeInsets.zero,
                  decoration: isFree
                      ? BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6))
                      : null,
                  child: Text(
                    rate.costFormattedLocalized(lang),
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: isFree ? FontWeight.w700 : FontWeight.w400,
                      color: isFree ? const Color(0xFF2E7D32) : _navy,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(rate.deliveryTime, style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B))),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}
