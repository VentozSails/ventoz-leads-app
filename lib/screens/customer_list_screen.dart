import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/customer_service.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _accent = Color(0xFF1B4965);
  static const _green = Color(0xFF2E7D32);
  static const _border = Color(0xFFE2E8F0);

  final _service = CustomerService();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _hScrollCtrl = ScrollController();

  List<Customer> _customers = [];
  List<Customer> _all = [];
  bool _loading = true;

  String? _landFilter;
  bool? _zakelijkFilter;
  String _sortBy = 'klantnummer';
  bool _sortAsc = false;

  int _totalCount = 0;
  int _zakelijkCount = 0;
  int _particulierCount = 0;

  final Set<String> _visibleCols = {
    'klantnr', 'naam', 'email', 'adres', 'postcode', 'plaats', 'land', 'telefoon', 'omzet', 'facturen', 'laatste_factuur', 'type',
  };

  late List<String> _colOrder = [
    'klantnr', 'naam', 'email', 'adres', 'postcode', 'plaats', 'land', 'telefoon', 'omzet', 'facturen', 'laatste_factuur', 'type',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _hScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await _service.getAll(
      landFilter: _landFilter,
      zakelijkFilter: _zakelijkFilter,
      sortBy: _sortBy,
      sortAsc: _sortAsc,
      limit: 5000,
    );
    if (!mounted) return;
    _all = results;
    _applySearch();
    _totalCount = results.length;
    _zakelijkCount = results.where((c) => c.isZakelijk).length;
    _particulierCount = _totalCount - _zakelijkCount;
    setState(() => _loading = false);
  }

  void _applySearch() {
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) {
      _customers = List.from(_all);
    } else {
      _customers = _all.where((c) {
        return c.displayNaam.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q) ||
            c.klantnummer.toLowerCase().contains(q) ||
            (c.bedrijfsnaam ?? '').toLowerCase().contains(q) ||
            (c.woonplaats ?? '').toLowerCase().contains(q) ||
            (c.snelstartKlantcode ?? '').toLowerCase().contains(q) ||
            (c.contactpersoon ?? '').toLowerCase().contains(q) ||
            (c.telefoon ?? '').toLowerCase().contains(q) ||
            (c.adres ?? '').toLowerCase().contains(q) ||
            (c.postcode ?? '').toLowerCase().contains(q) ||
            c.landCode.toLowerCase().contains(q) ||
            (c.landLabel).toLowerCase().contains(q) ||
            c.aantalFacturen.toString().contains(q);
      }).toList();
    }
    if (mounted) setState(() {});
  }

  void _openDetail(Customer? customer) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: customer?.id)),
    );
    if (result == true) _load();
  }

  void _setSort(String col) {
    setState(() {
      if (_sortBy == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sortBy = col;
        _sortAsc = true;
      }
    });
    _load();
  }

  String _fmtOmzet(double v) {
    if (v == 0) return '-';
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final whole = parts[0];
    final dec = parts[1];
    final buf = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buf.write('.');
      buf.write(whole[i]);
    }
    return '€ ${buf.toString()},$dec';
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Klanten', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Nieuwe klant',
            onPressed: () => _openDetail(null),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Vernieuwen',
            onPressed: _load,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildKpiRow(),
          _buildToolbar(),
          const Divider(height: 1, color: _border),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? _buildEmpty()
                    : isWide
                        ? _buildTable()
                        : _buildCardList(),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildKpiRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          _kpiChip(Icons.people_rounded, '$_totalCount', 'Totaal', _accent),
          const SizedBox(width: 10),
          _kpiChip(Icons.business_rounded, '$_zakelijkCount', 'Zakelijk', const Color(0xFF6366F1)),
          const SizedBox(width: 10),
          _kpiChip(Icons.person_rounded, '$_particulierCount', 'Particulier', const Color(0xFF0EA5E9)),
        ],
      ),
    );
  }

  Widget _kpiChip(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Text(value, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: color.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _applySearch(),
              decoration: InputDecoration(
                hintText: 'Zoek op naam, email, klantnr, adres, plaats, land...',
                hintStyle: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () { _searchCtrl.clear(); _applySearch(); },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accent, width: 1.5)),
              ),
              style: GoogleFonts.dmSans(fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          _filterDropdown<String?>(
            value: _landFilter,
            hint: 'Alle landen',
            items: [
              const DropdownMenuItem(value: null, child: Text('Alle landen')),
              for (final lc in ['NL', 'DE', 'BE', 'GB', 'IT', 'FR', 'IE', 'ES', 'AT', 'CH', 'PL'])
                DropdownMenuItem(value: lc, child: Text(lc)),
            ],
            onChanged: (v) { _landFilter = v; _load(); },
          ),
          const SizedBox(width: 8),
          _filterDropdown<bool?>(
            value: _zakelijkFilter,
            hint: 'Alle typen',
            items: const [
              DropdownMenuItem(value: null, child: Text('Alle typen')),
              DropdownMenuItem(value: true, child: Text('Zakelijk')),
              DropdownMenuItem(value: false, child: Text('Particulier')),
            ],
            onChanged: (v) { _zakelijkFilter = v; _load(); },
          ),
          const SizedBox(width: 8),
          _columnChooserButton(),
        ],
      ),
    );
  }

  Widget _columnChooserButton() {
    return IconButton(
      tooltip: 'Kolommen kiezen & ordenen',
      icon: Icon(Icons.view_column_rounded, size: 20, color: _accent.withValues(alpha: 0.7)),
      onPressed: _showColumnChooserDialog,
    );
  }

  void _showColumnChooserDialog() {
    final tempOrder = List<String>.from(_colOrder);
    final tempVisible = Set<String>.from(_visibleCols);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          title: Row(children: [
            const Icon(Icons.view_column_rounded, size: 22, color: Color(0xFF455A64)),
            const SizedBox(width: 10),
            Text('Kolommen', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          content: SizedBox(
            width: 320,
            height: 420,
            child: ReorderableListView.builder(
              shrinkWrap: true,
              itemCount: tempOrder.length,
              onReorder: (oldIdx, newIdx) {
                setDialogState(() {
                  if (newIdx > oldIdx) newIdx--;
                  final item = tempOrder.removeAt(oldIdx);
                  tempOrder.insert(newIdx, item);
                });
              },
              itemBuilder: (_, i) {
                final key = tempOrder[i];
                final def = _allColumns.firstWhere((d) => d.key == key, orElse: () => _ColDef(key, key));
                return CheckboxListTile(
                  key: ValueKey(key),
                  value: tempVisible.contains(key),
                  onChanged: (v) => setDialogState(() {
                    if (v == true) { tempVisible.add(key); } else { tempVisible.remove(key); }
                  }),
                  title: Text(def.label, style: GoogleFonts.dmSans(fontSize: 13)),
                  secondary: const Icon(Icons.drag_handle, size: 18, color: Color(0xFF94A3B8)),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _colOrder = tempOrder;
                  _visibleCols.clear();
                  _visibleCols.addAll(tempVisible);
                });
                Navigator.pop(ctx);
              },
              child: const Text('Toepassen'),
            ),
          ],
        );
      }),
    );
  }

  static const _allColumns = <_ColDef>[
    _ColDef('klantnr', 'Klantnr / Snelstart'),
    _ColDef('naam', 'Naam'),
    _ColDef('email', 'E-mail'),
    _ColDef('adres', 'Adres'),
    _ColDef('postcode', 'Postcode'),
    _ColDef('plaats', 'Plaats'),
    _ColDef('land', 'Land'),
    _ColDef('telefoon', 'Telefoon'),
    _ColDef('omzet', 'Omzet'),
    _ColDef('facturen', 'Factuurnr'),
    _ColDef('laatste_factuur', 'Laatste factuur'),
    _ColDef('type', 'Type'),
  ];

  Widget _filterDropdown<T>({required T value, required String hint, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: GoogleFonts.dmSans(fontSize: 12, color: _navy),
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Geen klanten gevonden', style: GoogleFonts.dmSans(color: Colors.grey)),
          if (_searchCtrl.text.isNotEmpty || _landFilter != null || _zakelijkFilter != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () {
                  _searchCtrl.clear();
                  _landFilter = null;
                  _zakelijkFilter = null;
                  _load();
                },
                child: const Text('Filters wissen'),
              ),
            ),
        ],
      ),
    );
  }

  static const _colDefs = <String, _Col>{
    'klantnr':        _Col('Klantnr', 110, sortKey: 'klantnummer'),
    'naam':           _Col('Naam', 180, sortKey: 'naam'),
    'email':          _Col('E-mail', 190),
    'adres':          _Col('Adres', 170),
    'postcode':       _Col('Postcode', 80),
    'plaats':         _Col('Plaats', 120, sortKey: 'woonplaats'),
    'land':           _Col('Land', 50, sortKey: 'land_code'),
    'telefoon':       _Col('Telefoon', 110),
    'omzet':          _Col('Omzet', 100, sortKey: 'totale_omzet'),
    'facturen':       _Col('Factuurnr', 120, sortKey: 'aantal_facturen'),
    'laatste_factuur': _Col('Laatste factuur', 105, sortKey: 'laatste_factuur_datum'),
    'type':           _Col('Particulier / Zakelijk', 105),
  };

  List<_Col> _buildCols() {
    final cols = <_Col>[const _Col('', 36)];
    for (final key in _colOrder) {
      if (_visibleCols.contains(key) && _colDefs.containsKey(key)) {
        cols.add(_colDefs[key]!);
      }
    }
    return cols;
  }

  Widget _buildTable() {
    final cols = _buildCols();

    return Scrollbar(
      controller: _hScrollCtrl,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _hScrollCtrl,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: cols.fold<double>(0, (s, c) => s + c.width + 12),
          child: Column(
            children: [
              Container(
                color: _navy.withValues(alpha: 0.04),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: cols.map((c) => _headerCell(c)).toList()),
              ),
              const Divider(height: 1, color: _border),
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  itemCount: _customers.length,
                  itemBuilder: (ctx, i) => _tableRow(_customers[i], i, cols),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCell(_Col col) {
    final isSorted = col.sortKey != null && _sortBy == col.sortKey;
    return InkWell(
      onTap: col.sortKey != null ? () => _setSort(col.sortKey!) : null,
      child: SizedBox(
        width: col.width,
        height: 36,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  col.label,
                  style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: _navy.withValues(alpha: 0.7)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSorted)
                Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: _accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _cellFor(String colLabel, Customer c) {
    final s11 = GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B));
    return switch (colLabel) {
      'Naam' => Text(c.displayNaam, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _navy), overflow: TextOverflow.ellipsis),
      'Particulier / Zakelijk' => _typeBadge(c.isZakelijk),
      'Klantnr' => _klantnrCell(c),
      'E-mail' => Text(c.email.startsWith('noemail_') ? '-' : c.email, style: s11, overflow: TextOverflow.ellipsis),
      'Adres' => Text(c.adres ?? '-', style: s11, overflow: TextOverflow.ellipsis),
      'Postcode' => Text(c.postcode ?? '-', style: s11, overflow: TextOverflow.ellipsis),
      'Plaats' => Text(c.woonplaats ?? '-', style: s11, overflow: TextOverflow.ellipsis),
      'Land' => _landBadge(c.landCode),
      'Telefoon' => Text(c.telefoon ?? c.mobiel ?? '-', style: s11, overflow: TextOverflow.ellipsis),
      'Omzet' => Text(_fmtOmzet(c.totaleOmzet), style: GoogleFonts.dmSans(fontSize: 11, fontWeight: c.totaleOmzet > 1000 ? FontWeight.w700 : FontWeight.w400, color: c.totaleOmzet > 1000 ? _green : const Color(0xFF64748B)), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis),
      'Factuurnr' => _factuurCell(c),
      'Laatste factuur' => Text(_fmtDate(c.laatsteFactuurDatum), style: s11),
      _ => null,
    };
  }

  Widget _factuurCell(Customer c) {
    if (c.factuurNummers.isEmpty) {
      return Text('-', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...c.factuurNummers.take(5).map((nr) => InkWell(
          onTap: () => _openInvoice(nr, c),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(nr, style: GoogleFonts.dmSans(fontSize: 10, color: _accent, decoration: TextDecoration.underline, fontWeight: FontWeight.w600)),
          ),
        )),
        if (c.factuurNummers.length > 5)
          Text('+${c.factuurNummers.length - 5}', style: GoogleFonts.dmSans(fontSize: 9, color: const Color(0xFF94A3B8))),
      ],
    );
  }

  Widget _klantnrCell(Customer c) {
    final codes = <String>[];
    if (c.snelstartKlantcode != null && c.snelstartKlantcode!.isNotEmpty) {
      codes.add(c.snelstartKlantcode!);
    }
    for (final alias in c.klantcodeAliases) {
      if (alias.isNotEmpty && !codes.contains(alias)) codes.add(alias);
    }
    if (codes.isEmpty && c.klantnummer.isNotEmpty) {
      codes.add(c.klantnummer);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(codes.first, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)), overflow: TextOverflow.ellipsis),
        for (final extra in codes.skip(1))
          Text(extra, style: GoogleFonts.dmSans(fontSize: 9, color: const Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  void _openInvoice(String factuurNummer, Customer c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Factuur $factuurNummer — factuurweergave wordt binnenkort toegevoegd'), duration: const Duration(seconds: 2)),
    );
  }

  Widget _tableRow(Customer c, int index, List<_Col> cols) {
    final bg = index.isEven ? Colors.white : const Color(0xFFF8FAFC);
    return InkWell(
      onTap: () => _openDetail(c),
      hoverColor: _accent.withValues(alpha: 0.03),
      child: Container(
        color: bg,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            SizedBox(
              width: cols[0].width,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: c.isZakelijk ? const Color(0xFF6366F1).withValues(alpha: 0.1) : _accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Text(
                      c.displayNaam.isNotEmpty ? c.displayNaam[0].toUpperCase() : '?',
                      style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: c.isZakelijk ? const Color(0xFF6366F1) : _accent),
                    ),
                  ),
                ),
              ),
            ),
            for (int i = 1; i < cols.length; i++)
              _cell(cols[i].width, _cellFor(cols[i].label, c) ?? const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _cell(double width, Widget child) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: child,
      ),
    );
  }

  Widget _landBadge(String code) {
    const flags = <String, String>{
      'NL': '🇳🇱', 'DE': '🇩🇪', 'BE': '🇧🇪', 'GB': '🇬🇧', 'FR': '🇫🇷',
      'IT': '🇮🇹', 'ES': '🇪🇸', 'AT': '🇦🇹', 'CH': '🇨🇭', 'PL': '🇵🇱',
      'IE': '🇮🇪', 'SE': '🇸🇪', 'DK': '🇩🇰', 'NO': '🇳🇴',
    };
    final flag = flags[code];
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (flag != null) ...[Text(flag, style: const TextStyle(fontSize: 12)), const SizedBox(width: 3)],
      Text(code, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
    ]);
  }

  Widget _typeBadge(bool zakelijk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: zakelijk ? const Color(0xFF6366F1).withValues(alpha: 0.08) : const Color(0xFF0EA5E9).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        zakelijk ? 'Zakelijk' : 'Particulier',
        style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: zakelijk ? const Color(0xFF6366F1) : const Color(0xFF0EA5E9)),
      ),
    );
  }

  Widget _buildCardList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _customers.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) {
        final c = _customers[i];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _openDetail(c),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: c.isZakelijk ? const Color(0xFF6366F1).withValues(alpha: 0.1) : _accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        c.displayNaam.isNotEmpty ? c.displayNaam[0].toUpperCase() : '?',
                        style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: c.isZakelijk ? const Color(0xFF6366F1) : _accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(c.displayNaam, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: _navy), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 6),
                            _typeBadge(c.isZakelijk),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          c.email.startsWith('noemail_') ? (c.woonplaats ?? '-') : c.email,
                          style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                        if ((c.snelstartKlantcode ?? c.klantnummer).isNotEmpty)
                          Text(
                            c.snelstartKlantcode ?? c.klantnummer,
                            style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                          ),
                        if (c.totaleOmzet > 0)
                          Text(
                            '${_fmtOmzet(c.totaleOmzet)} · ${c.aantalFacturen} facturen',
                            style: GoogleFonts.dmSans(fontSize: 11, color: _green),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(c.landCode, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
                      if (c.woonplaats != null)
                        Text(c.woonplaats!, style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade300),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Text(
            '${_customers.length} van $_totalCount klanten',
            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          if (_searchCtrl.text.isNotEmpty || _landFilter != null || _zakelijkFilter != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
              child: Text('gefilterd', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF92400E))),
            ),
          ],
          const Spacer(),
          Text(
            'Sorteer: $_sortBy ${_sortAsc ? '↑' : '↓'}',
            style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _Col {
  final String label;
  final double width;
  final String? sortKey;
  const _Col(this.label, this.width, {this.sortKey});
}

class _ColDef {
  final String key;
  final String label;
  const _ColDef(this.key, this.label);
}
