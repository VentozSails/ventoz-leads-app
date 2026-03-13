import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/catalog_product.dart';
import '../services/web_scraper_service.dart';
import '../services/featured_products_service.dart';
import '../services/user_service.dart';

class FeaturedProductsScreen extends StatefulWidget {
  const FeaturedProductsScreen({super.key});

  @override
  State<FeaturedProductsScreen> createState() => _FeaturedProductsScreenState();
}

class _FeaturedProductsScreenState extends State<FeaturedProductsScreen> {
  final _service = FeaturedProductsService();
  final _scraper = WebScraperService();
  final _userService = UserService();

  List<CatalogProduct> _allProducts = [];
  List<int> _selectedIds = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.uitgelichteProducten) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
        );
      }
      return;
    }
    try {
      final results = await Future.wait([
        _scraper.fetchCatalog(),
        _service.getFeaturedIds(),
      ]);
      if (mounted) {
        setState(() {
          _allProducts = results[0] as List<CatalogProduct>;
          _selectedIds = List<int>.from(results[1] as List<int>);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.setFeatured(_selectedIds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uitgelichte producten opgeslagen'), backgroundColor: Color(0xFF43A047)),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving featured products: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opslaan mislukt. Probeer het opnieuw.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleProduct(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        if (_selectedIds.length >= 15) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximaal 15 uitgelichte producten'), duration: Duration(seconds: 2)),
          );
          return;
        }
        _selectedIds.add(id);
      }
    });
  }

  void _moveUp(int id) {
    final idx = _selectedIds.indexOf(id);
    if (idx > 0) {
      setState(() {
        _selectedIds.removeAt(idx);
        _selectedIds.insert(idx - 1, id);
      });
    }
  }

  void _moveDown(int id) {
    final idx = _selectedIds.indexOf(id);
    if (idx < _selectedIds.length - 1) {
      setState(() {
        _selectedIds.removeAt(idx);
        _selectedIds.insert(idx + 1, id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uitgelichte producten'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, size: 18, color: Colors.white),
              label: const Text('Opslaan', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_selectedIds.isNotEmpty) _buildSelectedSection(),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFF78909C)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Selecteer maximaal 15 producten die op de landingspagina als slider worden getoond. '
                        'Gebruik de pijlen om de volgorde te wijzigen.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                  ]),
                ),
                const Divider(height: 1),
                ..._buildProductItems(),
              ],
            ),
    );
  }

  Widget _buildSelectedSection() {
    final selectedProducts = _selectedIds
        .map((id) => _allProducts.where((p) => p.id == id).firstOrNull)
        .where((p) => p != null)
        .cast<CatalogProduct>()
        .toList();

    return Container(
      color: const Color(0xFFFFF8E1),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Uitgelicht (${selectedProducts.length}/15)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          ...selectedProducts.map((p) {
            final idx = _selectedIds.indexOf(p.id!);
            return Card(
              margin: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                leading: SizedBox(
                  width: 40, height: 40,
                  child: p.afbeeldingUrl != null
                      ? Image.network(p.afbeeldingUrl!, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.sailing, size: 24))
                      : const Icon(Icons.sailing, size: 24),
                ),
                title: Text(p.naam, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(p.prijsFormatted, style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    onPressed: idx > 0 ? () => _moveUp(p.id!) : null,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 18),
                    onPressed: idx < _selectedIds.length - 1 ? () => _moveDown(p.id!) : null,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Color(0xFFE53935)),
                    onPressed: () => _toggleProduct(p.id!),
                    visualDensity: VisualDensity.compact,
                  ),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<Widget> _buildProductItems() {
    final available = _allProducts.where((p) => p.id != null && !_selectedIds.contains(p.id) && p.afbeeldingUrl != null).toList();

    final widgets = <Widget>[];
    for (var i = 0; i < available.length; i++) {
      final p = available[i];
      widgets.add(ListTile(
        leading: SizedBox(
          width: 48, height: 48,
          child: p.afbeeldingUrl != null
              ? Image.network(p.afbeeldingUrl!, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.sailing))
              : const Icon(Icons.sailing),
        ),
        title: Text(p.naam, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(children: [
          Text(p.prijsFormatted, style: const TextStyle(fontSize: 11)),
          if (p.categorie != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFFE8EAF6), borderRadius: BorderRadius.circular(4)),
              child: Text(p.categorieLabel, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1B2A4A)),
          onPressed: () => _toggleProduct(p.id!),
        ),
      ));
      if (i < available.length - 1) widgets.add(const Divider(height: 1));
    }
    return widgets;
  }
}
