import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/packaging_service.dart';
import '../services/user_service.dart';
import '../services/web_scraper_service.dart';
import '../models/catalog_product.dart';

class AdminBoxesScreen extends StatefulWidget {
  const AdminBoxesScreen({super.key});

  @override
  State<AdminBoxesScreen> createState() => _AdminBoxesScreenState();
}

class _AdminBoxesScreenState extends State<AdminBoxesScreen> {
  static const _navy = Color(0xFF0D1B2A);

  final _packagingService = PackagingService();
  final _userService = UserService();
  List<PackagingBox> _boxes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.verpakkingenBeheren) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
        );
      }
      return;
    }
    _boxes = await _packagingService.getAll();
    if (mounted) setState(() => _loading = false);
  }

  void _showEditDialog({PackagingBox? box}) async {
    final naamCtrl = TextEditingController(text: box?.naam ?? '');
    final gewichtCtrl = TextEditingController(text: box?.gewicht.toString() ?? '');
    final lengteCtrl = TextEditingController(text: box != null && box.lengteCm > 0 ? box.lengteCm.toString() : '');
    final breedteCtrl = TextEditingController(text: box != null && box.breedteCm > 0 ? box.breedteCm.toString() : '');
    final hoogteCtrl = TextEditingController(text: box != null && box.hoogteCm > 0 ? box.hoogteCm.toString() : '');
    final maxGewichtCtrl = TextEditingController(text: box != null && box.maxGewichtGram > 0 ? box.maxGewichtGram.toString() : '');
    final isNew = box == null;

    List<CatalogProduct> catalogProducts = [];
    Set<String> linkedProductIds = {};

    try {
      catalogProducts = await WebScraperService().fetchCatalog(includeBlocked: true);
      if (box?.id != null) {
        final links = await _packagingService.getLinksForBox(box!.id!);
        linkedProductIds = links.map((l) => l.productId).toSet();
      }
    } catch (_) {}

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(isNew ? 'Verpakking toevoegen' : 'Verpakking bewerken',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: naamCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Naam',
                    hintText: 'bijv. Standaard doos',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: gewichtCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Gewicht doos (gram)',
                    suffixText: 'g',
                    hintText: 'bijv. 800',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  const Icon(Icons.straighten, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text('Afmetingen (optioneel)', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(
                    controller: lengteCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Lengte',
                      suffixText: 'cm',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: breedteCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Breedte',
                      suffixText: 'cm',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: hoogteCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Hoogte',
                      suffixText: 'cm',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  )),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: maxGewichtCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Max gewicht inhoud (gram, optioneel)',
                    suffixText: 'g',
                    hintText: 'bijv. 30000',
                    border: OutlineInputBorder(),
                  ),
                ),

                if (catalogProducts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    const Icon(Icons.checklist, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text('Producten die in deze doos passen', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                  ]),
                  const SizedBox(height: 8),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: catalogProducts.length,
                      itemBuilder: (_, i) {
                        final p = catalogProducts[i];
                        final pid = p.artikelnummer ?? p.id.toString();
                        final checked = linkedProductIds.contains(pid);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (v) {
                            setSt(() {
                              if (v == true) {
                                linkedProductIds.add(pid);
                              } else {
                                linkedProductIds.remove(pid);
                              }
                            });
                          },
                          title: Text(p.displayNaam, style: const TextStyle(fontSize: 12)),
                          subtitle: p.artikelnummer != null
                              ? Text(p.artikelnummer!, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)))
                              : null,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
                  ),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuleren'),
            ),
            ElevatedButton(
              onPressed: () async {
                final naam = naamCtrl.text.trim();
                final gewicht = int.tryParse(gewichtCtrl.text) ?? 0;
                if (naam.isEmpty || gewicht <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vul naam en gewicht in'), backgroundColor: Color(0xFFE65100)),
                  );
                  return;
                }
                Navigator.pop(ctx);

                final savedBox = PackagingBox(
                  id: box?.id,
                  naam: naam,
                  gewicht: gewicht,
                  lengteCm: int.tryParse(lengteCtrl.text) ?? 0,
                  breedteCm: int.tryParse(breedteCtrl.text) ?? 0,
                  hoogteCm: int.tryParse(hoogteCtrl.text) ?? 0,
                  maxGewichtGram: int.tryParse(maxGewichtCtrl.text) ?? 0,
                  sortOrder: box?.sortOrder ?? _boxes.length,
                );
                await _packagingService.save(savedBox);

                if (box?.id != null) {
                  final links = linkedProductIds.map((pid) {
                    final p = catalogProducts.where((cp) => (cp.artikelnummer ?? cp.id.toString()) == pid).firstOrNull;
                    return BoxProductLink(
                      verpakkingId: box!.id!,
                      productId: pid,
                      productNaam: p?.displayNaam ?? pid,
                    );
                  }).toList();
                  await _packagingService.setLinksForBox(box!.id!, links);
                }

                _load();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
              child: Text(isNew ? 'Toevoegen' : 'Opslaan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(PackagingBox box) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verwijderen?'),
        content: Text('Verpakking "${box.naam}" verwijderen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (confirmed == true && box.id != null) {
      await _packagingService.delete(box.id!);
      _load();
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final item = _boxes.removeAt(oldIndex);
    _boxes.insert(newIndex, item);
    setState(() {});
    await _packagingService.updateSortOrder(_boxes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/ventoz_logo.png', width: 28, height: 28)),
          const SizedBox(width: 10),
          const Text('Verpakkingen'),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: 'Toevoegen', onPressed: () => _showEditDialog()),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _boxes.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFFB0BEC5)),
                  const SizedBox(height: 16),
                  const Text('Geen verpakkingen', style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Eerste verpakking toevoegen'),
                    onPressed: () => _showEditDialog(),
                  ),
                ]))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _boxes.length,
                  onReorder: _onReorder,
                  itemBuilder: (_, i) {
                    final box = _boxes[i];
                    return Card(
                      key: ValueKey(box.id ?? i),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B4965).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2, color: Color(0xFF1B4965), size: 20),
                        ),
                        title: Text(box.naam, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
                        subtitle: Text(
                          '${box.gewicht}g${box.hasAfmetingen ? '  \u00B7  ${box.afmetingenLabel}' : ''}${box.maxGewichtGram > 0 ? '  \u00B7  max ${box.maxGewichtGram}g' : ''}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: Color(0xFF455A64)),
                            onPressed: () => _showEditDialog(box: box),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFE53935)),
                            onPressed: () => _delete(box),
                          ),
                          const Icon(Icons.drag_handle, size: 20, color: Color(0xFFB0BEC5)),
                        ]),
                      ),
                    );
                  },
                ),
      floatingActionButton: _boxes.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showEditDialog(),
              backgroundColor: const Color(0xFF455A64),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
