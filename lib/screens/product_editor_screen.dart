import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../models/catalog_product.dart';
import '../services/web_scraper_service.dart';
import '../services/product_image_service.dart';

class ProductEditorScreen extends StatefulWidget {
  final CatalogProduct? initialProduct;
  const ProductEditorScreen({super.key, this.initialProduct});

  @override
  State<ProductEditorScreen> createState() => _ProductEditorScreenState();
}

class _ProductEditorScreenState extends State<ProductEditorScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _accent = Color(0xFF1B4965);

  final _scraperService = WebScraperService();

  List<CatalogProduct> _products = [];
  CatalogProduct? _selectedProduct;
  bool _loading = true;
  bool _saving = false;
  String _searchQuery = '';

  final _naamCtrl = TextEditingController();
  final _beschrijvingCtrl = TextEditingController();
  final _prijsCtrl = TextEditingController();
  final _afbeeldingUrlCtrl = TextEditingController();
  final _extraImageUrlCtrl = TextEditingController();
  final _seoTitleCtrl = TextEditingController();
  final _seoDescCtrl = TextEditingController();
  final _seoKeywordsCtrl = TextEditingController();
  final _materiaalCtrl = TextEditingController();
  final _luffCtrl = TextEditingController();
  final _footCtrl = TextEditingController();
  final _sailAreaCtrl = TextEditingController();
  final _inclusiefCtrl = TextEditingController();

  int _selectedImageIndex = 0;
  bool _uploading = false;

  Future<void> _uploadImage({bool isExtra = false}) async {
    final product = _selectedProduct;
    if (product == null || product.id == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _uploading = true);
    try {
      final filename = isExtra
          ? 'extra-${product.extraAfbeeldingen.length + 1}.${file.extension ?? 'jpg'}'
          : 'main.${file.extension ?? 'jpg'}';

      final url = await ProductImageService().uploadBytes(
        file.bytes!,
        product.id!,
        filename,
      );

      if (url != null && mounted) {
        if (isExtra) {
          final extras = List<String>.from(product.extraAfbeeldingen)..add(url);
          await _scraperService.updateProductOverrides(product.id!, {'extra_afbeeldingen': extras});
        } else {
          setState(() => _afbeeldingUrlCtrl.text = url);
          await _scraperService.updateProductOverrides(product.id!, {'afbeelding_url_override': url});
        }
        await _loadProducts();
        if (mounted) {
          final updated = _products.firstWhere((p) => p.id == product.id, orElse: () => product);
          _selectProduct(updated);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Afbeelding geüpload'), backgroundColor: Color(0xFF2E7D32)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload mislukt: $e'), backgroundColor: const Color(0xFFE53935)),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _naamCtrl.dispose();
    _beschrijvingCtrl.dispose();
    _prijsCtrl.dispose();
    _afbeeldingUrlCtrl.dispose();
    _extraImageUrlCtrl.dispose();
    _materiaalCtrl.dispose();
    _luffCtrl.dispose();
    _footCtrl.dispose();
    _sailAreaCtrl.dispose();
    _inclusiefCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    try {
      final products = await _scraperService.fetchCatalog(includeBlocked: true);
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
        if (widget.initialProduct != null) {
          _selectProduct(products.firstWhere(
            (p) => p.id == widget.initialProduct!.id,
            orElse: () => products.first,
          ));
        }
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectProduct(CatalogProduct product) {
    setState(() {
      _selectedProduct = product;
      _selectedImageIndex = 0;
      _naamCtrl.text = product.naamOverride ?? '';
      _beschrijvingCtrl.text = product.beschrijvingOverride ?? '';
      _prijsCtrl.text = product.prijsOverride?.toStringAsFixed(2) ?? '';
      _afbeeldingUrlCtrl.text = product.afbeeldingUrlOverride ?? '';
      _seoTitleCtrl.text = product.seoTitle ?? '';
      _seoDescCtrl.text = product.seoDescription ?? '';
      _seoKeywordsCtrl.text = product.seoKeywords ?? '';
      _materiaalCtrl.text = product.materiaal ?? '';
      _luffCtrl.text = product.luff ?? '';
      _footCtrl.text = product.foot ?? '';
      _sailAreaCtrl.text = product.sailArea ?? '';
      _inclusiefCtrl.text = product.inclusief ?? '';
    });
  }

  Future<void> _save() async {
    final product = _selectedProduct;
    if (product == null || product.id == null) return;

    setState(() => _saving = true);
    try {
      final overrides = <String, dynamic>{
        'naam_override': _naamCtrl.text.trim().isEmpty ? null : _naamCtrl.text.trim(),
        'beschrijving_override': _beschrijvingCtrl.text.trim().isEmpty ? null : _beschrijvingCtrl.text.trim(),
        'prijs_override': _prijsCtrl.text.trim().isEmpty ? null : double.tryParse(_prijsCtrl.text.trim().replaceAll(',', '.')),
        'afbeelding_url_override': _afbeeldingUrlCtrl.text.trim().isEmpty ? null : _afbeeldingUrlCtrl.text.trim(),
        'seo_title': _seoTitleCtrl.text.trim().isEmpty ? null : _seoTitleCtrl.text.trim(),
        'seo_description': _seoDescCtrl.text.trim().isEmpty ? null : _seoDescCtrl.text.trim(),
        'seo_keywords': _seoKeywordsCtrl.text.trim().isEmpty ? null : _seoKeywordsCtrl.text.trim(),
        'materiaal': _materiaalCtrl.text.trim().isEmpty ? null : _materiaalCtrl.text.trim(),
        'luff': _luffCtrl.text.trim().isEmpty ? null : _luffCtrl.text.trim(),
        'foot': _footCtrl.text.trim().isEmpty ? null : _footCtrl.text.trim(),
        'sail_area': _sailAreaCtrl.text.trim().isEmpty ? null : _sailAreaCtrl.text.trim(),
        'inclusief': _inclusiefCtrl.text.trim().isEmpty ? null : _inclusiefCtrl.text.trim(),
      };
      await _scraperService.updateProductOverrides(product.id!, overrides);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wijzigingen opgeslagen'), backgroundColor: Color(0xFF2E7D32)),
        );
        await _loadProducts();
        final updated = _products.firstWhere((p) => p.id == product.id, orElse: () => product);
        _selectProduct(updated);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opslaan mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFE53935)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addExtraImage() async {
    final url = _extraImageUrlCtrl.text.trim();
    if (url.isEmpty || _selectedProduct == null || _selectedProduct!.id == null) return;

    final current = List<String>.from(_selectedProduct!.extraAfbeeldingen);
    if (current.length >= 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximaal 9 extra afbeeldingen'), backgroundColor: Color(0xFFE65100)),
      );
      return;
    }
    current.add(url);

    try {
      await _scraperService.updateProductOverrides(_selectedProduct!.id!, {'extra_afbeeldingen': current});
      _extraImageUrlCtrl.clear();
      await _loadProducts();
      final updated = _products.firstWhere((p) => p.id == _selectedProduct!.id, orElse: () => _selectedProduct!);
      _selectProduct(updated);
    } catch (e) {
      if (kDebugMode) debugPrint('Error adding extra image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Toevoegen mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFE53935)),
        );
      }
    }
  }

  Future<void> _removeExtraImage(int index) async {
    if (_selectedProduct == null || _selectedProduct!.id == null) return;
    final current = List<String>.from(_selectedProduct!.extraAfbeeldingen);
    if (index < 0 || index >= current.length) return;
    current.removeAt(index);

    try {
      await _scraperService.updateProductOverrides(_selectedProduct!.id!, {'extra_afbeeldingen': current});
      await _loadProducts();
      final updated = _products.firstWhere((p) => p.id == _selectedProduct!.id, orElse: () => _selectedProduct!);
      _selectProduct(updated);
    } catch (e) {
      if (kDebugMode) debugPrint('Error removing extra image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verwijderen mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFE53935)),
        );
      }
    }
  }

  Future<void> _moveExtraImage(int from, int to) async {
    if (_selectedProduct == null || _selectedProduct!.id == null) return;
    final current = List<String>.from(_selectedProduct!.extraAfbeeldingen);
    if (from < 0 || from >= current.length || to < 0 || to >= current.length) return;
    final item = current.removeAt(from);
    current.insert(to, item);

    try {
      await _scraperService.updateProductOverrides(_selectedProduct!.id!, {'extra_afbeeldingen': current});
      await _loadProducts();
      final updated = _products.firstWhere((p) => p.id == _selectedProduct!.id, orElse: () => _selectedProduct!);
      _selectProduct(updated);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text('Product bewerken', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                _buildProductList(),
                Expanded(child: _selectedProduct == null ? _buildEmptyState() : _buildEditor()),
              ],
            ),
    );
  }

  Widget _buildProductList() {
    final filtered = _searchQuery.isEmpty
        ? _products
        : _products.where((p) {
            final hay = '${p.naam} ${p.artikelnummer ?? ''} ${p.categorieLabel}'.toLowerCase();
            return hay.contains(_searchQuery.toLowerCase());
          }).toList();

    return Container(
      width: 300,
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Zoeken...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${filtered.length} producten',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final p = filtered[i];
                final isSelected = _selectedProduct?.id == p.id;
                return Material(
                  color: isSelected ? _accent.withValues(alpha: 0.08) : Colors.transparent,
                  child: InkWell(
                    onTap: () => _selectProduct(p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: isSelected ? _accent : Colors.transparent,
                            width: 3,
                          ),
                          bottom: const BorderSide(color: Color(0xFFF1F5F9)),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: p.displayAfbeeldingUrl != null
                                  ? Image.network(
                                      p.displayAfbeeldingUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => Container(
                                        color: const Color(0xFFF0F4F8),
                                        child: const Icon(Icons.image, size: 18, color: Color(0xFFCBD5E1)),
                                      ),
                                    )
                                  : Container(
                                      color: const Color(0xFFF0F4F8),
                                      child: const Icon(Icons.image, size: 18, color: Color(0xFFCBD5E1)),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.displayNaam,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                    color: _navy,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    Text(
                                      p.categorieLabel,
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                    ),
                                    if (p.hasOverrides) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF2E7D32),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                    if (p.geblokkeerd) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.block, size: 10, color: Color(0xFFE53935)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit_note, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Selecteer een product om te bewerken',
            style: GoogleFonts.dmSans(fontSize: 16, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    final p = _selectedProduct!;
    final images = p.alleAfbeeldingen;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoBanner(),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 360, child: _buildImageSection(p, images)),
                    const SizedBox(width: 24),
                    Expanded(child: Column(children: [
                      _buildFormSection(p),
                      if (_hasSeoData(p)) ...[
                        const SizedBox(height: 20),
                        _buildSeoSection(p),
                      ],
                    ])),
                  ],
                );
              }
              return Column(
                children: [
                  _buildImageSection(p, images),
                  const SizedBox(height: 20),
                  _buildFormSection(p),
                  if (_hasSeoData(p)) ...[
                    const SizedBox(height: 20),
                    _buildSeoSection(p),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFF9A825), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Waarden van ventoz.nl worden periodiek bijgewerkt. Eigen aanpassingen (override) '
              'blijven behouden en hebben voorrang. Leeg laten = website-waarde gebruiken.',
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF5D4037), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(CatalogProduct p, List<String> images) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Afbeeldingen', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: images.isNotEmpty && _selectedImageIndex < images.length
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        images[_selectedImageIndex],
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image, size: 48, color: Color(0xFFCBD5E1)),
                        ),
                      ),
                    )
                  : const Center(child: Icon(Icons.image, size: 48, color: Color(0xFFCBD5E1))),
            ),
          ),
          if (images.length > 1) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final isActive = i == _selectedImageIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedImageIndex = i),
                    child: Container(
                      width: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isActive ? _accent : const Color(0xFFE2E8F0),
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Image.network(images[i], fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 16)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('Extra afbeeldingen beheren', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _navy)),
          const SizedBox(height: 8),
          if (p.extraAfbeeldingen.isNotEmpty) ...[
            ...List.generate(p.extraAfbeeldingen.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(p.extraAfbeeldingen[i], fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 14)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.extraAfbeeldingen[i].split('/').last,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (i > 0)
                      IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 16),
                        onPressed: () => _moveExtraImage(i, i - 1),
                        tooltip: 'Omhoog',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    if (i < p.extraAfbeeldingen.length - 1)
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 16),
                        onPressed: () => _moveExtraImage(i, i + 1),
                        tooltip: 'Omlaag',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFE53935)),
                      onPressed: () => _removeExtraImage(i),
                      tooltip: 'Verwijderen',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
          if (p.extraAfbeeldingen.length < 9)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _extraImageUrlCtrl,
                    decoration: InputDecoration(
                      hintText: 'Afbeelding-URL toevoegen',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addExtraImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    minimumSize: Size.zero,
                  ),
                  child: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFormSection(CatalogProduct p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Productgegevens', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
              const Spacer(),
              if (p.hasOverrides)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, size: 12, color: Color(0xFF2E7D32)),
                      SizedBox(width: 4),
                      Text('Overrides actief', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          _buildReadonlyField('Artikelnummer', p.artikelnummer ?? '-'),
          const SizedBox(height: 4),
          _buildReadonlyField('Categorie', p.categorieLabel),
          const SizedBox(height: 4),
          _buildReadonlyField('Webshop URL', p.webshopUrl ?? '-'),
          if (p.laatstBijgewerkt != null) ...[
            const SizedBox(height: 4),
            _buildReadonlyField('Laatst bijgewerkt',
              '${p.laatstBijgewerkt!.day}-${p.laatstBijgewerkt!.month}-${p.laatstBijgewerkt!.year}'),
          ],

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          _buildOverrideField(
            label: 'Naam',
            originalValue: p.naam,
            controller: _naamCtrl,
            hasOverride: p.naamOverride != null,
          ),
          const SizedBox(height: 16),
          _buildOverrideField(
            label: 'Beschrijving',
            originalValue: p.beschrijving ?? '-',
            controller: _beschrijvingCtrl,
            hasOverride: p.beschrijvingOverride != null,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          _buildOverrideField(
            label: 'Prijs (excl. BTW)',
            originalValue: p.prijs?.toStringAsFixed(2) ?? '-',
            controller: _prijsCtrl,
            hasOverride: p.prijsOverride != null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefix: '\u20AC ',
          ),
          const SizedBox(height: 16),
          _buildOverrideField(
            label: 'Afbeelding URL',
            originalValue: p.afbeeldingUrl ?? '-',
            controller: _afbeeldingUrlCtrl,
            hasOverride: p.afbeeldingUrlOverride != null,
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBDEFB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sailing, size: 18, color: Color(0xFF1565C0)),
                    const SizedBox(width: 8),
                    Text('Specificaties', style: GoogleFonts.dmSans(
                      fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1565C0),
                    )),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Worden getoond op de productpagina', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const SizedBox(height: 12),
                _buildSpecField('Materiaal', _materiaalCtrl, hint: 'bijv. sterk dacron (3.8 oz Newport by Challenge)'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildSpecField('Voorlijk / Luff', _luffCtrl, hint: 'bijv. 386 cm')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildSpecField('Onderlijk / Foot', _footCtrl, hint: 'bijv. 153 cm')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildSpecField('Zeiloppervlak', _sailAreaCtrl, hint: 'bijv. 2.8 m²')),
                    const SizedBox(width: 10),
                    const Expanded(child: SizedBox()),
                  ],
                ),
                const SizedBox(height: 10),
                _buildSpecField('Inclusief', _inclusiefCtrl, hint: 'bijv. zeilbattenset, opbergtas'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            OutlinedButton.icon(
              onPressed: _uploading ? null : () => _uploadImage(isExtra: false),
              icon: _uploading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file, size: 16),
              label: Text(_uploading ? 'Uploaden...' : 'Hoofdafbeelding uploaden'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1565C0),
                side: const BorderSide(color: Color(0xFF1565C0)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _uploading ? null : () => _uploadImage(isExtra: true),
              icon: const Icon(Icons.add_photo_alternate, size: 16),
              label: const Text('Extra afbeelding uploaden'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6A1B9A),
                side: const BorderSide(color: Color(0xFF6A1B9A)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ]),

          const SizedBox(height: 24),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 18),
                label: Text(_saving ? 'Opslaan...' : 'Opslaan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
              const SizedBox(width: 12),
              if (p.hasOverrides)
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _naamCtrl.clear();
                      _beschrijvingCtrl.clear();
                      _prijsCtrl.clear();
                      _afbeeldingUrlCtrl.clear();
                    });
                  },
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Alle overrides wissen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE53935),
                    side: const BorderSide(color: Color(0xFFE53935)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _hasSeoData(CatalogProduct p) {
    return (p.seoTitle ?? '').isNotEmpty ||
        (p.seoDescription ?? '').isNotEmpty ||
        (p.seoKeywords ?? '').isNotEmpty ||
        (p.canonicalUrl ?? '').isNotEmpty ||
        (p.ogImage ?? '').isNotEmpty;
  }

  Widget _buildSeoSection(CatalogProduct p) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.travel_explore, size: 18, color: Color(0xFF1565C0)),
            const SizedBox(width: 8),
            Text('SEO-informatie', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1565C0))),
          ]),
          const SizedBox(height: 14),
          _buildSeoTextField('Title tag', _seoTitleCtrl, 'Paginatitel voor zoekmachines'),
          const SizedBox(height: 10),
          _buildSeoTextField('Meta description', _seoDescCtrl, 'Korte beschrijving voor zoekmachines', maxLines: 3),
          const SizedBox(height: 10),
          _buildSeoTextField('Keywords', _seoKeywordsCtrl, 'Kommagescheiden zoekwoorden'),
          if ((p.canonicalUrl ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildSeoReadonly('Canonical URL', p.canonicalUrl!),
          ],
          if ((p.ogImage ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildSeoReadonly('OG Image', p.ogImage!),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                p.ogImage!,
                height: 80,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeoTextField(String label, TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1565C0))),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFBBDEFB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFBBDEFB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: Colors.white,
          ),
          style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF37474F)),
        ),
      ],
    );
  }

  Widget _buildSeoReadonly(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1565C0))),
        const SizedBox(height: 2),
        SelectableText(value, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF37474F), height: 1.4)),
      ],
    );
  }


  Widget _buildSpecField(String label, TextEditingController controller, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _navy)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFBBDEFB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFBBDEFB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadonlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildOverrideField({
    required String label,
    required String originalValue,
    required TextEditingController controller,
    required bool hasOverride,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
            if (hasOverride) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              const Text('override actief', style: TextStyle(fontSize: 10, color: Color(0xFF2E7D32), fontWeight: FontWeight.w500)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Van website: ', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
              Expanded(
                child: Text(
                  originalValue,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: 'Eigen aanpassing (leeg = website-waarde)',
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            prefixText: prefix,
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}
