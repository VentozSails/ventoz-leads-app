import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/catalog_product.dart';
import '../services/category_description_service.dart';
import '../services/user_service.dart';
import '../services/web_scraper_service.dart';

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

  void _showTranslateDialog() {
    final withText = _descriptions.entries
        .where((e) => e.value.beschrijvingNl.isNotEmpty)
        .toList();

    final selectedCats = <String>{};
    var catSelectAll = true;
    var translateCategoryTexts = true;
    var translateProductSpecs = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Vertalen naar alle talen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBDEFB)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, size: 18, color: Color(0xFF1565C0)),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'Zeiltermen worden correct vertaald (zeil, fok, grootzeil, voorlijk, etc.).',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1565C0)),
                    )),
                  ]),
                ),
                const SizedBox(height: 16),
                Text('Wat wilt u vertalen?', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: translateCategoryTexts,
                  onChanged: (v) => setDialogState(() => translateCategoryTexts = v ?? true),
                  title: const Text('Categorieteksten', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('${withText.length} categorieën met tekst',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  value: translateProductSpecs,
                  onChanged: (v) => setDialogState(() => translateProductSpecs = v ?? false),
                  title: const Text('Productspecificaties', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Materiaal, inclusief en andere specificatieteksten',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                if (translateCategoryTexts && withText.isNotEmpty) ...[
                  const Divider(height: 16),
                  Text('Categorieselectie', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _navy)),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    value: catSelectAll,
                    onChanged: (v) => setDialogState(() {
                      catSelectAll = v ?? true;
                      if (catSelectAll) selectedCats.clear();
                    }),
                    title: Text('Alle categorieën (${withText.length})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      catSelectAll ? 'Alle categorieteksten worden vertaald' : 'Selecteer specifieke categorieën',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (!catSelectAll) ...[
                    const SizedBox(height: 4),
                    ...withText.map((e) {
                      final count = e.value.beschrijvingen.length;
                      return CheckboxListTile(
                        value: selectedCats.contains(e.key),
                        onChanged: (v) => setDialogState(() {
                          if (v == true) { selectedCats.add(e.key); } else { selectedCats.remove(e.key); }
                        }),
                        title: Text(_label(e.key), style: const TextStyle(fontSize: 13)),
                        subtitle: Text('$count/27 talen', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        contentPadding: const EdgeInsets.only(left: 16),
                      );
                    }),
                  ],
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuleren'),
            ),
            FilledButton.icon(
              onPressed: (!translateCategoryTexts && !translateProductSpecs) ? null : () {
                Navigator.pop(ctx);
                if (translateCategoryTexts && withText.isNotEmpty) {
                  final items = catSelectAll
                      ? withText
                      : withText.where((e) => selectedCats.contains(e.key)).toList();
                  if (items.isNotEmpty) _runTranslation(items, alsoTranslateSpecs: translateProductSpecs);
                } else if (translateProductSpecs) {
                  _runSpecTranslation();
                }
              },
              icon: const Icon(Icons.translate, size: 16),
              label: Text(_translateButtonLabel(translateCategoryTexts, translateProductSpecs, catSelectAll, withText.length, selectedCats.length)),
            ),
          ],
        ),
      ),
    );
  }

  String _translateButtonLabel(bool cats, bool specs, bool allCats, int totalCats, int selectedCount) {
    final parts = <String>[];
    if (cats) parts.add(allCats ? '$totalCats categorieën' : '$selectedCount categorieën');
    if (specs) parts.add('specificaties');
    if (parts.isEmpty) return 'Selecteer teksten';
    return 'Vertalen: ${parts.join(' + ')}';
  }

  Future<void> _runTranslation(List<MapEntry<String, CategoryDescription>> items, {bool alsoTranslateSpecs = false}) async {
    String? currentCat;
    String? currentLang;
    var completed = 0;
    final totalSteps = items.length + (alsoTranslateSpecs ? 1 : 0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> run() async {
            for (final entry in items) {
              if (ctx.mounted) setDialogState(() => currentCat = _label(entry.key));
              try {
                await _service.saveAndTranslate(
                  entry.key,
                  entry.value.beschrijvingNl,
                  onProgress: (lang) {
                    if (ctx.mounted) setDialogState(() => currentLang = lang);
                  },
                );
              } catch (e) {
                if (kDebugMode) debugPrint('Translate ${entry.key} failed: $e');
              }
              completed++;
              if (ctx.mounted) setDialogState(() {});
            }

            if (alsoTranslateSpecs) {
              if (ctx.mounted) setDialogState(() { currentCat = 'Productspecificaties'; currentLang = null; });
              try {
                await _translateAllProductSpecs(onProgress: (lang) {
                  if (ctx.mounted) setDialogState(() => currentLang = lang);
                });
              } catch (e) {
                if (kDebugMode) debugPrint('Translate specs failed: $e');
              }
              completed++;
              if (ctx.mounted) setDialogState(() {});
            }

            if (ctx.mounted) Navigator.pop(ctx);
            await _load();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(alsoTranslateSpecs
                      ? '${items.length} categorieteksten + specificaties vertaald'
                      : '$completed categorieteksten vertaald naar alle talen'),
                  backgroundColor: const Color(0xFF2E7D32),
                ),
              );
            }
          }

          if (currentCat == null) Future.microtask(run);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Vertalen...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              LinearProgressIndicator(value: totalSteps == 0 ? 1 : completed / totalSteps),
              const SizedBox(height: 12),
              if (currentCat != null)
                Text('$currentCat ($completed/$totalSteps)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              if (currentLang != null)
                Text('Vertalen: $currentLang...', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _runSpecTranslation() async {
    String? currentLang;
    var completed = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> run() async {
            try {
              await _translateAllProductSpecs(onProgress: (lang) {
                if (ctx.mounted) setDialogState(() => currentLang = lang);
              });
            } catch (e) {
              if (kDebugMode) debugPrint('Translate specs failed: $e');
            }
            completed = 1;
            if (ctx.mounted) { setDialogState(() {}); Navigator.pop(ctx); }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Productspecificaties vertaald naar alle talen'),
                  backgroundColor: Color(0xFF2E7D32),
                ),
              );
            }
          }

          if (completed == 0) Future.microtask(run);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Specificaties vertalen...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              if (currentLang != null)
                Text('Vertalen: $currentLang...', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _translateAllProductSpecs({void Function(String lang)? onProgress}) async {
    final scraper = WebScraperService();
    final products = await scraper.fetchCatalog();
    for (final p in products) {
      if (p.id == null) continue;
      final mat = p.materiaal;
      final incl = p.inclusief;
      if ((mat == null || mat.isEmpty) && (incl == null || incl.isEmpty)) continue;
      await scraper.translateProductSpecs(
        p.id!,
        materiaal: mat,
        inclusief: incl,
        onProgress: onProgress,
      );
    }
  }

  void _showEditDialog(String slug) {
    final desc = _descriptions[slug];
    final nlCtl = TextEditingController(text: desc?.beschrijvingNl ?? '');
    String? progressLang;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(_label(slug), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _langField('Nederlands (bron)', nlCtl, required: true),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBDEFB)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.translate, size: 18, color: Color(0xFF1565C0)),
                    const SizedBox(width: 8),
                    const Expanded(child: Text(
                      'Na opslaan wordt de tekst automatisch vertaald naar alle 27 talen.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1565C0)),
                    )),
                  ]),
                ),
                if (progressLang != null) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Text('Vertalen: $progressLang...', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ]),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: progressLang != null ? null : () => Navigator.pop(ctx),
              child: const Text('Annuleren'),
            ),
            FilledButton(
              onPressed: progressLang != null ? null : () async {
                final nlText = nlCtl.text.trim();
                if (nlText.isEmpty) return;
                try {
                  await _service.saveAndTranslate(
                    slug,
                    nlText,
                    onProgress: (lang) {
                      if (ctx.mounted) setDialogState(() => progressLang = lang);
                    },
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${_label(slug)} opgeslagen en vertaald naar alle talen'), backgroundColor: const Color(0xFF2E7D32)),
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) setDialogState(() => progressLang = null);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opslaan mislukt: $e'), backgroundColor: const Color(0xFFEF4444)),
                    );
                  }
                }
              },
              child: const Text('Opslaan & vertalen'),
            ),
          ],
        ),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.translate),
            tooltip: 'Vertalen naar alle talen',
            onPressed: _showTranslateDialog,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
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
                final translationCount = desc?.beschrijvingen.length ?? 0;

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
                        child: Text('$translationCount/27 talen', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1565C0))),
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
