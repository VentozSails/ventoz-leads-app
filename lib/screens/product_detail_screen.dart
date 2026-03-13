import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/locale_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/catalog_product.dart';
import '../services/web_scraper_service.dart';
import '../services/cart_service.dart';
import '../services/pricing_service.dart';
import '../widgets/site_footer.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC8A85C);
  static const _slate = Color(0xFF64748B);

  final _cartService = CartService();
  final _locale = LocaleProvider();
  CatalogProduct? _product;
  bool _loading = true;
  int _quantity = 1;
  int _selectedImageIndex = 0;

  String get _lang => _locale.lang;
  AppLocalizations get _l => _locale.l;

  @override
  void initState() {
    super.initState();
    _locale.addListener(_onLocaleChanged);
    _load();
  }

  @override
  void dispose() {
    _locale.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final products = await WebScraperService().fetchCatalog();
      final match = products.where((p) => p.id == widget.productId && !p.geblokkeerd);
      if (mounted) {
        setState(() {
          _product = match.isNotEmpty ? match.first : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_product == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.sailing, size: 48, color: Color(0xFFB0C4DE)),
          const SizedBox(height: 16),
          Text(_l.t('product_niet_gevonden'), style: GoogleFonts.dmSans(fontSize: 16, color: _slate)),
          const SizedBox(height: 16),
          TextButton(onPressed: _goBack, child: Text(_l.t('terug_assortiment'))),
        ]),
      );
    }

    final p = _product!;
    final isWide = MediaQuery.of(context).size.width >= 900;
    return SingleChildScrollView(
      child: Column(children: [
        _buildBackBar(),
        _buildBreadcrumb(p),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: isWide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 5, child: _buildImage(p)),
                    const SizedBox(width: 40),
                    Expanded(flex: 5, child: _buildDetails(p)),
                  ])
                : Column(children: [
                    _buildImage(p),
                    const SizedBox(height: 24),
                    _buildDetails(p),
                  ]),
          ),
        ),
        const SiteFooter(),
      ]),
    );
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/catalogus');
    }
  }

  Widget _buildBackBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: _navy,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.arrow_back, size: 16, color: Colors.white70),
              label: Text(_l.t('terug_assortiment'), style: GoogleFonts.dmSans(fontSize: 13, color: Colors.white70)),
              onPressed: _goBack,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumb(CatalogProduct p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: const Color(0xFFF0F4FF),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(children: [
            InkWell(
              onTap: () => context.go('/'),
              child: Text('Home', style: GoogleFonts.dmSans(fontSize: 13, color: _slate)),
            ),
            Text('  /  ', style: GoogleFonts.dmSans(fontSize: 13, color: _slate)),
            InkWell(
              onTap: () => context.go('/catalogus'),
              child: Text(_l.t('nav_assortiment'), style: GoogleFonts.dmSans(fontSize: 13, color: _slate)),
            ),
            if (p.categorie != null) ...[
              Text('  /  ', style: GoogleFonts.dmSans(fontSize: 13, color: _slate)),
              InkWell(
                onTap: () => context.go('/catalogus?categorie=${p.categorie}'),
                child: Text(p.categorieLabel, style: GoogleFonts.dmSans(fontSize: 13, color: _slate)),
              ),
            ],
            Text('  /  ', style: GoogleFonts.dmSans(fontSize: 13, color: _slate)),
            Flexible(child: Text(p.naamForLang(_lang), overflow: TextOverflow.ellipsis, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: _navy))),
          ]),
        ),
      ),
    );
  }

  Widget _buildImage(CatalogProduct p) {
    final images = p.alleAfbeeldingen;
    if (images.isEmpty) {
      return AspectRatio(aspectRatio: 1, child: _placeholder());
    }

    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.network(
            images[_selectedImageIndex % images.length],
            fit: BoxFit.contain,
            width: double.infinity,
            errorBuilder: (_, _, _) => _placeholder(),
          ),
        ),
      ),
      if (images.length > 1) ...[
        const SizedBox(height: 12),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => setState(() => _selectedImageIndex = i),
              child: Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: i == _selectedImageIndex ? _navy : const Color(0xFFE2E8F0),
                    width: i == _selectedImageIndex ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(images[i], fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 16, color: Color(0xFFB0C4DE))),
              ),
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _buildDetails(CatalogProduct p) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (p.categorie != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: _navy.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(4)),
          child: Text(p.categorieLabel, style: GoogleFonts.dmSans(fontSize: 12, color: _navy, fontWeight: FontWeight.w600)),
        ),
      const SizedBox(height: 12),
      Text(p.naamForLang(_lang), style: GoogleFonts.dmSerifDisplay(fontSize: 26, color: _navy)),
      if (p.artikelnummer != null) ...[
        const SizedBox(height: 4),
        Text('Art. ${p.artikelnummer}', style: GoogleFonts.dmSans(fontSize: 13, color: _slate)),
      ],
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(p.prijsFormatted, style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w700, color: _navy)),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(_l.t('incl_btw'), style: GoogleFonts.dmSans(fontSize: 13, color: _slate)),
        ),
      ]),
      if (p.displayPrijs != null) ...[
        const SizedBox(height: 2),
        Text('${PricingService.formatEuro(PricingService.exclVat(p.displayPrijs!))} excl. BTW',
          style: GoogleFonts.dmSans(fontSize: 13, color: _slate)),
      ],
      const SizedBox(height: 12),
      Row(children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: p.inStock ? Colors.green : Colors.red.shade300),
        ),
        const SizedBox(width: 8),
        Text(p.inStock ? _l.t('op_voorraad') : _l.t('niet_op_voorraad'), style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: p.inStock ? Colors.green.shade700 : Colors.red)),
      ]),

      if (p.staffelprijzen != null && p.staffelprijzen!.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(_l.t('staffelprijzen'), style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
        const SizedBox(height: 8),
        ...p.staffelprijzen!.entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Text('Vanaf ${e.key}:', style: GoogleFonts.dmSans(fontSize: 13, color: _slate)),
            const SizedBox(width: 8),
            Text(PricingService.formatEuro(e.value), style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
          ]),
        )),
      ],

      // ── Beschrijving (inclusief specs, materiaal, inclusief als doorlopende tekst) ──
      if ((p.beschrijvingForLang(_lang) ?? '').isNotEmpty) ...[
        const SizedBox(height: 20),
        ..._buildFormattedDescription(p.beschrijvingForLang(_lang)!),
      ],

      const SizedBox(height: 24),
      if (p.inStock) ...[
        Row(children: [
          Container(
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null, iconSize: 18, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
              SizedBox(width: 32, child: Text('$_quantity', textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600))),
              IconButton(icon: const Icon(Icons.add, size: 18), onPressed: () => setState(() => _quantity++), iconSize: 18, constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: Text(_l.t('in_wagen'), style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold, foregroundColor: _navy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  _cartService.addToCart(p, quantity: _quantity);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${p.naamForLang(_lang)} ($_quantity×) ${_l.t('toegevoegd')}'), duration: const Duration(seconds: 2)),
                  );
                },
              ),
            ),
          ),
        ]),
      ],
    ]);
  }

  static final _specLinePattern = RegExp(r'^(Voorlijk|Achterlijk|Onderlijk|Bovenlijk|Oppervlakte|Luff|Foot|Sail Area)\s*:\s*(.+)$', caseSensitive: false);

  List<Widget> _buildFormattedDescription(String text) {
    final paragraphs = text.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
    if (paragraphs.isEmpty) {
      return [Text(text, style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF334155), height: 1.6))];
    }
    final widgets = <Widget>[];
    for (var i = 0; i < paragraphs.length; i++) {
      final para = paragraphs[i].trim();

      if (para == '---') {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      if (i > 0) widgets.add(const SizedBox(height: 12));

      if (para.startsWith('• ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('•  ', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
            Expanded(child: Text(para.substring(2), style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF334155), height: 1.5))),
          ]),
        ));
      } else if (_specLinePattern.hasMatch(para)) {
        final m = _specLinePattern.firstMatch(para)!;
        widgets.add(Row(children: [
          Text('${m.group(1)}: ', style: GoogleFonts.dmSans(fontSize: 14, color: _slate)),
          Text(m.group(2)!, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
        ]));
      } else {
        widgets.add(Text(para, style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF334155), height: 1.6)));
      }
    }
    return widgets;
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF0F4FF),
      child: const Center(child: Icon(Icons.sailing, size: 60, color: Color(0xFFB0C4DE))),
    );
  }
}
