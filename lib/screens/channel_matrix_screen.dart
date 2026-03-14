import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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
  String? _loadError;

  final _searchCtrl = TextEditingController();
  String _stockFilter = 'all';
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
    setState(() { _loading = true; _loadError = null; });
    try {
      final rows = await _service.getChannelMatrix();
      if (!mounted) return;
      setState(() {
        _allRows = rows;
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
            '${_filteredRows.length} / ${_allRows.length} producten',
            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
          ),
          const Spacer(),
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

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _buildTable(),
      ),
    );
  }

  Widget _buildTable() {
    const headerBg = Color(0xFFF1F5F9);
    const borderColor = Color(0xFFE2E8F0);
    const cellPad = EdgeInsets.symmetric(horizontal: 4, vertical: 6);
    const ebayColor = Color(0xFFE53238);
    const bolColor = Color(0xFF0000CC);
    const amazonColor = Color(0xFFFF9900);
    const admarkColor = Color(0xFF00897B);

    return Table(
      border: TableBorder.all(color: borderColor, width: 0.5),
      defaultColumnWidth: const FixedColumnWidth(54),
      columnWidths: const {
        0: FixedColumnWidth(28),   // checkbox
        1: FixedColumnWidth(180),  // product
        2: FixedColumnWidth(72),   // artikelnr
        3: FixedColumnWidth(44),   // voorraad
        4: FixedColumnWidth(56),   // eigen site prijs
      },
      children: [
        // Group header row — platform names with colored backgrounds
        TableRow(
          children: [
            _groupCell('', null),
            _groupCell('', null),
            _groupCell('', null),
            _groupCell('', null),
            _groupCell('Site', _navy),
            ...SalesChannel.ebayChannels.map((ch) => _groupCell(ch == SalesChannel.ebayUk ? 'eBay' : '', ebayColor)),
            ...SalesChannel.bolChannels.map((ch) => _groupCell(ch == SalesChannel.bolNl ? 'Bol' : '', bolColor)),
            ...SalesChannel.amazonChannels.map((ch) => _groupCell(ch == SalesChannel.amazonDe ? 'Amazon' : '', amazonColor)),
            _groupCell('Adm', admarkColor),
          ],
        ),
        // Sub-header row (country codes)
        TableRow(
          decoration: const BoxDecoration(color: headerBg),
          children: [
            const SizedBox(height: 28),
            Padding(padding: cellPad, child: Text('Product', style: _headerStyle)),
            Padding(padding: cellPad, child: Text('Art.nr', style: _headerStyle)),
            Padding(padding: cellPad, child: Text('Vrrd', style: _headerStyle, textAlign: TextAlign.center)),
            Padding(padding: cellPad, child: Text('Prijs', style: _headerStyle, textAlign: TextAlign.center)),
            ...SalesChannel.ebayChannels.map((ch) => Padding(padding: cellPad, child: Text(ch.shortLabel, style: _headerStyle, textAlign: TextAlign.center))),
            ...SalesChannel.bolChannels.map((ch) => Padding(padding: cellPad, child: Text(ch.shortLabel, style: _headerStyle, textAlign: TextAlign.center))),
            ...SalesChannel.amazonChannels.map((ch) => Padding(padding: cellPad, child: Text(ch.shortLabel, style: _headerStyle, textAlign: TextAlign.center))),
            Padding(padding: cellPad, child: Text('Adm', style: _headerStyle, textAlign: TextAlign.center)),
          ],
        ),
        // Data rows
        ..._filteredRows.map(_buildDataRow),
      ],
    );
  }

  TextStyle get _headerStyle => GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569));

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

  TableRow _buildDataRow(ChannelMatrixRow row) {
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
        // Checkbox
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
        // Product name + category
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(row.product.displayNaam, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: _navy), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (row.product.categorie != null)
                Text(_categoryLabel(row.product.categorie!), style: GoogleFonts.dmSans(fontSize: 9, color: const Color(0xFF94A3B8))),
            ],
          ),
        ),
        // Artikelnummer
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
        // Voorraad
        Center(child: _stockBadge(row.voorraad)),
        // Eigen site prijs
        _priceCell(row.product.displayPrijs, null, null),
        // eBay channels
        ...SalesChannel.ebayChannels.map((ch) => _channelCell(row, ch)),
        // Bol channels
        ...SalesChannel.bolChannels.map((ch) => _channelCell(row, ch)),
        // Amazon channels
        ...SalesChannel.amazonChannels.map((ch) => _channelCell(row, ch)),
        // Admark
        _channelCell(row, SalesChannel.admarkNl),
      ],
    );
  }

  Widget _priceCell(double? prijs, ListingStatus? status, VoidCallback? onTap) {
    if (prijs == null) {
      return Container(height: 38, alignment: Alignment.center);
    }
    final bg = _statusBg(status);
    final fg = _statusFg(status);
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        color: bg,
        child: Text(
          prijs.toStringAsFixed(0),
          style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
        ),
      ),
    );
  }

  Widget _channelCell(ChannelMatrixRow row, SalesChannel channel) {
    final listing = row.listingForChannel(channel.code);
    final isUitverkocht = row.voorraad <= 0;

    if (listing == null) {
      // No listing: show yellow "potential" if product has stock, grey if uitverkocht
      final canPlace = !isUitverkocht && row.product.displayPrijs != null;
      return Tooltip(
        message: canPlace ? 'Klik om advertentie te plaatsen' : '',
        child: InkWell(
          onTap: canPlace ? () => _showAddChannelDialog(row, channel) : null,
          child: Container(
            height: 38,
            alignment: Alignment.center,
            color: canPlace ? const Color(0xFFFFFDE7) : null,
            child: canPlace
                ? null
                : Text('—', style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFFE2E8F0))),
          ),
        ),
      );
    }

    // Has listing — show status-colored cell
    final hasPrice = listing.prijs != null;
    return Tooltip(
      message: '${channel.label}: ${listing.status.label}${listing.externUrl != null ? '\nKlik voor acties' : ''}',
      child: InkWell(
        onTap: () => _showQuickEdit(row, channel, listing),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          color: _statusBg(listing.status),
          child: hasPrice
              ? Text(
                  listing.prijs!.toStringAsFixed(0),
                  style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: _statusFg(listing.status)),
                )
              : Text(
                  'x',
                  style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: _statusFg(listing.status)),
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
  // Quick Edit Dialog
  // ═══════════════════════════════════════════

  void _showQuickEdit(ChannelMatrixRow row, SalesChannel channel, MarketplaceListing listing) {
    final prijsCtrl = TextEditingController(text: listing.prijs?.toStringAsFixed(2) ?? '');
    var selectedStatus = listing.status;
    final hasExternUrl = listing.externUrl != null && listing.externUrl!.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(children: [
            Icon(_platformIcon(channel.platform), size: 18, color: _platformColor(channel.platform)),
            const SizedBox(width: 6),
            Expanded(child: Text('${channel.label}', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700))),
          ]),
          content: SizedBox(
            width: 360,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Product info
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
                  prefixText: channel.currency == 'GBP' ? '£ ' : '€ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          Icon(_platformIcon(channel.platform), size: 18, color: _platformColor(channel.platform)),
          const SizedBox(width: 6),
          Text('Toevoegen: ${channel.label}', style: const TextStyle(fontSize: 14)),
        ]),
        content: SizedBox(
          width: 300,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(row.product.displayNaam, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: prijsCtrl,
              decoration: InputDecoration(
                labelText: 'Prijs (${channel.currency})',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixText: channel.currency == 'GBP' ? '£ ' : '€ ',
              ),
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
              await _service.createListing(MarketplaceListing(
                productId: row.product.id!,
                platform: channel.platform,
                status: ListingStatus.actief,
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
