import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/locale_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/catalog_product.dart';
import '../services/web_scraper_service.dart';
import '../services/cart_service.dart';
import '../services/pricing_service.dart';
import '../services/category_video_service.dart';
import '../services/category_description_service.dart';
import '../services/vat_service.dart';
import '../widgets/site_footer.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicCatalogScreen extends StatefulWidget {
  final String? initialCategory;
  const PublicCatalogScreen({super.key, this.initialCategory});

  @override
  State<PublicCatalogScreen> createState() => _PublicCatalogScreenState();
}

class _PublicCatalogScreenState extends State<PublicCatalogScreen> {
  static const _navy = Color(0xFF1B2A4A);
  static const _slate = Color(0xFF64748B);

  final _scraperService = WebScraperService();
  final _cartService = CartService();
  final _videoService = CategoryVideoService();
  final _descriptionService = CategoryDescriptionService();
  final _searchController = TextEditingController();
  final _locale = LocaleProvider();

  List<CatalogProduct> _allProducts = [];
  List<CatalogProduct> _filtered = [];
  Map<String, int> _categoryCounts = {};
  Map<String, CategoryVideo> _categoryVideos = {};
  Map<String, CategoryDescription> _categoryDescriptions = {};
  String? _selectedCategory;
  bool _loading = true;
  String? _error;

  String get _lang => _locale.lang;
  AppLocalizations get _l => _locale.l;

  @override
  void initState() {
    super.initState();
    _locale.addListener(_onLocaleChanged);
    _selectedCategory = widget.initialCategory ?? 'optimist';
    _load();
  }

  @override
  void dispose() {
    _locale.removeListener(_onLocaleChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(PublicCatalogScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialCategory != old.initialCategory) {
      setState(() => _selectedCategory = widget.initialCategory);
      _applyFilters();
    }
  }

  Future<void> _load() async {
    try {
      final raw = await _scraperService.fetchCatalog();
      final products = raw.where((p) => !p.geblokkeerd).toList();
      final rawCounts = <String, int>{};
      for (final p in products) {
        final cat = p.categorie ?? 'overig';
        rawCounts[cat] = (rawCounts[cat] ?? 0) + 1;
      }
      final counts = Map.fromEntries(
        rawCounts.entries.toList()..sort((a, b) {
          final la = CatalogProduct(naam: '', categorie: a.key).categorieLabelForLang(_lang);
          final lb = CatalogProduct(naam: '', categorie: b.key).categorieLabelForLang(_lang);
          return la.compareTo(lb);
        }),
      );
      Map<String, CategoryVideo> videos = {};
      Map<String, CategoryDescription> descriptions = {};
      try {
        videos = await _videoService.getVideos(forceRefresh: true);
      } catch (_) {}
      try {
        await _descriptionService.seedDefaults();
        descriptions = await _descriptionService.getAll(forceRefresh: true);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _allProducts = products;
          _categoryCounts = counts;
          _categoryVideos = videos;
          _categoryDescriptions = descriptions;
          _loading = false;
        });
        _applyFilters();
        _precacheVisibleImages(products);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading catalog: $e');
      if (mounted) setState(() { _error = _l.t('fout_probeer_opnieuw'); _loading = false; });
    }
  }

  void _precacheVisibleImages(List<CatalogProduct> products) {
    final imageUrls = products
        .take(12)
        .map((p) => p.displayAfbeeldingUrl)
        .whereType<String>();
    for (final url in imageUrls) {
      precacheImage(NetworkImage(url), context);
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _allProducts.where((p) {
        if (_selectedCategory != null && p.categorie != _selectedCategory) return false;
        if (query.isNotEmpty) {
          final haystack = '${p.naam} ${p.artikelnummer ?? ''} ${p.categorie ?? ''} ${p.beschrijving ?? ''}'.toLowerCase();
          if (!haystack.contains(query)) return false;
        }
        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return SingleChildScrollView(
      child: Column(children: [
        _buildHeader(context),
        _buildCategoryTabBar(context),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: isWide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 220, child: _buildSidebar()),
                    const SizedBox(width: 24),
                    Expanded(child: Column(children: [
                      if (_selectedCategory != null) _buildCategoryDescription(),
                      _buildProductGrid(isWide),
                      if (_selectedCategory != null && _categoryVideos.containsKey(_selectedCategory))
                        _buildCategoryVideo(_categoryVideos[_selectedCategory]!),
                    ])),
                  ])
                : Column(children: [
                    _buildSearchBar(),
                    const SizedBox(height: 16),
                    if (_selectedCategory != null) _buildCategoryDescription(),
                    _buildProductGrid(isWide),
                    if (_selectedCategory != null && _categoryVideos.containsKey(_selectedCategory))
                      _buildCategoryVideo(_categoryVideos[_selectedCategory]!),
                  ]),
          ),
        ),
        const SizedBox(height: 16),
        const SiteFooter(),
      ]),
    );
  }

  Widget _buildCategoryTabBar(BuildContext context) {
    if (_categoryCounts.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _categoryTab(null, _l.t('alle_producten').split(' ').first),
            ..._categoryCounts.entries.map((e) {
              final label = CatalogProduct(naam: '', categorie: e.key).categorieLabelForLang(_lang);
              return _categoryTab(e.key, label);
            }),
          ],
        ),
      ),
    );
  }

  Widget _categoryTab(String? key, String label) {
    final isActive = _selectedCategory == key;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: () { setState(() => _selectedCategory = key); _applyFilters(); },
        style: TextButton.styleFrom(
          foregroundColor: isActive ? _navy : const Color(0xFF64748B),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF0F1B33), Color(0xFF1B2A4A)]),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_l.t('nav_assortiment'), style: GoogleFonts.dmSerifDisplay(fontSize: 28, color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              _l.t('catalog_subtitle'),
              style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFFB0C4DE)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSearchBar(),
      const SizedBox(height: 16),
      Text(_l.t('categorieen'), style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
      const SizedBox(height: 8),
      _categoryItem(null, _l.t('alle_producten'), _allProducts.length),
      ..._categoryCounts.entries.map((e) {
        final label = CatalogProduct(naam: '', categorie: e.key).categorieLabelForLang(_lang);
        return _categoryItem(e.key, label, e.value);
      }),
    ]);
  }

  Widget _categoryItem(String? key, String label, int count) {
    final isActive = _selectedCategory == key;
    return InkWell(
      onTap: () { setState(() => _selectedCategory = key); _applyFilters(); },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _navy.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          Expanded(child: Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? _navy : _slate))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(8)),
            child: Text('$count', style: GoogleFonts.dmSans(fontSize: 11, color: _slate)),
          ),
        ]),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => _applyFilters(),
      decoration: InputDecoration(
        hintText: _l.t('zoek_product'),
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      ),
      style: GoogleFonts.dmSans(fontSize: 14),
    );
  }

  Widget _buildCategoryDescription() {
    final desc = _categoryDescriptions[_selectedCategory];
    if (desc == null) return const SizedBox.shrink();
    final text = desc.getForLocale(_lang);
    if (text.isEmpty) return const SizedBox.shrink();
    final catLabel = _selectedCategory != null
        ? CatalogProduct(naam: '', categorie: _selectedCategory!).categorieLabelForLang(_lang)
        : null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (catLabel != null) ...[
            Text(
              catLabel,
              style: GoogleFonts.dmSerifDisplay(fontSize: 22, fontWeight: FontWeight.w400, color: _navy, height: 1.2),
            ),
            const SizedBox(height: 10),
          ],
          ..._buildDescriptionParagraphs(text),
        ],
      ),
    );
  }

  List<Widget> _buildDescriptionParagraphs(String text) {
    final blocks = text.split('\n\n');
    final widgets = <Widget>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i].trim();
      if (block.isEmpty) continue;
      if (i > 0) widgets.add(const SizedBox(height: 12));

      final lines = block.split('\n');
      if (lines.length == 2 && lines[0].trim().length < 80) {
        widgets.add(Text(
          lines[0].trim(),
          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: _navy, height: 1.4),
        ));
        widgets.add(const SizedBox(height: 2));
        widgets.add(Text(
          lines[1].trim(),
          style: GoogleFonts.dmSans(fontSize: 14, height: 1.6, color: const Color(0xFF475569)),
        ));
      } else {
        widgets.add(Text(
          block,
          style: GoogleFonts.dmSans(fontSize: 14, height: 1.7, color: const Color(0xFF475569)),
        ));
      }
    }
    return widgets;
  }

  Widget _buildProductGrid(bool isWide) {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(64), child: CircularProgressIndicator()));
    if (_error != null) return Center(child: Text('${_l.t('fout')}: $_error'));
    if (_filtered.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(48), child: Text(_l.t('geen_producten'), style: GoogleFonts.dmSans(color: _slate))));

    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 600 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _filtered.length,
        itemBuilder: (ctx, i) => _productCard(_filtered[i]),
      );
    });
  }

  Widget _productCard(CatalogProduct product) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/product/${product.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: product.displayAfbeeldingUrl != null
                  ? Image.network(product.displayAfbeeldingUrl!, width: double.infinity, fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => _placeholder())
                  : _placeholder(),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (product.categorie != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: _navy.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(4)),
                        child: Text(product.categorieLabelForLang(_lang), style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w600, color: _navy)),
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: product.inStock ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.inStock ? _l.t('op_voorraad') : _l.t('niet_op_voorraad'),
                        style: GoogleFonts.dmSans(fontSize: 8, fontWeight: FontWeight.w600,
                          color: product.inStock ? const Color(0xFF2E7D32) : const Color(0xFFE65100)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(product.naamForLang(_lang), maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B), height: 1.3)),
                  ),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (product.displayPrijs != null)
                          Text(product.prijsFormatted, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
                        if (product.staffelprijzen != null && product.staffelprijzen!.isNotEmpty)
                          Builder(builder: (_) {
                            final minVal = product.staffelprijzen!.values.reduce((a, b) => a < b ? a : b);
                            return Text('${_l.t('vanaf')} ${PricingService.formatEuro(minVal)}',
                              style: GoogleFonts.dmSans(fontSize: 10, color: _slate));
                          }),
                      ]),
                    ),
                    if (product.inStock)
                      SizedBox(
                        width: 32, height: 32,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.add_shopping_cart, size: 18, color: Color(0xFF1B2A4A)),
                          tooltip: _l.t('in_wagen'),
                          onPressed: () {
                            _cartService.addToCart(product);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${product.naamForLang(_lang)} ${_l.t('toegevoegd')}'), duration: const Duration(seconds: 1)),
                            );
                            setState(() {});
                          },
                        ),
                      ),
                  ]),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF0F4FF),
      child: const Center(child: Icon(Icons.sailing, size: 40, color: Color(0xFFB0C4DE))),
    );
  }

  Widget _buildCategoryVideo(CategoryVideo video) {
    final thumbUrl = video.thumbnailUrl;
    if (thumbUrl == null) return const SizedBox.shrink();
    final isWideEnough = MediaQuery.of(context).size.width >= 600;

    final thumbWidget = SizedBox(
      width: isWideEnough ? 280 : double.infinity,
      height: isWideEnough ? 160 : 180,
      child: Stack(children: [
        Positioned.fill(
          child: Image.network(thumbUrl, fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: const Color(0xFF1B2A4A))),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withValues(alpha: 0.3), Colors.transparent, Colors.black.withValues(alpha: 0.2)],
                begin: isWideEnough ? Alignment.centerLeft : Alignment.bottomCenter,
                end: isWideEnough ? Alignment.centerRight : Alignment.topCenter,
              ),
            ),
          ),
        ),
        const Center(child: Icon(Icons.play_circle_fill, size: 56, color: Colors.white)),
      ]),
    );

    final textWidget = Padding(
      padding: EdgeInsets.symmetric(horizontal: isWideEnough ? 28 : 20, vertical: isWideEnough ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(4)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.play_arrow, size: 14, color: Colors.white),
              const SizedBox(width: 3),
              Text('YouTube', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
          const SizedBox(height: 10),
          Text(
            video.title ?? _l.t('bekijk_video'),
            style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, height: 1.3),
            maxLines: 2, overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            _l.t('video_beschrijving'),
            style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFFB0C4DE), height: 1.4),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(top: 28, bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1B3A5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () { if (VatService.isSafeUrl(video.youtubeUrl)) launchUrl(Uri.parse(video.youtubeUrl), mode: LaunchMode.externalApplication); },
          borderRadius: BorderRadius.circular(16),
          child: isWideEnough
              ? Row(children: [thumbWidget, Expanded(child: textWidget)])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [thumbWidget, textWidget]),
        ),
      ),
    );
  }
}
