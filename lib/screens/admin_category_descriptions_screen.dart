import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/catalog_product.dart';
import '../services/category_description_service.dart';
import '../services/user_service.dart';

class AdminCategoryDescriptionsScreen extends StatefulWidget {
  const AdminCategoryDescriptionsScreen({super.key});

  @override
  State<AdminCategoryDescriptionsScreen> createState() => _AdminCategoryDescriptionsScreenState();
}

class _AdminCategoryDescriptionsScreenState extends State<AdminCategoryDescriptionsScreen> {
  static const _navy = Color(0xFF0D1B2A);

  final _service = CategoryDescriptionService();
  final _userService = UserService();
  Map<String, CategoryDescription> _descriptions = {};
  bool _loading = true;

  static const _allCategories = [
    'optimist', 'ventoz-laserzeil', 'ventoz-topaz', 'ventoz-splash',
    'beachsailing', 'ventoz-centaur', 'rs-feva', 'valk', 'randmeer',
    'hobie-cat', 'ventoz-420-470-sails', 'efsix', 'sunfish', 'stormfok',
    'open-bic', 'nacra-17', 'yamaha-seahopper', 'mirror', 'fox-22', 'diversen',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final perms = await _userService.getCurrentUserPermissions();
    if (!perms.aboutTekstBewerken && mounted) {
      Navigator.of(context).pop();
      return;
    }
    try {
      await _service.seedDefaults();
      _descriptions = await _service.getAll(forceRefresh: true);
    } catch (e) {
      if (kDebugMode) debugPrint('Load category descriptions error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  String _label(String slug) =>
      CatalogProduct(naam: '', categorie: slug).categorieLabel;

  void _showEditDialog(String slug) {
    final desc = _descriptions[slug];
    final nlCtl = TextEditingController(text: desc?.beschrijvingNl ?? '');
    final enCtl = TextEditingController(text: desc?.beschrijvingEn ?? '');
    final deCtl = TextEditingController(text: desc?.beschrijvingDe ?? '');
    final frCtl = TextEditingController(text: desc?.beschrijvingFr ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(_label(slug), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _langField('Nederlands', nlCtl, required: true),
              const SizedBox(height: 12),
              _langField('English', enCtl),
              const SizedBox(height: 12),
              _langField('Deutsch', deCtl),
              const SizedBox(height: 12),
              _langField('Français', frCtl),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _service.save(CategoryDescription(
                  id: desc?.id,
                  categorie: slug,
                  beschrijvingNl: nlCtl.text.trim(),
                  beschrijvingEn: enCtl.text.trim().isEmpty ? null : enCtl.text.trim(),
                  beschrijvingDe: deCtl.text.trim().isEmpty ? null : deCtl.text.trim(),
                  beschrijvingFr: frCtl.text.trim().isEmpty ? null : frCtl.text.trim(),
                ));
                await _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${_label(slug)} opgeslagen'), backgroundColor: const Color(0xFF2E7D32)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Opslaan mislukt: $e'), backgroundColor: const Color(0xFFEF4444)),
                  );
                }
              }
            },
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );
  }

  Widget _langField(String label, TextEditingController ctl, {bool required = false}) {
    return TextField(
      controller: ctl,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: '$label${required ? ' *' : ' (optioneel)'}',
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/ventoz_logo.png', width: 28, height: 28)),
          const SizedBox(width: 10),
          const Text('Categorieteksten'),
        ]),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _allCategories.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final slug = _allCategories[i];
                final desc = _descriptions[slug];
                final hasText = desc != null && desc.beschrijvingNl.isNotEmpty;
                final translationCount = [desc?.beschrijvingEn, desc?.beschrijvingDe, desc?.beschrijvingFr]
                    .where((t) => t != null && t.isNotEmpty).length;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  leading: Icon(
                    hasText ? Icons.check_circle : Icons.edit_note,
                    color: hasText ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                    size: 22,
                  ),
                  title: Text(_label(slug), style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
                  subtitle: hasText
                      ? Text(
                          desc.beschrijvingNl,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        )
                      : const Text('Nog geen tekst', style: TextStyle(fontSize: 12, color: Color(0xFFE65100))),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (translationCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('$translationCount/${3} talen', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1565C0))),
                      ),
                    const Icon(Icons.edit, size: 18, color: Color(0xFF6B7280)),
                  ]),
                  onTap: () => _showEditDialog(slug),
                );
              },
            ),
    );
  }
}
