import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/locale_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/catalog_product.dart';
import '../services/about_text_service.dart';
import '../services/featured_products_service.dart';
import '../widgets/site_footer.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC8A85C);
  static const _slate = Color(0xFF64748B);

  final _locale = LocaleProvider();
  AppLocalizations get _l => _locale.l;
  String get _lang => _locale.lang;

  List<CatalogProduct> _featured = [];
  int _currentSlide = 0;
  Timer? _slideTimer;
  Map<String, String> _aboutTexts = {};

  @override
  void initState() {
    super.initState();
    _locale.addListener(_onLocaleChanged);
    _loadFeatured();
    _loadAboutText();
  }

  @override
  void dispose() {
    _locale.removeListener(_onLocaleChanged);
    _slideTimer?.cancel();
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadFeatured() async {
    final products = await FeaturedProductsService().getFeatured();
    if (mounted && products.isNotEmpty) {
      setState(() => _featured = products);
      _startSlideTimer();
    }
  }

  Future<void> _loadAboutText() async {
    AboutTextService().invalidateCache();
    final texts = await AboutTextService().getTexts();
    if (mounted && texts.isNotEmpty) {
      setState(() => _aboutTexts = texts);
    }
  }

  String get _aboutText {
    if (_aboutTexts.isNotEmpty) {
      return _aboutTexts[_lang] ?? _aboutTexts['en'] ?? _aboutTexts['nl'] ?? _l.t('about_text');
    }
    return _l.t('about_text');
  }

  void _startSlideTimer() {
    _slideTimer?.cancel();
    if (_featured.length <= 1) return;
    _slideTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (mounted) {
        setState(() => _currentSlide = (_currentSlide + 1) % _featured.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.of(context).size.height;
    final navBarHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
    final windowPadding = MediaQuery.of(context).padding.bottom;
    final availableHeight = viewportHeight - navBarHeight - windowPadding;
    final isWide = MediaQuery.of(context).size.width >= 800;
    final uspHeight = isWide ? 140.0 : 170.0;
    final heroHeight = (availableHeight - uspHeight).clamp(isWide ? 440.0 : 340.0, 900.0);

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHero(context, heroHeight),
          _buildUspBar(context),
          const SiteFooter(),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, double targetHeight) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return SizedBox(
      width: double.infinity,
      height: targetHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.asset('assets/login_bg.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF37474F).withValues(alpha: 0.65),
                      const Color(0xFF37474F).withValues(alpha: 0.45),
                      const Color(0xFF37474F).withValues(alpha: 0.25),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 64 : 24,
                  vertical: isWide ? 72 : 48,
                ),
                child: isWide ? _heroWide(context) : _heroNarrow(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroWide(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          flex: 5,
          child: _buildAboutHero(context),
        ),
        const SizedBox(width: 40),
        Expanded(
          flex: 4,
          child: _buildProductSlider(context),
        ),
      ]),
    );
  }

  Widget _heroNarrow(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 16),
      _buildAboutHero(context, center: true),
      const SizedBox(height: 24),
      if (_featured.isNotEmpty) ...[
        _buildProductSlider(context),
        const SizedBox(height: 20),
      ],
    ]);
  }

  Widget _buildAboutHero(BuildContext context, {bool center = false}) {
    const btnHeight = 50.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 360),
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.white.withValues(alpha: 0.6), blurRadius: 28, spreadRadius: 6),
                    BoxShadow(color: Colors.white.withValues(alpha: 0.35), blurRadius: 50, spreadRadius: 10),
                    BoxShadow(color: Colors.white.withValues(alpha: 0.15), blurRadius: 80, spreadRadius: 16),
                  ],
                ),
                child: Image.asset(
                  'assets/ventoz_text_logo_transparent.png',
                  height: 44,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 26),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                _aboutText,
                style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white, height: 1.75),
                textAlign: TextAlign.left,
              ),
            ),
          ]),
        ),
        Positioned(
          left: 0, right: 0, bottom: -(btnHeight / 2),
          child: Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow, size: 18),
              label: Text(_l.t('hero_cta'), style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 14)),
              onPressed: () => context.go('/catalogus'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _navy,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 6,
                shadowColor: _gold.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutCard() {
    return Container(
      constraints: const BoxConstraints(minHeight: 360),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 32, offset: const Offset(0, 10)),
          BoxShadow(color: _gold.withValues(alpha: 0.15), blurRadius: 40, spreadRadius: -4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/ventoz_emblem.png', width: 36, height: 36),
            ),
            const SizedBox(width: 10),
            Text(_l.t('about_title'), style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700, color: _navy)),
          ]),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _aboutText,
                style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF475569), height: 1.65),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => context.go('/catalogus'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _navy,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(_l.t('hero_cta'), style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildProductSlider(BuildContext context) {
    if (_featured.isEmpty) {
      return _buildAboutCard();
    }

    final product = _featured[_currentSlide % _featured.length];
    return GestureDetector(
      onTap: () => context.push('/product/${product.id}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 360),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 32, offset: const Offset(0, 10)),
            BoxShadow(color: _gold.withValues(alpha: 0.15), blurRadius: 40, spreadRadius: -4),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Expanded(
            flex: 7,
            child: Stack(children: [
              Positioned.fill(
                child: Container(color: Colors.white.withValues(alpha: 0.6)),
              ),
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: product.displayAfbeeldingUrl != null
                      ? Image.network(
                          product.displayAfbeeldingUrl!,
                          key: ValueKey(product.id),
                          fit: BoxFit.contain,
                          width: double.infinity,
                          errorBuilder: (_, _, _) => Container(
                            color: Colors.white.withValues(alpha: 0.5),
                            child: const Center(child: Icon(Icons.sailing, size: 48, color: Color(0xFFB0C4DE))),
                          ),
                        )
                      : Container(
                          key: ValueKey(product.id),
                          color: Colors.white.withValues(alpha: 0.5),
                          child: const Center(child: Icon(Icons.sailing, size: 48, color: Color(0xFFB0C4DE))),
                        ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.1),
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.15),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),
              if (product.categorie != null)
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _navy.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(6)),
                    child: Text(product.categorieLabelForLang(_lang), style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              if (_featured.length > 1) ...[
                Positioned(
                  left: 4, top: 0, bottom: 0,
                  child: Center(
                    child: _SliderArrow(
                      icon: Icons.chevron_left,
                      onTap: () => setState(() {
                        _currentSlide = (_currentSlide - 1 + _featured.length) % _featured.length;
                        _startSlideTimer();
                      }),
                    ),
                  ),
                ),
                Positioned(
                  right: 4, top: 0, bottom: 0,
                  child: Center(
                    child: _SliderArrow(
                      icon: Icons.chevron_right,
                      onTap: () => setState(() {
                        _currentSlide = (_currentSlide + 1) % _featured.length;
                        _startSlideTimer();
                      }),
                    ),
                  ),
                ),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.naamForLang(_lang), maxLines: 2, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: _navy, height: 1.3)),
              const SizedBox(height: 8),
              Row(children: [
                  Text(product.prijsFormatted, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(6)),
                    child: Text(_l.t('bekijk_product'), style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: _navy)),
                  ),
                ]),
                if (_featured.length > 1) ...[
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_featured.length, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _currentSlide ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _currentSlide ? _gold : const Color(0xFFD0D5DD),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    )),
                  ),
                ],
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _buildUspBar(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    final usps = <(IconData, String, String, VoidCallback?, bool)>[
      (Icons.card_giftcard, _l.t('usp_gratis'), _l.t('usp_gratis_sub'), () => context.go('/verzending'), false),
      (Icons.flight_takeoff, _l.t('usp_eu'), _l.t('usp_eu_sub'), null, false),
      (Icons.access_time, _l.t('usp_voorraad'), _l.t('usp_voorraad_sub'), null, false),
      (Icons.verified, _l.t('usp_kwaliteit'), _l.t('usp_kwaliteit_sub'), null, false),
      (Icons.star_rounded, _l.t('usp_reviews'), _l.t('usp_reviews_sub'), () => context.go('/beoordelingen'), true),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      padding: EdgeInsets.symmetric(vertical: isWide ? 28 : 18, horizontal: isWide ? 64 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isWide
              ? Row(children: usps.map((u) => Expanded(child: _uspItem(u.$1, u.$2, u.$3, onTap: u.$4, fiveStars: u.$5))).toList())
              : Wrap(
                  spacing: 8,
                  runSpacing: 14,
                  children: usps.map((u) => SizedBox(width: MediaQuery.of(context).size.width / 2 - 24, child: _uspItem(u.$1, u.$2, u.$3, onTap: u.$4, fiveStars: u.$5))).toList(),
                ),
        ),
      ),
    );
  }

  Widget _uspItem(IconData icon, String title, String subtitle, {VoidCallback? onTap, bool fiveStars = false}) {
    final iconWidget = fiveStars
        ? Container(
            height: 44,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (_) => Icon(Icons.star_rounded, color: _gold, size: 18)),
            ),
          )
        : Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: _gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: _gold, size: 22),
          );
    final content = Column(children: [
      iconWidget,
      const SizedBox(height: 8),
      Text(title, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: _navy), textAlign: TextAlign.center),
      const SizedBox(height: 3),
      Text(subtitle, style: GoogleFonts.dmSans(fontSize: 11, color: _slate), textAlign: TextAlign.center),
    ]);
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2), child: content),
      );
    }
    return content;
  }

}

class _SliderArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SliderArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF1B2A4A).withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
