import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/locale_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/review_platforms_service.dart';
import '../services/user_service.dart';

class ReviewPlatformsScreen extends StatefulWidget {
  const ReviewPlatformsScreen({super.key});

  @override
  State<ReviewPlatformsScreen> createState() => _ReviewPlatformsScreenState();
}

class _ReviewPlatformsScreenState extends State<ReviewPlatformsScreen> {
  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC8A85C);

  AppLocalizations get _l => LocaleProvider().l;
  final _service = ReviewPlatformsService();
  final _userService = UserService();

  List<ReviewPlatform> _platforms = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.reviewPlatformsBeheren) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
        );
      }
      return;
    }
    _service.invalidateCache();
    final platforms = await _service.getPlatforms();
    if (mounted) setState(() { _platforms = platforms; _loading = false; });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.savePlatforms(_platforms);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l.t('opgeslagen')), backgroundColor: const Color(0xFF16A34A)),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving review platforms: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l.t('opslaan_mislukt')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addPlatform() {
    setState(() {
      _platforms = [..._platforms, const ReviewPlatform(name: '', url: '')];
    });
  }

  void _removePlatform(int index) {
    setState(() {
      _platforms = [..._platforms]..removeAt(index);
    });
  }

  void _updatePlatform(int index, ReviewPlatform updated) {
    setState(() {
      _platforms = [..._platforms]..[index] = updated;
    });
  }

  static const _iconOptions = <String, (IconData, String)>{
    'star': (Icons.star_rounded, 'Ster'),
    'ebay': (Icons.store, 'Winkel'),
    'shopping': (Icons.shopping_bag, 'Tas'),
    'thumb': (Icons.thumb_up, 'Duim'),
    'verified': (Icons.verified, 'Verificatie'),
    'favorite': (Icons.favorite, 'Hart'),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: Text(_l.t('reviews_beheer'), style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          if (!_loading)
            TextButton.icon(
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 18),
              label: Text(_l.t('opgeslagen').split(' ').first, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(foregroundColor: _gold),
              onPressed: _saving ? null : _save,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _l.t('reviews_beheer_sub'),
                        style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 24),
                      ..._platforms.asMap().entries.map((e) => _buildPlatformEditor(e.key, e.value)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(_l.t('platform_toevoegen'), style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _navy,
                            side: BorderSide(color: _navy.withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _addPlatform,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save, size: 18),
                          label: Text('Opslaan', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 15)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _saving ? null : _save,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPlatformEditor(int index, ReviewPlatform platform) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: _gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(_iconOptions[platform.icon]?.$1 ?? Icons.star, color: _gold, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              platform.name.isEmpty ? '${_l.t('platform_naam')} ${index + 1}' : platform.name,
              style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: _navy),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
            onPressed: () => _removePlatform(index),
            tooltip: _l.t('verwijderen'),
          ),
        ]),
        const SizedBox(height: 16),
        _field(_l.t('platform_naam'), platform.name, (v) => _updatePlatform(index, platform.copyWith(name: v))),
        const SizedBox(height: 12),
        _field(_l.t('platform_url'), platform.url, (v) => _updatePlatform(index, platform.copyWith(url: v))),
        const SizedBox(height: 12),
        _field('Embed URL (optioneel)', platform.embedUrl, (v) => _updatePlatform(index, platform.copyWith(embedUrl: v)),
          hint: 'URL voor inline preview (laat leeg voor standaard)'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _field(_l.t('platform_score'), platform.score, (v) => _updatePlatform(index, platform.copyWith(score: v)))),
          const SizedBox(width: 12),
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<String>(
              initialValue: _iconOptions.containsKey(platform.icon) ? platform.icon : 'star',
              decoration: InputDecoration(
                labelText: 'Icoon',
                labelStyle: GoogleFonts.dmSans(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              items: _iconOptions.entries.map((e) => DropdownMenuItem(
                value: e.key,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(e.value.$1, size: 16, color: _navy),
                  const SizedBox(width: 6),
                  Text(e.value.$2, style: GoogleFonts.dmSans(fontSize: 12)),
                ]),
              )).toList(),
              onChanged: (v) {
                if (v != null) _updatePlatform(index, platform.copyWith(icon: v));
              },
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _field(_l.t('platform_beschrijving'), platform.description, (v) => _updatePlatform(index, platform.copyWith(description: v)), maxLines: 2),
      ]),
    );
  }

  Widget _field(String label, String value, ValueChanged<String> onChanged, {int maxLines = 1, String? hint}) {
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8)),
        labelStyle: GoogleFonts.dmSans(fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      style: GoogleFonts.dmSans(fontSize: 13),
      maxLines: maxLines,
      onChanged: onChanged,
    );
  }
}
