import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/inventory_service.dart';
import '../services/user_service.dart';

class EanManagementScreen extends StatefulWidget {
  const EanManagementScreen({super.key});

  static const routeName = '/ean-beheer';

  @override
  State<EanManagementScreen> createState() => _EanManagementScreenState();
}

class _EanManagementScreenState extends State<EanManagementScreen> {
  final InventoryService _inventoryService = InventoryService();
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();

  List<EanRegistryEntry> _allEntries = [];
  List<EanRegistryEntry> _filteredEntries = [];
  EanRegistryEntry? _nextAvailable;
  bool _loading = true;
  String? _error;
  String _filterStatus = 'alle';
  static const _headerColor = Color(0xFF1E3A5F);

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final perms = await _userService.getCurrentUserPermissions();
      if (!perms.eanCodesBeheren) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Geen toegang'), backgroundColor: Color(0xFFEF4444)),
          );
        }
        return;
      }
      final entries = await _inventoryService.getAllEan();
      final next = await _inventoryService.findNextAvailableEan();
      if (mounted) {
        setState(() { _allEntries = entries; _loading = false; _nextAvailable = next; });
        _applyFilters();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('EanManagement load error: $e');
      if (mounted) setState(() { _loading = false; _error = 'Laden mislukt. Probeer het opnieuw.'; });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    var list = _allEntries;
    switch (_filterStatus) {
      case 'actief':
        list = list.where((e) => e.actief).toList();
      case 'inactief':
      case 'beschikbaar':
        list = list.where((e) => !e.actief).toList();
    }
    if (query.isNotEmpty) {
      list = list.where((e) {
        return e.eanCode.toLowerCase().contains(query) ||
            (e.productNaam ?? '').toLowerCase().contains(query) ||
            e.artikelnummer.toString().contains(query) ||
            (e.variant ?? '').toLowerCase().contains(query) ||
            (e.kleur ?? '').toLowerCase().contains(query);
      }).toList();
    }
    setState(() => _filteredEntries = list);
  }

  int get _actiefCount => _allEntries.where((e) => e.actief).length;
  int get _inactiefCount => _allEntries.where((e) => !e.actief).length;

  void _openDetail(EanRegistryEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _EanDetailScreen(entry: entry, service: _inventoryService)),
    ).then((_) => _loadData());
  }

  Future<void> _showAssignDialog(EanRegistryEntry entry) async {
    final productNaam = TextEditingController();
    final variant = TextEditingController();
    final kleur = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('EAN toewijzen', style: TextStyle(color: _headerColor)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('EAN: ${entry.eanCode}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Artikelnr: ${entry.artikelnummer}', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 20),
              TextField(controller: productNaam, autofocus: true, decoration: const InputDecoration(labelText: 'Product naam *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: variant, decoration: const InputDecoration(labelText: 'Variant', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: kleur, decoration: const InputDecoration(labelText: 'Kleur', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuleren')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Toewijzen')),
        ],
      ),
    );

    if (result == true && mounted && productNaam.text.trim().isNotEmpty) {
      try {
        await _inventoryService.reassignEan(entry.id!, productNaam: productNaam.text.trim(),
          variant: variant.text.trim().isEmpty ? null : variant.text.trim(),
          kleur: kleur.text.trim().isEmpty ? null : kleur.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EAN toegewezen')));
          _loadData();
        }
      } catch (e) {
        if (kDebugMode) debugPrint('EanManagement reassign error: $e');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Toewijzen mislukt: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EAN-codes beheren'),
        backgroundColor: _headerColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _loadData, child: const Text('Opnieuw proberen')),
                ]))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          _buildNextAvailableCard(),
                          const SizedBox(height: 16),
                          _buildSummaryStats(),
                          const SizedBox(height: 16),
                          _buildSearchBar(),
                          const SizedBox(height: 12),
                          _buildFilterButtons(),
                          const SizedBox(height: 16),
                        ]),
                      )),
                      _buildTable(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildNextAvailableCard() {
    return Card(
      color: Colors.white, elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: _headerColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.qr_code_rounded, color: _headerColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Volgende beschikbare EAN', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 4),
              _nextAvailable != null
                  ? Text(_nextAvailable!.eanCode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1))
                  : const Text('Geen beschikbare EAN-codes meer.', style: TextStyle(color: Colors.orange)),
            ])),
            if (_nextAvailable != null)
              FilledButton.icon(
                onPressed: () => _showAssignDialog(_nextAvailable!),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Toewijzen'),
                style: FilledButton.styleFrom(backgroundColor: _headerColor),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStats() {
    return Row(
      children: [
        _statCard('${_allEntries.length}', 'Totaal', Icons.list_alt_rounded, Colors.blueGrey),
        const SizedBox(width: 8),
        _statCard('$_actiefCount', 'Actief', Icons.check_circle_rounded, Colors.green),
        const SizedBox(width: 8),
        _statCard('$_inactiefCount', 'Inactief', Icons.cancel_rounded, Colors.orange),
      ],
    );
  }

  Widget _statCard(String count, String label, IconData icon, Color color) {
    return Expanded(
      child: Card(color: Colors.white, elevation: 1, child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ]),
      )),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: const InputDecoration(
        hintText: 'Zoeken op EAN, product, variant, kleur of artikelnummer...',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
        filled: true, fillColor: Colors.white,
      ),
    );
  }

  Widget _buildFilterButtons() {
    return Wrap(spacing: 8, children: [
      _filterChip('Alle', 'alle'),
      _filterChip('Actief', 'actief'),
      _filterChip('Inactief', 'inactief'),
      _filterChip('Beschikbaar', 'beschikbaar'),
    ]);
  }

  Widget _filterChip(String label, String value) {
    final selected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() { _filterStatus = value; _applyFilters(); }),
      selectedColor: _headerColor.withValues(alpha: 0.3),
      checkmarkColor: _headerColor,
    );
  }

  Widget _buildTable() {
    if (_filteredEntries.isEmpty) {
      return const SliverToBoxAdapter(child: Card(
        child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Geen EAN-codes gevonden.'))),
      ));
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverToBoxAdapter(
        child: Card(
          color: Colors.white, elevation: 2, clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(_headerColor),
                headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                dataTextStyle: const TextStyle(fontSize: 13),
                columnSpacing: 16,
                horizontalMargin: 16,
                showCheckboxColumn: false,
                columns: const [
                  DataColumn(label: Text('Nr')),
                  DataColumn(label: Text('EAN-code')),
                  DataColumn(label: Text('Product')),
                  DataColumn(label: Text('Variant')),
                  DataColumn(label: Text('Kleur')),
                  DataColumn(label: Text('Status')),
                ],
                rows: _filteredEntries.map((e) => DataRow(
                  onSelectChanged: (_) => _openDetail(e),
                  cells: [
                    DataCell(Text('${e.artikelnummer}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(e.eanCode, style: const TextStyle(fontFamily: 'monospace', letterSpacing: 0.5))),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(e.productNaam ?? '-', overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(Text(e.variant ?? '-')),
                    DataCell(Text(e.kleur ?? '-')),
                    DataCell(_statusBadge(e.actief)),
                  ],
                )).toList(),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _statusBadge(bool actief) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: actief ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: actief ? Colors.green.withValues(alpha: 0.4) : Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Text(
        actief ? 'Actief' : 'Inactief',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: actief ? Colors.green.shade800 : Colors.orange.shade800),
      ),
    );
  }
}

// ────────────────────────────────────────────────────
// Detail screen for a single EAN entry
// ────────────────────────────────────────────────────

class _EanDetailScreen extends StatefulWidget {
  final EanRegistryEntry entry;
  final InventoryService service;

  const _EanDetailScreen({required this.entry, required this.service});

  @override
  State<_EanDetailScreen> createState() => _EanDetailScreenState();
}

class _EanDetailScreenState extends State<_EanDetailScreen> {
  static const _headerColor = Color(0xFF1E3A5F);

  late TextEditingController _productNaam;
  late TextEditingController _variant;
  late TextEditingController _kleur;
  late TextEditingController _opmerking;
  late bool _actief;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _productNaam = TextEditingController(text: widget.entry.productNaam ?? '');
    _variant = TextEditingController(text: widget.entry.variant ?? '');
    _kleur = TextEditingController(text: widget.entry.kleur ?? '');
    _opmerking = TextEditingController(text: widget.entry.opmerking ?? '');
    _actief = widget.entry.actief;
    for (final c in [_productNaam, _variant, _kleur, _opmerking]) {
      c.addListener(_markChanged);
    }
  }

  void _markChanged() { if (!_changed) setState(() => _changed = true); }

  @override
  void dispose() {
    _productNaam.dispose();
    _variant.dispose();
    _kleur.dispose();
    _opmerking.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = EanRegistryEntry(
        id: widget.entry.id,
        artikelnummer: widget.entry.artikelnummer,
        eanCode: widget.entry.eanCode,
        productNaam: _productNaam.text.trim().isEmpty ? null : _productNaam.text.trim(),
        variant: _variant.text.trim().isEmpty ? null : _variant.text.trim(),
        kleur: _kleur.text.trim().isEmpty ? null : _kleur.text.trim(),
        opmerking: _opmerking.text.trim().isEmpty ? null : _opmerking.text.trim(),
        actief: _actief,
      );
      await widget.service.saveEan(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EAN opgeslagen')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('EanDetail save error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opslaan mislukt: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return Scaffold(
      appBar: AppBar(
        title: Text('EAN ${e.artikelnummer}'),
        backgroundColor: _headerColor,
        foregroundColor: Colors.white,
        actions: [
          if (_changed || _actief != widget.entry.actief)
            TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(_saving ? 'Opslaan...' : 'Opslaan', style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // EAN header card
            Card(color: _headerColor.withValues(alpha: 0.05), elevation: 0, shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), side: BorderSide(color: _headerColor.withValues(alpha: 0.2)),
            ), child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(color: _headerColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.qr_code_2_rounded, color: _headerColor, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('EAN-code', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    SelectableText(e.eanCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 1.5)),
                  ])),
                  _statusBadgeLarge(_actief),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _infoChip(Icons.tag_rounded, 'Artikelnr: ${e.artikelnummer}'),
                  const SizedBox(width: 12),
                  _infoChip(Icons.calendar_today_rounded, 'Geregistreerd: ${e.id != null ? "ja" : "nee"}'),
                ]),
              ]),
            )),

            const SizedBox(height: 24),

            // Product info section
            _sectionHeader('Productinformatie'),
            const SizedBox(height: 12),
            Card(color: Colors.white, elevation: 1, child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(controller: _productNaam, decoration: const InputDecoration(labelText: 'Product naam', border: OutlineInputBorder(), prefixIcon: Icon(Icons.inventory_2_outlined))),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: TextField(controller: _variant, decoration: const InputDecoration(labelText: 'Variant', border: OutlineInputBorder(), prefixIcon: Icon(Icons.style_outlined)))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _kleur, decoration: const InputDecoration(labelText: 'Kleur', border: OutlineInputBorder(), prefixIcon: Icon(Icons.palette_outlined)))),
                ]),
                const SizedBox(height: 16),
                TextField(controller: _opmerking, maxLines: 3, decoration: const InputDecoration(labelText: 'Opmerking', border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes_rounded), alignLabelWithHint: true)),
              ]),
            )),

            const SizedBox(height: 24),

            // Status section
            _sectionHeader('Status'),
            const SizedBox(height: 12),
            Card(color: Colors.white, elevation: 1, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SwitchListTile(
                title: const Text('Actief', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_actief
                    ? 'Deze EAN-code is in gebruik en toegewezen aan een product.'
                    : 'Deze EAN-code is inactief en beschikbaar voor hertoewijzing.'),
                value: _actief,
                onChanged: (v) => setState(() { _actief = v; }),
                activeTrackColor: Colors.green.withValues(alpha: 0.4),
                activeThumbColor: Colors.green,
                secondary: Icon(_actief ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: _actief ? Colors.green : Colors.orange, size: 32),
              ),
            )),

            const SizedBox(height: 32),

            // Save button at bottom
            if (_changed || _actief != widget.entry.actief)
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Opslaan...' : 'Wijzigingen opslaan'),
                style: FilledButton.styleFrom(backgroundColor: _headerColor, padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(children: [
      Container(width: 4, height: 20, decoration: BoxDecoration(color: _headerColor, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _headerColor)),
    ]);
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ]),
    );
  }

  Widget _statusBadgeLarge(bool actief) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: actief ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: actief ? Colors.green.withValues(alpha: 0.4) : Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Text(
        actief ? 'Actief' : 'Inactief',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: actief ? Colors.green.shade800 : Colors.orange.shade800),
      ),
    );
  }
}
