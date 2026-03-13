import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/inventory_service.dart';
import '../services/user_service.dart';

class SailInventoryScreen extends StatefulWidget {
  const SailInventoryScreen({super.key});

  static const routeName = '/dashboard/zeil-voorraad';

  @override
  State<SailInventoryScreen> createState() => _SailInventoryScreenState();
}

class _SailInventoryScreenState extends State<SailInventoryScreen>
    with SingleTickerProviderStateMixin {
  static const _navy = Color(0xFF1E3A5F);
  static const _teal = Color(0xFF00897B);

  final InventoryService _inventoryService = InventoryService();
  final UserService _userService = UserService();

  List<SailNumberLetter> _items = [];
  bool _loading = true;
  String? _error;
  late TabController _tabController;

  static const List<String> _nummerWaarden = [
    '0', '1', '2', '3', '4', '5', '6/9', '7', '8',
  ];

  static const List<String> _letterWaarden = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'K', 'L',
    'N', 'P', 'R', 'S', 'T', 'U', 'W', 'Y', '0',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final perms = await _userService.getCurrentUserPermissions();
      if (!perms.voorraadBeheren) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Geen toegang'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
        return;
      }

      final items = await _inventoryService.getAllSailItems();
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SailInventoryScreen load error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Laden mislukt. Probeer het opnieuw.';
        });
      }
    }
  }

  SailNumberLetter? _findItem(String type, String waarde, int maatMm) {
    for (final item in _items) {
      if (item.maatMm != maatMm) continue;
      final itemWaarde = item.waarde;
      if (item.type == type && itemWaarde == waarde) return item;
      if (waarde == '6/9' && item.type == 'nummer' &&
          (itemWaarde == '6' || itemWaarde == '9' || itemWaarde == '6/9')) {
        return item;
      }
      if (waarde == '0' && type == 'letter' &&
          ((item.type == 'nummer' && itemWaarde == '0') ||
              (item.type == 'letter' && (itemWaarde == '0' || itemWaarde == 'O')))) {
        return item;
      }
    }
    return null;
  }

  int _getStockFor(String type, String waarde, int maatMm) {
    return _findItem(type, waarde, maatMm)?.voorraad ?? 0;
  }

  int? _getIdFor(String type, String waarde, int maatMm) {
    return _findItem(type, waarde, maatMm)?.id;
  }

  int _totaal(List<String> waarden, String type, int maatMm) =>
      waarden.fold(0, (s, w) => s + _getStockFor(type, w, maatMm));

  Color _stockColor(int stock) {
    if (stock >= 10) return const Color(0xFF22C55E);
    if (stock >= 5) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Future<void> _quickAdjust(int id, int delta) async {
    final item = _items.firstWhere((i) => i.id == id);
    final newStock = (item.voorraad + delta).clamp(0, 9999);
    try {
      await _inventoryService.updateSailStock(id, newStock);
      if (mounted) {
        setState(() {
          final idx = _items.indexWhere((i) => i.id == id);
          if (idx >= 0) {
            _items[idx] = SailNumberLetter(
              id: _items[idx].id,
              type: _items[idx].type,
              waarde: _items[idx].waarde,
              maatMm: _items[idx].maatMm,
              voorraad: newStock,
              opmerking: _items[idx].opmerking,
            );
          }
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SailInventoryScreen quickAdjust error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  void _showManualCorrectionDialog({
    required String displayLabel,
    required int currentStock,
    required int? itemId,
    required int maatMm,
  }) {
    final newStockCtrl = TextEditingController(text: currentStock.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(displayLabel, style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
          ),
          const SizedBox(width: 10),
          Text('Voorraad aanpassen', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('$maatMm mm Bainbridge', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              Text('Huidige voorraad: $currentStock', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              TextField(
                controller: newStockCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Nieuwe voorraad',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () async {
              final newStock = int.tryParse(newStockCtrl.text);
              if (newStock == null || newStock < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Voer een geldig getal in.'), backgroundColor: Color(0xFFEF4444)),
                );
                return;
              }
              Navigator.pop(ctx);
              if (itemId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item niet gevonden in database.'), backgroundColor: Color(0xFFEF4444)),
                );
                return;
              }
              try {
                await _inventoryService.updateSailStock(itemId, newStock);
                if (!mounted) return;
                await _loadData();
              } catch (e) {
                if (kDebugMode) debugPrint('SailInventoryScreen manual correction error: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Fout: $e'), backgroundColor: const Color(0xFFEF4444)),
                  );
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

  Widget _buildSizeTab(int maatMm) {
    final nummersTotal = _totaal(_nummerWaarden, 'nummer', maatMm);
    final lettersTotal = _totaal(_letterWaarden, 'letter', maatMm);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            _summaryCard('Totaal nummers', nummersTotal, Icons.tag),
            const SizedBox(width: 12),
            _summaryCard('Totaal letters', lettersTotal, Icons.abc),
            const SizedBox(width: 12),
            _summaryCard('Totaal', nummersTotal + lettersTotal, Icons.inventory_2),
          ]),
          const SizedBox(height: 24),
          _buildSectionTable('Zeilnummers (0\u20139)', _nummerWaarden, 'nummer', maatMm, nummersTotal),
          const SizedBox(height: 24),
          _buildSectionTable('Zeilletters', _letterWaarden, 'letter', maatMm, lettersTotal),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, int value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: _navy.withValues(alpha: 0.5)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            Text('$value', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: _navy)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildSectionTable(String title, List<String> waarden, String type, int maatMm, int total) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              Text(title, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: _navy)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Totaal: $total', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _teal)),
              ),
            ]),
          ),
          DataTable(
            columnSpacing: 16,
            horizontalMargin: 16,
            headingRowHeight: 36,
            dataRowMinHeight: 42,
            dataRowMaxHeight: 42,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFB)),
            columns: const [
              DataColumn(label: Text('Teken', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Voorraad', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)), numeric: true),
              DataColumn(label: Text('', style: TextStyle(fontSize: 12))),
              DataColumn(label: Text('', style: TextStyle(fontSize: 12))),
            ],
            rows: waarden.map((w) {
              final stock = _getStockFor(type, w, maatMm);
              final itemId = _getIdFor(type, w, maatMm);
              final color = _stockColor(stock);

              return DataRow(cells: [
                DataCell(Container(
                  width: 36, height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(w, style: GoogleFonts.dmSans(
                    fontSize: w.length > 2 ? 12 : 16,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                  )),
                )),
                DataCell(Text(
                  '$stock',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
                )),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  _stepperButton(Icons.remove, const Color(0xFFEF4444),
                      itemId != null && stock > 0 ? () => _quickAdjust(itemId, -1) : null),
                  const SizedBox(width: 4),
                  _stepperButton(Icons.add, const Color(0xFF22C55E),
                      itemId != null ? () => _quickAdjust(itemId, 1) : null),
                ])),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                    tooltip: 'Handmatig aanpassen',
                    onPressed: () => _showManualCorrectionDialog(
                      displayLabel: w,
                      currentStock: stock,
                      itemId: itemId,
                      maatMm: maatMm,
                    ),
                  ),
                ),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _stepperButton(IconData icon, Color color, VoidCallback? onPressed) {
    return SizedBox(
      width: 28, height: 28,
      child: IconButton(
        icon: Icon(icon, size: 16),
        color: color,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Zeilnummers & -letters', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Vernieuwen', onPressed: _loadData),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: '230 mm Bainbridge'),
            Tab(text: '300 mm Bainbridge'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Color(0xFF64748B))),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadData, child: const Text('Opnieuw laden')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSizeTab(230),
                    _buildSizeTab(300),
                  ],
                ),
    );
  }
}
