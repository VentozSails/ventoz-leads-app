import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/marketplace_listing.dart';
import '../services/marketplace_service.dart';

class ChannelMatrixScreen extends StatefulWidget {
  const ChannelMatrixScreen({super.key});

  @override
  State<ChannelMatrixScreen> createState() => _ChannelMatrixScreenState();
}

class _ChannelMatrixScreenState extends State<ChannelMatrixScreen> {
  static const _navy = Color(0xFF0D1B2A);

  final _service = MarketplaceService();
  List<ChannelMatrixRow> _allRows = [];
  List<ChannelMatrixRow> _filteredRows = [];
  bool _loading = true;

  final _searchCtrl = TextEditingController();
  String _stockFilter = 'all'; // all, in_stock, out_of_stock, low
  String? _categoryFilter;
  String _sortField = 'naam';
  bool _sortAsc = true;
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _service.getChannelMatrix();
    if (!mounted) return;
    setState(() {
      _allRows = rows;
      _loading = false;
      _applyFilters();
    });
  }

  void _applyFilters() {
    var rows = List<ChannelMatrixRow>.from(_allRows);

    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      rows = rows.where((r) =>
          r.product.naam.toLowerCase().contains(q) ||
          (r.product.artikelnummer?.toLowerCase().contains(q) ?? false) ||
          (r.product.eanCode?.toLowerCase().contains(q) ?? false)
      ).toList();
    }

    if (_categoryFilter != null) {
      rows = rows.where((r) => r.product.categorie == _categoryFilter).toList();
    }

    switch (_stockFilter) {
      case 'in_stock':
        rows = rows.where((r) => r.voorraad > 0).toList();
        break;
      case 'out_of_stock':
        rows = rows.where((r) => r.voorraad <= 0).toList();
        break;
      case 'low':
        rows = rows.where((r) => r.voorraad > 0 && r.voorraad < 5).toList();
        break;
      case 'auto':
        rows = rows.where((r) => MarketplacePlatform.values.any((p) => _isAutoAction(r, p))).toList();
        break;
    }

    rows.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case 'prijs':
          cmp = (a.product.displayPrijs ?? 0).compareTo(b.product.displayPrijs ?? 0);
          break;
        case 'voorraad':
          cmp = a.voorraad.compareTo(b.voorraad);
          break;
        case 'platforms':
          cmp = a.activeCount.compareTo(b.activeCount);
          break;
        default:
          cmp = a.product.naam.compareTo(b.product.naam);
      }
      return _sortAsc ? cmp : -cmp;
    });

    setState(() => _filteredRows = rows);
  }

  Set<String> get _allCategories {
    final cats = <String>{};
    for (final r in _allRows) {
      if (r.product.categorie != null) cats.add(r.product.categorie!);
    }
    return cats;
  }

  // ═══════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(children: [
        _buildToolbar(context),
        if (_selected.isNotEmpty) _buildBulkBar(),
        Expanded(child: _buildMatrix(context)),
      ]),
    );
  }

  // ── Toolbar ──

  Widget _buildToolbar(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text(
            '${_filteredRows.length} van ${_allRows.length} producten',
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
          ),
          const Spacer(),
          _sortChip('Naam', 'naam'),
          const SizedBox(width: 4),
          _sortChip('Prijs', 'prijs'),
          const SizedBox(width: 4),
          _sortChip('Voorraad', 'voorraad'),
          const SizedBox(width: 4),
          _sortChip('Platforms', 'platforms'),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, size: 20),
            tooltip: 'CSV exporteren',
            onPressed: _exportCsv,
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            flex: wide ? 3 : 2,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _applyFilters(),
              decoration: InputDecoration(
                hintText: 'Zoek op naam, artikelnr, EAN...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); _applyFilters(); })
                    : null,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          _buildCategoryDropdown(),
          const SizedBox(width: 8),
          _buildStockDropdown(),
        ]),
      ]),
    );
  }

  Widget _sortChip(String label, String field) {
    final active = _sortField == field;
    return InkWell(
      onTap: () {
        setState(() {
          if (_sortField == field) {
            _sortAsc = !_sortAsc;
          } else {
            _sortField = field;
            _sortAsc = true;
          }
        });
        _applyFilters();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? const Color(0xFF1D4ED8) : const Color(0xFF64748B))),
          if (active) ...[
            const SizedBox(width: 2),
            Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: const Color(0xFF1D4ED8)),
          ],
        ]),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _categoryFilter,
          hint: const Text('Categorie', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          isDense: true,
          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
          items: [
            const DropdownMenuItem(value: null, child: Text('Alle categorieën')),
            ..._allCategories.map((c) => DropdownMenuItem(
              value: c,
              child: Text(_categoryLabel(c), overflow: TextOverflow.ellipsis),
            )),
          ],
          onChanged: (v) { setState(() => _categoryFilter = v); _applyFilters(); },
        ),
      ),
    );
  }

  Widget _buildStockDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _stockFilter,
          isDense: true,
          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Alle voorraad')),
            DropdownMenuItem(value: 'in_stock', child: Text('Op voorraad')),
            DropdownMenuItem(value: 'low', child: Text('Laag (< 5)')),
            DropdownMenuItem(value: 'out_of_stock', child: Text('Uitverkocht')),
            DropdownMenuItem(value: 'auto', child: Text('Auto-acties')),
          ],
          onChanged: (v) { if (v != null) { setState(() => _stockFilter = v); _applyFilters(); } },
        ),
      ),
    );
  }

  // ── Bulk Action Bar ──

  Widget _buildBulkBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFEFF6FF),
      child: Row(children: [
        Text(
          '${_selected.length} geselecteerd',
          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => setState(() => _selected.clear()),
          icon: const Icon(Icons.clear, size: 16),
          label: const Text('Wis selectie'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B), textStyle: const TextStyle(fontSize: 12)),
        ),
        const Spacer(),
        ...MarketplacePlatform.values.map((p) => Padding(
          padding: const EdgeInsets.only(left: 4),
          child: _bulkAction(p),
        )),
      ]),
    );
  }

  Widget _bulkAction(MarketplacePlatform platform) {
    return PopupMenuButton<String>(
      tooltip: platform.label,
      itemBuilder: (_) => [
        PopupMenuItem(value: 'add', child: Text('Toevoegen aan ${platform.label}')),
        PopupMenuItem(value: 'pause', child: Text('Pauzeren op ${platform.label}')),
        PopupMenuItem(value: 'activate', child: Text('Activeren op ${platform.label}')),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'remove', child: Text('Verwijderen van ${platform.label}', style: const TextStyle(color: Color(0xFFE53935)))),
      ],
      onSelected: (action) => _executeBulkAction(platform, action),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_platformIcon(platform), size: 14, color: _platformColor(platform)),
          const SizedBox(width: 4),
          Text(platform.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const Icon(Icons.arrow_drop_down, size: 16),
        ]),
      ),
    );
  }

  Future<void> _executeBulkAction(MarketplacePlatform platform, String action) async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;

    String message;
    switch (action) {
      case 'add':
        if (platform == MarketplacePlatform.marktplaats) {
          await _service.addProductsToMarktplaatsFeed(ids);
        } else {
          for (final pid in ids) {
            final row = _allRows.where((r) => r.product.id == pid).firstOrNull;
            if (row == null) continue;
            if (row.listings[platform]?.isNotEmpty ?? false) continue;
            await _service.createListing(MarketplaceListing(
              productId: pid,
              platform: platform,
              status: ListingStatus.concept,
              prijs: row.product.displayPrijs,
              taal: 'nl',
            ));
          }
        }
        message = '${ids.length} product(en) toegevoegd aan ${platform.label}';
        break;
      case 'pause':
        for (final pid in ids) {
          final row = _allRows.where((r) => r.product.id == pid).firstOrNull;
          final listing = row?.primaryListing(platform);
          if (listing?.id != null && listing!.status == ListingStatus.actief) {
            await _service.updateListing(listing.id!, status: ListingStatus.gepauzeerd);
          }
        }
        message = '${ids.length} product(en) gepauzeerd op ${platform.label}';
        break;
      case 'activate':
        for (final pid in ids) {
          final row = _allRows.where((r) => r.product.id == pid).firstOrNull;
          final listing = row?.primaryListing(platform);
          if (listing?.id != null && listing!.status == ListingStatus.gepauzeerd) {
            await _service.updateListing(listing.id!, status: ListingStatus.actief);
          }
        }
        message = '${ids.length} product(en) geactiveerd op ${platform.label}';
        break;
      case 'remove':
        for (final pid in ids) {
          final row = _allRows.where((r) => r.product.id == pid).firstOrNull;
          final listing = row?.primaryListing(platform);
          if (listing != null && listing.id != null) {
            await _service.updateListing(listing.id!, status: ListingStatus.verwijderd);
          }
        }
        message = '${ids.length} product(en) verwijderd van ${platform.label}';
        break;
      default:
        return;
    }

    setState(() => _selected.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: const Color(0xFF2E7D32)));
    }
    _load();
  }

  // ── Matrix / Table ──

  Widget _buildMatrix(BuildContext context) {
    if (_filteredRows.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.grid_off_rounded, size: 48, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          Text('Geen producten gevonden', style: GoogleFonts.dmSans(fontSize: 16, color: const Color(0xFF94A3B8))),
        ]),
      );
    }

    final wide = MediaQuery.of(context).size.width >= 900;
    if (wide) return _buildWideTable();
    return _buildNarrowList();
  }

  // ── Wide: DataTable ──

  Widget _buildWideTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          dataRowMinHeight: 48,
          dataRowMaxHeight: 56,
          columnSpacing: 16,
          horizontalMargin: 12,
          showCheckboxColumn: true,
          columns: [
            const DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
            const DataColumn(label: Text('Prijs', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
            const DataColumn(label: Text('Voorraad', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), numeric: true),
            ...MarketplacePlatform.values.map((p) => DataColumn(
              label: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_platformIcon(p), size: 14, color: _platformColor(p)),
                const SizedBox(width: 4),
                Text(p.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            )),
          ],
          rows: _filteredRows.map((row) {
            final pid = row.product.id!;
            return DataRow(
              selected: _selected.contains(pid),
              onSelectChanged: (v) => setState(() {
                if (v == true) { _selected.add(pid); } else { _selected.remove(pid); }
              }),
              cells: [
                DataCell(
                  SizedBox(
                    width: 220,
                    child: Row(children: [
                      if (row.product.displayAfbeeldingUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(row.product.displayAfbeeldingUrl!, width: 32, height: 32, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(width: 32, height: 32)),
                        )
                      else
                        Container(width: 32, height: 32, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                          child: const Icon(Icons.sailing, size: 18, color: Color(0xFFCBD5E1))),
                      const SizedBox(width: 8),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(row.product.displayNaam, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (row.product.categorie != null)
                            Text(_categoryLabel(row.product.categorie!), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        ],
                      )),
                    ]),
                  ),
                ),
                DataCell(Text(
                  row.product.displayPrijs != null ? '€${row.product.displayPrijs!.toStringAsFixed(0)}' : '-',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                )),
                DataCell(_stockBadge(row.voorraad)),
                ...MarketplacePlatform.values.map((p) => DataCell(
                  _platformCell(row, p),
                  onTap: () => _showQuickEdit(row, p),
                )),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Narrow: Card list ──

  Widget _buildNarrowList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredRows.length,
      itemBuilder: (context, i) {
        final row = _filteredRows[i];
        final pid = row.product.id!;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: _selected.contains(pid)
                ? const BorderSide(color: Color(0xFF3B82F6), width: 2)
                : const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            onLongPress: () => setState(() {
              if (_selected.contains(pid)) { _selected.remove(pid); } else { _selected.add(pid); }
            }),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (_selected.isNotEmpty)
                    Checkbox(
                      value: _selected.contains(pid),
                      onChanged: (v) => setState(() {
                        if (v == true) { _selected.add(pid); } else { _selected.remove(pid); }
                      }),
                      visualDensity: VisualDensity.compact,
                    ),
                  Expanded(child: Text(row.product.displayNaam, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                  _stockBadge(row.voorraad),
                ]),
                Row(children: [
                  if (row.product.categorie != null)
                    Text(_categoryLabel(row.product.categorie!), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  const Spacer(),
                  Text(
                    row.product.displayPrijs != null ? '€${row.product.displayPrijs!.toStringAsFixed(2)}' : '-',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                ]),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: MarketplacePlatform.values.map((p) => GestureDetector(
                    onTap: () => _showQuickEdit(row, p),
                    child: _platformChip(row, p),
                  )).toList(),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  // ── Platform cells / chips ──

  bool _isAutoAction(ChannelMatrixRow row, MarketplacePlatform platform) {
    final listing = row.primaryListing(platform);
    if (listing == null) return false;
    return listing.platformData.containsKey('auto_actie');
  }

  String? _autoActionLabel(MarketplaceListing listing) {
    final actie = listing.platformData['auto_actie'] as String?;
    if (actie == null) return null;
    switch (actie) {
      case 'auto_pause': return 'AUTO-PAUZE';
      case 'auto_close': return 'AUTO-GESLOTEN';
      default: return 'AUTO';
    }
  }

  String? _autoRedenLabel(MarketplaceListing listing) {
    final reden = listing.platformData['auto_reden'] as String?;
    if (reden == null) return null;
    switch (reden) {
      case 'uitverkocht': return 'Uitverkocht';
      case 'laatste_besteld': return 'Laatste besteld';
      case 'voorraad_laag': return 'Voorraad < 2';
      default: return reden;
    }
  }

  Widget _platformCell(ChannelMatrixRow row, MarketplacePlatform platform) {
    final status = row.statusOn(platform);
    final prijs = row.prijsOp(platform);
    final taal = row.taalOp(platform);
    final isAuto = _isAutoAction(row, platform);

    if (status == null) {
      return Container(
        width: 100,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Center(child: Text('—', style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)))),
      );
    }

    final color = _statusColor(status);
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAuto ? const Color(0xFFE65100).withValues(alpha: 0.5) : color.withValues(alpha: 0.3),
          width: isAuto ? 1.5 : 1,
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_statusIcon(status), size: 12, color: color),
          const SizedBox(width: 3),
          if (prijs != null)
            Text('€${prijs.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
        if (isAuto)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFE65100).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              _autoActionLabel(row.primaryListing(platform)!) ?? 'AUTO',
              style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: Color(0xFFE65100), letterSpacing: 0.3),
            ),
          )
        else if (taal != null)
          Text(taal, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _platformChip(ChannelMatrixRow row, MarketplacePlatform platform) {
    final status = row.statusOn(platform);
    final prijs = row.prijsOp(platform);
    final isAuto = _isAutoAction(row, platform);

    if (status == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(platform.label, style: const TextStyle(fontSize: 10, color: Color(0xFFCBD5E1))),
      );
    }

    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAuto ? const Color(0xFFE65100).withValues(alpha: 0.5) : color.withValues(alpha: 0.3),
          width: isAuto ? 1.5 : 1,
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_statusIcon(status), size: 12, color: color),
        const SizedBox(width: 3),
        Text(platform.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        if (isAuto) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFE65100).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('AUTO', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: Color(0xFFE65100))),
          ),
        ] else if (prijs != null) ...[
          const SizedBox(width: 4),
          Text('€${prijs.toStringAsFixed(0)}', style: TextStyle(fontSize: 10, color: color)),
        ],
      ]),
    );
  }

  Widget _stockBadge(int stock) {
    Color bg, fg;
    String label;
    if (stock <= 0) {
      bg = const Color(0xFFFFEBEE); fg = const Color(0xFFE53935); label = 'Uitverkocht';
    } else if (stock < 2) {
      bg = const Color(0xFFFFEBEE); fg = const Color(0xFFE53935); label = '$stock — PAUZEREN';
    } else if (stock < 5) {
      bg = const Color(0xFFFFF3E0); fg = const Color(0xFFE65100); label = '$stock — LET OP';
    } else {
      bg = const Color(0xFFE8F5E9); fg = const Color(0xFF2E7D32); label = '$stock';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  // ═══════════════════════════════════════════
  // Quick Edit Dialog
  // ═══════════════════════════════════════════

  void _showQuickEdit(ChannelMatrixRow row, MarketplacePlatform platform) {
    final listing = row.primaryListing(platform);
    final hasListing = listing != null;

    if (!hasListing) {
      _showAddListingDialog(row, platform);
      return;
    }

    final prijsCtrl = TextEditingController(text: listing.prijs?.toStringAsFixed(2) ?? row.product.displayPrijs?.toStringAsFixed(2) ?? '');
    var selectedTaal = listing.taal;
    var selectedStatus = listing.status;
    var voorraadSync = listing.voorraadSync;

    final isFeed = platform == MarketplacePlatform.marktplaats;
    final cpcCtrl = TextEditingController(text: ((listing.platformData['cpc_eurocent'] ?? listing.platformData['cpc'] ?? 2) as num).toString());
    final totalBudgetCtrl = TextEditingController(text: ((listing.platformData['total_budget_eurocent'] ?? listing.platformData['total_budget'] ?? 5000) as num).toString());
    final dailyBudgetCtrl = TextEditingController(text: ((listing.platformData['daily_budget_eurocent'] ?? listing.platformData['daily_budget'] ?? 1000) as num).toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(children: [
            Icon(_platformIcon(platform), size: 20, color: _platformColor(platform)),
            const SizedBox(width: 8),
            Expanded(child: Text('${platform.label} — ${row.product.displayNaam}', style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis)),
          ]),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (listing.platformData.containsKey('auto_actie')) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE65100).withValues(alpha: 0.3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.auto_mode_rounded, size: 16, color: Color(0xFFE65100)),
                      const SizedBox(width: 6),
                      Text(
                        _autoActionLabel(listing) ?? 'AUTO',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFE65100)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      'Reden: ${_autoRedenLabel(listing) ?? "onbekend"} (voorraad: ${listing.platformData['auto_voorraad'] ?? "?"})',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF795548)),
                    ),
                    if (listing.platformData['auto_datum'] != null)
                      Text(
                        'Sinds: ${_formatAutoDate(listing.platformData['auto_datum'] as String)}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final pd = Map<String, dynamic>.from(listing.platformData);
                          pd.remove('auto_actie');
                          pd.remove('auto_reden');
                          pd.remove('auto_datum');
                          pd.remove('auto_voorraad');
                          await _service.updateListing(listing.id!, status: ListingStatus.actief, platformData: pd);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Listing handmatig geheractiveerd'), backgroundColor: Color(0xFF2E7D32)),
                            );
                          }
                          _load();
                        },
                        icon: const Icon(Icons.play_circle_outline, size: 16),
                        label: const Text('Handmatig heractiveren'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2E7D32),
                          side: const BorderSide(color: Color(0xFF2E7D32)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
              DropdownButtonFormField<ListingStatus>(
                value: selectedStatus,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
                items: [ListingStatus.actief, ListingStatus.gepauzeerd, ListingStatus.concept].map((s) =>
                    DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                onChanged: (v) { if (v != null) setDlg(() => selectedStatus = v); },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: prijsCtrl,
                decoration: const InputDecoration(labelText: 'Prijs (€)', border: OutlineInputBorder(), isDense: true, prefixText: '€ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedTaal,
                decoration: const InputDecoration(labelText: 'Taal', border: OutlineInputBorder(), isDense: true),
                items: ['nl', 'en', 'de', 'fr'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                onChanged: (v) { if (v != null) setDlg(() => selectedTaal = v); },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Voorraad sync', style: TextStyle(fontSize: 13)),
                subtitle: const Text('Auto-pauzeer bij lage voorraad', style: TextStyle(fontSize: 11)),
                value: voorraadSync,
                dense: true,
                onChanged: (v) => setDlg(() => voorraadSync = v),
                activeColor: const Color(0xFF2E7D32),
              ),
              if (isFeed) ...[
                const Divider(height: 24),
                const Text('Marktplaats Budget', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: cpcCtrl,
                  decoration: const InputDecoration(labelText: 'CPC (eurocent)', border: OutlineInputBorder(), isDense: true),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: totalBudgetCtrl,
                  decoration: const InputDecoration(labelText: 'Totaalbudget (eurocent)', border: OutlineInputBorder(), isDense: true, helperText: '5000 = €50'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dailyBudgetCtrl,
                  decoration: const InputDecoration(labelText: 'Dagbudget (eurocent)', border: OutlineInputBorder(), isDense: true, helperText: '1000 = €10'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ])),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuleren'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _service.updateListing(listing.id!, status: ListingStatus.verwijderd);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${platform.label} listing verwijderd'), backgroundColor: const Color(0xFFE65100)),
                  );
                }
                _load();
              },
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFE53935)),
              child: const Text('Verwijderen'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final newPrijs = double.tryParse(prijsCtrl.text.replaceAll(',', '.'));
                final pd = Map<String, dynamic>.from(listing.platformData);
                if (isFeed) {
                  pd['cpc_eurocent'] = int.tryParse(cpcCtrl.text) ?? 2;
                  pd['total_budget_eurocent'] = int.tryParse(totalBudgetCtrl.text) ?? 5000;
                  pd['daily_budget_eurocent'] = int.tryParse(dailyBudgetCtrl.text) ?? 1000;
                }
                if (pd.containsKey('auto_actie')) {
                  pd.remove('auto_actie');
                  pd.remove('auto_reden');
                  pd.remove('auto_datum');
                  pd.remove('auto_voorraad');
                }
                await _service.updateListing(
                  listing.id!,
                  prijs: newPrijs,
                  taal: selectedTaal,
                  status: selectedStatus,
                  voorraadSync: voorraadSync,
                  platformData: pd,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Listing bijgewerkt'), backgroundColor: Color(0xFF2E7D32)),
                  );
                }
                _load();
              },
              style: ElevatedButton.styleFrom(backgroundColor: _navy),
              child: const Text('Opslaan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddListingDialog(ChannelMatrixRow row, MarketplacePlatform platform) {
    final prijsCtrl = TextEditingController(text: row.product.displayPrijs?.toStringAsFixed(2) ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          Icon(_platformIcon(platform), size: 20, color: _platformColor(platform)),
          const SizedBox(width: 8),
          Text('Toevoegen aan ${platform.label}', style: const TextStyle(fontSize: 15)),
        ]),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(row.product.displayNaam, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: prijsCtrl,
              decoration: const InputDecoration(labelText: 'Prijs (€)', border: OutlineInputBorder(), isDense: true, prefixText: '€ '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prijs = double.tryParse(prijsCtrl.text.replaceAll(',', '.'));
              if (platform == MarketplacePlatform.marktplaats) {
                await _service.addProductsToMarktplaatsFeed([row.product.id!]);
              } else {
                await _service.createListing(MarketplaceListing(
                  productId: row.product.id!,
                  platform: platform,
                  status: ListingStatus.actief,
                  prijs: prijs ?? row.product.displayPrijs,
                  taal: 'nl',
                ));
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Toegevoegd aan ${platform.label}'), backgroundColor: const Color(0xFF2E7D32)),
                );
              }
              _load();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _navy),
            child: const Text('Toevoegen'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // CSV Export
  // ═══════════════════════════════════════════

  void _exportCsv() {
    final buf = StringBuffer();
    buf.writeln('Product;Artikelnr;Categorie;Prijs;Voorraad;${MarketplacePlatform.values.map((p) => '${p.label} Status;${p.label} Prijs;${p.label} Taal').join(';')}');

    for (final row in _filteredRows) {
      final fields = <String>[
        row.product.displayNaam,
        row.product.artikelnummer ?? '',
        row.product.categorie != null ? _categoryLabel(row.product.categorie!) : '',
        row.product.displayPrijs?.toStringAsFixed(2) ?? '',
        row.voorraad.toString(),
      ];
      for (final p in MarketplacePlatform.values) {
        final status = row.statusOn(p);
        fields.add(status?.label ?? '-');
        fields.add(row.prijsOp(p)?.toStringAsFixed(2) ?? '-');
        fields.add(row.taalOp(p) ?? '-');
      }
      buf.writeln(fields.join(';'));
    }

    final csv = buf.toString();
    Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CSV (${_filteredRows.length} rijen) gekopieerd naar klembord'),
        backgroundColor: const Color(0xFF2E7D32),
        action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════

  Color _statusColor(ListingStatus status) {
    switch (status) {
      case ListingStatus.actief: return const Color(0xFF2E7D32);
      case ListingStatus.gepauzeerd: return const Color(0xFFE65100);
      case ListingStatus.fout: return const Color(0xFFE53935);
      case ListingStatus.concept: return const Color(0xFF1565C0);
      case ListingStatus.verwijderd: return const Color(0xFF94A3B8);
    }
  }

  IconData _statusIcon(ListingStatus status) {
    switch (status) {
      case ListingStatus.actief: return Icons.check_circle;
      case ListingStatus.gepauzeerd: return Icons.pause_circle;
      case ListingStatus.fout: return Icons.error;
      case ListingStatus.concept: return Icons.edit_note;
      case ListingStatus.verwijderd: return Icons.remove_circle;
    }
  }

  IconData _platformIcon(MarketplacePlatform p) {
    switch (p) {
      case MarketplacePlatform.bolCom: return Icons.shopping_bag_rounded;
      case MarketplacePlatform.ebay: return Icons.gavel_rounded;
      case MarketplacePlatform.amazon: return Icons.local_shipping_rounded;
      case MarketplacePlatform.marktplaats: return Icons.storefront_rounded;
    }
  }

  Color _platformColor(MarketplacePlatform p) {
    switch (p) {
      case MarketplacePlatform.bolCom: return const Color(0xFF0000CC);
      case MarketplacePlatform.ebay: return const Color(0xFFE53238);
      case MarketplacePlatform.amazon: return const Color(0xFFFF9900);
      case MarketplacePlatform.marktplaats: return const Color(0xFF2D8CFF);
    }
  }

  static const _catLabels = {
    'optimist': 'Optimist',
    'ventoz-laserzeil': 'Laser / ILCA',
    'ventoz-topaz': 'Topaz',
    'ventoz-splash': 'Splash',
    'beachsailing': 'Strandzeil',
    'ventoz-centaur': 'Centaur',
    'rs-feva': 'RS Feva',
    'valk': 'Polyvalk',
    'randmeer': 'Randmeer',
    'hobie-cat': 'Hobie Cat',
    'ventoz-420-470-sails': '420 / 470',
    'efsix': 'EFSix',
    'sunfish': 'Sunfish',
    'stormfok': 'Stormfok',
    'open-bic': 'Open Bic',
    'nacra-17': 'Nacra 17',
    'yamaha-seahopper': 'Yamaha Seahopper',
    'mirror': 'Mirror',
    'fox-22': 'Fox 22',
    'diversen': 'Diversen',
  };

  String _categoryLabel(String cat) => _catLabels[cat] ?? cat;

  String _formatAutoDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.day}-${dt.month}-${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}
