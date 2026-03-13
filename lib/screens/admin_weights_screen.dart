import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/web_scraper_service.dart';
import '../models/catalog_product.dart';
import '../services/user_service.dart';

class AdminWeightsScreen extends StatefulWidget {
  const AdminWeightsScreen({super.key});

  @override
  State<AdminWeightsScreen> createState() => _AdminWeightsScreenState();
}

class _AdminWeightsScreenState extends State<AdminWeightsScreen> {
  static const _navy = Color(0xFF0D1B2A);

  final _scraper = WebScraperService();
  final _userService = UserService();
  List<CatalogProduct> _products = [];
  bool _loading = true;
  String _search = '';
  String? _categoryFilter;
  bool _onlyMissing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.productgewichtenBeheren) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
        );
      }
      return;
    }
    try {
      _products = await _scraper.fetchCatalog(includeBlocked: true);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<CatalogProduct> get _filtered {
    var list = _products;
    if (_onlyMissing) list = list.where((p) => p.gewicht == null).toList();
    if (_categoryFilter != null) list = list.where((p) => p.categorie == _categoryFilter).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((p) =>
        p.displayNaam.toLowerCase().contains(q) ||
        (p.artikelnummer?.toLowerCase().contains(q) ?? false)).toList();
    }
    return list;
  }

  List<String> get _categories {
    final cats = _products.map((p) => p.categorie).whereType<String>().toSet().toList();
    cats.sort();
    return cats;
  }

  int get _missingCount => _products.where((p) => p.gewicht == null).length;

  Future<void> _updateWeight(CatalogProduct product, double? gewicht) async {
    try {
      await _scraper.updateProductOverrides(product.id!, {'gewicht': gewicht});
      await _load();
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving weight: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opslaan mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFE53935)),
        );
      }
    }
  }

  void _showEditDialog(CatalogProduct product) {
    final ctrl = TextEditingController(
      text: product.gewicht != null ? product.gewicht!.toInt().toString() : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(product.displayNaam, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 300,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (product.artikelnummer != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Art.nr: ${product.artikelnummer}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Gewicht (gram)',
                suffixText: 'g',
                border: OutlineInputBorder(),
                hintText: 'bijv. 2500',
              ),
              autofocus: true,
            ),
          ]),
        ),
        actions: [
          if (product.gewicht != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateWeight(product, null);
              },
              child: const Text('Wissen', style: TextStyle(color: Color(0xFFE53935))),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final val = int.tryParse(ctrl.text);
              if (val != null && val > 0) {
                _updateWeight(product, val.toDouble());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final total = _products.length;
    final filled = total - _missingCount;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/ventoz_logo.png', width: 28, height: 28)),
          const SizedBox(width: 10),
          const Text('Productgewichten'),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Column(children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: filled == total ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$filled / $total ingevuld',
                        style: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: filled == total ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: Text('Alleen ontbrekend ($_missingCount)', style: const TextStyle(fontSize: 12)),
                      selected: _onlyMissing,
                      onSelected: (v) => setState(() => _onlyMissing = v),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 200,
                      height: 36,
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: const InputDecoration(
                          hintText: 'Zoeken...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      FilterChip(
                        label: const Text('Alle', style: TextStyle(fontSize: 11)),
                        selected: _categoryFilter == null,
                        onSelected: (_) => setState(() => _categoryFilter = null),
                      ),
                      const SizedBox(width: 4),
                      ..._categories.map((c) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: FilterChip(
                          label: Text(CatalogProduct(naam: '', categorie: c).categorieLabel, style: const TextStyle(fontSize: 11)),
                          selected: _categoryFilter == c,
                          onSelected: (_) => setState(() => _categoryFilter = _categoryFilter == c ? null : c),
                        ),
                      )),
                    ]),
                  ),
                ]),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text(
                        _onlyMissing ? 'Alle producten hebben een gewicht!' : 'Geen producten gevonden',
                        style: const TextStyle(color: Color(0xFF94A3B8)),
                      ))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) => _buildProductRow(filtered[i]),
                      ),
              ),
            ]),
    );
  }

  Widget _buildProductRow(CatalogProduct product) {
    final hasWeight = product.gewicht != null;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: product.displayAfbeeldingUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(product.displayAfbeeldingUrl!, width: 36, height: 36, fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(Icons.sailing, size: 20, color: Color(0xFFB0BEC5))),
            )
          : const Icon(Icons.sailing, size: 20, color: Color(0xFFB0BEC5)),
      title: Text(
        product.displayNaam,
        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: _navy),
        maxLines: 1, overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${product.categorieLabel}${product.artikelnummer != null ? ' • ${product.artikelnummer}' : ''}',
        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
      ),
      trailing: InkWell(
        onTap: () => _showEditDialog(product),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: hasWeight ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: hasWeight ? const Color(0xFFC8E6C9) : const Color(0xFFFFE0B2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              hasWeight ? Icons.scale : Icons.warning_amber,
              size: 14,
              color: hasWeight ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
            ),
            const SizedBox(width: 6),
            Text(
              hasWeight ? '${product.gewicht!.toInt()}g' : 'Instellen',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: hasWeight ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
              ),
            ),
          ]),
        ),
      ),
      onTap: () => _showEditDialog(product),
    );
  }
}
