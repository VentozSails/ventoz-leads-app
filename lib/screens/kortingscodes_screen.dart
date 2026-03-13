import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/kortingscode.dart';
import '../services/kortingscodes_service.dart';
import '../services/user_service.dart';

class KortingscodesScreen extends StatefulWidget {
  const KortingscodesScreen({super.key});

  @override
  State<KortingscodesScreen> createState() => _KortingscodesScreenState();
}

class _KortingscodesScreenState extends State<KortingscodesScreen> {
  final KortingscodesService _service = KortingscodesService();
  final _userService = UserService();
  List<Kortingscode> _codes = [];
  List<Kortingscode> _filtered = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.kortingscodesBeheren) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
        );
      }
      return;
    }
    try {
      final list = await _service.fetchAll();
      if (mounted) {
        setState(() {
          _codes = list;
          _applyFilter();
          _loading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading kortingscodes: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laden mislukt. Probeer het opnieuw.')),
        );
      }
    }
  }

  void _applyFilter() {
    if (_search.isEmpty) {
      _filtered = List.of(_codes);
    } else {
      final q = _search.toLowerCase();
      _filtered = _codes.where((k) =>
          k.code.toLowerCase().contains(q) ||
          k.productNamen.toLowerCase().contains(q)).toList();
    }
  }

  Future<void> _toggleActief(Kortingscode k) async {
    try {
      await _service.update(k.id!, actief: !k.actief);
      _load();
    } catch (e) {
      if (kDebugMode) debugPrint('Error toggling kortingscode: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Actie mislukt. Probeer het opnieuw.')));
      }
    }
  }

  Future<void> _editCode(Kortingscode k) async {
    final codeCtrl = TextEditingController(text: k.code);
    final percentCtrl = TextEditingController(text: k.kortingspercentage.toString());
    final proefCtrl = TextEditingController(text: k.proefperiodeDagen.toString());
    DateTime? geldigTot = k.geldigTot;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Code bewerken'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Kortingscode'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: percentCtrl,
                  decoration: const InputDecoration(labelText: 'Kortingspercentage (%)', suffixText: '%'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: proefCtrl,
                  decoration: const InputDecoration(labelText: 'Proefperiode (dagen)'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        geldigTot != null
                            ? 'Geldig tot: ${geldigTot!.day}-${geldigTot!.month}-${geldigTot!.year}'
                            : 'Geldig tot: Onbeperkt',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: geldigTot ?? DateTime.now().add(const Duration(days: 90)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) setDialogState(() => geldigTot = d);
                      },
                      child: const Text('Kies datum', style: TextStyle(fontSize: 12)),
                    ),
                    if (geldigTot != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () => setDialogState(() => geldigTot = null),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, {
                'code': codeCtrl.text.trim(),
                'percentage': int.tryParse(percentCtrl.text) ?? k.kortingspercentage,
                'proef': int.tryParse(proefCtrl.text) ?? k.proefperiodeDagen,
                'geldig_tot': geldigTot,
                'clear_geldig_tot': geldigTot == null && k.geldigTot != null,
              }),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
              child: const Text('Opslaan'),
            ),
          ],
        ),
      ),
    );

    codeCtrl.dispose();
    percentCtrl.dispose();
    proefCtrl.dispose();

    if (result == null) return;
    try {
      await _service.update(
        k.id!,
        code: result['code'] != k.code ? result['code'] as String : null,
        kortingspercentage: result['percentage'] as int,
        proefperiodeDagen: result['proef'] as int,
        geldigTot: result['geldig_tot'] as DateTime?,
        clearGeldigTot: result['clear_geldig_tot'] as bool,
      );
      _load();
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating kortingscode: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opslaan mislukt. Probeer het opnieuw.')));
      }
    }
  }

  Future<void> _deleteCode(Kortingscode k) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Code verwijderen?'),
        content: Text('Weet je zeker dat je "${k.code}" wilt verwijderen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _service.delete(k.id!);
        _load();
      } catch (e) {
        if (kDebugMode) debugPrint('Error deleting kortingscode: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verwijderen mislukt. Probeer het opnieuw.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF37474F),
        foregroundColor: Colors.white,
        title: const Text('Kortingscodes'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Vernieuwen', onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Zoek op code of product...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) {
                setState(() {
                  _search = v;
                  _applyFilter();
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_filtered.length} code${_filtered.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const Spacer(),
                Text(
                  '${_codes.where((k) => k.actief).length} actief',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_offer_outlined, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              _search.isNotEmpty ? 'Geen resultaten' : 'Nog geen kortingscodes',
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                            ),
                            if (_search.isEmpty)
                              Text(
                                'Codes worden automatisch aangemaakt bij het selecteren van producten',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _buildCodeCard(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeCard(Kortingscode k) {
    final isExpired = k.geldigTot != null && k.geldigTot!.isBefore(DateTime.now());

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: !k.actief || isExpired ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
      ),
      color: !k.actief || isExpired ? const Color(0xFFFEF2F2) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: k.actief && !isExpired ? const Color(0xFFFFF8E1) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: k.actief && !isExpired ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                  ),
                  child: Text(
                    k.code,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: k.actief && !isExpired ? const Color(0xFF78350F) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!k.actief)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(4)),
                    child: const Text('Inactief', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                if (isExpired && k.actief)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(4)),
                    child: const Text('Verlopen', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'Kopieer code',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: k.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code gekopieerd'), duration: Duration(seconds: 2)),
                    );
                  },
                ),
                IconButton(icon: const Icon(Icons.edit_outlined, size: 16), tooltip: 'Bewerk code', onPressed: () => _editCode(k)),
                IconButton(
                  icon: Icon(k.actief ? Icons.toggle_on : Icons.toggle_off, size: 28, color: k.actief ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)),
                  tooltip: k.actief ? 'Deactiveren' : 'Activeren',
                  onPressed: () => _toggleActief(k),
                ),
                IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)), tooltip: 'Verwijderen', onPressed: () => _deleteCode(k)),
              ],
            ),
            const SizedBox(height: 8),
            Text(k.productNamen, style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _detailChip(Icons.percent, '${k.kortingspercentage}% korting'),
                _detailChip(Icons.timer_outlined, 'Proef: ${k.proefperiodeLabel}'),
                _detailChip(
                  Icons.event,
                  'Geldig tot: ${k.geldigTotLabel}',
                  color: isExpired ? const Color(0xFFEF4444) : null,
                ),
              ],
            ),
            if (k.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Aangemaakt: ${k.createdAt!.day}-${k.createdAt!.month}-${k.createdAt!.year}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String text, {Color? color}) {
    final c = color ?? const Color(0xFF64748B);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
