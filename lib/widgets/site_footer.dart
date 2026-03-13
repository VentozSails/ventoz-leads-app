import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/locale_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/vat_service.dart';

class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  static const _navy = Color(0xFF1B2A4A);
  static const _lightBg = Color(0xFFE8EDF2);
  static const _textDark = Color(0xFF334155);
  static const _textMuted = Color(0xFF64748B);

  AppLocalizations get _l => LocaleProvider().l;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Column(
      children: [
        _buildMainFooter(context, isWide),
        _buildBottomBar(isWide),
      ],
    );
  }

  Widget _buildMainFooter(BuildContext context, bool isWide) {
    return Container(
      color: _lightBg,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 24, vertical: isWide ? 40 : 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildContactColumn()),
                    const SizedBox(width: 32),
                    Expanded(flex: 2, child: _buildNavColumn(context)),
                    const SizedBox(width: 32),
                    Expanded(flex: 4, child: _buildPaymentColumn()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildContactColumn(),
                    const SizedBox(height: 28),
                    _buildNavColumn(context),
                    const SizedBox(height: 28),
                    _buildPaymentColumn(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildContactColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(_l.t('footer_contact')),
        const SizedBox(height: 12),
        _contactRow(Icons.business, 'Ventoz Sails'),
        _contactRow(Icons.location_on_outlined, 'Dorpsstraat 111'),
        _contactRow(Icons.home_outlined, '7948 BN Nijeveen (NL)'),
        const SizedBox(height: 10),
        _contactRowTap(Icons.phone_outlined, 'Igor +31610193845', 'tel:+31610193845'),
        _contactRowTap(Icons.phone_outlined, 'Bart +31645055465', 'tel:+31645055465'),
        _contactRowTap(Icons.email_outlined, 'info@ventoz.nl', 'mailto:info@ventoz.nl'),
        const SizedBox(height: 10),
        _contactRow(Icons.badge_outlined, 'KvK: 64140814'),
        _contactRow(Icons.receipt_long_outlined, 'BTW: NL855539203B01'),
      ],
    );
  }

  Widget _buildNavColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(_l.t('footer_nav')),
        const SizedBox(height: 12),
        _navLink(context, _l.t('nav_assortiment'), '/catalogus'),
        _navLink(context, _l.t('nav_inloggen'), '/inloggen'),
        _navLink(context, _l.t('nav_winkelwagen'), '/winkelwagen'),
        const SizedBox(height: 14),
        _navText('Leveringsvoorwaarden / Terms of Delivery'),
        _navText('Privacy Statement / Datenschutzrichtlinie'),
        _navText('Garantie / Warranty'),
        _navText('Klachten / Complaints'),
        _navText('Retourneren / Returns'),
        _navText('Contact'),
      ],
    );
  }

  Widget _buildPaymentColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(_l.t('footer_payment')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _paymentBadge('iDEAL', const Color(0xFFCC0066)),
            _paymentBadge('Bancontact', const Color(0xFF005498)),
            _paymentBadge('Creditcard', const Color(0xFF1A1F71)),
            _paymentBadge('MasterCard', const Color(0xFFEB001B)),
            _paymentBadge('VISA', const Color(0xFF1A1F71)),
            _paymentBadge('Maestro', const Color(0xFF0099DF)),
            _paymentBadge('V PAY', const Color(0xFF1A1F71)),
            _paymentBadge('PayPal', const Color(0xFF003087)),
            _paymentBadge('Apple Pay', const Color(0xFF333333)),
            _paymentBadge('Google Pay', const Color(0xFF4285F4)),
            _paymentBadge('Klarna', const Color(0xFFFFB3C7)),
            _paymentBadge('Riverty', const Color(0xFF2B7A4B)),
            _paymentBadge('SOFORT', const Color(0xFF3B3B3B)),
            _paymentBadge('Giropay', const Color(0xFF003A7D)),
            _paymentBadge('EPS', const Color(0xFFC8202F)),
            _paymentBadge('Wero', const Color(0xFF003D2E)),
            _paymentBadge('BLIK', const Color(0xFF000000)),
            _paymentBadge('Przelewy24', const Color(0xFFD42127)),
            _paymentBadge('Trustly', const Color(0xFF0EBB52)),
            _paymentBadge('Swish', const Color(0xFF00A042)),
            _paymentBadge('MobilePay', const Color(0xFF5A78FF)),
            _paymentBadge('Vipps', const Color(0xFFFF5B24)),
            _paymentBadge('Bizum', const Color(0xFF05C3DD)),
            _paymentBadge('MB Way', const Color(0xFFE40520)),
            _paymentBadge('MyBank', const Color(0xFF1A3C6E)),
            _paymentBadge('Satispay', const Color(0xFFE53935)),
            _paymentBadge('Belfius', const Color(0xFF005CA9)),
            _paymentBadge('KBC/CBC', const Color(0xFF003D6A)),
            _paymentBadge('Pay By Bank', const Color(0xFF00897B)),
            _paymentBadge('SEPA', const Color(0xFF2D4B8E)),
            _paymentBadge('Overschrijving', const Color(0xFF546E7A)),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool isWide) {
    return Container(
      color: _navy,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 24, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/ventoz_emblem.png', width: 24, height: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '\u00A9 ${DateTime.now().year} Ventoz Sails. ${_l.t('footer_copyright')}',
                  style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.dmSans(fontSize: 12, color: _textDark))),
        ],
      ),
    );
  }

  Widget _contactRowTap(IconData icon, String text, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () { if (VatService.isSafeUrl(url)) launchUrl(Uri.parse(url)); },
        child: Row(
          children: [
            Icon(icon, size: 15, color: _textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF1565C0), decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navLink(BuildContext context, String text, String route) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => context.go(route),
        child: Text(text, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF1565C0))),
      ),
    );
  }

  Widget _navText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(text, style: GoogleFonts.dmSans(fontSize: 11, color: _textMuted)),
    );
  }

  Widget _paymentBadge(String name, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Text(
        name,
        style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3),
      ),
    );
  }
}
