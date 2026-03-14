import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/legal_text_service.dart';
import '../services/user_service.dart';
import '../services/translate_service.dart';

class LegalTextScreen extends StatefulWidget {
  const LegalTextScreen({super.key});

  @override
  State<LegalTextScreen> createState() => _LegalTextScreenState();
}

class _LegalTextScreenState extends State<LegalTextScreen> {
  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC8A85C);

  final _service = LegalTextService();
  final _userService = UserService();
  final _controller = TextEditingController();

  String _selectedKey = LegalTextService.pages.keys.first;
  Map<String, String> _translations = {};
  bool _loading = true;
  bool _saving = false;
  bool _seeding = false;
  String? _progressLang;

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAccessAndLoad() async {
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.aboutTekstBewerken) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
      );
      return;
    }
    await _loadPage(_selectedKey);
  }

  Future<void> _loadPage(String key) async {
    setState(() { _loading = true; });
    _service.invalidateCache(key);
    final texts = await _service.getTexts(key);
    if (!mounted) return;
    setState(() {
      _selectedKey = key;
      _translations = Map.from(texts);
      _controller.text = texts['nl'] ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    final nlText = _controller.text.trim();
    if (nlText.isEmpty) return;

    setState(() { _saving = true; _progressLang = null; });
    try {
      await _service.saveAndTranslate(
        _selectedKey,
        nlText,
        onProgress: (lang) {
          if (mounted) setState(() => _progressLang = lang);
        },
      );
      final texts = await _service.getTexts(_selectedKey);
      if (mounted) {
        setState(() {
          _translations = Map.from(texts);
          _saving = false;
          _progressLang = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${LegalTextService.pages[_selectedKey]} opgeslagen en vertaald naar alle talen'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving legal text: $e');
      if (mounted) {
        setState(() { _saving = false; _progressLang = null; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opslaan mislukt. Probeer het opnieuw.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _seedAll() async {
    setState(() { _seeding = true; });
    try {
      await _service.seedAllPages(
        onProgress: (key, lang) {
          if (mounted) {
            setState(() => _progressLang = '${LegalTextService.pages[key]} → $lang');
          }
        },
      );
      if (mounted) {
        setState(() { _seeding = false; _progressLang = null; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alle legal pagina\'s aangemaakt en vertaald!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        await _loadPage(_selectedKey);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error seeding: $e');
      if (mounted) {
        setState(() { _seeding = false; _progressLang = null; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seed mislukt. Probeer het opnieuw.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: Text('Legal pagina\'s', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          if (!_seeding)
            IconButton(
              icon: const Icon(Icons.auto_fix_high, size: 20),
              tooltip: 'Alle pagina\'s vullen (seed)',
              onPressed: _saving ? null : _seedAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_seeding) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFD966)),
                        ),
                        child: Row(children: [
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(
                            _progressLang != null ? 'Bezig: $_progressLang...' : 'Pagina\'s vullen en vertalen...',
                            style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF856404)),
                          )),
                        ]),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Text(
                      'Selecteer een pagina, pas de Nederlandse tekst aan en sla op. '
                      'Na opslaan wordt de tekst automatisch vertaald naar alle ondersteunde talen.',
                      style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF64748B), height: 1.5),
                    ),
                    const SizedBox(height: 16),

                    // Page selector
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedKey,
                          items: LegalTextService.pages.entries.map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
                          )).toList(),
                          onChanged: _saving || _seeding ? null : (key) {
                            if (key != null && key != _selectedKey) _loadPage(key);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Editor
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: _navy.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(4)),
                            child: Text('NL', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: _navy)),
                          ),
                          const SizedBox(width: 8),
                          Text('Nederlandse brontekst', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
                        ]),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _controller,
                          maxLines: 18,
                          decoration: InputDecoration(
                            hintText: 'Voer hier de tekst in...',
                            hintStyle: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.all(14),
                          ),
                          style: GoogleFonts.dmSans(fontSize: 13, height: 1.6),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tip: gebruik lege regels (enter 2x) voor alinea-scheiding.',
                          style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.translate, size: 18),
                        label: Text(
                          _saving
                              ? (_progressLang != null
                                  ? 'Vertalen naar ${TranslateService.languageLabels[_progressLang] ?? _progressLang}...'
                                  : 'Opslaan...')
                              : 'Opslaan en vertalen naar alle talen',
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _saving || _seeding ? null : _save,
                      ),
                    ),

                    if (_translations.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Text('Vertalingen', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: _navy)),
                      const SizedBox(height: 4),
                      Text(
                        '${_translations.length} talen beschikbaar',
                        style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 12),
                      ..._sortedTranslations().map((e) => _translationCard(e.key, e.value)),
                    ],
                  ]),
                ),
              ),
            ),
    );
  }

  List<MapEntry<String, String>> _sortedTranslations() {
    const order = ['nl', 'en', 'de', 'fr', 'es', 'it'];
    final entries = _translations.entries.toList();
    entries.sort((a, b) {
      final ai = order.indexOf(a.key);
      final bi = order.indexOf(b.key);
      if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
      if (ai >= 0) return -1;
      if (bi >= 0) return 1;
      return a.key.compareTo(b.key);
    });
    return entries;
  }

  Widget _translationCard(String lang, String text) {
    final label = TranslateService.languageLabels[lang] ?? lang;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: lang == 'nl' ? _gold.withValues(alpha: 0.15) : _navy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              lang.toUpperCase(),
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: lang == 'nl' ? _gold : _navy),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _navy)),
          if (lang == 'nl') ...[
            const SizedBox(width: 6),
            Text('(bron)', style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF94A3B8))),
          ],
        ]),
        const SizedBox(height: 8),
        Text(text, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF475569), height: 1.5), maxLines: 8, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
