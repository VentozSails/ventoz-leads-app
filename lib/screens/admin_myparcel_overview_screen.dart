import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/myparcel_service.dart';
import '../services/user_service.dart';

class AdminMyParcelOverviewScreen extends StatefulWidget {
  const AdminMyParcelOverviewScreen({super.key});

  @override
  State<AdminMyParcelOverviewScreen> createState() => _AdminMyParcelOverviewScreenState();
}

class _AdminMyParcelOverviewScreenState extends State<AdminMyParcelOverviewScreen> {
  static const _navy = Color(0xFF1B2A4A);

  final _myparcel = MyParcelService();
  final _userService = UserService();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _shipments = [];
  bool _loading = true;
  String _statusFilter = '';
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (!append) setState(() { _loading = true; _page = 1; });
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.zendingenOverzicht) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
        );
      }
      return;
    }
    final results = await _myparcel.getShipments(
      page: _page,
      size: 50,
      statusFilter: _statusFilter.isEmpty ? null : _statusFilter,
      query: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      if (append) {
        _shipments.addAll(results);
      } else {
        _shipments = results;
      }
      _hasMore = results.length >= 50;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MyParcel Zendingen', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
        _buildFilters(),
        Expanded(child: _shipments.isEmpty
                ? const Center(child: Text('Geen zendingen gevonden', style: TextStyle(color: Color(0xFF64748B))))
                : _buildList(),
        ),
      ]),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: const Color(0xFFF8FAFB),
      child: Row(children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Zoeken (naam, barcode, referentie)...',
              prefixIcon: const Icon(Icons.search, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(fontSize: 13),
            onSubmitted: (_) => _load(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _statusFilter,
            decoration: InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            items: [
              const DropdownMenuItem(value: '', child: Text('Alle statussen')),
              ...MyParcelService.shipmentStatuses.entries.map((e) =>
                DropdownMenuItem(value: '${e.key}', child: Text(e.value)),
              ),
            ],
            onChanged: (v) {
              _statusFilter = v ?? '';
              _load();
            },
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Vernieuwen',
          onPressed: _load,
        ),
      ]),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _shipments.length + (_hasMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _shipments.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: ElevatedButton(
              onPressed: () { _page++; _load(append: true); },
              child: const Text('Meer laden'),
            )),
          );
        }
        return _buildShipmentCard(_shipments[i]);
      },
    );
  }

  Widget _buildShipmentCard(Map<String, dynamic> s) {
    final id = s['id'] as num?;
    final barcode = s['barcode'] as String? ?? '';
    final ref = s['reference_identifier'] as String? ?? '';
    final statusCode = (s['status'] as num?)?.toInt() ?? 0;
    final statusText = MyParcelService.shipmentStatuses[statusCode] ?? 'Onbekend ($statusCode)';
    final created = s['created'] as String? ?? '';
    final carrierId = (s['carrier_id'] as num?)?.toInt() ?? 0;
    final carrierName = MyParcelService.carriers[carrierId] ?? 'Carrier $carrierId';

    final recipient = s['recipient'] as Map<String, dynamic>?;
    final personName = recipient?['person'] as String? ?? '';
    final city = recipient?['city'] as String? ?? '';
    final postalCode = recipient?['postal_code'] as String? ?? '';

    final options = s['options'] as Map<String, dynamic>?;
    final packageType = (options?['package_type'] as num?)?.toInt() ?? 1;
    final packageTypeName = MyParcelService.packageTypes[packageType] ?? 'Pakket';

    final statusColor = _statusColor(statusCode);
    final isConcept = statusCode == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(6)),
              child: Text(carrierName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1565C0))),
            ),
            const SizedBox(width: 8),
            Text(packageTypeName, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const Spacer(),
            Text(created.length >= 10 ? created.substring(0, 10) : created,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            if (personName.isNotEmpty) ...[
              const Icon(Icons.person, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(personName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
            ],
            if (city.isNotEmpty || postalCode.isNotEmpty) ...[
              const Icon(Icons.location_on, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text('$postalCode $city'.trim(), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ]),
          const SizedBox(height: 4),
          Row(children: [
            if (barcode.isNotEmpty) ...[
              const Icon(Icons.qr_code, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              SelectableText(barcode, style: GoogleFonts.robotoMono(fontSize: 12, color: _navy)),
              const SizedBox(width: 12),
            ],
            if (ref.isNotEmpty) ...[
              const Icon(Icons.tag, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(ref, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
            const Spacer(),
            if (id != null) Text('ID: $id', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ]),
          if (isConcept && id != null) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFE53935)),
                label: const Text('Concept verwijderen', style: TextStyle(fontSize: 11, color: Color(0xFFE53935))),
                onPressed: () => _deleteConcept(id.toInt()),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Color _statusColor(int status) {
    return switch (status) {
      1 || 30 => const Color(0xFF78909C),
      2 || 31 => const Color(0xFF1565C0),
      3 || 4 || 5 || 32 || 33 || 34 => const Color(0xFF0277BD),
      6 || 35 => const Color(0xFFE65100),
      7 || 9 || 19 || 36 || 38 => const Color(0xFF2E7D32),
      8 || 10 || 37 => const Color(0xFF00897B),
      11 => const Color(0xFF558B2F),
      12 || 14 || 15 || 18 => const Color(0xFF5C6BC0),
      13 => const Color(0xFF6A1B9A),
      16 || 17 => const Color(0xFFE53935),
      _ => const Color(0xFF9E9E9E),
    };
  }

  Future<void> _deleteConcept(int shipmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Concept verwijderen?', style: TextStyle(fontSize: 16)),
        content: const Text('Dit concept wordt definitief verwijderd uit MyParcel.'),
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
    if (confirmed != true) return;

    final ok = await _myparcel.deleteShipment(shipmentId);
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Concept verwijderd'), backgroundColor: Color(0xFF43A047),
        ));
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Verwijderen mislukt — mogelijk is het label al gegenereerd'),
          backgroundColor: Color(0xFFE65100),
        ));
      }
    }
  }
}
