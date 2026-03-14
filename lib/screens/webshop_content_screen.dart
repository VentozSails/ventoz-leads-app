import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_service.dart';

class WebshopContentScreen extends StatefulWidget {
  const WebshopContentScreen({super.key});

  @override
  State<WebshopContentScreen> createState() => _WebshopContentScreenState();
}

class _WebshopContentScreenState extends State<WebshopContentScreen> {
  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC8A85C);

  final _userService = UserService();
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  bool _saving = false;

  final _heroTitleCtrl = TextEditingController();
  final _heroSubtitleCtrl = TextEditingController();

  final Map<String, TextEditingController> _uspControllers = {};

  static const _uspKeys = [
    'freeShipping', 'freeShippingSub',
    'euShipping', 'euShippingSub',
    'inStock', 'inStockSub',
    'quality', 'qualitySub',
  ];

  static const _uspLabels = {
    'freeShipping': 'USP 1 - Titel',
    'freeShippingSub': 'USP 1 - Subtekst',
    'euShipping': 'USP 2 - Titel',
    'euShippingSub': 'USP 2 - Subtekst',
    'inStock': 'USP 3 - Titel',
    'inStockSub': 'USP 3 - Subtekst',
    'quality': 'USP 4 - Titel',
    'qualitySub': 'USP 4 - Subtekst',
  };

  @override
  void initState() {
    super.initState();
    for (final key in _uspKeys) {
      _uspControllers[key] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    _heroTitleCtrl.dispose();
    _heroSubtitleCtrl.dispose();
    for (final c in _uspControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final isAdmin = await _userService.isCurrentUserAdmin();
    if (!mounted) return;
    if (!isAdmin) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen toegang'), backgroundColor: Color(0xFFE53935)),
      );
      return;
    }

    try {
      final heroRes = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', 'webshop_hero')
          .maybeSingle();

      if (heroRes != null && heroRes['value'] != null) {
        final hero = heroRes['value'] as Map<String, dynamic>;
        _heroTitleCtrl.text = hero['title'] ?? '';
        _heroSubtitleCtrl.text = hero['subtitle'] ?? '';
      }

      final uspRes = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', 'webshop_usp')
          .maybeSingle();

      if (uspRes != null && uspRes['value'] != null) {
        final usp = uspRes['value'] as Map<String, dynamic>;
        for (final key in _uspKeys) {
          _uspControllers[key]?.text = (usp[key] ?? '') as String;
        }
      }
    } catch (_) {
      // defaults remain empty
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      final heroData = {
        'title': _heroTitleCtrl.text.trim(),
        'subtitle': _heroSubtitleCtrl.text.trim(),
      };
      await _supabase.from('app_settings').upsert({
        'key': 'webshop_hero',
        'value': heroData,
      }, onConflict: 'key');

      final uspData = <String, String>{};
      for (final key in _uspKeys) {
        uspData[key] = _uspControllers[key]?.text.trim() ?? '';
      }
      await _supabase.from('app_settings').upsert({
        'key': 'webshop_usp',
        'value': uspData,
      }, onConflict: 'key');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Webshop content opgeslagen'), backgroundColor: Color(0xFF2E7D32)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opslaan mislukt: $e'), backgroundColor: const Color(0xFFE53935)),
        );
      }
    }

    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Webshop Content', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          if (!_loading)
            TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(_saving ? 'Opslaan...' : 'Opslaan',
                  style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Hero Banner', Icons.image),
                  const SizedBox(height: 12),
                  _buildTextField('Hero Titel', _heroTitleCtrl, 'Bijv. Premium One Design Sails'),
                  const SizedBox(height: 10),
                  _buildTextField('Hero Subtekst', _heroSubtitleCtrl, 'Bijv. European sail brand from the Netherlands', maxLines: 3),

                  const SizedBox(height: 30),
                  _sectionTitle('USP-teksten', Icons.star),
                  const SizedBox(height: 8),
                  Text('Laat leeg om de standaard vertalingen te gebruiken.',
                      style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 12),

                  for (final key in _uspKeys) ...[
                    _buildTextField(_uspLabels[key] ?? key, _uspControllers[key]!, ''),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: _gold),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _navy)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          style: GoogleFonts.dmSans(fontSize: 13),
        ),
      ],
    );
  }
}
