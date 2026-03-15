import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/marketplace_listing.dart';
import '../services/marketplace_service.dart';
import '../services/inventory_service.dart';
import '../services/web_scraper_service.dart';
import '../services/user_service.dart';

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
  String? _loadError;
  int _totalListings = 0;

  final _searchCtrl = TextEditingController();
  String _stockFilter = 'all';
  String? _categoryFilter;
  String _sortField = 'naam';
  bool _sortAsc = true;
  final Set<int> _selected = {};
  bool _canBatchConvert = false;

  double _channelColWidth = 68;
  double _productColWidth = 220;
  double _artNrColWidth = 90;
  bool _hideInactiveChannels = false;
  final Set<String> _manuallyHiddenChannels = {};

  List<SalesChannel> get _visibleEbayChannels => SalesChannel.ebayChannels.where(_isChannelVisible).toList();
  List<SalesChannel> get _visibleBolChannels => SalesChannel.bolChannels.where(_isChannelVisible).toList();
  List<SalesChannel> get _visibleAmazonChannels => SalesChannel.amazonChannels.where(_isChannelVisible).toList();
  bool get _isAdmarkVisible => _isChannelVisible(SalesChannel.admarkNl);

  bool _isChannelVisible(SalesChannel ch) {
    if (_manuallyHiddenChannels.contains(ch.code)) return false;
    if (_hideInactiveChannels && !_isChannelActive(ch)) return false;
    return true;
  }

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
    setState(() { _loading = true; _loadError = null; });
    try {
      final results = await Future.wait([
        _service.getChannelMatrix(),
        UserService().isRealOwner(),
        UserService().isCurrentUserAdmin(),
        _service.getCredentialStatuses(),
      ]);
      final rows = results[0] as List<ChannelMatrixRow>;
      final isOwner = results[1] as bool;
      final isAdmin = results[2] as bool;
      final credStatuses = results[3] as List<MarketplaceCredentialStatus>;

      final active = <String>{'eigen_site'};
      for (final s in credStatuses) {
        if (s.isConfigured && s.isActive) {
          for (final ch in SalesChannel.allChannels) {
            if (ch.platform == s.platform) active.add(ch.code);
          }
        }
      }

      int totalListings = 0;
      for (final r in rows) {
        for (final entry in r.listings.entries) {
          totalListings += entry.value.length;
        }
      }

      if (!mounted) return;
      setState(() {
        _allRows = rows;
        _canBatchConvert = isOwner || isAdmin;
        _activeChannelCodes = active;
        _totalListings = totalListings;
        _loading = false;
        _applyFilters();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Fout bij laden: $e';
      });
    }
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
      case 'out_of_stock':
        rows = rows.where((r) => r.voorraad <= 0).toList();
      case 'low':
        rows = rows.where((r) => r.voorraad > 0 && r.voorraad < 5).toList();
    }
    rows.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case 'prijs':
          cmp = (a.product.displayPrijs ?? 0).compareTo(b.product.displayPrijs ?? 0);
        case 'voorraad':
          cmp = a.voorraad.compareTo(b.voorraad);
        case 'platforms':
          cmp = a.activeChannelCount.compareTo(b.activeChannelCount);
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
        _buildToolbar(),
        if (_selected.isNotEmpty) _buildBulkBar(),
        Expanded(child: _buildMatrix()),
      ]),
    );
  }

  // ── Toolbar ──

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Row 1: actions
        Row(children: [
          Text(
            '${_filteredRows.length} / ${_allRows.length} producten · $_totalListings listings',
            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
          ),
          const Spacer(),
          if (_canBatchConvert)
            OutlinedButton.icon(
              onPressed: _showBatchConvertDialog,
              icon: const Icon(Icons.currency_exchange_rounded, size: 16),
              label: const Text('Omrekenen naar lokale valuta'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF92400E),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                side: const BorderSide(color: Color(0xFFF59E0B)),
              ),
            ),
          if (_canBatchConvert) const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: _showMatchReviewDialog,
            icon: const Icon(Icons.link_rounded, size: 16),
            label: const Text('Voorraadkoppeling'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1565C0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              side: const BorderSide(color: Color(0xFF42A5F5)),
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: _importCsv,
            icon: const Icon(Icons.upload_file_outlined, size: 16),
            label: const Text('CSV importeren'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF3B82F6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              side: BorderSide.none,
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: _exportCsv,
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: const Text('Exporteren'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _navy,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        // Row 2: search + filters + sort
        Row(children: [
          Expanded(
            flex: 4,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _applyFilters(),
              decoration: InputDecoration(
                hintText: 'Zoek op naam, artikelnr, EAN...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { _searchCtrl.clear(); _applyFilters(); })
                    : null,
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 6),
          _buildCategoryDropdown(),
          const SizedBox(width: 6),
          _buildStockDropdown(),
          const SizedBox(width: 10),
          _sortChip('Naam', 'naam'),
          const SizedBox(width: 3),
          _sortChip('Prijs', 'prijs'),
          const SizedBox(width: 3),
          _sortChip('Voorraad', 'voorraad'),
          const SizedBox(width: 3),
          _sortChip('Kanalen', 'platforms'),
          const SizedBox(width: 16),
          const SizedBox(width: 8),
          Tooltip(
            message: _hideInactiveChannels ? 'Inactieve kanalen tonen' : 'Inactieve kanalen verbergen',
            child: InkWell(
              onTap: () => setState(() => _hideInactiveChannels = !_hideInactiveChannels),
              borderRadius: BorderRadius.circular(5),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: _hideInactiveChannels ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: _hideInactiveChannels ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _hideInactiveChannels ? Icons.visibility_off : Icons.visibility,
                    size: 12,
                    color: _hideInactiveChannels ? const Color(0xFF1D4ED8) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Inactief',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: _hideInactiveChannels ? FontWeight.w700 : FontWeight.w500,
                      color: _hideInactiveChannels ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            tooltip: 'Kolommen tonen/verbergen',
            icon: const Icon(Icons.view_column_outlined, size: 16, color: Color(0xFF64748B)),
            itemBuilder: (_) => SalesChannel.allChannels.map((ch) {
              final hidden = _manuallyHiddenChannels.contains(ch.code);
              return PopupMenuItem<String>(
                value: ch.code,
                child: Row(children: [
                  Icon(hidden ? Icons.check_box_outline_blank : Icons.check_box, size: 18, color: hidden ? const Color(0xFF94A3B8) : const Color(0xFF1565C0)),
                  const SizedBox(width: 8),
                  Text(ch.label, style: TextStyle(fontSize: 12, color: hidden ? const Color(0xFF94A3B8) : const Color(0xFF1E293B))),
                  if (!_isChannelActive(ch)) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.link_off, size: 10, color: Color(0xFFAAAAAA)),
                  ],
                ]),
              );
            }).toList(),
            onSelected: (code) => setState(() {
              if (_manuallyHiddenChannels.contains(code)) {
                _manuallyHiddenChannels.remove(code);
              } else {
                _manuallyHiddenChannels.add(code);
              }
            }),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.width_normal_outlined, size: 14, color: Color(0xFF94A3B8)),
          SizedBox(
            width: 70,
            child: Slider(
              value: _channelColWidth,
              min: 48,
              max: 120,
              onChanged: (v) => setState(() => _channelColWidth = v),
            ),
          ),
        ]),
        if (_loadError != null) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_loadError!, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFFE53935))),
          ),
        ],
      ]),
    );
  }

  Widget _sortChip(String label, String field) {
    final active = _sortField == field;
    return InkWell(
      onTap: () {
        setState(() {
          if (_sortField == field) { _sortAsc = !_sortAsc; } else { _sortField = field; _sortAsc = true; }
        });
        _applyFilters();
      },
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: active ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? const Color(0xFF1D4ED8) : const Color(0xFF64748B))),
          if (active) ...[
            const SizedBox(width: 1),
            Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 10, color: const Color(0xFF1D4ED8)),
          ],
        ]),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _categoryFilter,
          hint: const Text('Categorie', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          isDense: true,
          style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
          items: [
            const DropdownMenuItem(value: null, child: Text('Alle')),
            ..._allCategories.map((c) => DropdownMenuItem(value: c, child: Text(_categoryLabel(c), overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) { setState(() => _categoryFilter = v); _applyFilters(); },
        ),
      ),
    );
  }

  Widget _buildStockDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _stockFilter,
          isDense: true,
          style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('Alle')),
            DropdownMenuItem(value: 'in_stock', child: Text('Op voorraad')),
            DropdownMenuItem(value: 'low', child: Text('Laag (< 5)')),
            DropdownMenuItem(value: 'out_of_stock', child: Text('Uitverkocht')),
          ],
          onChanged: (v) { if (v != null) { setState(() => _stockFilter = v); _applyFilters(); } },
        ),
      ),
    );
  }

  // ── Bulk Action Bar ──

  Widget _buildBulkBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFFEFF6FF),
      child: Row(children: [
        Text('${_selected.length} geselecteerd', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8))),
        const SizedBox(width: 6),
        TextButton.icon(
          onPressed: () => setState(() => _selected.clear()),
          icon: const Icon(Icons.clear, size: 14),
          label: const Text('Wis'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B), textStyle: const TextStyle(fontSize: 11)),
        ),
        const Spacer(),
        _bulkActionButton('Uitverkocht op alle kanalen', Icons.block_rounded, const Color(0xFFE53935), _bulkSetUitverkocht),
        const SizedBox(width: 6),
        _bulkActionButton('Activeer op alle kanalen', Icons.check_circle_outline, const Color(0xFF2E7D32), _bulkActivateAll),
      ]),
    );
  }

  Widget _bulkActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: color),
      label: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  // ── Matrix Table ──

  Set<String> _activeChannelCodes = {};

  bool _isChannelActive(SalesChannel ch) => _activeChannelCodes.contains(ch.code);

  Widget _buildMatrix() {
    if (_filteredRows.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.grid_off_rounded, size: 48, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          Text('Geen producten gevonden', style: GoogleFonts.dmSans(fontSize: 16, color: const Color(0xFF94A3B8))),
        ]),
      );
    }

    final hScrollCtrl = ScrollController();
    return Scrollbar(
      controller: hScrollCtrl,
      thumbVisibility: true,
      trackVisibility: true,
      child: SingleChildScrollView(
        controller: hScrollCtrl,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _calcTableWidth(),
          child: _buildStickyHeaderTable(hScrollCtrl),
        ),
      ),
    );
  }

  Widget _buildStickyHeaderTable(ScrollController hScrollCtrl) {
    const borderColor = Color(0xFFE2E8F0);
    final vScrollCtrl = ScrollController();
    return Column(children: [
      _buildHeaderRows(),
      const Divider(height: 1, color: borderColor),
      Expanded(
        child: Scrollbar(
          controller: vScrollCtrl,
          thumbVisibility: true,
          trackVisibility: true,
          child: ListView.builder(
            controller: vScrollCtrl,
            itemCount: _filteredRows.length,
            itemBuilder: (_, i) => _buildDataRowWidget(_filteredRows[i]),
          ),
        ),
      ),
    ]);
  }

  double _calcTableWidth() {
    const fixedCols = 28.0 + 48.0; // checkbox + voorraad
    final channelCount = _visibleEbayChannels.length
        + _visibleBolChannels.length
        + _visibleAmazonChannels.length
        + (_isAdmarkVisible ? 1 : 0)
        + 1; // eigen site prijs
    return fixedCols + _productColWidth + _artNrColWidth + (channelCount * _channelColWidth) + 2;
  }

  Widget _buildHeaderRows() {
    const headerBg = Color(0xFFF1F5F9);
    const cellPad = EdgeInsets.symmetric(horizontal: 4, vertical: 6);
    const ebayColor = Color(0xFFE53238);
    const bolColor = Color(0xFF0000CC);
    const amazonColor = Color(0xFFFF9900);
    const admarkColor = Color(0xFF00897B);
    const inactiveOverlay = Color(0x30000000);

    Color groupBg(SalesChannel ch, Color base) {
      if (!_isChannelActive(ch)) return Color.alphaBlend(inactiveOverlay, base);
      return base;
    }

    final visibleEbay = _visibleEbayChannels;
    final visibleBol = _visibleBolChannels;
    final visibleAmazon = _visibleAmazonChannels;
    final showAdmark = _isAdmarkVisible;

    return Table(
      border: TableBorder.all(color: const Color(0xFFE2E8F0), width: 0.5),
      defaultColumnWidth: FixedColumnWidth(_channelColWidth),
      columnWidths: {
        0: const FixedColumnWidth(28),
        1: FixedColumnWidth(_productColWidth),
        2: FixedColumnWidth(_artNrColWidth),
        3: const FixedColumnWidth(48),
        4: FixedColumnWidth(_channelColWidth),
      },
      children: [
        TableRow(children: [
          _groupCell('', null),
          _resizableGroupCell('', null, (d) => setState(() => _productColWidth = (_productColWidth + d).clamp(120, 400))),
          _resizableGroupCell('', null, (d) => setState(() => _artNrColWidth = (_artNrColWidth + d).clamp(60, 180))),
          _groupCell('', null),
          _groupCell('Site', _navy),
          ...visibleEbay.map((ch) => _groupCell(
            ch == visibleEbay.first ? 'eBay' : '',
            groupBg(ch, ebayColor),
          )),
          ...visibleBol.map((ch) => _groupCell(
            ch == visibleBol.first ? 'Bol' : '',
            groupBg(ch, bolColor),
          )),
          ...visibleAmazon.map((ch) => _groupCell(
            ch == visibleAmazon.first ? 'Amazon' : '',
            groupBg(ch, amazonColor),
          )),
          if (showAdmark) _groupCell('Adm', groupBg(SalesChannel.admarkNl, admarkColor)),
        ]),
        TableRow(
          decoration: const BoxDecoration(color: headerBg),
          children: [
            const SizedBox(height: 28),
            Padding(padding: cellPad, child: Text('Product', style: _headerStyle)),
            Padding(padding: cellPad, child: Text('Art.nr', style: _headerStyle)),
            Padding(padding: cellPad, child: Text('Vrrd', style: _headerStyle, textAlign: TextAlign.center)),
            Padding(padding: cellPad, child: Text('€', style: _headerStyle, textAlign: TextAlign.center)),
            ...visibleEbay.map((ch) => _channelSubHeader(ch)),
            ...visibleBol.map((ch) => _channelSubHeader(ch)),
            ...visibleAmazon.map((ch) => _channelSubHeader(ch)),
            if (showAdmark) _channelSubHeader(SalesChannel.admarkNl),
          ],
        ),
      ],
    );
  }

  Widget _resizableGroupCell(String text, Color? bg, void Function(double dx) onDrag) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
      child: Stack(
        children: [
          _groupCell(text, bg),
          Positioned(
            right: 0, top: 0, bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: Container(width: 4, color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _channelSubHeader(SalesChannel ch) {
    const cellPad = EdgeInsets.symmetric(horizontal: 4, vertical: 6);
    final active = _isChannelActive(ch);
    return Container(
      color: active ? null : const Color(0xFFF1F0EC),
      padding: cellPad,
      child: Text(
        '${ch.shortLabel} ${_currencySymbol(ch.currency)}',
        style: _headerStyle.copyWith(
          color: active ? const Color(0xFF475569) : const Color(0xFFAAAAAA),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDataRowWidget(ChannelMatrixRow row) {
    const borderColor = Color(0xFFE2E8F0);
    final visibleEbay = _visibleEbayChannels;
    final visibleBol = _visibleBolChannels;
    final visibleAmazon = _visibleAmazonChannels;
    final showAdmark = _isAdmarkVisible;

    return Table(
      border: TableBorder.all(color: borderColor, width: 0.5),
      defaultColumnWidth: FixedColumnWidth(_channelColWidth),
      columnWidths: {
        0: const FixedColumnWidth(28),
        1: FixedColumnWidth(_productColWidth),
        2: FixedColumnWidth(_artNrColWidth),
        3: const FixedColumnWidth(48),
        4: FixedColumnWidth(_channelColWidth),
      },
      children: [_buildDataRow(row, visibleEbay, visibleBol, visibleAmazon, showAdmark)],
    );
  }

  TextStyle get _headerStyle => GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569));

  String _currencySymbol(String currency) {
    return switch (currency) {
      'GBP' => '£',
      'USD' => '\$',
      'PLN' => 'zł',
      _ => '€',
    };
  }

  Widget _groupCell(String text, Color? bg) {
    return Container(
      height: 26,
      alignment: Alignment.center,
      color: bg ?? const Color(0xFF0D1B2A),
      child: text.isNotEmpty
          ? Text(text, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5))
          : null,
    );
  }

  TableRow _buildDataRow(ChannelMatrixRow row, List<SalesChannel> visibleEbay, List<SalesChannel> visibleBol, List<SalesChannel> visibleAmazon, bool showAdmark) {
    final pid = row.product.id!;
    final isSelected = _selected.contains(pid);
    final isUitverkocht = row.voorraad <= 0;
    final rowColor = isSelected
        ? const Color(0xFFF0F5FF)
        : isUitverkocht
            ? const Color(0xFFFFF5F5)
            : Colors.white;

    return TableRow(
      decoration: BoxDecoration(color: rowColor),
      children: [
        SizedBox(
          height: 38,
          child: Center(child: SizedBox(
            width: 18, height: 18,
            child: Checkbox(
              value: isSelected,
              onChanged: (v) => setState(() { if (v == true) { _selected.add(pid); } else { _selected.remove(pid); } }),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(row.product.displayNaam, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: _navy), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (row.product.categorie != null || row.product.eanCode != null)
                Text(
                  [if (row.product.categorie != null) _categoryLabel(row.product.categorie!), if (row.product.eanCode != null) 'EAN: ${row.product.eanCode}'].join(' · '),
                  style: GoogleFonts.dmSans(fontSize: 9, color: const Color(0xFF94A3B8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        Container(
          height: 38,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            row.product.artikelnummer ?? '',
            style: GoogleFonts.sourceCodePro(fontSize: 9, color: const Color(0xFF64748B)),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        ),
        Tooltip(
          message: row.voorraad > 0
              ? 'Voorraad: ${row.voorraad} (beheer via Voorraadlijst)'
              : 'Niet op voorraad (beheer via Voorraadlijst)',
          child: Container(
            height: 38,
            alignment: Alignment.center,
            child: _stockBadge(row.voorraad),
          ),
        ),
        _priceCell(row.product.displayPrijs, null, () => _showSitePriceEdit(row)),
        ...visibleEbay.map((ch) => _channelCell(row, ch)),
        ...visibleBol.map((ch) => _channelCell(row, ch)),
        ...visibleAmazon.map((ch) => _channelCell(row, ch)),
        if (showAdmark) _channelCell(row, SalesChannel.admarkNl),
      ],
    );
  }

  Widget _priceCell(double? prijs, ListingStatus? status, VoidCallback? onTap) {
    if (prijs == null) {
      return onTap != null
          ? Tooltip(
              message: 'Klik om prijs in te stellen',
              child: InkWell(
                onTap: onTap,
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  color: const Color(0xFFFFFDE7),
                  child: const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          : Container(height: 38, alignment: Alignment.center);
    }
    final bg = _statusBg(status);
    final fg = _statusFg(status);
    return Tooltip(
      message: onTap != null ? 'Klik om prijs aan te passen' : '',
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          color: bg,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                prijs.toStringAsFixed(0),
                style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 2),
                Icon(Icons.edit_outlined, size: 10, color: fg.withValues(alpha: 0.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _channelCell(ChannelMatrixRow row, SalesChannel channel) {
    final listing = row.listingForChannel(channel.code);
    final active = _isChannelActive(channel);
    final isUitverkocht = row.voorraad <= 0;

    if (listing == null) {
      return Tooltip(
        message: active
            ? 'Klik om listing toe te voegen'
            : '${channel.label} (niet gekoppeld) — klik om prijs in te stellen',
        child: InkWell(
          onTap: () => _showAddChannelDialog(row, channel),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            color: active
                ? (isUitverkocht ? null : const Color(0xFFFFFDE7))
                : const Color(0xFFF5F3EE),
            child: active && !isUitverkocht
                ? const Icon(Icons.add, size: 12, color: Color(0xFFBBBBBB))
                : Text('—', style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFFD0D0D0))),
          ),
        ),
      );
    }

    final hasPrice = listing.prijs != null;
    return Tooltip(
      message: '${channel.label}: ${listing.status.label}${!active ? ' (niet gekoppeld)' : ''}',
      child: InkWell(
        onTap: () => _showQuickEdit(row, channel, listing),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          color: active ? _statusBg(listing.status) : Color.alphaBlend(const Color(0x18000000), _statusBg(listing.status)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!active)
                const Padding(
                  padding: EdgeInsets.only(right: 2),
                  child: Icon(Icons.link_off, size: 8, color: Color(0xFFAAAAAA)),
                ),
              Text(
                hasPrice ? listing.prijs!.toStringAsFixed(0) : 'x',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: active ? _statusFg(listing.status) : _statusFg(listing.status).withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusBg(ListingStatus? status) {
    if (status == null) return Colors.transparent;
    return switch (status) {
      ListingStatus.actief     => const Color(0xFFE8F5E9),
      ListingStatus.gepauzeerd => const Color(0xFFFFF3E0),
      ListingStatus.fout       => const Color(0xFFFFEBEE),
      ListingStatus.verwijderd => const Color(0xFFF1F5F9),
      ListingStatus.concept    => const Color(0xFFE3F2FD),
    };
  }

  Color _statusFg(ListingStatus? status) {
    if (status == null) return _navy;
    return switch (status) {
      ListingStatus.actief     => const Color(0xFF2E7D32),
      ListingStatus.gepauzeerd => const Color(0xFFE65100),
      ListingStatus.fout       => const Color(0xFFE53935),
      ListingStatus.verwijderd => const Color(0xFF94A3B8),
      ListingStatus.concept    => const Color(0xFF1565C0),
    };
  }

  Widget _stockBadge(int stock) {
    Color bg, fg;
    String label;
    if (stock <= 0) {
      bg = const Color(0xFFFFEBEE); fg = const Color(0xFFE53935); label = '0';
    } else if (stock < 5) {
      bg = const Color(0xFFFFF3E0); fg = const Color(0xFFE65100); label = '$stock';
    } else {
      bg = const Color(0xFFE8F5E9); fg = const Color(0xFF2E7D32); label = '$stock';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  // ═══════════════════════════════════════════
  // Site Price Edit (bidirectional sync via prijs_override)
  // ═══════════════════════════════════════════

  void _showSitePriceEdit(ChannelMatrixRow row) {
    final currentPrijs = row.product.displayPrijs;
    final ctrl = TextEditingController(text: currentPrijs?.toStringAsFixed(2) ?? '');
    final scraperService = WebScraperService();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          const Icon(Icons.euro_rounded, size: 18, color: Color(0xFF0D1B2A)),
          const SizedBox(width: 6),
          Expanded(child: Text('Siteprijs aanpassen', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700))),
        ]),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(row.product.displayNaam, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
                const SizedBox(height: 2),
                if (row.product.artikelnummer != null)
                  Text('Art: ${row.product.artikelnummer}', style: GoogleFonts.sourceCodePro(fontSize: 10, color: const Color(0xFF64748B))),
              ]),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Verkoopprijs (EUR)',
                border: OutlineInputBorder(),
                isDense: true,
                prefixText: '€ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.sync_rounded, size: 14, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  'Wijziging wordt automatisch doorgevoerd in de productcatalogus en het overzicht.',
                  style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF1D4ED8)),
                )),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final newPrijs = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (newPrijs == null || newPrijs < 0) return;
              if (row.product.id == null) return;
              try {
                await scraperService.updateProductOverrides(row.product.id!, {'prijs_override': newPrijs});
                _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Siteprijs van "${row.product.displayNaam}" bijgewerkt naar €${newPrijs.toStringAsFixed(2)}'),
                    backgroundColor: const Color(0xFF2E7D32),
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Fout bij opslaan: $e'),
                    backgroundColor: const Color(0xFFE53935),
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Match-review Dialog (inventory ↔ product linking)
  // ═══════════════════════════════════════════

  Future<void> _showMatchReviewDialog() async {
    final invService = InventoryService();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<InventoryMatchSuggestion> suggestions;
    List<Map<String, dynamic>> allProducts;
    try {
      final scraperService = WebScraperService();
      final results = await Future.wait([
        invService.autoMatchInventoryToProducts(),
        scraperService.fetchCatalog(),
      ]);
      suggestions = results[0] as List<InventoryMatchSuggestion>;
      final catalogProducts = results[1] as List;
      allProducts = catalogProducts.map((p) => {'id': p.id, 'naam': p.displayNaam}).toList().cast<Map<String, dynamic>>();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Fout bij laden suggesties: $e'),
          backgroundColor: const Color(0xFFE53935),
        ));
      }
      return;
    }

    if (mounted) Navigator.pop(context);

    if (suggestions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Alle voorraadartikelen zijn al gekoppeld aan producten.'),
          backgroundColor: Color(0xFF2E7D32),
        ));
      }
      return;
    }

    final matchedCount = suggestions.where((s) => s.matchScore > 0).length;
    final unmatchedCount = suggestions.length - matchedCount;
    final autoApproved = suggestions.where((s) => s.approved).length;

    if (!mounted) return;
    final searchCtrl = TextEditingController();
    String filterMode = 'all'; // 'all', 'matched', 'unmatched', 'approved'

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final q = searchCtrl.text.toLowerCase().trim();
          final filtered = suggestions.where((s) {
            if (filterMode == 'matched' && s.matchScore == 0) return false;
            if (filterMode == 'unmatched' && s.matchScore > 0) return false;
            if (filterMode == 'approved' && !s.approved) return false;
            if (q.isNotEmpty) {
              final item = s.inventoryItem;
              final haystack = '${item.variantLabel} ${item.artikelnummer ?? ''} ${item.eanCode ?? ''} ${item.leverancierCode ?? ''} ${s.productNaam}'.toLowerCase();
              if (!haystack.contains(q)) return false;
            }
            return true;
          }).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(children: [
              const Icon(Icons.link_rounded, size: 18, color: Color(0xFF1565C0)),
              const SizedBox(width: 6),
              Expanded(child: Text('Voorraadkoppeling', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700))),
            ]),
            content: SizedBox(
              width: 760,
              height: 520,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats banner
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      _matchStatChip('$matchedCount', 'gematcht', const Color(0xFF2E7D32)),
                      const SizedBox(width: 8),
                      _matchStatChip('$unmatchedCount', 'geen match', const Color(0xFFE53935)),
                      const SizedBox(width: 8),
                      _matchStatChip('$autoApproved', 'auto-goedgekeurd', const Color(0xFF1565C0)),
                      const Spacer(),
                      Text(
                        '${suggestions.where((s) => s.approved).length} geselecteerd',
                        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1D4ED8)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  // Search bar + filter chips
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: searchCtrl,
                        onChanged: (_) => setDlg(() {}),
                        decoration: InputDecoration(
                          hintText: 'Zoek op naam, artikelnr, EAN...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          suffixIcon: searchCtrl.text.isNotEmpty
                              ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { searchCtrl.clear(); setDlg(() {}); })
                              : null,
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _matchFilterChip('Alle', filterMode == 'all', () => setDlg(() => filterMode = 'all')),
                    const SizedBox(width: 4),
                    _matchFilterChip('Gematcht', filterMode == 'matched', () => setDlg(() => filterMode = 'matched')),
                    const SizedBox(width: 4),
                    _matchFilterChip('Geen match', filterMode == 'unmatched', () => setDlg(() => filterMode = 'unmatched')),
                    const SizedBox(width: 4),
                    _matchFilterChip('Goedgek.', filterMode == 'approved', () => setDlg(() => filterMode = 'approved')),
                  ]),
                  const SizedBox(height: 8),
                  // Column header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    color: const Color(0xFFF1F5F9),
                    child: Row(children: [
                      const SizedBox(width: 30),
                      Expanded(flex: 3, child: Text('Voorraaditem', style: _headerStyle)),
                      const SizedBox(width: 6),
                      Expanded(flex: 3, child: Text('Gekoppeld product', style: _headerStyle)),
                      SizedBox(width: 55, child: Text('Via', style: _headerStyle, textAlign: TextAlign.center)),
                      SizedBox(width: 45, child: Text('Score', style: _headerStyle, textAlign: TextAlign.center)),
                    ]),
                  ),
                  // Suggestion list
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(child: Text('Geen resultaten', style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF94A3B8))))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final s = filtered[i];
                              final item = s.inventoryItem;
                              final noMatch = s.matchScore == 0;
                              final scoreColor = s.matchScore >= 90
                                  ? const Color(0xFF2E7D32)
                                  : s.matchScore >= 70
                                      ? const Color(0xFFE65100)
                                      : s.matchScore >= 50
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFE53935);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 2),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(
                                  color: s.approved
                                      ? const Color(0xFFE8F5E9)
                                      : noMatch
                                          ? const Color(0xFFFFF8F8)
                                          : Colors.white,
                                  border: Border.all(color: s.approved ? const Color(0xFF66BB6A) : noMatch ? const Color(0xFFFFCDD2) : const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(children: [
                                  SizedBox(
                                    width: 30,
                                    child: Checkbox(
                                      value: s.approved,
                                      onChanged: (v) => setDlg(() => s.approved = v ?? false),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.variantLabel.isNotEmpty ? item.variantLabel : '(naamloos)', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: _navy), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text(
                                          [
                                            if (item.eanCode != null) 'EAN: ${item.eanCode}',
                                            if (item.artikelnummer != null) 'Art: ${item.artikelnummer}',
                                            'Voorraad: ${s.totalStock}',
                                            if (s.variantCount > 1) '(${s.variantCount} regels)',
                                          ].join(' · '),
                                          style: GoogleFonts.dmSans(fontSize: 9, color: const Color(0xFF94A3B8)),
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: allProducts.any((p) => p['id'] == s.effectiveProductId) ? s.effectiveProductId : null,
                                        isDense: true,
                                        isExpanded: true,
                                        hint: Text(noMatch ? 'Kies product...' : '', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8))),
                                        style: GoogleFonts.dmSans(fontSize: 11, color: _navy),
                                        items: allProducts.map((p) => DropdownMenuItem<int>(
                                          value: p['id'] as int,
                                          child: Text(
                                            (p['naam'] as String?) ?? 'Product ${p['id']}',
                                            maxLines: 1, overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.dmSans(fontSize: 11),
                                          ),
                                        )).toList(),
                                        onChanged: (v) {
                                          if (v != null) setDlg(() { s.overrideProductId = v; s.approved = true; });
                                        },
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 55,
                                    child: noMatch
                                        ? const Icon(Icons.help_outline, size: 14, color: Color(0xFFE53935))
                                        : Text(s.matchMethod, style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF64748B)), textAlign: TextAlign.center),
                                  ),
                                  SizedBox(
                                    width: 45,
                                    child: noMatch
                                        ? Text('—', style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFFE2E8F0)), textAlign: TextAlign.center)
                                        : Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: scoreColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text('${s.matchScore}%', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: scoreColor)),
                                          ),
                                  ),
                                ]),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    TextButton(
                      onPressed: () => setDlg(() { for (final s in suggestions) { if (s.matchScore >= 90) s.approved = true; } }),
                      child: const Text('Alle hoge matches', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () => setDlg(() { for (final s in suggestions) { if (s.matchScore > 0) s.approved = true; } }),
                      child: const Text('Alle matches', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () => setDlg(() { for (final s in suggestions) s.approved = false; }),
                      child: const Text('Niets', style: TextStyle(fontSize: 11)),
                    ),
                    const Spacer(),
                    Text(
                      '${filtered.length} getoond · ${suggestions.where((s) => s.approved).length} / ${suggestions.length} geselecteerd',
                      style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ]),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
              ElevatedButton.icon(
                onPressed: suggestions.any((s) => s.approved)
                    ? () => Navigator.pop(ctx, true)
                    : null,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: Text('Koppelen (${suggestions.where((s) => s.approved).length})'),
                style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;

    final toLink = suggestions.where((s) => s.approved && s.effectiveProductId > 0).toList();
    if (toLink.isEmpty) return;

    int linkedGroups = 0;
    int linkedItems = 0;
    for (final s in toLink) {
      try {
        if (s.groupItems.isNotEmpty) {
          await invService.linkGroupToProduct(s.groupItems, s.effectiveProductId);
          linkedItems += s.groupItems.length;
        } else {
          await invService.linkInventoryToProduct(s.inventoryItem.id!, s.effectiveProductId);
          linkedItems++;
        }
        linkedGroups++;
      } catch (_) {}
    }

    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$linkedGroups producten gekoppeld ($linkedItems voorraadregels)'),
        backgroundColor: const Color(0xFF2E7D32),
      ));
    }
  }

  Widget _matchStatChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: color)),
      ]),
    );
  }

  Widget _matchFilterChip(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: active ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0)),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? const Color(0xFF1D4ED8) : const Color(0xFF64748B))),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Quick Edit Dialog
  // ═══════════════════════════════════════════

  void _showQuickEdit(ChannelMatrixRow row, SalesChannel channel, MarketplaceListing listing) {
    final prijsCtrl = TextEditingController(text: listing.prijs?.toStringAsFixed(2) ?? '');
    var selectedStatus = listing.status;
    final hasExternUrl = listing.externUrl != null && listing.externUrl!.isNotEmpty;
    final active = _isChannelActive(channel);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(children: [
            Icon(_platformIcon(channel.platform), size: 18, color: _platformColor(channel.platform)),
            const SizedBox(width: 6),
            Expanded(child: Text(channel.label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700))),
            if (!active)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Text('Niet gekoppeld', style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF92400E))),
              ),
          ]),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(row.product.displayNaam, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (row.product.artikelnummer != null) ...[
                      Text('Art: ${row.product.artikelnummer}', style: GoogleFonts.sourceCodePro(fontSize: 10, color: const Color(0xFF64748B))),
                      const SizedBox(width: 10),
                    ],
                    Text('Voorraad: ${row.voorraad}', style: GoogleFonts.dmSans(fontSize: 10, color: row.voorraad > 0 ? const Color(0xFF2E7D32) : const Color(0xFFE53935), fontWeight: FontWeight.w600)),
                    if (row.product.displayPrijs != null) ...[
                      const SizedBox(width: 10),
                      Text('Site: €${row.product.displayPrijs!.toStringAsFixed(0)}', style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF64748B))),
                    ],
                  ]),
                ]),
              ),
              const SizedBox(height: 12),

              // External link
              if (hasExternUrl)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      final uri = Uri.tryParse(listing.externUrl!);
                      if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    child: Row(children: [
                      Icon(Icons.open_in_new, size: 14, color: _platformColor(channel.platform)),
                      const SizedBox(width: 4),
                      Expanded(child: Text(
                        'Bekijk op ${channel.platform.label}',
                        style: GoogleFonts.dmSans(fontSize: 11, color: _platformColor(channel.platform), fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                      )),
                    ]),
                  ),
                ),

              if (listing.platformData.containsKey('auto_actie'))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE65100).withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.auto_mode_rounded, size: 14, color: Color(0xFFE65100)),
                    const SizedBox(width: 6),
                    Text('Automatisch gepauzeerd/gesloten', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFE65100))),
                  ]),
                ),

              DropdownButtonFormField<ListingStatus>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
                items: [ListingStatus.actief, ListingStatus.gepauzeerd, ListingStatus.concept].map((s) =>
                    DropdownMenuItem(value: s, child: Text(s.label))).toList(),
                onChanged: (v) { if (v != null) setDlg(() => selectedStatus = v); },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: prijsCtrl,
                decoration: InputDecoration(
                  labelText: 'Prijs (${channel.currency})',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  prefixText: channel.currency == 'GBP' ? '£ ' : channel.currency == 'PLN' ? 'zł ' : '€ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
              ),
              if (listing.externTitle != null) ...[
                const SizedBox(height: 10),
                Text('eBay titel:', style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF94A3B8))),
                Text(listing.externTitle!, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF475569)), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _service.updateListing(listing.id!, status: ListingStatus.verwijderd);
                _load();
              },
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFE53935)),
              child: const Text('Verwijderen'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final pd = Map<String, dynamic>.from(listing.platformData);
                pd.remove('auto_actie');
                pd.remove('auto_reden');
                pd.remove('auto_datum');
                pd.remove('auto_voorraad');
                await _service.updateListing(
                  listing.id!,
                  prijs: double.tryParse(prijsCtrl.text.replaceAll(',', '.')),
                  status: selectedStatus,
                  platformData: pd,
                );
                _load();
              },
              style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
              child: const Text('Opslaan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddChannelDialog(ChannelMatrixRow row, SalesChannel channel) {
    final prijsCtrl = TextEditingController(text: row.product.displayPrijs?.toStringAsFixed(2) ?? '');
    final active = _isChannelActive(channel);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          Icon(_platformIcon(channel.platform), size: 18, color: _platformColor(channel.platform)),
          const SizedBox(width: 6),
          Expanded(child: Text('Toevoegen: ${channel.label}', style: const TextStyle(fontSize: 14))),
        ]),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(row.product.displayNaam, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 14),
            if (!active)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFF92400E)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    '${channel.platform.label} is nog niet gekoppeld. '
                    'Prijs wordt opgeslagen maar pas actief na koppeling via Marktplaatsen.',
                    style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF92400E)),
                  )),
                ]),
              ),
            TextField(
              controller: prijsCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Prijs (${channel.currency})',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixText: channel.currency == 'GBP' ? '£ ' : channel.currency == 'PLN' ? 'zł ' : '€ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prijs = double.tryParse(prijsCtrl.text.replaceAll(',', '.'));
              await _service.createListing(MarketplaceListing(
                productId: row.product.id!,
                platform: channel.platform,
                status: active ? ListingStatus.actief : ListingStatus.concept,
                prijs: prijs ?? row.product.displayPrijs,
                taal: channel.country,
              ));
              _load();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
            child: const Text('Toevoegen'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Batch Omrekenen
  // ═══════════════════════════════════════════

  Future<void> _showBatchConvertDialog() async {
    final rowsToProcess = _selected.isNotEmpty
        ? _allRows.where((r) => r.product.id != null && _selected.contains(r.product.id!)).toList()
        : _filteredRows;
    if (rowsToProcess.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecteer producten of filter de lijst'), backgroundColor: Color(0xFFF59E0B)),
        );
      }
      return;
    }
    Map<String, Map<String, dynamic>> kanaalValuta = {};
    try {
      kanaalValuta = await _service.getKanaalValuta();
    } catch (_) {}
    final changes = <_BatchConvertItem>[];
    for (final row in rowsToProcess) {
      final eurPrice = row.product.displayPrijs;
      if (eurPrice == null || eurPrice <= 0) continue;
      for (final ch in SalesChannel.allChannels) {
        if (ch.currency == 'EUR') continue;
        final kv = kanaalValuta[ch.code];
        final wisselkoers = (kv?['wisselkoers_eur'] as num?)?.toDouble();
        if (wisselkoers == null || wisselkoers <= 0) continue;
        final listing = row.listingForChannel(ch.code);
        if (listing == null || listing.id == null || listing.prijs == null) continue;
        final proposed = (eurPrice / wisselkoers).ceilToDouble();
        if (proposed == listing.prijs) continue;
        changes.add(_BatchConvertItem(
          productId: row.product.id!,
          productNaam: row.product.displayNaam,
          channel: ch,
          currentPrijs: listing.prijs!,
          proposedPrijs: proposed,
          listingId: listing.id!,
        ));
      }
    }
    if (changes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen prijswijzigingen nodig voor niet-EUR kanalen'), backgroundColor: Color(0xFF2E7D32)),
        );
      }
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          Icon(Icons.currency_exchange_rounded, color: const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Text('Omrekenen naar lokale valuta', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: SizedBox(
          width: 480,
          height: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${changes.length} prijswijziging(en) voorgesteld. Bron: catalogus-basisprijs (EUR), afgerond naar boven.',
                  style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF92400E)),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: changes.length,
                  itemBuilder: (_, i) {
                    final c = changes[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFDE7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(c.productNaam, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          SizedBox(width: 50, child: Text(c.channel.shortLabel, style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF64748B)))),
                          SizedBox(width: 50, child: Text('${c.currentPrijs.toStringAsFixed(0)} →', style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF94A3B8)))),
                          SizedBox(width: 50, child: Text(c.proposedPrijs.toStringAsFixed(0), style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF92400E)))),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF92400E)),
            child: const Text('Toepassen'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    int count = 0;
    for (final c in changes) {
      try {
        await _service.updateListing(c.listingId, prijs: c.proposedPrijs);
        count++;
      } catch (_) {}
    }
    setState(() => _selected.clear());
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count prijzen bijgewerkt'), backgroundColor: const Color(0xFF2E7D32)),
      );
    }
  }

  // ═══════════════════════════════════════════
  // Bulk Actions
  // ═══════════════════════════════════════════

  Future<void> _bulkSetUitverkocht() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    int count = 0;
    for (final pid in ids) {
      final row = _allRows.where((r) => r.product.id == pid).firstOrNull;
      if (row == null) continue;
      for (final entry in row.listings.entries) {
        for (final listing in entry.value) {
          if (listing.id != null && listing.status != ListingStatus.verwijderd) {
            await _service.updateListing(listing.id!, status: ListingStatus.gepauzeerd);
            count++;
          }
        }
      }
    }
    setState(() => _selected.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$count listing(s) gepauzeerd'),
        backgroundColor: const Color(0xFFE65100),
      ));
    }
    _load();
  }

  Future<void> _bulkActivateAll() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    int count = 0;
    for (final pid in ids) {
      final row = _allRows.where((r) => r.product.id == pid).firstOrNull;
      if (row == null) continue;
      for (final entry in row.listings.entries) {
        for (final listing in entry.value) {
          if (listing.id != null && listing.status == ListingStatus.gepauzeerd) {
            final pd = Map<String, dynamic>.from(listing.platformData);
            pd.remove('auto_actie');
            pd.remove('auto_reden');
            pd.remove('auto_datum');
            pd.remove('auto_voorraad');
            await _service.updateListing(listing.id!, status: ListingStatus.actief, platformData: pd);
            count++;
          }
        }
      }
    }
    setState(() => _selected.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$count listing(s) geactiveerd'),
        backgroundColor: const Color(0xFF2E7D32),
      ));
    }
    _load();
  }

  // ═══════════════════════════════════════════
  // CSV Import
  // ═══════════════════════════════════════════

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    final content = String.fromCharCodes(bytes);

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('CSV Importeren'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Bestand: ${result.files.first.name}\n'
              'Regels: ${content.split('\n').where((l) => l.trim().isNotEmpty).length}',
              style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Text(
                'Producten worden gematcht op naam. Bestaande listings worden bijgewerkt met nieuwe prijzen.',
                style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF92400E)),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
            child: const Text('Importeren'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV wordt geïmporteerd...'), duration: Duration(seconds: 2)),
    );

    try {
      final summary = await _service.importAdvertentiesCsv(content);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Import klaar: ${summary['matched'] ?? 0} producten gematcht, ${summary['created'] ?? 0} listings aangemaakt/bijgewerkt, ${summary['skipped'] ?? 0} overgeslagen'),
        backgroundColor: const Color(0xFF2E7D32),
        duration: const Duration(seconds: 5),
      ));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Import mislukt: $e'),
        backgroundColor: const Color(0xFFE53935),
      ));
    }
  }

  // ═══════════════════════════════════════════
  // CSV Export
  // ═══════════════════════════════════════════

  void _exportCsv() {
    final buf = StringBuffer();
    final allChannels = SalesChannel.allChannels;
    buf.write('Product;Artikelnr;Categorie;Voorraad;Eigen site');
    for (final ch in allChannels) {
      buf.write(';${ch.label}');
    }
    buf.writeln();

    for (final row in _filteredRows) {
      final fields = <String>[
        row.product.displayNaam,
        row.product.artikelnummer ?? '',
        row.product.categorie != null ? _categoryLabel(row.product.categorie!) : '',
        row.voorraad.toString(),
        row.product.displayPrijs?.toStringAsFixed(2) ?? '',
      ];
      for (final ch in allChannels) {
        final listing = row.listingForChannel(ch.code);
        if (listing == null) {
          fields.add('-');
        } else {
          final statusPrefix = listing.status == ListingStatus.actief ? '' : '(${listing.status.label}) ';
          fields.add('$statusPrefix${listing.prijs?.toStringAsFixed(2) ?? "x"}');
        }
      }
      buf.writeln(fields.join(';'));
    }

    Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('CSV (${_filteredRows.length} rijen, ${allChannels.length + 5} kolommen) gekopieerd naar klembord'),
        backgroundColor: const Color(0xFF2E7D32),
      ));
    }
  }

  // ═══════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════

  IconData _platformIcon(MarketplacePlatform p) => switch (p) {
    MarketplacePlatform.bolCom => Icons.shopping_bag_rounded,
    MarketplacePlatform.ebay => Icons.gavel_rounded,
    MarketplacePlatform.amazon => Icons.local_shipping_rounded,
    MarketplacePlatform.marktplaats => Icons.storefront_rounded,
    MarketplacePlatform.admark => Icons.campaign_rounded,
  };

  Color _platformColor(MarketplacePlatform p) => switch (p) {
    MarketplacePlatform.bolCom => const Color(0xFF0000CC),
    MarketplacePlatform.ebay => const Color(0xFFE53238),
    MarketplacePlatform.amazon => const Color(0xFFFF9900),
    MarketplacePlatform.marktplaats => const Color(0xFF2D8CFF),
    MarketplacePlatform.admark => const Color(0xFF00897B),
  };

  static const _catLabels = {
    'optimist': 'Optimist', 'ventoz-laserzeil': 'Laser / ILCA', 'ventoz-topaz': 'Topaz',
    'ventoz-splash': 'Splash', 'beachsailing': 'Strandzeil', 'ventoz-centaur': 'Centaur',
    'rs-feva': 'RS Feva', 'valk': 'Polyvalk', 'randmeer': 'Randmeer', 'hobie-cat': 'Hobie Cat',
    'ventoz-420-470-sails': '420 / 470', 'efsix': 'EFSix', 'sunfish': 'Sunfish',
    'stormfok': 'Stormfok', 'open-bic': 'Open Bic', 'nacra-17': 'Nacra 17',
    'yamaha-seahopper': 'Yamaha Seahopper', 'mirror': 'Mirror', 'fox-22': 'Fox 22', 'diversen': 'Diversen',
  };

  String _categoryLabel(String cat) => _catLabels[cat] ?? cat;
}

class _BatchConvertItem {
  final int productId;
  final String productNaam;
  final SalesChannel channel;
  final double currentPrijs;
  final double proposedPrijs;
  final String listingId;

  const _BatchConvertItem({
    required this.productId,
    required this.productNaam,
    required this.channel,
    required this.currentPrijs,
    required this.proposedPrijs,
    required this.listingId,
  });
}
