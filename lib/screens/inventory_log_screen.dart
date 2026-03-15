import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/inventory_service.dart';
import '../services/sales_channel_service.dart';
import '../services/user_service.dart';

class InventoryLogScreen extends StatefulWidget {
  const InventoryLogScreen({super.key});

  @override
  State<InventoryLogScreen> createState() => _InventoryLogScreenState();
}

class _InventoryLogScreenState extends State<InventoryLogScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _accent = Color(0xFF1B4965);
  static const _pageSize = 50;

  final _inventoryService = InventoryService();
  final _channelService = SalesChannelService();
  final _userService = UserService();
  final _searchCtrl = TextEditingController();

  List<InventoryMutation> _mutations = [];
  List<SalesChannel> _channels = [];
  bool _loading = true;
  int _offset = 0;
  bool _hasMore = true;

  String? _filterType;
  String? _filterChannel;
  DateTime? _filterFrom;
  DateTime? _filterTo;

  @override
  void initState() {
    super.initState();
    _loadChannels();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    _channels = await _channelService.getAll();
    if (mounted) setState(() {});
  }

  Future<void> _load({bool append = false}) async {
    if (!append) {
      _offset = 0;
      setState(() => _loading = true);
      final perms = await _userService.getCurrentUserPermissions();
      if (!mounted) return;
      if (!perms.voorraadBeheren) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geen toegang'), backgroundColor: Color(0xFFEF4444)));
        return;
      }
    }
    final results = await _inventoryService.getAllMutations(
      limit: _pageSize,
      offset: _offset,
      search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      mutatieType: _filterType,
      verkoopkanaalCode: _filterChannel,
      from: _filterFrom,
      to: _filterTo,
    );
    if (mounted) {
      setState(() {
        if (append) {
          _mutations.addAll(results);
        } else {
          _mutations = results;
        }
        _hasMore = results.length >= _pageSize;
        _loading = false;
      });
    }
  }

  void _loadMore() {
    _offset += _pageSize;
    _load(append: true);
  }

  void _resetFilters() {
    _filterType = null;
    _filterChannel = null;
    _filterFrom = null;
    _filterTo = null;
    _searchCtrl.clear();
    _load();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _filterFrom : _filterTo) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _filterFrom = picked;
        } else {
          _filterTo = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Voorraadlog', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilters(),
          const Divider(height: 1),
          _buildTableHeader(),
          Expanded(
            child: _loading && _mutations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _mutations.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('Geen mutaties gevonden', style: GoogleFonts.dmSans(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _mutations.length + (_hasMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i >= _mutations.length) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: ElevatedButton(
                                  onPressed: _loadMore,
                                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                                  child: const Text('Meer laden'),
                                ),
                              ),
                            );
                          }
                          return _buildRow(_mutations[i]);
                        },
                      ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Zoek op productnaam, ordernummer, klant...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _load(); })
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          isDense: true,
        ),
        onSubmitted: (_) => _load(),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip(
              label: _filterType != null ? (InventoryMutation.mutatieTypes[_filterType] ?? _filterType!) : 'Type',
              active: _filterType != null,
              onTap: () => _showTypeFilter(),
            ),
            const SizedBox(width: 8),
            _filterChip(
              label: _filterChannel != null
                  ? (_channels.where((c) => c.code == _filterChannel).firstOrNull?.naam ?? _filterChannel!)
                  : 'Kanaal',
              active: _filterChannel != null,
              onTap: () => _showChannelFilter(),
            ),
            const SizedBox(width: 8),
            _filterChip(
              label: _filterFrom != null ? 'Vanaf ${_fmtDate(_filterFrom!)}' : 'Van datum',
              active: _filterFrom != null,
              onTap: () => _pickDate(true),
            ),
            const SizedBox(width: 8),
            _filterChip(
              label: _filterTo != null ? 'Tot ${_fmtDate(_filterTo!)}' : 'Tot datum',
              active: _filterTo != null,
              onTap: () => _pickDate(false),
            ),
            if (_filterType != null || _filterChannel != null || _filterFrom != null || _filterTo != null) ...[
              const SizedBox(width: 8),
              ActionChip(
                label: const Text('Reset'),
                avatar: const Icon(Icons.clear, size: 16),
                onPressed: _resetFilters,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterChip({required String label, required bool active, required VoidCallback onTap}) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: active ? Colors.white : _navy)),
      selected: active,
      onSelected: (_) => onTap(),
      selectedColor: _accent,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: active ? _accent : const Color(0xFFE8ECF1))),
    );
  }

  void _showTypeFilter() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Mutatietype'),
        children: [
          SimpleDialogOption(
            onPressed: () { Navigator.pop(ctx); setState(() => _filterType = null); _load(); },
            child: const Text('Alle types'),
          ),
          ...InventoryMutation.mutatieTypes.entries.map((e) => SimpleDialogOption(
            onPressed: () { Navigator.pop(ctx); setState(() => _filterType = e.key); _load(); },
            child: Text(e.value),
          )),
        ],
      ),
    );
  }

  void _showChannelFilter() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Verkoopkanaal'),
        children: [
          SimpleDialogOption(
            onPressed: () { Navigator.pop(ctx); setState(() => _filterChannel = null); _load(); },
            child: const Text('Alle kanalen'),
          ),
          ..._channels.map((ch) => SimpleDialogOption(
            onPressed: () { Navigator.pop(ctx); setState(() => _filterChannel = ch.code); _load(); },
            child: Text(ch.naam),
          )),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    const headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B));
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          SizedBox(width: 100, child: Text('Datum', style: headerStyle)),
          SizedBox(width: 10),
          Expanded(flex: 2, child: Text('Product', style: headerStyle)),
          SizedBox(width: 10),
          SizedBox(width: 60, child: Text('Delta', style: headerStyle, textAlign: TextAlign.center)),
          SizedBox(width: 10),
          SizedBox(width: 70, child: Text('Type', style: headerStyle)),
          SizedBox(width: 10),
          SizedBox(width: 80, child: Text('Kanaal', style: headerStyle)),
          SizedBox(width: 10),
          SizedBox(width: 110, child: Text('Order', style: headerStyle)),
          SizedBox(width: 10),
          Expanded(flex: 1, child: Text('Klant', style: headerStyle)),
          SizedBox(width: 10),
          Expanded(flex: 1, child: Text('Reden', style: headerStyle)),
        ],
      ),
    );
  }

  Widget _buildRow(InventoryMutation m) {
    final isPositive = m.hoeveelheidDelta >= 0;
    final deltaColor = isPositive ? const Color(0xFF2E7D32) : const Color(0xFFE53935);
    final deltaPrefix = isPositive ? '+' : '';

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              m.createdAt != null ? _fmtDateTime(m.createdAt!) : '',
              style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.itemVariantLabel ?? '#${m.inventoryItemId}',
                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _navy),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (m.itemKleur != null && m.itemKleur!.isNotEmpty)
                  Text(m.itemKleur!, style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF94A3B8))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: deltaColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$deltaPrefix${m.hoeveelheidDelta}',
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: deltaColor),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(m.mutatieTypeLabel, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B))),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              _channelLabel(m.verkoopkanaalCode),
              style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              m.orderNummer ?? m.externOrderNummer ?? '',
              style: GoogleFonts.dmSans(fontSize: 11, color: _accent),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: Text(
              m.klantNaam ?? '',
              style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: Text(
              m.reden,
              style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text(
            '${_mutations.length} mutaties geladen',
            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Vernieuwen'),
          ),
        ],
      ),
    );
  }

  String _channelLabel(String? code) {
    if (code == null) return '—';
    final ch = _channels.where((c) => c.code == code).firstOrNull;
    return ch?.naam ?? code;
  }

  String _fmtDate(DateTime d) => '${d.day}-${d.month}-${d.year}';
  String _fmtDateTime(DateTime d) => '${d.day}-${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
