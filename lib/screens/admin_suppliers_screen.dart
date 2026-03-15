import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supplier_service.dart';
import '../services/user_service.dart';

class AdminSuppliersScreen extends StatefulWidget {
  const AdminSuppliersScreen({super.key});

  @override
  State<AdminSuppliersScreen> createState() => _AdminSuppliersScreenState();
}

class _AdminSuppliersScreenState extends State<AdminSuppliersScreen> {
  static const _navy = Color(0xFF1E3A5F);

  final SupplierService _service = SupplierService();
  List<SupplierConfig> _suppliers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final perms = await UserService().getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.voorraadBeheren) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
      );
      return;
    }
    final list = await _service.loadSuppliers();
    if (list.isEmpty) {
      list.add(const SupplierConfig(
        name: 'Wilfer',
        websiteUrl: 'https://www.wilfer.de',
      ));
    }
    if (mounted) setState(() { _suppliers = list; _loading = false; });
  }

  Future<void> _save() async {
    try {
      await _service.saveSuppliers(_suppliers);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leveranciers opgeslagen'), backgroundColor: Color(0xFF2E7D32)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opslaan mislukt: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  void _editSupplier(int index) {
    final s = _suppliers[index];
    final nameC = TextEditingController(text: s.name);
    final urlC = TextEditingController(text: s.websiteUrl);
    final userC = TextEditingController(text: s.username);
    final passC = TextEditingController(text: s.password);
    final notesC = TextEditingController(text: s.notes);
    bool showPass = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.name.isEmpty ? 'Nieuwe leverancier' : s.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Naam', hintText: 'bijv. Wilfer')),
                  const SizedBox(height: 8),
                  TextField(controller: urlC, decoration: const InputDecoration(labelText: 'Website URL', hintText: 'https://www.wilfer.de')),
                  const SizedBox(height: 8),
                  TextField(controller: userC, decoration: const InputDecoration(labelText: 'Gebruikersnaam')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passC,
                    obscureText: !showPass,
                    decoration: InputDecoration(
                      labelText: 'Wachtwoord',
                      suffixIcon: IconButton(
                        icon: Icon(showPass ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () => setDialogState(() => showPass = !showPass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: notesC, maxLines: 2, decoration: const InputDecoration(labelText: 'Notities', hintText: 'Optioneel')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
            FilledButton(
              onPressed: () {
                setState(() {
                  _suppliers[index] = SupplierConfig(
                    name: nameC.text.trim(),
                    websiteUrl: urlC.text.trim(),
                    username: userC.text.trim(),
                    password: passC.text,
                    notes: notesC.text.trim(),
                  );
                });
                Navigator.pop(ctx);
                _save();
              },
              child: const Text('Opslaan'),
            ),
          ],
        ),
      ),
    );
  }

  void _addSupplier() {
    setState(() => _suppliers.add(const SupplierConfig()));
    _editSupplier(_suppliers.length - 1);
  }

  void _deleteSupplier(int index) {
    final name = _suppliers[index].name;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leverancier verwijderen?'),
        content: Text('Weet je zeker dat je "$name" wilt verwijderen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              setState(() => _suppliers.removeAt(index));
              Navigator.pop(ctx);
              _save();
            },
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
  }

  Future<void> _openWebsite(SupplierConfig s) async {
    if (s.websiteUrl.isEmpty) return;
    final uri = Uri.tryParse(s.websiteUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leveranciers'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.add), tooltip: 'Leverancier toevoegen', onPressed: _addSupplier),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _suppliers.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.local_shipping_outlined, size: 48, color: Color(0xFFCBD5E1)),
                    const SizedBox(height: 12),
                    const Text('Geen leveranciers geconfigureerd'),
                    const SizedBox(height: 12),
                    FilledButton.icon(onPressed: _addSupplier, icon: const Icon(Icons.add), label: const Text('Toevoegen')),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _suppliers.length,
                  itemBuilder: (ctx, i) => _buildSupplierCard(_suppliers[i], i),
                ),
    );
  }

  Widget _buildSupplierCard(SupplierConfig s, int index) {
    final hasCredentials = s.username.isNotEmpty && s.password.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _navy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.factory_rounded, size: 18, color: _navy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name.isNotEmpty ? s.name : 'Naamloos', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _navy)),
                      if (s.websiteUrl.isNotEmpty)
                        Text(s.websiteUrl, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                if (hasCredentials)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle, size: 12, color: Color(0xFF2E7D32)),
                      SizedBox(width: 3),
                      Text('Inloggegevens', style: TextStyle(fontSize: 10, color: Color(0xFF2E7D32))),
                    ]),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.warning_amber, size: 12, color: Color(0xFFF59E0B)),
                      SizedBox(width: 3),
                      Text('Niet ingesteld', style: TextStyle(fontSize: 10, color: Color(0xFFF59E0B))),
                    ]),
                  ),
              ],
            ),
            if (s.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(s.notes, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontStyle: FontStyle.italic)),
              ),
            const Divider(height: 20),
            Row(
              children: [
                if (s.websiteUrl.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _openWebsite(s),
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('Website openen', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32)),
                  ),
                if (s.websiteUrl.isNotEmpty) const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _editSupplier(index),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Bewerken', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                  tooltip: 'Verwijderen',
                  onPressed: () => _deleteSupplier(index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
