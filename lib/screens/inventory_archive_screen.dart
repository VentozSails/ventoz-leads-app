import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/inventory_service.dart';
import '../services/user_service.dart';

class InventoryArchiveScreen extends StatefulWidget {
  const InventoryArchiveScreen({super.key});

  @override
  State<InventoryArchiveScreen> createState() => _InventoryArchiveScreenState();
}

class _InventoryArchiveScreenState extends State<InventoryArchiveScreen> {
  static const _navy = Color(0xFF1E3A5F);
  static const _hdrBg = Color(0xFF6D4C41);
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
      if (!mounted) return;
      if (!perms.voorraadBeheren) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geen toegang'), backgroundColor: Color(0xFFEF4444)));
        return;
      }
      final items = await _svc.getAllArchived();
      final grouped = <String, List<InventoryItem>>{};
      for (final it in items) { (grouped[_gKey(it)] ??= []).add(it); }
      if (mounted) { setState(() { _all = items; _grouped = grouped; _loading = false; }); _filter(); }
    } catch (e) {
      if (kDebugMode) debugPrint('InventoryArchive: $e');
      if (mounted) setState(() { _loading = false; _error = 'Laden mislukt.'; });
    }
  }

  String _gKey(InventoryItem i) { final n = i.variantLabel.trim().toLowerCase(); return n.isEmpty ? '_overig_' : n; }
  String _gName(String k, List<InventoryItem> ii) => k == '_overig_' ? 'Overig' : (ii.first.variantLabel.isNotEmpty ? ii.first.variantLabel : 'Onbekend');
  int _gStk(List<InventoryItem> ii) => ii.fold(0, (s, i) => s + i.voorraadActueel);

  void _filter() {
    final q = _searchCtl.text.toLowerCase().trim();
    final f = <MapEntry<String, List<InventoryItem>>>[];
    for (final e in _grouped.entries) {
      if (q.isNotEmpty) {
        final n = _gName(e.key, e.value).toLowerCase();
        if (!(n.contains(q) || e.value.any((i) => i.kleur.toLowerCase().contains(q) || (i.eanCode ?? '').toLowerCase().contains(q) || (i.artikelnummer ?? '').toLowerCase().contains(q) || (i.leverancierCode ?? '').toLowerCase().contains(q)))) continue;
      }
      f.add(e);
    }
    f.sort((a, b) => _gName(a.key, a.value).toLowerCase().compareTo(_gName(b.key, b.value).toLowerCase()));
    setState(() => _filtered = f);
  }

  void _toggleSelectMode() {
    setState(() { _selectMode = !_selectMode; _selectedIds.clear(); });
  }

  void _toggleSelectItem(int id) {
    setState(() { _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id); });
  }

  Future<void> _restoreSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terugplaatsen'),
        content: Text('$count item(s) terugplaatsen naar de actieve voorraadlijst?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)), child: const Text('Terugplaatsen')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.unarchiveItems(_selectedIds.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count item(s) teruggeplaatst'), backgroundColor: const Color(0xFF2E7D32)));
        setState(() { _selectMode = false; _selectedIds.clear(); });
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fout: $e'), backgroundColor: const Color(0xFFEF4444)));
    }
  }

  String _eur(double v) => '€${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectMode ? '${_selectedIds.length} geselecteerd' : 'Voorraad Archief'),
        backgroundColor: _selectMode ? const Color(0xFF37474F) : _hdrBg, foregroundColor: Colors.white,
        leading: _selectMode
            ? IconButton(icon: const Icon(Icons.close), tooltip: 'Selectie annuleren', onPressed: _toggleSelectMode)
            : null,
        actions: _selectMode
            ? [
                if (_selectedIds.isNotEmpty)
                  FilledButton.icon(
                    onPressed: _restoreSelected,
                    icon: const Icon(Icons.unarchive_rounded, size: 16),
                    label: const Text('Terugplaatsen', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12)),
                  ),
                const SizedBox(width: 8),
              ]
            : [
                IconButton(icon: const Icon(Icons.checklist_rounded), tooltip: 'Selecteren om terug te plaatsen', onPressed: _toggleSelectMode),
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
              : _all.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.archive_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('Het archief is leeg', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                      const SizedBox(height: 8),
                      Text('Items met 0 voorraad kunnen vanuit het\nvoorraadoverzicht worden gearchiveerd.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                    ]))
                  : Column(children: [
                      _buildInfo(),
                      _buildToolbar(),
                      Expanded(
                        child: Scrollbar(
                          controller: _hScroll, thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _hScroll, scrollDirection: Axis.horizontal,
                            child: SizedBox(width: _tableWidth, child: Column(children: [
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
                        ),
                      ),
                      _buildFooter(),
                    ]),
    );
  }

  Widget _buildInfo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      color: const Color(0xFFFAF3EB),
      child: Row(children: [
        const Icon(Icons.archive_rounded, size: 18, color: Color(0xFF6D4C41)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Gearchiveerde items', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4E342E))),
          Text('${_all.length} items in ${_grouped.length} productgroepen  ·  Niet muteerbaar',
            style: const TextStyle(fontSize: 10, color: Color(0xFF8D6E63))),
        ])),
        OutlinedButton.icon(
          onPressed: _toggleSelectMode,
          icon: Icon(_selectMode ? Icons.close : Icons.checklist_rounded, size: 14),
          label: Text(_selectMode ? 'Annuleren' : 'Selecteren', style: const TextStyle(fontSize: 11)),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF6D4C41), minimumSize: const Size(0, 30)),
        ),
      ]),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3), color: const Color(0xFFF8F9FA),
      child: Row(children: [
        Expanded(child: SizedBox(height: 28, child: TextField(
          controller: _searchCtl, style: const TextStyle(fontSize: 11),
          decoration: InputDecoration(hintText: 'Zoeken in archief...', hintStyle: const TextStyle(fontSize: 11), prefixIcon: const Icon(Icons.search, size: 14), contentPadding: EdgeInsets.zero,
            filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border))),
        ))),
        const SizedBox(width: 4),
        SizedBox(height: 28, child: InkWell(
          onTap: () { setState(() { _collapsed.isEmpty ? _collapsed.addAll(_grouped.keys) : _collapsed.clear(); }); },
          borderRadius: BorderRadius.circular(4),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(4)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_collapsed.isEmpty ? Icons.unfold_less : Icons.unfold_more, size: 12, color: const Color(0xFF64748B)),
              const SizedBox(width: 2),
              Text(_collapsed.isEmpty ? 'Inklap' : 'Uitklap', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
            ]),
          ),
        )),
      ]),
    );
  }

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

  Widget _buildGroup(String key, List<InventoryItem> items, int idx) {
    final name = _gName(key, items); final total = _gStk(items);
    final open = !_collapsed.contains(key);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        onTap: () { setState(() { open ? _collapsed.add(key) : _collapsed.remove(key); }); },
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFFF5F0EB), border: Border(
            bottom: BorderSide(color: _border.withValues(alpha: 0.5)),
            top: idx > 0 ? BorderSide(color: _border.withValues(alpha: 0.3)) : BorderSide.none)),
          child: Row(children: [
            AnimatedRotation(turns: open ? 0.25 : 0, duration: const Duration(milliseconds: 150), child: const Icon(Icons.chevron_right, size: 14, color: Colors.black54)),
            const SizedBox(width: 3),
            Container(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFF6D4C41).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(2)),
              child: const Text('archief', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF6D4C41)))),
            const SizedBox(width: 4),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4E342E)))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFF9E9E9E).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
              child: Text('$total', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF757575)))),
            const SizedBox(width: 4),
            Text('${items.length} items', style: const TextStyle(fontSize: 8, color: Color(0xFF9E9E9E))),
          ]),
        ),
      ),
      if (open) ...items.asMap().entries.map((e) => _buildRow(e.value, e.key.isEven)),
    ]);
  }

  Widget _buildRow(InventoryItem it, bool even) {
    final selected = it.id != null && _selectedIds.contains(it.id!);
    final bg = selected ? const Color(0xFFE3F2FD) : even ? const Color(0xFFFAF8F5) : const Color(0xFFF5F0EB);
    const tc = Color(0xFF8D6E63);

    return InkWell(
      onTap: _selectMode && it.id != null ? () => _toggleSelectItem(it.id!) : null,
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
          SizedBox(width: 150, child: Text(it.variantLabel, style: const TextStyle(fontSize: 12, color: tc), overflow: TextOverflow.ellipsis)),
          SizedBox(width: 90, child: Text(it.kleur, style: const TextStyle(fontSize: 10, color: tc), overflow: TextOverflow.ellipsis)),
          SizedBox(width: 30, child: Text(it.artikelnummer ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: tc))),
          SizedBox(width: 100, child: Text(it.eanCode ?? '', style: const TextStyle(fontSize: 9, color: tc, fontFamily: 'monospace'))),
          SizedBox(width: 40, child: Text('${it.voorraadActueel}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF9E9E9E)))),
          SizedBox(width: 36, child: Text(it.voorraadBesteld > 0 ? '${it.voorraadBesteld}' : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, color: tc))),
          SizedBox(width: 32, child: Text(it.voorraadMinimum > 0 ? '${it.voorraadMinimum}' : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, color: tc))),
          _eurCell(it.inkoopPrijs, 56),
          _eurCell(it.vliegtuigKosten, 56),
          _eurCell(it.invoertaxAdmin, 50),
          _eurCell(it.inkoopTotaal, 56),
          _eurCell(it.nettoInkoop, 56),
          _eurCell(it.importKosten, 56),
          _eurCell(it.brutoInkoop, 56),
          _eurCell(it.verkoopprijsIncl, 56),
          _eurCell(it.verkoopprijsExcl, 56),
          SizedBox(width: 46, child: Text(it.marge != null ? '${(it.marge! * 100).toStringAsFixed(0)}%' : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, color: tc))),
          SizedBox(width: 20, child: _vIcon(it.vervoerMethode)),
          SizedBox(width: 70, child: Text(it.leverancierCode ?? '', textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF8D6E63), fontFamily: 'monospace'))),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }

  Widget _eurCell(double? v, double w) => SizedBox(width: w, child: Text(v != null ? _eur(v) : '', textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, color: Color(0xFF8D6E63))));

  Widget _buildFooter() {
    final totalStk = _all.fold(0, (s, i) => s + i.voorraadActueel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(color: Color(0xFFFAF3EB), border: Border(top: BorderSide(color: _border))),
      child: Row(children: [
        Text('${_filtered.length} groepen  ·  ${_all.length} items', style: const TextStyle(fontSize: 9, color: Color(0xFF8D6E63))),
        const Spacer(),
        Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(color: const Color(0xFF6D4C41).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2)),
          child: Text('$totalStk stk in archief', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF6D4C41)))),
      ]),
    );
  }

  Widget _vIcon(String? m) {
    if (m == null || m.isEmpty) return const SizedBox.shrink();
    const c = Color(0xFFBDBDBD);
    return switch (m.toLowerCase()) {
      'vliegtuig' => const Tooltip(message: 'Vliegtuig', child: Icon(Icons.flight, size: 10, color: c)),
      'trein' => const Tooltip(message: 'Trein', child: Icon(Icons.train, size: 10, color: c)),
      _ => Tooltip(message: m, child: const Icon(Icons.local_shipping_outlined, size: 10, color: c)),
    };
  }
}
