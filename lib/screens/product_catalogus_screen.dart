import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/catalog_product.dart';
import '../services/web_scraper_service.dart';
import '../services/user_service.dart';
import '../services/translate_service.dart';
import '../services/pricing_service.dart';
import '../services/favorieten_service.dart';
import '../services/cart_service.dart';
import '../services/shipping_service.dart';
import '../services/vat_service.dart';
import '../services/inventory_service.dart';
import '../services/marketplace_service.dart';
import '../models/marketplace_listing.dart';
import '../l10n/app_localizations.dart';
import 'cart_screen.dart';

class ProductCatalogusScreen extends StatefulWidget {
  final bool showBlocked;
  const ProductCatalogusScreen({super.key, this.showBlocked = false});

  @override
  State<ProductCatalogusScreen> createState() => _ProductCatalogusScreenState();
}

class _ProductCatalogusScreenState extends State<ProductCatalogusScreen> {
  final WebScraperService _scraperService = WebScraperService();
  final UserService _userService = UserService();
  final FavorietenService _favorietenService = FavorietenService();
  final CartService _cartService = CartService();
  final TextEditingController _searchController = TextEditingController();

  List<CatalogProduct> _allProducts = [];
  List<CatalogProduct> _filteredProducts = [];
  Map<String, int> _categoryCounts = {};
  String? _selectedCategory = 'optimist';
  bool _loading = true;
  bool _syncing = false;
  bool _isAdmin = false;
  UserPermissions _permissions = const UserPermissions();
  ScrapeProgress? _syncProgress;
  String? _error;
  bool _gridView = true;
  bool _backgroundSyncing = false;
  StaleCatalogInfo? _staleInfo;
  String _lang = 'nl';
  late AppLocalizations _l;
  AppUser? _appUser;
  bool _showInclVat = true;
  late bool _showBlocked = widget.showBlocked;
  List<CatalogProduct> _blockedProducts = [];
  final Set<int> _selectedForBlock = {};

  @override
  void initState() {
    super.initState();
    _l = AppLocalizations(_lang);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _scraperService.fetchCatalog(includeBlocked: true),
        _userService.isCurrentUserAdmin(),
        _userService.getUserLanguage(),
        _userService.getCurrentUser(),
        _favorietenService.fetchFavorieten(),
        _userService.getCurrentUserPermissions(),
      ]);
      final allProducts = results[0] as List<CatalogProduct>;
      final admin = results[1] as bool;
      final lang = results[2] as String;
      final appUser = results[3] as AppUser?;
      final perms = results[5] as UserPermissions;
      if (!mounted) return;
      setState(() {
        _allProducts = allProducts.where((p) => !p.geblokkeerd).toList();
        _blockedProducts = allProducts.where((p) => p.geblokkeerd).toList();
        _isAdmin = admin;
        _permissions = perms;
        _lang = lang;
        _l = AppLocalizations(lang);
        _appUser = appUser;
        _rebuildCategoryCounts();
        _loading = false;
      });
      _applyFilters();
      _checkFreshness();
      _ensureTranslationsAvailable(allProducts.where((p) => !p.geblokkeerd).toList());
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading products: $e');
      if (!mounted) return;
      setState(() { _error = 'Er is een fout opgetreden bij het laden.'; _loading = false; });
    }
  }

  Future<void> _ensureTranslationsAvailable(List<CatalogProduct> products) async {
    if (products.isEmpty) return;
    final needsTranslation = products.any((p) => !p.hasAllTranslations && p.naam.isNotEmpty);
    if (!needsTranslation) return;

    try {
      setState(() { _backgroundSyncing = true; });
      await _scraperService.ensureTranslations();
      if (!mounted) return;
      setState(() { _backgroundSyncing = false; });
      _loadDataSilent();
    } catch (_) {
      if (mounted) setState(() { _backgroundSyncing = false; });
    }
  }

  bool _isGhostProduct(CatalogProduct p) =>
      !p.inStock && p.afbeeldingUrl == null && p.prijs == null;

  void _rebuildCategoryCounts() {
    final counts = <String, int>{};
    for (final p in _allProducts) {
      if (_isGhostProduct(p) || p.geblokkeerd) continue;
      final cat = p.categorie ?? 'overig';
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    _categoryCounts = Map.fromEntries(
      counts.entries.toList()..sort((a, b) {
        final la = CatalogProduct(naam: '', categorie: a.key).categorieLabel;
        final lb = CatalogProduct(naam: '', categorie: b.key).categorieLabel;
        return la.compareTo(lb);
      }),
    );
  }

  Future<void> _checkFreshness() async {
    try {
      final stale = await _scraperService.checkFreshness();
      if (!mounted || stale == null) return;

      if (_permissions.productenBewerken) {
        setState(() { _staleInfo = stale; });
      } else {
        setState(() { _backgroundSyncing = true; });
        final result = await _scraperService.backgroundSyncSafe();
        if (!mounted) return;
        setState(() { _backgroundSyncing = false; });
        if (result.warnings.isNotEmpty) {
          _showSyncWarnings(result.warnings);
        }
        if (!result.aborted) _loadDataSilent();
      }
    } catch (_) {
      if (mounted) setState(() { _backgroundSyncing = false; });
    }
  }

  void _showSyncWarnings(List<SyncWarning> warnings) {
    if (!mounted || warnings.isEmpty) return;
    final critical = warnings.where((w) => w.level == SyncWarningLevel.critical).toList();
    final other = warnings.where((w) => w.level != SyncWarningLevel.critical).toList();

    final msg = [...critical, ...other].map((w) => w.message).join('\n\n');
    final isCritical = critical.isNotEmpty;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 12)),
      backgroundColor: isCritical ? const Color(0xFFE53935) : const Color(0xFFF57F17),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
    ));
  }

  Future<void> _loadDataSilent() async {
    try {
      final allProducts = await _scraperService.fetchCatalog(includeBlocked: true);
      if (!mounted) return;
      setState(() {
        _allProducts = allProducts.where((p) => !p.geblokkeerd).toList();
        _blockedProducts = allProducts.where((p) => p.geblokkeerd).toList();
        _rebuildCategoryCounts();
        _staleInfo = null;
      });
      _applyFilters();
    } catch (_) {}
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    final source = _showBlocked ? _blockedProducts : _allProducts;
    setState(() {
      _filteredProducts = source.where((p) {
        if (!_showBlocked && _isGhostProduct(p)) return false;
        if (!_showBlocked && p.geblokkeerd) return false;
        if (_showBlocked && !p.geblokkeerd) return false;
        if (_selectedCategory != null && p.categorie != _selectedCategory) {
          return false;
        }
        if (query.isNotEmpty) {
          final name = p.naamForLang(_lang).toLowerCase();
          final desc = p.beschrijvingForLang(_lang)?.toLowerCase() ?? '';
          return name.contains(query) ||
              desc.contains(query) ||
              (p.artikelnummer?.toLowerCase().contains(query) ?? false) ||
              p.categorieLabel.toLowerCase().contains(query);
        }
        return true;
      }).toList();
    });
  }

  void _selectCategory(String? cat) {
    setState(() { _selectedCategory = cat; });
    _applyFilters();
  }

  Future<void> _toggleBlock(CatalogProduct product, bool block) async {
    if (product.id == null) return;
    final email = _userService.currentUserEmail;
    try {
      await _scraperService.toggleBlockProduct(product.id!, block, byEmail: email);
      await _loadDataSilent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(block ? 'Product geblokkeerd: ${product.displayNaam}' : 'Product gedeblokkeerd: ${product.displayNaam}'),
          backgroundColor: block ? const Color(0xFFE53935) : const Color(0xFF43A047),
        ));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error toggling product block: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Actie mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFE53935),
        ));
      }
    }
  }

  Future<void> _bulkBlock(bool block) async {
    if (_selectedForBlock.isEmpty) return;
    final email = _userService.currentUserEmail;
    try {
      await _scraperService.bulkBlockProducts(_selectedForBlock.toList(), block, byEmail: email);
      setState(() { _selectedForBlock.clear(); });
      await _loadDataSilent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(block ? 'Producten geblokkeerd' : 'Producten gedeblokkeerd'),
          backgroundColor: block ? const Color(0xFFE53935) : const Color(0xFF43A047),
        ));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error bulk blocking products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Actie mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFE53935),
        ));
      }
    }
  }

  void _toggleShowBlocked() {
    setState(() {
      _showBlocked = !_showBlocked;
      _selectedForBlock.clear();
      _selectedCategory = null;
    });
    _applyFilters();
  }

  void _changeLanguage(String lang) async {
    setState(() {
      _lang = lang;
      _l = AppLocalizations(lang);
    });
    _applyFilters();
    try {
      await _userService.setUserLanguage(lang);
    } catch (_) {}

    if (lang != 'nl') {
      _ensureTranslationsForLang(lang);
    }
  }

  Future<void> _ensureTranslationsForLang(String lang) async {
    final missing = _allProducts.where((p) =>
        p.naam.isNotEmpty && !p.translatedNames.containsKey(lang)).toList();
    if (missing.isEmpty) return;

    setState(() { _backgroundSyncing = true; });
    try {
      await _scraperService.translateAllProducts();
      if (!mounted) return;
      setState(() { _backgroundSyncing = false; });
      _loadDataSilent();
    } catch (_) {
      if (mounted) setState(() { _backgroundSyncing = false; });
    }
  }

  Future<void> _syncFromWebsite() async {
    bool withImages = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          icon: const Icon(Icons.sync, color: Color(0xFF455A64), size: 40),
          title: Text(_l.t('sync_titel')),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_l.t('sync_beschrijving')),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: withImages,
              onChanged: (v) => setDlgState(() => withImages = v ?? false),
              title: const Text('Afbeeldingen ophalen', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Haalt alle productfoto\'s op (duurt langer)', style: TextStyle(fontSize: 12)),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_l.t('annuleren'))),
            ElevatedButton.icon(
              icon: const Icon(Icons.sync, size: 18),
              label: Text(_l.t('synchroniseren')),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    setState(() { _syncing = true; _syncProgress = null; _staleInfo = null; });

    try {
      final products = await _scraperService.scrapeAll(
        onProgress: (progress) {
          if (mounted) setState(() { _syncProgress = progress; });
        },
        scrapeImages: withImages,
      );

      if (!mounted) return;
      setState(() { _syncProgress = ScrapeProgress(total: products.length, current: 0, currentProduct: _l.t('opslaan_db')); });

      final result = await _scraperService.safeSyncToSupabase(products);

      if (!mounted) return;

      if (result.aborted) {
        setState(() { _syncing = false; _syncProgress = null; });
        _showSyncWarnings(result.warnings);
        return;
      }

      if (result.warnings.isNotEmpty) {
        _showSyncWarnings(result.warnings);
      }

      setState(() { _syncing = false; _syncProgress = null; });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${result.syncedCount} ${_l.t('producten_gesynct')}'),
        backgroundColor: const Color(0xFF43A047),
      ));

      _loadData();
      _translateAfterSync();
    } catch (e) {
      if (kDebugMode) debugPrint('Error syncing products: $e');
      if (!mounted) return;
      setState(() { _syncing = false; _syncProgress = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_l.t('sync_mislukt')),
        backgroundColor: const Color(0xFFE53935),
      ));
    }
  }

  Future<void> _startFullTranslation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.translate, color: Color(0xFF455A64), size: 40),
        title: const Text('Alle vertalingen genereren'),
        content: const Text(
          'Dit vertaalt alle productnamen en -beschrijvingen naar alle 23 EU-talen.\n\n'
          'Dit kan enkele minuten duren bij ca. 90 producten.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_l.t('annuleren'))),
          ElevatedButton.icon(
            icon: const Icon(Icons.translate, size: 18),
            label: const Text('Starten'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _syncing = true;
      _syncProgress = ScrapeProgress(total: 0, current: 0, currentProduct: _l.t('vertalen_bezig'));
    });

    try {
      final count = await _scraperService.translateAllProducts(
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _syncProgress = ScrapeProgress(
                total: total, current: current,
                currentProduct: '${_l.t('vertalen_bezig')} $current/$total',
              );
            });
          }
        },
      );

      if (!mounted) return;
      setState(() { _syncing = false; _syncProgress = null; });

      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$count ${_l.t('producten_vertaald')}'),
          backgroundColor: const Color(0xFF43A047),
        ));
        _loadDataSilent();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Alle vertalingen zijn al up-to-date'),
          backgroundColor: Color(0xFF455A64),
        ));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error translating products: $e');
      if (!mounted) return;
      setState(() { _syncing = false; _syncProgress = null; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vertalen mislukt. Probeer het opnieuw.'),
        backgroundColor: Color(0xFFE53935),
      ));
    }
  }

  Future<void> _translateAfterSync() async {
    if (!_permissions.productenBewerken) return;
    try {
      setState(() { _syncing = true; _syncProgress = ScrapeProgress(total: 0, current: 0, currentProduct: _l.t('vertalen_bezig')); });

      final count = await _scraperService.translateAllProducts(
        onProgress: (current, total) {
          if (mounted) {
            setState(() { _syncProgress = ScrapeProgress(total: total, current: current, currentProduct: '${_l.t('vertalen_bezig')} $current/$total'); });
          }
        },
      );

      if (!mounted) return;

      // Also retranslate recently changed products
      final retranslated = await _scraperService.retranslateChanged();

      if (!mounted) return;
      setState(() { _syncing = false; _syncProgress = null; });

      final totalTranslated = count + retranslated;
      if (totalTranslated > 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$count ${_l.t('producten_vertaald')}${retranslated > 0 ? ', $retranslated ${_l.t('hertaald')}' : ''}'),
          backgroundColor: const Color(0xFF43A047),
        ));
        _loadDataSilent();
      }
    } catch (_) {
      if (mounted) setState(() { _syncing = false; _syncProgress = null; });
    }
  }

  // ---------------------------------------------------------------
  // Product detail dialog
  // ---------------------------------------------------------------

  void _showProductDetail(CatalogProduct product) {
    final displayName = product.naamForLang(_lang);
    final displayDesc = product.beschrijvingForLang(_lang);

    showDialog(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final isWide = screenWidth >= 800;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 16, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWide ? 960 : 600, maxHeight: MediaQuery.of(ctx).size.height * 0.9),
            child: StatefulBuilder(
              builder: (ctx, setDetailState) {
                return _ProductDetailContent(
                  product: product,
                  displayName: displayName,
                  displayDesc: displayDesc,
                  isWide: isWide,
                  isAdmin: _isAdmin,
                  showInclVat: _showInclVat,
                  appUser: _appUser,
                  lang: _lang,
                  l: _l,
                  favorietenService: _favorietenService,
                  onClose: () => Navigator.pop(ctx),
                  onAddToCart: (p) { _addToCart(p); Navigator.pop(ctx); },
                  onToggleFavoriet: (p) async { await _toggleFavoriet(p); setDetailState(() {}); },
                  onToggleBlock: (p, block) { Navigator.pop(ctx); _toggleBlock(p, block); },
                  onOpenUrl: (url) { if (VatService.isSafeUrl(url)) launchUrl(Uri.parse(url)); },
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------
  // Small helper widgets
  // ---------------------------------------------------------------

  /// Returns the display price for a product based on the incl/excl toggle.
  /// Catalog prices are always incl. 21% NL VAT.
  double _displayPrice(CatalogProduct product) {
    final catalogPrice = product.prijs ?? 0;
    if (_appUser == null) return _showInclVat ? catalogPrice : PricingService.exclVat(catalogPrice);
    final bd = PricingService.calculate(product: product, user: _appUser!);
    return _showInclVat ? bd.totalInclVat : bd.afterDiscountExcl;
  }

  String _formatCardPrice(CatalogProduct product) {
    return PricingService.formatEuro(_displayPrice(product));
  }

  Widget _buildStockBadge(bool inStock) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: inStock ? const Color(0xFF43A047).withValues(alpha: 0.1) : const Color(0xFFE53935).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        inStock ? _l.t('op_voorraad') : _l.t('niet_op_voorraad'),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: inStock ? const Color(0xFF43A047) : const Color(0xFFE53935)),
      ),
    );
  }

  // ---------------------------------------------------------------
  // Favorieten / Winkelwagen helpers
  // ---------------------------------------------------------------

  Future<void> _toggleFavoriet(CatalogProduct product) async {
    final key = product.artikelnummer ?? product.naam;
    await _favorietenService.toggleFavoriet(key);
    if (mounted) setState(() {});
  }

  void _addToCart(CatalogProduct product, {int quantity = 1}) {
    _cartService.addToCart(product, quantity: quantity);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${product.naamForLang(_lang)} ${_l.t('toegevoegd_aan_winkelmand')}'),
      backgroundColor: const Color(0xFF43A047),
      duration: const Duration(seconds: 2),
      action: SnackBarAction(
        label: _l.t('bekijk_winkelmand'),
        textColor: Colors.white,
        onPressed: _openCart,
      ),
    ));
  }

  void _openCart() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CartScreen(appUser: _appUser),
    )).then((_) { if (mounted) setState(() {}); });
  }

  void _showFavorietenList() {
    final favIds = _favorietenService.cachedIds;
    final favProducts = _allProducts.where((p) {
      final key = p.artikelnummer ?? p.naam;
      return favIds.contains(key);
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                const Icon(Icons.favorite, size: 20, color: Color(0xFFE53935)),
                const SizedBox(width: 8),
                Text(_l.t('favorieten'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${favProducts.length} ${_l.t('items')}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: favProducts.isEmpty
                  ? Center(child: Text(_l.t('geen_favorieten'), style: const TextStyle(color: Color(0xFF94A3B8))))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: favProducts.length,
                      itemBuilder: (_, i) {
                        final p = favProducts[i];
                        return ListTile(
                          leading: p.displayAfbeeldingUrl != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(6),
                                  child: Image.network(p.displayAfbeeldingUrl!, width: 48, height: 48, fit: BoxFit.contain,
                                    errorBuilder: (_, e, s) => const Icon(Icons.sailing, size: 32)))
                              : const Icon(Icons.sailing, size: 32, color: Color(0xFFB0BEC5)),
                          title: Text(p.naamForLang(_lang), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text(p.prijs != null ? _formatCardPrice(p) : '', style: const TextStyle(fontSize: 12)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (p.inStock)
                              IconButton(
                                icon: const Icon(Icons.add_shopping_cart, size: 20),
                                tooltip: _l.t('toevoegen_aan_winkelmand'),
                                onPressed: () { _addToCart(p); Navigator.pop(ctx); },
                              ),
                            IconButton(
                              icon: const Icon(Icons.favorite, size: 20, color: Color(0xFFE53935)),
                              onPressed: () { _toggleFavoriet(p); Navigator.pop(ctx); },
                            ),
                          ]),
                          onTap: () { Navigator.pop(ctx); _showProductDetail(p); },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVatToggle() {
    final buyerCountry = _appUser?.landCode.toUpperCase() ?? 'NL';
    final shipping = ShippingService.getRate(buyerCountry);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Tooltip(
        message: 'Verzendkosten: ${shipping.costFormatted} naar ${shipping.countryName} (${shipping.deliveryTime})',
        child: IconButton(
          icon: const Icon(Icons.local_shipping_outlined, size: 20),
          onPressed: _showShippingRates,
        ),
      ),
      GestureDetector(
        onTap: () => setState(() => _showInclVat = !_showInclVat),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_showInclVat ? Icons.toggle_on : Icons.toggle_off, size: 20, color: Colors.white),
            const SizedBox(width: 4),
            Text(_showInclVat ? 'incl. BTW' : 'excl. BTW',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
        ),
      ),
    ]);
  }

  void _showShippingRates() {
    final userCountry = _appUser?.landCode.toUpperCase() ?? 'NL';
    final rates = ShippingService.allRatesLocalized(_lang);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF455A64),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(children: [
                const Icon(Icons.local_shipping, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(_l.t('verzendkosten'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
                IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 20), onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _l.t('verzend_info'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: rates.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final r = rates[i];
                  final isUserCountry = r.countryCode == userCountry;
                  return ListTile(
                    dense: true,
                    tileColor: isUserCountry ? const Color(0xFFE8F5E9) : null,
                    leading: Text(r.countryCode, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: isUserCountry ? const Color(0xFF2E7D32) : const Color(0xFF78909C),
                    )),
                    title: Text(r.localizedName(_lang), style: TextStyle(
                      fontSize: 13, fontWeight: isUserCountry ? FontWeight.w700 : FontWeight.w500,
                    )),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(r.costFormattedLocalized(_lang), style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: r.cost == 0 ? const Color(0xFF2E7D32) : const Color(0xFF455A64),
                      )),
                      const SizedBox(width: 12),
                      Text(r.deliveryTime, style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
                    ]),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  Widget _buildFavBadge() {
    final count = _favorietenService.count;
    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count', style: const TextStyle(fontSize: 10)),
        child: Icon(count > 0 ? Icons.favorite : Icons.favorite_border, size: 22),
      ),
      tooltip: _l.t('favorieten'),
      onPressed: _showFavorietenList,
    );
  }

  Widget _buildCartBadge() {
    final count = _cartService.totalItems;
    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count', style: const TextStyle(fontSize: 10)),
        child: const Icon(Icons.shopping_cart_outlined, size: 22),
      ),
      tooltip: _l.t('winkelmand'),
      onPressed: _openCart,
    );
  }

  // ---------------------------------------------------------------
  // Main build
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          if (_syncing && _syncProgress != null) _buildSyncBar(),
          if (_staleInfo != null && _permissions.productenBewerken && !_syncing) _buildStaleBanner(),
          if (_backgroundSyncing) _buildBackgroundSyncBar(),
          Expanded(child: _buildResponsiveBody(context)),
        ],
      ),
      floatingActionButton: _permissions.productenBewerken
          ? FloatingActionButton.extended(
              onPressed: _showAddProductDialog,
              icon: const Icon(Icons.add),
              label: const Text('Product toevoegen'),
              backgroundColor: const Color(0xFF1B4965),
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Future<void> _showAddProductDialog() async {
    final naamCtrl = TextEditingController();
    final prijsCtrl = TextEditingController();
    final categorieCtrl = TextEditingController();
    final beschrijvingCtrl = TextEditingController();
    final artikelCtrl = TextEditingController();
    final afbeeldingCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final categories = _categoryCounts.keys.toList()..sort();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.add_box_outlined, color: Color(0xFF1B4965)),
          const SizedBox(width: 8),
          const Text('Product toevoegen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: naamCtrl,
                  decoration: const InputDecoration(labelText: 'Productnaam *', isDense: true),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Verplicht' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: prijsCtrl,
                  decoration: const InputDecoration(labelText: 'Prijs (EUR)', isDense: true, hintText: '0.01'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Categorie', isDense: true),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Geen / overig')),
                    ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    const DropdownMenuItem(value: '__new__', child: Text('+ Nieuwe categorie...')),
                  ],
                  onChanged: (val) {
                    if (val == '__new__') {
                      categorieCtrl.clear();
                      showDialog(
                        context: ctx,
                        builder: (innerCtx) {
                          final newCatCtrl = TextEditingController();
                          return AlertDialog(
                            title: const Text('Nieuwe categorie'),
                            content: TextField(
                              controller: newCatCtrl,
                              decoration: const InputDecoration(labelText: 'Categorienaam', isDense: true),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(innerCtx), child: const Text('Annuleren')),
                              TextButton(
                                onPressed: () {
                                  categorieCtrl.text = newCatCtrl.text.trim().toLowerCase();
                                  Navigator.pop(innerCtx);
                                },
                                child: const Text('OK'),
                              ),
                            ],
                          );
                        },
                      );
                    } else {
                      categorieCtrl.text = val ?? '';
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: artikelCtrl,
                  decoration: const InputDecoration(labelText: 'Artikelnummer (optioneel)', isDense: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: beschrijvingCtrl,
                  decoration: const InputDecoration(labelText: 'Beschrijving (optioneel)', isDense: true),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: afbeeldingCtrl,
                  decoration: const InputDecoration(labelText: 'Afbeelding URL (optioneel)', isDense: true),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Toevoegen'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B4965), foregroundColor: Colors.white),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        final prijs = double.tryParse(prijsCtrl.text.trim().replaceAll(',', '.'));
        final newProduct = await _scraperService.addManualProduct(
          naam: naamCtrl.text.trim(),
          categorie: categorieCtrl.text.trim().isEmpty ? null : categorieCtrl.text.trim(),
          prijs: prijs,
          beschrijving: beschrijvingCtrl.text.trim().isEmpty ? null : beschrijvingCtrl.text.trim(),
          afbeeldingUrl: afbeeldingCtrl.text.trim().isEmpty ? null : afbeeldingCtrl.text.trim(),
          artikelnummer: artikelCtrl.text.trim().isEmpty ? null : artikelCtrl.text.trim(),
        );

        try {
          await InventoryService().save(InventoryItem(
            productId: newProduct.id,
            variantLabel: newProduct.naam,
            artikelnummer: newProduct.artikelnummer,
            eanCode: newProduct.eanCode,
            categorie: newProduct.categorie,
            inkoopPrijs: newProduct.prijs,
          ));
        } catch (e) {
          if (kDebugMode) debugPrint('Auto inventory concept error: $e');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Product "${naamCtrl.text.trim()}" toegevoegd (+ concept voorraaditem)'), backgroundColor: const Color(0xFF2E7D32)),
          );
          await _loadDataSilent();
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Error adding product: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Toevoegen mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFE53935)),
          );
        }
      }
    }

    naamCtrl.dispose();
    prijsCtrl.dispose();
    categorieCtrl.dispose();
    beschrijvingCtrl.dispose();
    artikelCtrl.dispose();
    afbeeldingCtrl.dispose();
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    return AppBar(
      title: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/ventoz_logo.png', width: 28, height: 28)),
        const SizedBox(width: 10),
        Text(_showBlocked ? 'Afgewezen items (${_blockedProducts.length})' : _l.t('productcatalogus')),
      ]),
      actions: [
        _buildVatToggle(),
        _buildLanguageSelector(),
        _buildFavBadge(),
        _buildCartBadge(),
        if (!isWide)
          IconButton(
            icon: Icon(_selectedCategory != null ? Icons.filter_alt : Icons.filter_alt_outlined),
            tooltip: _l.t('categorieen'),
            onPressed: _showCategorySheet,
          ),
        IconButton(
          icon: Icon(_gridView ? Icons.view_list : Icons.grid_view),
          tooltip: _gridView ? _l.t('lijstweergave') : _l.t('rasterweergave'),
          onPressed: () => setState(() { _gridView = !_gridView; }),
        ),
        if (_permissions.productenBlokkeren)
          Badge(
            isLabelVisible: _blockedProducts.isNotEmpty,
            label: Text('${_blockedProducts.length}', style: const TextStyle(fontSize: 9)),
            backgroundColor: const Color(0xFFE53935),
            child: IconButton(
              icon: Icon(_showBlocked ? Icons.visibility : Icons.block, color: _showBlocked ? const Color(0xFFE53935) : null),
              tooltip: _showBlocked ? 'Terug naar catalogus' : 'Afgewezen items (${_blockedProducts.length})',
              onPressed: _toggleShowBlocked,
            ),
          ),
        if (_permissions.productenBlokkeren && _showBlocked && _selectedForBlock.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Color(0xFF43A047)),
            tooltip: 'Selectie deblokkeren (${_selectedForBlock.length})',
            onPressed: () => _bulkBlock(false),
          ),
        if (_permissions.productenBlokkeren && !_showBlocked && _selectedForBlock.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.block, color: Color(0xFFE53935)),
            tooltip: 'Selectie blokkeren (${_selectedForBlock.length})',
            onPressed: () => _bulkBlock(true),
          ),
        if (_permissions.productenBewerken)
          _syncing
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                )
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.sync),
                  tooltip: _l.t('sync_tooltip'),
                  onSelected: (val) {
                    if (val == 'sync') _syncFromWebsite();
                    if (val == 'translate') _startFullTranslation();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'sync',
                      child: ListTile(
                        leading: const Icon(Icons.sync, size: 20),
                        title: Text(_l.t('synchroniseren'), style: const TextStyle(fontSize: 13)),
                        subtitle: const Text('Website + vertalingen', style: TextStyle(fontSize: 11)),
                        dense: true, contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'translate',
                      child: ListTile(
                        leading: Icon(Icons.translate, size: 20),
                        title: Text('Alle vertalingen genereren', style: TextStyle(fontSize: 13)),
                        subtitle: Text('23 EU-talen, alle producten', style: TextStyle(fontSize: 11)),
                        dense: true, contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
        IconButton(icon: const Icon(Icons.refresh), tooltip: _l.t('vernieuwen'), onPressed: _loadData),
      ],
    );
  }

  // ---------------------------------------------------------------
  // Responsive body: sidebar (>=700px) or no sidebar (<700px)
  // ---------------------------------------------------------------

  Widget _buildResponsiveBody(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 700;
      if (isWide) {
        return Row(
          children: [
            SizedBox(width: 240, child: _buildSidebar()),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: _buildMainContent()),
          ],
        );
      } else {
        return _buildMainContent();
      }
    });
  }

  // ---------------------------------------------------------------
  // Left sidebar (desktop)
  // ---------------------------------------------------------------

  Widget _buildSidebar() {
    return Container(
      color: const Color(0xFFFAFBFC),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _applyFilters(),
              decoration: InputDecoration(
                hintText: _l.t('zoek_hint'),
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { _searchController.clear(); _applyFilters(); })
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildCategoryList()),
        ],
      ),
    );
  }

  Widget _buildCategoryList() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        _buildCategoryTile(null, _l.t('alle_categorieen'), _allProducts.length),
        ..._categoryCounts.entries.map((e) {
          final label = CatalogProduct(naam: '', categorie: e.key).categorieLabel;
          return _buildCategoryTile(e.key, label, e.value);
        }),
      ],
    );
  }

  Widget _buildCategoryTile(String? cat, String label, int count) {
    final selected = _selectedCategory == cat;
    return Material(
      color: selected ? const Color(0xFF455A64).withValues(alpha: 0.1) : Colors.transparent,
      child: InkWell(
        onTap: () => _selectCategory(cat),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Icon(
                cat == null ? Icons.grid_view_rounded : Icons.sailing,
                size: 16,
                color: selected ? const Color(0xFF455A64) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? const Color(0xFF1E293B) : const Color(0xFF475569),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF455A64).withValues(alpha: 0.15) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? const Color(0xFF455A64) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // Bottom sheet (mobile)
  // ---------------------------------------------------------------

  void _showCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 20, color: Color(0xFF455A64)),
                  const SizedBox(width: 8),
                  Text(_l.t('categorieen'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (_selectedCategory != null)
                    TextButton(
                      onPressed: () { _selectCategory(null); Navigator.pop(ctx); },
                      child: Text(_l.t('alle_categorieen'), style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  _buildSheetTile(ctx, null, _l.t('alle_categorieen'), _allProducts.length),
                  ..._categoryCounts.entries.map((e) {
                    final label = CatalogProduct(naam: '', categorie: e.key).categorieLabel;
                    return _buildSheetTile(ctx, e.key, label, e.value);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetTile(BuildContext ctx, String? cat, String label, int count) {
    final selected = _selectedCategory == cat;
    return ListTile(
      dense: true,
      leading: Icon(
        cat == null ? Icons.grid_view_rounded : Icons.sailing,
        size: 20,
        color: selected ? const Color(0xFF455A64) : const Color(0xFF94A3B8),
      ),
      title: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, fontSize: 14)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF455A64).withValues(alpha: 0.15) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? const Color(0xFF455A64) : const Color(0xFF64748B))),
      ),
      selected: selected,
      selectedTileColor: const Color(0xFF455A64).withValues(alpha: 0.05),
      onTap: () {
        _selectCategory(cat);
        Navigator.pop(ctx);
      },
    );
  }

  // ---------------------------------------------------------------
  // Main content area (products + mobile search bar)
  // ---------------------------------------------------------------

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildMobileSearchBar(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildMobileSearchBar() {
    final isWide = MediaQuery.of(context).size.width >= 700;
    if (isWide) {
      if (_selectedCategory != null) {
        final label = CatalogProduct(naam: '', categorie: _selectedCategory!).categorieLabel;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.sailing, size: 16, color: Color(0xFF455A64)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
              Text(' (${_filteredProducts.length})', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.close, size: 16),
                label: Text(_l.t('alle_categorieen'), style: const TextStyle(fontSize: 12)),
                onPressed: () => _selectCategory(null),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => _applyFilters(),
            decoration: InputDecoration(
              hintText: _l.t('zoek_hint'),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); _applyFilters(); })
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            ),
          ),
          if (_selectedCategory != null) ...[
            const SizedBox(height: 6),
            Chip(
              label: Text(CatalogProduct(naam: '', categorie: _selectedCategory!).categorieLabel, style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => _selectCategory(null),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // Language selector
  // ---------------------------------------------------------------

  Widget _buildLanguageSelector() {
    return PopupMenuButton<String>(
      initialValue: _lang,
      tooltip: _l.t('taal'),
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(TranslateService.languageFlags[_lang] ?? '', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
      onSelected: _changeLanguage,
      itemBuilder: (_) => TranslateService.supportedLanguages.map((code) {
        return PopupMenuItem<String>(
          value: code,
          child: Row(children: [
            Text(TranslateService.languageFlags[code] ?? '', style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Text(TranslateService.languageLabels[code] ?? code, style: TextStyle(fontWeight: code == _lang ? FontWeight.w700 : FontWeight.w400)),
          ]),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------
  // Status bars
  // ---------------------------------------------------------------

  Widget _buildStaleBanner() {
    final info = _staleInfo!;
    final parts = <String>[];
    if (info.countMismatch) {
      parts.add('${info.sitemapCount} op website, ${info.dbCount} in database');
    }
    if (info.isOld) {
      parts.add(info.lastSync != null
          ? 'laatste sync: ${_formatDate(info.lastSync!)}'
          : 'nog nooit gesynchroniseerd');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFFF3E0),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFE65100)),
          const SizedBox(width: 10),
          Expanded(child: Text(
            '${_l.t('verouderd')}: ${parts.join(' · ')}',
            style: const TextStyle(fontSize: 12, color: Color(0xFFE65100)),
          )),
          TextButton.icon(
            icon: const Icon(Icons.sync, size: 16),
            label: Text(_l.t('nu_bijwerken'), style: const TextStyle(fontSize: 12)),
            onPressed: () {
              setState(() { _staleInfo = null; });
              _syncFromWebsite();
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day}-${d.month}-${d.year}';
  }

  Widget _buildBackgroundSyncBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: const Color(0xFF455A64).withValues(alpha: 0.05),
      child: Row(
        children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Text(_l.t('achtergrond_sync'), style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
        ],
      ),
    );
  }

  Widget _buildSyncBar() {
    final p = _syncProgress!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF455A64).withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 10),
            Expanded(child: Text('${p.current} / ${p.total} — ${p.currentProduct}', style: const TextStyle(fontSize: 12, color: Color(0xFF455A64)))),
          ]),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: p.fraction, backgroundColor: const Color(0xFFCFD8DC), color: const Color(0xFF455A64)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------
  // Product body (grid/list/empty/loading/error)
  // ---------------------------------------------------------------

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFE53935)),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Color(0xFFE53935))),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadData, child: Text(_l.t('opnieuw_proberen'))),
        ],
      ));
    }
    if (_allProducts.isEmpty) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/ventoz_logo.png', width: 64, height: 64, opacity: const AlwaysStoppedAnimation(0.3)),
          const SizedBox(height: 16),
          Text(_l.t('geen_producten'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
          const SizedBox(height: 8),
          Text(_l.t('sync_eerst'), style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          if (_permissions.productenBewerken) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.sync, size: 18),
              label: Text(_l.t('nu_synchroniseren')),
              onPressed: _syncFromWebsite,
            ),
          ],
        ],
      ));
    }
    if (_filteredProducts.isEmpty) {
      return Center(child: Text(_l.t('geen_gevonden'), style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8))));
    }

    if (_gridView) return _buildGridView();
    return _buildListView();
  }

  Widget _buildGridView() {
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 600 ? 3 : 2;
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.72,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) => _buildProductCard(_filteredProducts[index]),
      );
    });
  }

  Widget _buildListView() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredProducts.length,
      separatorBuilder: (_, i) => const SizedBox(height: 6),
      itemBuilder: (context, index) => _buildProductListTile(_filteredProducts[index]),
    );
  }

  // ---------------------------------------------------------------
  // Product card / list tile
  // ---------------------------------------------------------------

  Widget _buildProductCard(CatalogProduct product) {
    final displayName = product.naamForLang(_lang);
    final productKey = product.artikelnummer ?? product.naam;
    final isFav = _favorietenService.isFavoriet(productKey);
    final isSelected = product.id != null && _selectedForBlock.contains(product.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? const BorderSide(color: Color(0xFFE53935), width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          if (_selectedForBlock.isNotEmpty && _permissions.productenBlokkeren && product.id != null) {
            setState(() {
              if (isSelected) { _selectedForBlock.remove(product.id); } else { _selectedForBlock.add(product.id!); }
            });
          } else {
            _showProductDetail(product);
          }
        },
        onLongPress: _permissions.productenBlokkeren && product.id != null ? () {
          setState(() {
            if (isSelected) { _selectedForBlock.remove(product.id); } else { _selectedForBlock.add(product.id!); }
          });
        } : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: product.displayAfbeeldingUrl != null
                        ? Image.network(product.displayAfbeeldingUrl!, width: double.infinity, fit: BoxFit.contain, errorBuilder: (_, e2, s2) => _buildPlaceholderImage())
                        : _buildPlaceholderImage(),
                  ),
                  if (_permissions.productenBlokkeren && isSelected)
                    Positioned(
                      top: 4, left: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle),
                        child: const Icon(Icons.check, size: 16, color: Colors.white),
                      ),
                    ),
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => _toggleFavoriet(product),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                        child: Icon(isFav ? Icons.favorite : Icons.favorite_border, size: 18, color: isFav ? const Color(0xFFE53935) : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF455A64).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
                        child: Text(product.categorieLabel, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF455A64))),
                      ),
                      const Spacer(),
                      _buildStockBadge(product.inStock),
                    ]),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(displayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B), height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    Row(
                      children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product.prijs != null) ...[
                              Text(_formatCardPrice(product), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                                color: (_appUser != null && _appUser!.effectiveKorting > 0) ? const Color(0xFF2E7D32) : const Color(0xFF455A64))),
                              if (_appUser != null && _appUser!.effectiveKorting > 0)
                                Text(product.prijsFormatted, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), decoration: TextDecoration.lineThrough)),
                            ],
                            if (product.staffelprijzen != null && product.staffelprijzen!.isNotEmpty) ...[
                              Builder(builder: (_) {
                                final minVal = product.staffelprijzen!.values.reduce((a, b) => a < b ? a : b);
                                final display = _showInclVat ? minVal : PricingService.exclVat(minVal);
                                return Text('${_l.t('vanaf')} ${PricingService.formatEuro(display)}',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF78909C)));
                              }),
                            ],
                          ],
                        )),
                        if (product.inStock)
                          SizedBox(
                            width: 32, height: 32,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.add_shopping_cart, size: 18, color: Color(0xFF455A64)),
                              tooltip: _l.t('toevoegen_aan_winkelmand'),
                              onPressed: () => _addToCart(product),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductListTile(CatalogProduct product) {
    final displayName = product.naamForLang(_lang);
    final hasDiscount = _appUser != null && _appUser!.effectiveKorting > 0;
    final productKey = product.artikelnummer ?? product.naam;
    final isFav = _favorietenService.isFavoriet(productKey);
    final isSelected = product.id != null && _selectedForBlock.contains(product.id);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? const BorderSide(color: Color(0xFFE53935), width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          if (_selectedForBlock.isNotEmpty && _permissions.productenBlokkeren && product.id != null) {
            setState(() {
              if (isSelected) { _selectedForBlock.remove(product.id); } else { _selectedForBlock.add(product.id!); }
            });
          } else {
            _showProductDetail(product);
          }
        },
        onLongPress: _permissions.productenBlokkeren && product.id != null ? () {
          setState(() {
            if (isSelected) { _selectedForBlock.remove(product.id); } else { _selectedForBlock.add(product.id!); }
          });
        } : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: product.displayAfbeeldingUrl != null
                    ? Image.network(product.displayAfbeeldingUrl!, width: 64, height: 64, fit: BoxFit.contain,
                        errorBuilder: (_, e3, s3) => Container(width: 64, height: 64, color: const Color(0xFFF5F7F8), child: const Icon(Icons.sailing, color: Color(0xFFB0BEC5))))
                    : Container(width: 64, height: 64, color: const Color(0xFFF5F7F8), child: const Icon(Icons.sailing, color: Color(0xFFB0BEC5))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF455A64).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
                      child: Text(product.categorieLabel, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF455A64))),
                    ),
                    const SizedBox(width: 6),
                    _buildStockBadge(product.inStock),
                    if (product.artikelnummer != null) ...[
                      const SizedBox(width: 6),
                      Text('Art. ${product.artikelnummer}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(displayName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (product.sailArea != null)
                    Text(product.sailArea!, style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
                ],
              )),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (product.prijs != null) ...[
                    Text(_formatCardPrice(product), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: hasDiscount ? const Color(0xFF2E7D32) : const Color(0xFF455A64))),
                    if (hasDiscount) Text(product.prijsFormatted, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), decoration: TextDecoration.lineThrough)),
                  ],
                  if (product.staffelprijzen != null && product.staffelprijzen!.isNotEmpty)
                    Builder(builder: (_) {
                      final minVal = product.staffelprijzen!.values.reduce((a, b) => a < b ? a : b);
                      final display = _showInclVat ? minVal : PricingService.exclVat(minVal);
                      return Text('${_l.t('vanaf')} ${PricingService.formatEuro(display)}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF78909C)));
                    }),
                ],
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _toggleFavoriet(product),
                child: Icon(isFav ? Icons.favorite : Icons.favorite_border, size: 20, color: isFav ? const Color(0xFFE53935) : const Color(0xFFB0BEC5)),
              ),
              if (product.inStock) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _addToCart(product),
                  child: const Icon(Icons.add_shopping_cart, size: 20, color: Color(0xFF455A64)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF5F7F8),
      child: const Center(child: Icon(Icons.sailing, size: 40, color: Color(0xFFB0BEC5))),
    );
  }
}

class _ProductDetailContent extends StatefulWidget {
  final CatalogProduct product;
  final String displayName;
  final String? displayDesc;
  final bool isWide;
  final bool isAdmin;
  final bool showInclVat;
  final AppUser? appUser;
  final String lang;
  final AppLocalizations l;
  final FavorietenService favorietenService;
  final VoidCallback onClose;
  final void Function(CatalogProduct) onAddToCart;
  final void Function(CatalogProduct) onToggleFavoriet;
  final void Function(CatalogProduct, bool) onToggleBlock;
  final void Function(String) onOpenUrl;

  const _ProductDetailContent({
    required this.product,
    required this.displayName,
    this.displayDesc,
    required this.isWide,
    required this.isAdmin,
    required this.showInclVat,
    this.appUser,
    required this.lang,
    required this.l,
    required this.favorietenService,
    required this.onClose,
    required this.onAddToCart,
    required this.onToggleFavoriet,
    required this.onToggleBlock,
    required this.onOpenUrl,
  });

  @override
  State<_ProductDetailContent> createState() => _ProductDetailContentState();
}

class _ProductDetailContentState extends State<_ProductDetailContent> {
  int _selectedImageIndex = 0;
  List<MarketplaceListing> _marketplaceListings = [];

  List<String> get _images => widget.product.alleAfbeeldingen;

  @override
  void initState() {
    super.initState();
    if (widget.isAdmin && widget.product.id != null) {
      MarketplaceService().getListings(productId: widget.product.id!).then((listings) {
        if (mounted) setState(() => _marketplaceListings = listings);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            IconButton(icon: const Icon(Icons.close, size: 20), onPressed: widget.onClose),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: widget.isWide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 5, child: _buildImageSection()),
                    const SizedBox(width: 32),
                    Expanded(flex: 5, child: _buildInfoSection(p)),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildImageSection(),
                    const SizedBox(height: 20),
                    _buildInfoSection(p),
                  ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildImageSection() {
    if (_images.isEmpty) {
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFFF5F7F8), borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Icon(Icons.sailing, size: 64, color: Color(0xFFB0BEC5))),
        ),
      );
    }

    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.network(
            _images[_selectedImageIndex],
            fit: BoxFit.contain,
            width: double.infinity,
            errorBuilder: (_, _, _) => Container(
              color: const Color(0xFFF5F7F8),
              child: const Center(child: Icon(Icons.sailing, size: 64, color: Color(0xFFB0BEC5))),
            ),
          ),
        ),
      ),
      if (_images.length > 1) ...[
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _images.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => setState(() => _selectedImageIndex = i),
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: i == _selectedImageIndex ? const Color(0xFF1B2A4A) : const Color(0xFFE2E8F0),
                    width: i == _selectedImageIndex ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(_images[i], fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 16, color: Color(0xFFB0BEC5))),
              ),
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _buildInfoSection(CatalogProduct p) {
    final productKey = p.artikelnummer ?? p.naam;
    final isFav = widget.favorietenService.isFavoriet(productKey);
    final hasDiscount = widget.appUser != null && widget.appUser!.effectiveKorting > 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFF455A64).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(p.categorieLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF455A64))),
        ),
        const SizedBox(width: 8),
        if (p.artikelnummer != null)
          Text('Art. ${p.artikelnummer}', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: p.inStock ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: p.inStock ? const Color(0xFF43A047) : const Color(0xFFE65100))),
            const SizedBox(width: 6),
            Text(p.inStock ? 'Op voorraad' : 'Niet op voorraad',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: p.inStock ? const Color(0xFF2E7D32) : const Color(0xFFE65100))),
          ]),
        ),
      ]),
      const SizedBox(height: 14),
      Text(widget.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      const SizedBox(height: 12),
      if (p.prijs != null) ...[
        Builder(builder: (_) {
          if (widget.appUser == null) {
            final price = widget.showInclVat ? p.prijs! : PricingService.exclVat(p.prijs!);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(PricingService.formatEuro(price), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(widget.showInclVat ? 'incl. BTW' : 'excl. BTW', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ),
              ]),
            ]);
          }
          final bd = PricingService.calculate(product: p, user: widget.appUser!);
          final mainPrice = widget.showInclVat ? bd.totalInclVat : bd.afterDiscountExcl;
          final origPrice = widget.showInclVat ? bd.catalogPriceInclVat : bd.unitPriceExclVat;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(PricingService.formatEuro(mainPrice),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                  color: hasDiscount ? const Color(0xFF2E7D32) : const Color(0xFF1E293B))),
              if (hasDiscount) ...[
                const SizedBox(width: 8),
                Text(PricingService.formatEuro(origPrice),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8), decoration: TextDecoration.lineThrough)),
              ],
            ]),
            if (hasDiscount)
              Text('-${bd.discountPercentage.toStringAsFixed(0)}% korting',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
            if (bd.reverseCharge)
              const Text('excl. BTW (verlegd)', style: TextStyle(fontSize: 11, color: Color(0xFF78909C)))
            else
              Text(widget.showInclVat ? 'incl. BTW' : 'excl. BTW', style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
          ]);
        }),
      ],

      if (p.staffelprijzen != null && p.staffelprijzen!.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(widget.l.t('staffelprijzen'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF455A64))),
        const SizedBox(height: 6),
        ...p.staffelprijzen!.entries.map((e) {
          final price = widget.showInclVat ? e.value : PricingService.exclVat(e.value);
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(children: [
              SizedBox(width: 50, child: Text('${e.key}×', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              Text('${PricingService.formatEuro(price)} p/s', style: const TextStyle(fontSize: 13, color: Color(0xFF455A64))),
            ]),
          );
        }),
      ],

      if (widget.displayDesc != null && widget.displayDesc!.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        ..._buildFormattedDescription(widget.displayDesc!),
      ],

      const SizedBox(height: 20),
      const Divider(),
      const SizedBox(height: 12),

      if (p.inStock)
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: Text(widget.l.t('toevoegen_aan_winkelmand')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => widget.onAddToCart(p),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? const Color(0xFFE53935) : const Color(0xFF94A3B8)),
            tooltip: widget.l.t('favoriet'),
            onPressed: () => widget.onToggleFavoriet(p),
          ),
        ])
      else
        OutlinedButton.icon(
          icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, size: 18, color: isFav ? const Color(0xFFE53935) : null),
          label: Text(isFav ? widget.l.t('favoriet_verwijderen') : widget.l.t('toevoegen_aan_favorieten')),
          onPressed: () => widget.onToggleFavoriet(p),
        ),

      if (p.webshopUrl != null) ...[
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(widget.l.t('bekijk_op_site')),
            onPressed: () => widget.onOpenUrl(p.webshopUrl!),
          ),
        ),
      ],

      if (widget.isAdmin && p.id != null) ...[
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: p.geblokkeerd
              ? OutlinedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF43A047)),
                  label: const Text('Deblokkeren', style: TextStyle(color: Color(0xFF43A047))),
                  onPressed: () => widget.onToggleBlock(p, false),
                )
              : OutlinedButton.icon(
                  icon: const Icon(Icons.block, size: 16, color: Color(0xFFE53935)),
                  label: const Text('Blokkeren voor catalogus', style: TextStyle(color: Color(0xFFE53935))),
                  onPressed: () => widget.onToggleBlock(p, true),
                ),
        ),
      ],

      if (widget.isAdmin && p.id != null) ...[
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        _buildMarketplaceSection(p),
      ],
    ]);
  }

  // ── Marketplace Management Panel ──

  static const _platformLanguages = <MarketplacePlatform, List<String>>{
    MarketplacePlatform.bolCom: ['nl', 'fr'],
    MarketplacePlatform.ebay: ['nl', 'en', 'de', 'fr'],
    MarketplacePlatform.amazon: ['nl', 'en', 'de', 'fr', 'it', 'es'],
    MarketplacePlatform.marktplaats: ['nl'],
  };

  Widget _buildMarketplaceSection(CatalogProduct p) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF455A64)),
        const SizedBox(width: 8),
        const Text('Marktplaatsen', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        const Spacer(),
        _buildStockIndicator(),
      ]),
      const SizedBox(height: 12),

      ...MarketplacePlatform.values.map((platform) => _buildPlatformRow(p, platform)),

      if (_marketplaceListings.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Voorraad < 5: waarschuwing  •  < 2: auto-pauzeren  •  0: advertenties sluiten',
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            )),
          ]),
        ),
      ],
    ]);
  }

  Widget _buildStockIndicator() {
    final stock = _marketplaceListings.isNotEmpty ? _marketplaceListings.first.productVoorraad : null;
    if (stock == null) return const SizedBox.shrink();
    final Color bg, fg;
    final String label;
    if (stock <= 0) {
      bg = const Color(0xFFFFEBEE); fg = const Color(0xFFE53935); label = 'Uitverkocht';
    } else if (stock < 2) {
      bg = const Color(0xFFFFEBEE); fg = const Color(0xFFE53935); label = '$stock stuk — AUTO-PAUZEREN';
    } else if (stock < 5) {
      bg = const Color(0xFFFFF3E0); fg = const Color(0xFFE65100); label = '$stock stuks — LET OP';
    } else {
      bg = const Color(0xFFE8F5E9); fg = const Color(0xFF2E7D32); label = '$stock op voorraad';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  Widget _buildPlatformRow(CatalogProduct product, MarketplacePlatform platform) {
    final listing = _marketplaceListings.where((l) => l.platform == platform).toList();
    final isListed = listing.isNotEmpty;
    final primaryListing = isListed ? listing.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isListed ? _platformColorForCode(platform).withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_platformIconForCode(platform), size: 18, color: _platformColorForCode(platform)),
          const SizedBox(width: 8),
          Text(platform.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const Spacer(),
          if (isListed) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor(primaryListing!.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(primaryListing.status.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor(primaryListing.status))),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
              child: const Text('Niet actief', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
            ),
          ],
        ]),

        if (isListed) ...[
          const SizedBox(height: 8),
          // Show all language variants
          ...listing.map((l) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                child: Text(l.taal.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF455A64), letterSpacing: 0.5)),
              ),
              const SizedBox(width: 8),
              if (l.prijs != null)
                Text('€ ${l.prijs!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
              const Spacer(),
              if (l.syncFout != null)
                Tooltip(message: l.syncFout!, child: const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFE65100)))
              else if (l.laatsteSync != null)
                Text('Synced ${_timeAgo(l.laatsteSync!)}', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
            ]),
          )),

          const SizedBox(height: 6),
          Row(children: [
            _miniAction('Bewerk', Icons.edit, () => _showListingEditor(product, platform, primaryListing)),
            const SizedBox(width: 6),
            if (primaryListing!.status == ListingStatus.actief)
              _miniAction('Pauzeer', Icons.pause, () async {
                await MarketplaceService().updateListing(primaryListing.id!, status: ListingStatus.gepauzeerd);
                _reloadMarketplace();
              })
            else if (primaryListing.status == ListingStatus.gepauzeerd || primaryListing.status == ListingStatus.concept)
              _miniAction('Activeer', Icons.play_arrow, () async {
                await MarketplaceService().publishListing(primaryListing.id!);
                await MarketplaceService().updateListing(primaryListing.id!, status: ListingStatus.actief);
                _reloadMarketplace();
              }),
            const Spacer(),
            _miniAction('Verwijder', Icons.delete_outline, () async {
              await MarketplaceService().deleteListing(primaryListing.id!);
              _reloadMarketplace();
            }, color: const Color(0xFFE53935)),
          ]),
        ] else ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity, height: 32,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 14),
              label: Text('Adverteren op ${platform.label}', style: const TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _platformColorForCode(platform),
                side: BorderSide(color: _platformColorForCode(platform).withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () => _showListingEditor(product, platform, null),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _miniAction(String label, IconData icon, VoidCallback onTap, {Color? color}) {
    final c = color ?? const Color(0xFF455A64);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c)),
        ]),
      ),
    );
  }

  void _showListingEditor(CatalogProduct product, MarketplacePlatform platform, MarketplaceListing? existing) {
    final prijsCtrl = TextEditingController(text: existing?.prijs?.toStringAsFixed(2) ?? product.prijs?.toStringAsFixed(2) ?? '');
    String selectedTaal = existing?.taal ?? 'nl';
    bool voorraadSync = existing?.voorraadSync ?? true;
    final availableLanguages = _platformLanguages[platform] ?? ['nl'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(children: [
            Icon(_platformIconForCode(platform), size: 20, color: _platformColorForCode(platform)),
            const SizedBox(width: 8),
            Text(existing != null ? '${platform.label} bewerken' : 'Adverteren op ${platform.label}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(product.naam, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF455A64))),
              const SizedBox(height: 16),
              TextField(
                controller: prijsCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Prijs (EUR)', border: OutlineInputBorder(), prefixText: '€ ', isDense: true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: availableLanguages.contains(selectedTaal) ? selectedTaal : availableLanguages.first,
                decoration: const InputDecoration(labelText: 'Taal advertentie', border: OutlineInputBorder(), isDense: true),
                items: availableLanguages.map((lang) => DropdownMenuItem(
                  value: lang,
                  child: Text(_langLabel(lang)),
                )).toList(),
                onChanged: (v) => setD(() => selectedTaal = v!),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: voorraadSync,
                onChanged: (v) => setD(() => voorraadSync = v),
                title: const Text('Voorraad automatisch synchroniseren', style: TextStyle(fontSize: 12)),
                subtitle: const Text('Inclusief auto-pauzeren bij lage voorraad', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              if (product.translatedNames.containsKey(selectedTaal)) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.check_circle, size: 14, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      'Vertaling beschikbaar: ${product.translatedNames[selectedTaal]}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF2E7D32)),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    )),
                  ]),
                ),
              ] else if (selectedTaal != 'nl') ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.translate, size: 14, color: Color(0xFFE65100)),
                    SizedBox(width: 6),
                    Expanded(child: Text('Geen vertaling beschikbaar. Nederlandse tekst wordt gebruikt.', style: TextStyle(fontSize: 10, color: Color(0xFFE65100)))),
                  ]),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final prijs = double.tryParse(prijsCtrl.text.replaceAll(',', '.'));
                final svc = MarketplaceService();
                try {
                  if (existing != null) {
                    await svc.updateListing(existing.id!, prijs: prijs, taal: selectedTaal, voorraadSync: voorraadSync);
                  } else {
                    await svc.createListing(MarketplaceListing(
                      productId: product.id!,
                      platform: platform,
                      prijs: prijs,
                      taal: selectedTaal,
                      voorraadSync: voorraadSync,
                    ));
                  }
                  _reloadMarketplace();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fout: $e'), backgroundColor: const Color(0xFFE53935)));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _platformColorForCode(platform), foregroundColor: Colors.white),
              child: Text(existing != null ? 'Opslaan' : 'Aanmaken'),
            ),
          ],
        ),
      ),
    );
  }

  void _reloadMarketplace() {
    if (widget.product.id != null) {
      MarketplaceService().getListings(productId: widget.product.id!).then((listings) {
        if (mounted) setState(() => _marketplaceListings = listings);
      });
    }
  }

  String _langLabel(String code) => switch (code) {
    'nl' => '🇳🇱 Nederlands',
    'en' => '🇬🇧 English',
    'de' => '🇩🇪 Deutsch',
    'fr' => '🇫🇷 Français',
    'es' => '🇪🇸 Español',
    'it' => '🇮🇹 Italiano',
    _ => code.toUpperCase(),
  };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'zojuist';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m geleden';
    if (diff.inHours < 24) return '${diff.inHours}u geleden';
    return '${diff.inDays}d geleden';
  }

  IconData _platformIconForCode(MarketplacePlatform p) {
    switch (p) {
      case MarketplacePlatform.bolCom: return Icons.store_rounded;
      case MarketplacePlatform.ebay: return Icons.gavel_rounded;
      case MarketplacePlatform.amazon: return Icons.shopping_cart_rounded;
      case MarketplacePlatform.marktplaats: return Icons.sell_rounded;
    }
  }

  Color _platformColorForCode(MarketplacePlatform p) {
    switch (p) {
      case MarketplacePlatform.bolCom: return const Color(0xFF0070E0);
      case MarketplacePlatform.ebay: return const Color(0xFFE53238);
      case MarketplacePlatform.amazon: return const Color(0xFFFF9900);
      case MarketplacePlatform.marktplaats: return const Color(0xFF34A853);
    }
  }

  Color _statusColor(ListingStatus s) {
    switch (s) {
      case ListingStatus.actief: return const Color(0xFF2E7D32);
      case ListingStatus.concept: return const Color(0xFF1565C0);
      case ListingStatus.gepauzeerd: return const Color(0xFFE65100);
      case ListingStatus.verwijderd: return const Color(0xFF94A3B8);
      case ListingStatus.fout: return const Color(0xFFE53935);
    }
  }

  static const _descNavy = Color(0xFF1E293B);
  static const _descSlate = Color(0xFF64748B);
  static final _specLinePattern = RegExp(r'^(Voorlijk|Achterlijk|Onderlijk|Bovenlijk|Oppervlakte|Luff|Foot|Sail Area)\s*:\s*(.+)$', caseSensitive: false);

  List<Widget> _buildFormattedDescription(String text) {
    final paragraphs = text.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
    if (paragraphs.isEmpty) {
      return [Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.6))];
    }
    final widgets = <Widget>[];
    for (var i = 0; i < paragraphs.length; i++) {
      final para = paragraphs[i].trim();
      if (para == '---') {
        widgets.add(const SizedBox(height: 6));
        continue;
      }
      if (i > 0) widgets.add(const SizedBox(height: 10));
      if (para.startsWith('• ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('•  ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _descNavy)),
            Expanded(child: Text(para.substring(2), style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.5))),
          ]),
        ));
      } else if (_specLinePattern.hasMatch(para)) {
        final m = _specLinePattern.firstMatch(para)!;
        widgets.add(Row(children: [
          Text('${m.group(1)}: ', style: TextStyle(fontSize: 13, color: _descSlate)),
          Text(m.group(2)!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _descNavy)),
        ]));
      } else {
        widgets.add(Text(para, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.6)));
      }
    }
    return widgets;
  }
}
