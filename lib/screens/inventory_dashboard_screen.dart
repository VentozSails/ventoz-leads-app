import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/inventory_service.dart';
import '../services/user_service.dart';
import 'inventory_item_screen.dart';
import 'inventory_import_screen.dart';
import 'inventory_archive_screen.dart';

class InventoryDashboardScreen extends StatefulWidget {
  const InventoryDashboardScreen({super.key});

  static const routeName = '/dashboard/voorraad';

  @override
  State<InventoryDashboardScreen> createState() =>
      _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends State<InventoryDashboardScreen> {
  static const _navy = Color(0xFF1E3A5F);
  static const _hdrBg = Color(0xFF2E7D32);
  static const _hdrFg = Colors.white;
  static const _border = Color(0xFFD0D5DD);
  static const double _tableWidth = 16 + 150 + 90 + 30 + 100 + 40 + 36 + 32 + 56 + 56 + 50 + 56 + 56 + 56 + 56 + 56 + 56 + 46 + 20 + 70 + 8;

  final InventoryService _svc = InventoryService();
  final UserService _uSvc = UserService();
  final TextEditingController _searchCtl = TextEditingController();
  final ScrollController _hScroll = ScrollController();

  List<InventoryItem> _all = [];
  Map<String, List<InventoryItem>> _grouped = {};
  List<MapEntry<String, List<InventoryItem>>> _filtered = [];
  final Set<String> _collapsed = {};
  bool _loading = true;
  String? _error;
  bool _canImport = false;
  String? _selCat;
  String _sortBy = 'naam';
  bool _sortAsc = true;

  bool _selectMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() { super.initState(); _load(); _searchCtl.addListener(_filter); }

  @override
  void dispose() { _searchCtl.dispose(); _hScroll.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final perms = await _uSvc.getCurrentUserPermissions();
      if (!perms.voorraadBeheren) {
        if (mounted) { Navigator.of(context).pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geen toegang'), backgroundColor: Color(0xFFEF4444))); }
        return;
      }
      if (mounted) setState(() => _canImport = perms.voorraadImporteren);
      final items = await _svc.getAll();
      final grouped = <String, List<InventoryItem>>{};
      for (final it in items) (grouped[_gKey(it)] ??= []).add(it);
      if (mounted) { setState(() { _all = items; _grouped = grouped; _loading = false; }); _filter(); }
    } catch (e) {
      if (kDebugMode) debugPrint('InventoryDashboard: $e');
      if (mounted) setState(() { _loading = false; _error = 'Laden mislukt.'; });
    }
  }

  String _gKey(InventoryItem i) { final n = i.variantLabel.trim().toLowerCase(); return n.isEmpty ? '_overig_' : n; }
  String _gName(String k, List<InventoryItem> ii) => k == '_overig_' ? 'Overig' : (ii.first.variantLabel.isNotEmpty ? ii.first.variantLabel : 'Onbekend');
  String _gCat(List<InventoryItem> ii) { final c = ii.firstWhere((i) => i.categorie != null && i.categorie!.isNotEmpty, orElse: () => ii.first); return c.categorie ?? 'Overig'; }
  int _gStk(List<InventoryItem> ii) => ii.fold(0, (s, i) => s + i.voorraadActueel);
  int _gBest(List<InventoryItem> ii) => ii.fold(0, (s, i) => s + i.voorraadBesteld);
  double _gCost(List<InventoryItem> ii) => ii.fold(0.0, (s, i) => s + ((i.inkoopPrijs ?? 0) * i.voorraadActueel));
  double _gSaleI(List<InventoryItem> ii) => ii.fold(0.0, (s, i) => s + ((i.verkoopprijsIncl ?? 0) * i.voorraadActueel));

  Color _gColor(List<InventoryItem> ii) {
    final t = _gStk(ii);
    if (t <= 0) return const Color(0xFFF8D7DA);
    if (ii.any((i) => i.voorraadMinimum > 0 && i.voorraadActueel <= i.voorraadMinimum)) return const Color(0xFFFFF3CD);
    return const Color(0xFFD4EDDA);
  }

  List<InventoryItem> _sorted(List<InventoryItem> ii) {
    final s = List<InventoryItem>.from(ii);
    s.sort((a, b) {
      final ah = a.voorraadActueel > 0 ? 0 : 1;
      final bh = b.voorraadActueel > 0 ? 0 : 1;
      if (ah != bh) return ah.compareTo(bh);
      return (a.leverancierCode ?? '').compareTo(b.leverancierCode ?? '');
    });
    return s;
  }

  void _filter() {
    final q = _searchCtl.text.toLowerCase().trim();
    final f = <MapEntry<String, List<InventoryItem>>>[];
    for (final e in _grouped.entries) {
      final ii = e.value;
      if (_selCat != null && _selCat!.isNotEmpty && _gCat(ii) != _selCat) continue;
      if (q.isNotEmpty) {
        final n = _gName(e.key, ii).toLowerCase();
        if (!(n.contains(q) || ii.any((i) => i.kleur.toLowerCase().contains(q) || (i.eanCode ?? '').toLowerCase().contains(q) || (i.artikelnummer ?? '').toLowerCase().contains(q) || (i.leverancierCode ?? '').toLowerCase().contains(q) || (i.opmerking ?? '').toLowerCase().contains(q)))) continue;
      }
      f.add(e);
    }
    f.sort((a, b) {
      int c;
      switch (_sortBy) {
        case 'voorraad': c = _gStk(a.value).compareTo(_gStk(b.value)); break;
        case 'categorie': c = _gCat(a.value).compareTo(_gCat(b.value)); if (c == 0) c = _gName(a.key, a.value).toLowerCase().compareTo(_gName(b.key, b.value).toLowerCase()); break;
        default: c = _gName(a.key, a.value).toLowerCase().compareTo(_gName(b.key, b.value).toLowerCase());
      }
      return _sortAsc ? c : -c;
    });
    setState(() => _filtered = f);
  }

  // ── KPI ──
  int get _kStk => _all.fold(0, (s, i) => s + i.voorraadActueel);
  int get _kBest => _all.fold(0, (s, i) => s + i.voorraadBesteld);
  int get _kItems => _all.length;
  int get _kProds => _grouped.length;
  int get _kInStock => _grouped.values.where((ii) => _gStk(ii) > 0).length;
  int get _kOOS => _grouped.values.where((ii) => _gStk(ii) <= 0).length;
  int get _kBelowMin => _grouped.values.where((ii) => ii.any((i) => i.voorraadMinimum > 0 && i.voorraadActueel <= i.voorraadMinimum)).length;
  double get _kCost => _all.fold(0.0, (s, i) => s + ((i.inkoopPrijs ?? 0) * i.voorraadActueel));
  double get _kSaleVal => _all.fold(0.0, (s, i) => s + ((i.verkoopprijsIncl ?? 0) * i.voorraadActueel));
  int get _kCats => _cats.length;
  List<String> get _cats { final c = <String>{}; for (final ii in _grouped.values) c.add(_gCat(ii)); return c.toList()..sort(); }

  String _eur(double v) => '€${v.toStringAsFixed(2).replaceAll('.', ',')}';
  String _eurS(double v) => '€${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

  // ── Inline stock edit – user types NEW total; default = verlagen ──
  void _showInlineStockEdit(InventoryItem item) {
    if (item.id == null) return;
    final qtyCtl = TextEditingController(text: '${item.voorraadActueel}');
    final redenCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final newQty = int.tryParse(qtyCtl.text) ?? item.voorraadActueel;
          final delta = newQty - item.voorraadActueel;
          final isIncrease = delta > 0;
          final label = delta == 0
              ? 'Geen wijziging'
              : '${delta > 0 ? '+' : ''}$delta stk (${delta > 0 ? 'verhogen' : 'verlagen'})';
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.variantLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                if (item.kleur.isNotEmpty) Text(item.kleur, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _navy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('Huidig: ${item.voorraadActueel}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
              ),
            ]),
            content: SizedBox(
              width: 360,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: qtyCtl, autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Nieuw aantal', border: OutlineInputBorder(), helperText: 'Typ het nieuwe totaal (bijv. was 5, verkocht 1 → typ 4)'),
                  onChanged: (_) => setD(() {}),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: delta == 0 ? const Color(0xFFF3F4F6) : isIncrease ? const Color(0xFFD4EDDA) : const Color(0xFFF8D7DA),
                    borderRadius: BorderRadius.circular(6)),
                  child: Row(children: [
                    Icon(delta == 0 ? Icons.remove : isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14, color: delta == 0 ? const Color(0xFF6B7280) : isIncrease ? const Color(0xFF2E7D32) : const Color(0xFFEF4444)),
                    const SizedBox(width: 6),
                    Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: delta == 0 ? const Color(0xFF6B7280) : isIncrease ? const Color(0xFF2E7D32) : const Color(0xFFEF4444))),
                  ]),
                ),
                const SizedBox(height: 12),
                TextField(controller: redenCtl, decoration: const InputDecoration(labelText: 'Reden (verplicht)', border: OutlineInputBorder()), maxLines: 2),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: delta == 0 ? const Color(0xFF9E9E9E) : isIncrease ? const Color(0xFF2E7D32) : const Color(0xFFEF4444)),
                onPressed: delta == 0 ? null : () async {
                  if (redenCtl.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reden is verplicht'), backgroundColor: Color(0xFFEF4444))); return; }
                  Navigator.pop(ctx);
                  try {
                    await _svc.adjustStock(item.id!, delta, redenCtl.text.trim(), bron: 'handmatig', mutatieType: isIncrease ? 'inkoop' : 'correctie');
                    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voorraad bijgewerkt'), backgroundColor: Color(0xFF2E7D32))); _load(); }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fout: $e'), backgroundColor: const Color(0xFFEF4444)));
                  }
                },
                child: const Text('Opslaan'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Archive selection helpers ──
  void _toggleSelectMode() {
    setState(() { _selectMode = !_selectMode; _selectedIds.clear(); });
  }

  void _toggleSelectItem(int id) {
    setState(() { _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id); });
  }

  bool _canArchiveSelection() {
    if (_selectedIds.isEmpty) return false;
    for (final e in _grouped.entries) {
      for (final it in e.value) {
        if (it.id != null && _selectedIds.contains(it.id!) && it.voorraadActueel > 0) return false;
      }
    }
    return true;
  }

  Future<void> _archiveSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archiveren'),
        content: Text('$count item(s) verplaatsen naar het archief?\nDeze items zijn daarna niet meer zichtbaar in de voorraadlijst.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: _navy), child: const Text('Archiveren')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.archiveItems(_selectedIds.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count item(s) gearchiveerd'), backgroundColor: const Color(0xFF2E7D32)));
        setState(() { _selectMode = false; _selectedIds.clear(); });
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fout: $e'), backgroundColor: const Color(0xFFEF4444)));
    }
  }

  // ── Add order dialog ──
  void _showAddOrder() {
    final productCtl = TextEditingController();
    final kleurCtl = TextEditingController();
    final artCtl = TextEditingController();
    final eanCtl = TextEditingController();
    final veCtl = TextEditingController();
    final opmCtl = TextEditingController();
    final stkCtl = TextEditingController(text: '0');
    final bestCtl = TextEditingController(text: '0');
    final minCtl = TextEditingController(text: '0');
    final inkoopCtl = TextEditingController();
    final vliegCtl = TextEditingController();
    final taxCtl = TextEditingController();
    final inkTotCtl = TextEditingController();
    final nettoCtl = TextEditingController();
    final importCtl = TextEditingController();
    final brutoCtl = TextEditingController();
    final vkInclCtl = TextEditingController();
    final vkExclCtl = TextEditingController();
    final margeCtl = TextEditingController();
    String? vervoer;
    String? categorie;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(children: [
            Icon(Icons.add_shopping_cart_rounded, color: _navy, size: 22),
            SizedBox(width: 8),
            Text('Order toevoegen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
          ]),
          content: SizedBox(
            width: 520,
            height: 480,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: TextField(controller: productCtl, decoration: const InputDecoration(labelText: 'Productnaam', border: OutlineInputBorder(), isDense: true))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: kleurCtl, decoration: const InputDecoration(labelText: 'Kleur', border: OutlineInputBorder(), isDense: true))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                SizedBox(width: 80, child: TextField(controller: artCtl, decoration: const InputDecoration(labelText: 'Art.nr', border: OutlineInputBorder(), isDense: true))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: eanCtl, decoration: const InputDecoration(labelText: 'EAN-code', border: OutlineInputBorder(), isDense: true))),
                const SizedBox(width: 8),
                SizedBox(width: 100, child: TextField(controller: veCtl, decoration: const InputDecoration(labelText: 'VE-code', border: OutlineInputBorder(), isDense: true))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: categorie, isDense: true,
                  decoration: const InputDecoration(labelText: 'Categorie', border: OutlineInputBorder(), isDense: true),
                  items: _cats.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setD(() => categorie = v),
                )),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: opmCtl, decoration: const InputDecoration(labelText: 'Opmerking', border: OutlineInputBorder(), isDense: true))),
              ]),
              const SizedBox(height: 14),
              const Text('Voorraad', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: TextField(controller: stkCtl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Voorraad', border: OutlineInputBorder(), isDense: true))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: bestCtl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Besteld', border: OutlineInputBorder(), isDense: true))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: minCtl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Minimum', border: OutlineInputBorder(), isDense: true))),
              ]),
              const SizedBox(height: 14),
              const Text('Financieel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: TextField(controller: inkoopCtl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Inkoop', border: OutlineInputBorder(), isDense: true, prefixText: '€'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: vliegCtl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Vliegtuig', border: OutlineInputBorder(), isDense: true, prefixText: '€'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: taxCtl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Tax/Adm', border: OutlineInputBorder(), isDense: true, prefixText: '€'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: inkTotCtl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Ink.Tot.', border: OutlineInputBorder(), isDense: true, prefixText: '€'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: nettoCtl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Netto', border: OutlineInputBorder(), isDense: true, prefixText: '€'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: importCtl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Import', border: OutlineInputBorder(), isDense: true, prefixText: '€'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: brutoCtl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Bruto', border: OutlineInputBorder(), isDense: true, prefixText: '€'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: vkInclCtl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Vk.Incl', border: OutlineInputBorder(), isDense: true, prefixText: '€'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: vkExclCtl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Vk.Excl', border: OutlineInputBorder(), isDense: true, prefixText: '€'))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                SizedBox(width: 100, child: TextField(controller: margeCtl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Marge', border: OutlineInputBorder(), isDense: true))),
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonFormField<String>(
                  value: vervoer, isDense: true,
                  decoration: const InputDecoration(labelText: 'Vervoer', border: OutlineInputBorder(), isDense: true),
                  items: ['vliegtuig', 'trein', 'boot', 'overig'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setD(() => vervoer = v),
                )),
              ]),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Toevoegen'),
              style: FilledButton.styleFrom(backgroundColor: _navy),
              onPressed: () async {
                if (productCtl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Productnaam is verplicht'), backgroundColor: Color(0xFFEF4444)));
                  return;
                }
                double? p(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));
                final item = InventoryItem(
                  variantLabel: productCtl.text.trim(),
                  kleur: kleurCtl.text.trim(),
                  artikelnummer: artCtl.text.trim().isEmpty ? null : artCtl.text.trim(),
                  eanCode: eanCtl.text.trim().isEmpty ? null : eanCtl.text.trim(),
                  leverancierCode: veCtl.text.trim().isEmpty ? null : veCtl.text.trim(),
                  categorie: categorie,
                  opmerking: opmCtl.text.trim().isEmpty ? null : opmCtl.text.trim(),
                  voorraadActueel: int.tryParse(stkCtl.text) ?? 0,
                  voorraadBesteld: int.tryParse(bestCtl.text) ?? 0,
                  voorraadMinimum: int.tryParse(minCtl.text) ?? 0,
                  inkoopPrijs: p(inkoopCtl), vliegtuigKosten: p(vliegCtl), invoertaxAdmin: p(taxCtl),
                  inkoopTotaal: p(inkTotCtl), nettoInkoop: p(nettoCtl), importKosten: p(importCtl),
                  brutoInkoop: p(brutoCtl), verkoopprijsIncl: p(vkInclCtl), verkoopprijsExcl: p(vkExclCtl),
                  marge: p(margeCtl), vervoerMethode: vervoer,
                );
                Navigator.pop(ctx);
                try {
                  await _svc.save(item);
                  if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order toegevoegd'), backgroundColor: Color(0xFF2E7D32))); _load(); }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fout: $e'), backgroundColor: const Color(0xFFEF4444)));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectMode ? '${_selectedIds.length} geselecteerd' : 'Voorraadoverzicht'),
        backgroundColor: _selectMode ? const Color(0xFF37474F) : _navy, foregroundColor: Colors.white,
        leading: _selectMode
            ? IconButton(icon: const Icon(Icons.close), tooltip: 'Selectie annuleren', onPressed: _toggleSelectMode)
            : null,
        actions: _selectMode
            ? [
                if (_selectedIds.isNotEmpty)
                  FilledButton.icon(
                    onPressed: _canArchiveSelection() ? _archiveSelected : null,
                    icon: const Icon(Icons.archive_rounded, size: 16),
                    label: Text(_canArchiveSelection() ? 'Archiveren' : 'Alleen 0-voorraad', style: const TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _canArchiveSelection() ? const Color(0xFF6D4C41) : const Color(0xFF9E9E9E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12)),
                  ),
                const SizedBox(width: 8),
              ]
            : [
                FilledButton.icon(
                  onPressed: _showAddOrder,
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('Order toevoegen', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12)),
                ),
                const SizedBox(width: 4),
                IconButton(icon: const Icon(Icons.checklist_rounded), tooltip: 'Selecteren voor archief', onPressed: _toggleSelectMode),
                IconButton(icon: const Icon(Icons.archive_outlined), tooltip: 'Voorraad Archief',
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryArchiveScreen()));
                    if (mounted) _load();
                  }),
                if (_canImport)
                  IconButton(icon: const Icon(Icons.upload_file), tooltip: 'CSV importeren', onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryImportScreen()));
                    if (mounted) _load();
                  }),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, style: const TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _load, child: const Text('Opnieuw laden')),
                ]))
              : Column(children: [
                  _buildKpi(),
                  _buildToolbar(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final availableWidth = constraints.maxWidth;
                        final effectiveWidth = availableWidth > _tableWidth ? availableWidth : _tableWidth;
                        return Scrollbar(
                          controller: _hScroll, thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _hScroll, scrollDirection: Axis.horizontal,
                            child: SizedBox(width: effectiveWidth, child: Column(children: [
                              _buildColHdr(),
                              Expanded(child: RefreshIndicator(onRefresh: _load, child: ListView.builder(
                                itemCount: _filtered.length + 1,
                                itemBuilder: (_, i) {
                                  if (i >= _filtered.length) return const SizedBox(height: 60);
                                  final e = _filtered[i];
                                  return _buildGroup(e.key, e.value, i);
                                },
                              ))),
                            ])),
                          ),
                        );
                      },
                    ),
                  ),
                  _buildFooter(),
                ]),
    );
  }

  // ── KPI Section ──
  Widget _buildKpi() {
    final pct = _kProds > 0 ? (_kInStock / _kProds * 100).round() : 0;
    final margin = _kSaleVal - _kCost;
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Column(children: [
        Row(children: [
          Expanded(child: _kpiCard('Totale Voorraad', '$_kStk', '$_kItems items', const Color(0xFF2E7D32), Icons.inventory_2_rounded, onTap: () => _showKpiDetail('Voorraad per Product', _buildStockDetail()))),
          const SizedBox(width: 5),
          Expanded(child: _kpiCard('Inkoopwaarde', _eurS(_kCost), 'op voorraad', const Color(0xFF1565C0), Icons.euro_rounded, onTap: () => _showKpiDetail('Waarde Overzicht', _buildValueDetail()))),
          const SizedBox(width: 5),
          Expanded(child: _kpiCard('Verkoopwaarde', _eurS(_kSaleVal), margin > 0 ? 'marge ${_eurS(margin)}' : '', const Color(0xFF6A1B9A), Icons.trending_up_rounded, onTap: () => _showKpiDetail('Waarde Overzicht', _buildValueDetail()))),
          const SizedBox(width: 5),
          Expanded(child: _kpiCard('Producten', '$_kProds', '$_kCats categorieën', const Color(0xFF00695C), Icons.category_rounded, onTap: () => _showKpiDetail('Producten per Categorie', _buildCatDetail()))),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: _statusCard('Op voorraad', '$_kInStock', '$pct%', const Color(0xFF2E7D32), onTap: () => _showKpiDetail('Op voorraad', _buildFilteredList((ii) => _gStk(ii) > 0)))),
          const SizedBox(width: 5),
          Expanded(child: _statusCard('Onder minimum', '$_kBelowMin', _kBelowMin > 0 ? 'actie nodig' : 'ok', _kBelowMin > 0 ? const Color(0xFFE65100) : const Color(0xFF2E7D32),
            onTap: () => _showKpiDetail('Onder Minimum', _buildBelowMinDetail()))),
          const SizedBox(width: 5),
          Expanded(child: _statusCard('Niet op voorraad', '$_kOOS', _kBest > 0 ? '$_kBest besteld' : '', _kOOS > 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32), onTap: () => _showKpiDetail('Niet op Voorraad', _buildFilteredList((ii) => _gStk(ii) <= 0)))),
          const SizedBox(width: 5),
          Expanded(child: _topMini()),
        ]),
      ]),
    );
  }

  Widget _kpiCard(String title, String val, String sub, Color c, IconData icon, {VoidCallback? onTap}) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1))]),
      child: Row(children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Icon(icon, size: 14, color: c)),
        const SizedBox(width: 6),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF6B7280), letterSpacing: 0.2)),
          Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c, height: 1.1)),
          if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF))),
        ])),
        if (onTap != null) const Icon(Icons.chevron_right, size: 14, color: Color(0xFFCBD5E1)),
      ]),
    ));
  }

  Widget _statusCard(String lbl, String val, String det, Color c, {VoidCallback? onTap}) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1))]),
      child: Row(children: [
        Container(width: 4, height: 24, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lbl, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c, height: 1.2)),
            if (det.isNotEmpty) ...[const SizedBox(width: 3), Flexible(child: Text(det, style: const TextStyle(fontSize: 8, color: Color(0xFF9CA3AF)), overflow: TextOverflow.ellipsis))],
          ]),
        ])),
        if (onTap != null) const Icon(Icons.chevron_right, size: 14, color: Color(0xFFCBD5E1)),
      ]),
    ));
  }

  Widget _topMini() {
    final top = _grouped.entries.map((e) => MapEntry(_gName(e.key, e.value), _gStk(e.value))).toList()..sort((a, b) => b.value.compareTo(a.value));
    return InkWell(onTap: () => _showKpiDetail('Top Voorraad', _buildStockDetail()), borderRadius: BorderRadius.circular(8), child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Top voorraad', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
        const SizedBox(height: 2),
        ...top.take(3).map((e) => Padding(padding: const EdgeInsets.only(bottom: 1), child: Row(children: [
          Expanded(child: Text(e.key, style: const TextStyle(fontSize: 9, color: Color(0xFF374151)), overflow: TextOverflow.ellipsis)),
          Text('${e.value}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32))),
        ]))),
      ]),
    ));
  }

  // ── KPI Detail Sheets ──
  void _showKpiDetail(String title, Widget content) {
    showModalBottomSheet(context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(initialChildSize: 0.65, maxChildSize: 0.9, minChildSize: 0.3, expand: false,
        builder: (ctx, scroll) => Column(children: [
          Container(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Row(children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
          ])),
          const Divider(height: 1),
          Expanded(child: ListView(controller: scroll, padding: const EdgeInsets.all(12), children: [content])),
        ]),
      ),
    );
  }

  Widget _buildStockDetail() {
    final entries = _grouped.entries.toList()..sort((a, b) => _gStk(b.value).compareTo(_gStk(a.value)));
    return Column(children: entries.map((e) {
      final n = _gName(e.key, e.value); final s = _gStk(e.value); final maxS = entries.isNotEmpty ? _gStk(entries.first.value) : 1;
      return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
        SizedBox(width: 140, child: Text(n, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
        Expanded(child: LinearProgressIndicator(value: maxS > 0 ? s / maxS : 0, backgroundColor: const Color(0xFFE5E7EB), color: s > 0 ? const Color(0xFF2E7D32) : const Color(0xFFEF4444), minHeight: 8)),
        SizedBox(width: 40, child: Text('$s', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: s > 0 ? const Color(0xFF2E7D32) : const Color(0xFFEF4444)))),
      ]));
    }).toList());
  }

  Widget _buildValueDetail() {
    final entries = _grouped.entries.toList()..sort((a, b) => _gCost(b.value).compareTo(_gCost(a.value)));
    return DataTable(columnSpacing: 12, horizontalMargin: 4, headingRowHeight: 28, dataRowMinHeight: 24, dataRowMaxHeight: 28,
      columns: const [
        DataColumn(label: Text('Product', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700))),
        DataColumn(label: Text('Stk', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)), numeric: true),
        DataColumn(label: Text('Inkoop', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)), numeric: true),
        DataColumn(label: Text('Verkoop', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)), numeric: true),
        DataColumn(label: Text('Marge', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)), numeric: true),
      ],
      rows: entries.where((e) => _gCost(e.value) > 0).map((e) {
        final n = _gName(e.key, e.value); final cost = _gCost(e.value); final sale = _gSaleI(e.value);
        return DataRow(cells: [
          DataCell(SizedBox(width: 120, child: Text(n, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis))),
          DataCell(Text('${_gStk(e.value)}', style: const TextStyle(fontSize: 10))),
          DataCell(Text(_eurS(cost), style: const TextStyle(fontSize: 10))),
          DataCell(Text(_eurS(sale), style: const TextStyle(fontSize: 10))),
          DataCell(Text(_eurS(sale - cost), style: TextStyle(fontSize: 10, color: (sale - cost) >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFEF4444)))),
        ]);
      }).toList(),
    );
  }

  Widget _buildCatDetail() {
    final bycat = <String, List<InventoryItem>>{}; for (final e in _grouped.entries) (bycat[_gCat(e.value)] ??= []).addAll(e.value);
    final cats = bycat.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Column(children: cats.map((e) {
      final stk = e.value.fold(0, (s, i) => s + i.voorraadActueel);
      final prods = <String>{}; for (final i in e.value) if (i.variantLabel.isNotEmpty) prods.add(i.variantLabel);
      return ListTile(dense: true, contentPadding: EdgeInsets.zero,
        leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: const Color(0xFF00695C).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Center(child: Text('${prods.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF00695C))))),
        title: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        subtitle: Text('${prods.length} producten, $stk stuks', style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
        trailing: Text(_eurS(e.value.fold(0.0, (s, i) => s + ((i.inkoopPrijs ?? 0) * i.voorraadActueel))), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      );
    }).toList());
  }

  Widget _buildFilteredList(bool Function(List<InventoryItem>) test) {
    final matches = _grouped.entries.where((e) => test(e.value)).toList()..sort((a, b) => _gName(a.key, a.value).compareTo(_gName(b.key, b.value)));
    if (matches.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Geen resultaten', style: TextStyle(color: Color(0xFF9CA3AF)))));
    return Column(children: matches.map((e) {
      final n = _gName(e.key, e.value); final s = _gStk(e.value); final b = _gBest(e.value);
      return ListTile(dense: true, contentPadding: EdgeInsets.zero,
        title: Text(n, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        subtitle: Text(_gCat(e.value), style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (b > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: const Color(0xFF1565C0).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3)),
            child: Text('+$b besteld', style: const TextStyle(fontSize: 9, color: Color(0xFF1565C0)))),
          Text('$s stk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s > 0 ? const Color(0xFF2E7D32) : const Color(0xFFEF4444))),
        ]),
      );
    }).toList());
  }

  Widget _buildBelowMinDetail() {
    final matches = _grouped.entries.where((e) => e.value.any((i) => i.voorraadMinimum > 0 && i.voorraadActueel <= i.voorraadMinimum)).toList()
      ..sort((a, b) => _gName(a.key, a.value).compareTo(_gName(b.key, b.value)));
    if (matches.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Geen producten onder minimum', style: TextStyle(color: Color(0xFF9CA3AF)))));
    }
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(6)),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFE65100)),
          const SizedBox(width: 6),
          Text('${matches.length} product${matches.length == 1 ? '' : 'en'} onder minimum', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFE65100))),
        ]),
      ),
      const SizedBox(height: 2),
      ...matches.map((e) {
        final items = e.value;
        final name = _gName(e.key, items);
        final stock = _gStk(items);
        final minVal = items.map((i) => i.voorraadMinimum).where((m) => m > 0).reduce((a, b) => a < b ? a : b);
        final tekort = minVal - stock;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFFFCC80)),
          ),
          child: Row(children: [
            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text(_gCat(items), style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Voorraad: ', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                Text('$stock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: stock > 0 ? const Color(0xFFE65100) : const Color(0xFFEF4444))),
              ]),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('Minimum: ', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                Text('$minVal', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1565C0))),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _showEditMinimum(items, name, minVal),
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(3)),
                    child: const Icon(Icons.edit, size: 12, color: Color(0xFF1565C0)),
                  ),
                ),
              ]),
            ]),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text('−$tekort', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
            ),
          ]),
        );
      }),
    ]);
  }

  void _showEditMinimum(List<InventoryItem> items, String name, int currentMin) {
    final ctl = TextEditingController(text: '$currentMin');
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Minimum aanpassen', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Huidig minimum: $currentMin', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        const SizedBox(height: 12),
        TextField(
          controller: ctl, autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Nieuw minimum', border: OutlineInputBorder()),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
        FilledButton(onPressed: () async {
          final newMin = int.tryParse(ctl.text.trim()) ?? currentMin;
          Navigator.pop(ctx);
          try {
            final svc = InventoryService();
            for (final item in items) {
              await svc.save(item.copyWith(voorraadMinimum: newMin));
            }
            await _load();
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fout: $e'), backgroundColor: const Color(0xFFEF4444)));
          }
        }, child: const Text('Opslaan')),
      ],
    ));
  }

  // ── Toolbar ──
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3), color: const Color(0xFFF8F9FA),
      child: Row(children: [
        Expanded(flex: 3, child: SizedBox(height: 28, child: TextField(
          controller: _searchCtl, style: const TextStyle(fontSize: 11),
          decoration: InputDecoration(hintText: 'Zoeken...', hintStyle: const TextStyle(fontSize: 11), prefixIcon: const Icon(Icons.search, size: 14), contentPadding: EdgeInsets.zero,
            filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border))),
        ))),
        const SizedBox(width: 4),
        SizedBox(height: 28, width: 130, child: DropdownButtonFormField<String>(value: _selCat, isDense: true, isExpanded: true, style: const TextStyle(fontSize: 10, color: Color(0xFF334155)),
          decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 6), filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border))),
          items: [const DropdownMenuItem(value: null, child: Text('Alle', style: TextStyle(fontSize: 10))), ..._cats.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 10))))],
          onChanged: (v) { setState(() { _selCat = v; _filter(); }); },
        )),
        const SizedBox(width: 3),
        _toolBtn(Icons.sort, 'Sorteren', onTap: _showSort),
        const SizedBox(width: 3),
        _toolBtn(_collapsed.isEmpty ? Icons.unfold_less : Icons.unfold_more, _collapsed.isEmpty ? 'Inklap' : 'Uitklap',
          onTap: () { setState(() { _collapsed.isEmpty ? _collapsed.addAll(_grouped.keys) : _collapsed.clear(); }); }),
      ]),
    );
  }

  Widget _toolBtn(IconData icon, String label, {VoidCallback? onTap}) {
    return SizedBox(height: 28, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(4),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(4)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: const Color(0xFF64748B)), const SizedBox(width: 2), Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)))]),
      ),
    ));
  }

  void _showSort() {
    showMenu(context: context, position: const RelativeRect.fromLTRB(200, 140, 0, 0), items: [
      PopupMenuItem(value: 'naam', child: Text('Naam${_sortBy == 'naam' ? (_sortAsc ? ' ↑' : ' ↓') : ''}', style: const TextStyle(fontSize: 12))),
      PopupMenuItem(value: 'voorraad', child: Text('Voorraad${_sortBy == 'voorraad' ? (_sortAsc ? ' ↑' : ' ↓') : ''}', style: const TextStyle(fontSize: 12))),
      PopupMenuItem(value: 'categorie', child: Text('Categorie${_sortBy == 'categorie' ? (_sortAsc ? ' ↑' : ' ↓') : ''}', style: const TextStyle(fontSize: 12))),
    ]).then((v) { if (v != null) setState(() { if (v == _sortBy) _sortAsc = !_sortAsc; else { _sortBy = v; _sortAsc = true; } _filter(); }); });
  }

  // ── Column Header ──
  Widget _buildColHdr() {
    const s = TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _hdrFg);
    return Container(color: _hdrBg, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: const Row(children: [
        SizedBox(width: 16),
        SizedBox(width: 150, child: Text('Product', style: s)),
        SizedBox(width: 90, child: Text('Kleur', style: s)),
        SizedBox(width: 30, child: Text('Art.', textAlign: TextAlign.center, style: s)),
        SizedBox(width: 100, child: Text('EAN', style: s)),
        SizedBox(width: 40, child: Text('Voorr.', textAlign: TextAlign.right, style: s)),
        SizedBox(width: 36, child: Text('Best.', textAlign: TextAlign.right, style: s)),
        SizedBox(width: 32, child: Text('Min.', textAlign: TextAlign.right, style: s)),
        SizedBox(width: 56, child: Text('Inkoop', textAlign: TextAlign.right, style: s)),
        SizedBox(width: 56, child: Text('Vliegtuig', textAlign: TextAlign.right, style: s)),
        SizedBox(width: 50, child: Text('Tax/Adm', textAlign: TextAlign.right, style: s)),
        SizedBox(width: 56, child: Text('Tot.Ink.', textAlign: TextAlign.right, style: s)),
        SizedBox(width: 56, child: Text('Netto', textAlign: TextAlign.right, style: s)),
        SizedBox(width: 56, child: Text('Import', textAlign: TextAlign.right, style: s)),
        SizedBox(width: 56, child: Text('Bruto', textAlign: TextAlign.right, style: s)),
        SizedBox(width: 56, child: Text('Vk.Incl', textAlign: TextAlign.right, style: s)),
        SizedBox(width: 56, child: Text('Vk.Excl', textAlign: TextAlign.right, style: s)),
        SizedBox(width: 46, child: Text('Marge', textAlign: TextAlign.right, style: s)),
        SizedBox(width: 20, child: Text('V', textAlign: TextAlign.center, style: s)),
        SizedBox(width: 70, child: Text('VE-code', textAlign: TextAlign.right, style: s)),
        SizedBox(width: 8),
      ]),
    );
  }

  // ── Product Group ──
  Widget _buildGroup(String key, List<InventoryItem> items, int idx) {
    final name = _gName(key, items); final cat = _gCat(items); final total = _gStk(items);
    final besteld = _gBest(items); final cost = _gCost(items); final open = !_collapsed.contains(key);
    final clr = _gColor(items); final wStk = items.where((i) => i.voorraadActueel > 0).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        onTap: () { setState(() { open ? _collapsed.add(key) : _collapsed.remove(key); }); },
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(color: clr, border: Border(
            bottom: BorderSide(color: _border.withValues(alpha: 0.5)),
            top: idx > 0 ? BorderSide(color: _border.withValues(alpha: 0.3)) : BorderSide.none)),
          child: Row(children: [
            AnimatedRotation(turns: open ? 0.25 : 0, duration: const Duration(milliseconds: 150), child: Icon(Icons.chevron_right, size: 14, color: Colors.black54)),
            const SizedBox(width: 3),
            Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(2)),
              child: Text(cat, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32)))),
            const SizedBox(width: 4),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)))),
            Text('$wStk/${items.length}', style: TextStyle(fontSize: 8, color: Colors.black.withValues(alpha: 0.35))),
            const SizedBox(width: 4),
            if (besteld > 0) Container(margin: const EdgeInsets.only(right: 4), padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFF1565C0).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2)),
              child: Text('+$besteld', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Color(0xFF1565C0)))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: total > 0 ? const Color(0xFF2E7D32).withValues(alpha: 0.15) : const Color(0xFFDC3545).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
              child: Text('$total', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: total > 0 ? const Color(0xFF2E7D32) : const Color(0xFFDC3545)))),
            const SizedBox(width: 4),
            SizedBox(width: 55, child: Text(cost > 0 ? _eurS(cost) : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280)))),
          ]),
        ),
      ),
      if (open) ..._sorted(items).asMap().entries.map((e) => _buildRow(e.value, e.key.isEven)),
    ]);
  }

  // ── Item Row (voorraad klikbaar) ──
  Widget _buildRow(InventoryItem it, bool even) {
    final has = it.voorraadActueel > 0;
    final low = it.voorraadMinimum > 0 && it.voorraadActueel <= it.voorraadMinimum;
    final selected = it.id != null && _selectedIds.contains(it.id!);
    Color bg;
    if (selected) bg = const Color(0xFFE3F2FD);
    else if (has && low) bg = const Color(0xFFFFF8E1);
    else if (has) bg = even ? const Color(0xFFF1F8E9) : const Color(0xFFE8F5E9);
    else bg = even ? Colors.white : const Color(0xFFFAFAFA);
    final tc = has ? const Color(0xFF1A1A1A) : const Color(0xFFAAAAAA);
    final bc = has ? const Color(0xFF1A1A1A) : const Color(0xFFCCCCCC);

    return InkWell(
      onTap: _selectMode
          ? (it.id != null ? () => _toggleSelectItem(it.id!) : null)
          : (it.id != null ? () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryItemScreen(itemId: it.id!))); _load(); } : null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: _border.withValues(alpha: 0.2)))),
        child: Row(children: [
          if (_selectMode)
            SizedBox(width: 16, child: it.id != null
                ? Icon(selected ? Icons.check_box : Icons.check_box_outline_blank, size: 14, color: selected ? _navy : const Color(0xFFBDBDBD))
                : const SizedBox.shrink())
          else
            const SizedBox(width: 16),
          SizedBox(width: 150, child: Row(children: [
            Flexible(child: Text(it.variantLabel, style: TextStyle(fontSize: 12, color: has ? tc : const Color(0xFFCCCCCC)), overflow: TextOverflow.ellipsis)),
            if (it.opmerking != null && it.opmerking!.isNotEmpty)
              Padding(padding: const EdgeInsets.only(left: 2), child: Tooltip(message: it.opmerking!, child: Icon(Icons.chat_bubble_outline, size: 9, color: has ? const Color(0xFFFF8F00) : const Color(0xFFDDDDDD)))),
          ])),
          SizedBox(width: 90, child: Text(it.kleur.isNotEmpty ? it.kleur : '', style: TextStyle(fontSize: 10, color: tc), overflow: TextOverflow.ellipsis)),
          SizedBox(width: 30, child: Text(it.artikelnummer ?? '', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: tc))),
          SizedBox(width: 100, child: Text(it.eanCode ?? '', style: TextStyle(fontSize: 9, color: tc.withValues(alpha: 0.7), fontFamily: 'monospace'))),
          // Clickable stock cell
          InkWell(
            onTap: it.id != null ? () => _showInlineStockEdit(it) : null,
            child: Container(width: 40, padding: const EdgeInsets.symmetric(vertical: 1),
              decoration: BoxDecoration(
                color: has ? (low ? const Color(0xFFFFC107).withValues(alpha: 0.3) : const Color(0xFF4CAF50).withValues(alpha: 0.2)) : null,
                border: it.id != null ? Border.all(color: _navy.withValues(alpha: 0.2), width: 0.5) : null,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                Text('${it.voorraadActueel}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: bc)),
                if (it.id != null) Icon(Icons.edit, size: 8, color: _navy.withValues(alpha: 0.3)),
              ]),
            ),
          ),
          SizedBox(width: 36, child: Text(it.voorraadBesteld > 0 ? '${it.voorraadBesteld}' : '', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, color: tc))),
          SizedBox(width: 32, child: Text(it.voorraadMinimum > 0 ? '${it.voorraadMinimum}' : '', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, color: low ? const Color(0xFFE65100) : tc))),
          _eurCell(it.inkoopPrijs, 56, tc),
          _eurCell(it.vliegtuigKosten, 56, tc),
          _eurCell(it.invoertaxAdmin, 50, tc),
          _eurCell(it.inkoopTotaal, 56, tc),
          _eurCell(it.nettoInkoop, 56, tc),
          _eurCell(it.importKosten, 56, tc),
          _eurCell(it.brutoInkoop, 56, tc),
          _eurCell(it.verkoopprijsIncl, 56, tc),
          _eurCell(it.verkoopprijsExcl, 56, tc),
          SizedBox(width: 46, child: Text(it.marge != null ? '${(it.marge! * 100).toStringAsFixed(0)}%' : '', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, color: tc))),
          SizedBox(width: 20, child: _vIcon(it.vervoerMethode, !has)),
          SizedBox(width: 70, child: Text(it.leverancierCode ?? '', textAlign: TextAlign.right,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: has ? _navy : const Color(0xFFCCCCCC), fontFamily: 'monospace'))),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }

  Widget _eurCell(double? v, double w, Color tc) => SizedBox(width: w, child: Text(v != null ? _eur(v) : '', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, color: tc)));

  // ── Footer ──
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(color: Color(0xFFF8F9FA), border: Border(top: BorderSide(color: _border))),
      child: Row(children: [
        Text('${_filtered.length} producten  ·  $_kItems items', style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2)),
          child: Text('$_kStk stk', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32)))),
        const SizedBox(width: 6),
        if (_kBelowMin > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFFFC107).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
          child: Text('$_kBelowMin onder min.', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFE65100)))),
        const SizedBox(width: 6),
        Text(_eurS(_kCost), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
      ]),
    );
  }

  Widget _vIcon(String? m, bool dim) {
    if (m == null || m.isEmpty) return const SizedBox.shrink();
    final c = dim ? const Color(0xFFDDDDDD) : const Color(0xFF6B7280);
    return switch (m.toLowerCase()) {
      'vliegtuig' => Tooltip(message: 'Vliegtuig', child: Icon(Icons.flight, size: 10, color: c)),
      'trein' => Tooltip(message: 'Trein', child: Icon(Icons.train, size: 10, color: c)),
      _ => Tooltip(message: m, child: Icon(Icons.local_shipping_outlined, size: 10, color: c)),
    };
  }
}
