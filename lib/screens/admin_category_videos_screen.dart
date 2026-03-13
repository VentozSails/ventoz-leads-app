import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/category_video_service.dart';
import '../services/user_service.dart';
import '../services/web_scraper_service.dart';
import '../models/catalog_product.dart';

class AdminCategoryVideosScreen extends StatefulWidget {
  const AdminCategoryVideosScreen({super.key});

  @override
  State<AdminCategoryVideosScreen> createState() => _AdminCategoryVideosScreenState();
}

class _AdminCategoryVideosScreenState extends State<AdminCategoryVideosScreen> {
  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC8A85C);

  final _videoService = CategoryVideoService();
  final _userService = UserService();
  Map<String, CategoryVideo> _videos = {};
  List<String> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.categoryVideosBeheren) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
        );
      }
      return;
    }
    try {
      final products = await WebScraperService().fetchCatalog();
      final cats = <String>{};
      for (final p in products) {
        if (p.categorie != null && !p.geblokkeerd) cats.add(p.categorie!);
      }
      Map<String, CategoryVideo> videos = {};
      try {
        videos = await _videoService.getVideos(forceRefresh: true);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _videos = videos;
          _categories = cats.toList()..sort();
          _loading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading category videos: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Laden mislukt. Probeer het opnieuw.'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _editVideo(String category) async {
    final existing = _videos[category];
    final urlCtrl = TextEditingController(text: existing?.youtubeUrl ?? '');
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final label = CatalogProduct(naam: '', categorie: category).categorieLabel;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.play_circle_fill, color: Colors.red.shade600, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Video voor $label',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ]),
            const SizedBox(height: 20),
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: 'YouTube URL',
                hintText: 'https://www.youtube.com/watch?v=...',
                isDense: true,
                prefixIcon: Icon(Icons.link, size: 18, color: Colors.grey.shade500),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: GoogleFonts.dmSans(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: 'Titel (optioneel)',
                hintText: 'Bijv. "Optimist zeil review"',
                isDense: true,
                prefixIcon: Icon(Icons.title, size: 18, color: Colors.grey.shade500),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: GoogleFonts.dmSans(fontSize: 13),
            ),
            if (existing != null && existing.thumbnailUrl != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: Image.network(existing.thumbnailUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink()),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(children: [
              if (existing != null)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'DELETE'),
                  child: Text('Verwijderen', style: TextStyle(color: Colors.red.shade600)),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuleren'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, 'SAVE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Opslaan'),
              ),
            ]),
          ]),
        ),
      ),
    );

    if (result == 'SAVE' && urlCtrl.text.trim().isNotEmpty) {
      setState(() => _loading = true);
      try {
        await _videoService.saveVideo(
          category: category,
          youtubeUrl: urlCtrl.text.trim(),
          title: titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim(),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('Error saving video: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Opslaan mislukt. Probeer het opnieuw.'), backgroundColor: Colors.red.shade700),
          );
        }
      }
      await _load();
    } else if (result == 'DELETE') {
      setState(() => _loading = true);
      try {
        await _videoService.deleteVideo(category);
      } catch (e) {
        if (kDebugMode) debugPrint('Error deleting video: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Verwijderen mislukt. Probeer het opnieuw.'), backgroundColor: Colors.red.shade700),
          );
        }
      }
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: Text("Video's per categorie", style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Koppel YouTube-video's aan categorieën. De video wordt getoond onder de producten in het assortiment.",
                            style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF475569), height: 1.4),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    ..._categories.map(_buildCategoryRow),
                  ]),
                ),
              ),
            ),
    );
  }

  Widget _buildCategoryRow(String category) {
    final video = _videos[category];
    final label = CatalogProduct(naam: '', categorie: category).categorieLabel;
    final hasVideo = video != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasVideo ? _gold.withValues(alpha: 0.4) : const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: () => _editVideo(category),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: hasVideo ? Colors.red.shade50 : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: hasVideo
                  ? (video.thumbnailUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(children: [
                            Image.network(video.thumbnailUrl!, width: 44, height: 44, fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Icon(Icons.play_circle_fill, color: Colors.red.shade400, size: 24)),
                            Positioned.fill(
                              child: Center(
                                child: Icon(Icons.play_circle_fill, color: Colors.white.withValues(alpha: 0.85), size: 20),
                              ),
                            ),
                          ]),
                        )
                      : Icon(Icons.play_circle_fill, color: Colors.red.shade400, size: 24))
                  : Icon(Icons.videocam_off, color: Colors.grey.shade400, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
                const SizedBox(height: 2),
                Text(
                  hasVideo ? (video.title ?? video.youtubeUrl) : 'Geen video gekoppeld',
                  style: GoogleFonts.dmSans(fontSize: 12, color: hasVideo ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
            Icon(
              hasVideo ? Icons.edit : Icons.add_circle_outline,
              size: 20,
              color: hasVideo ? _gold : const Color(0xFF94A3B8),
            ),
          ]),
        ),
      ),
    );
  }
}
