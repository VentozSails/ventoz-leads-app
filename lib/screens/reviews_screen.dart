import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';
import '../l10n/locale_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/review_platforms_service.dart';
import '../services/vat_service.dart';
import '../widgets/site_footer.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC8A85C);

  AppLocalizations get _l => LocaleProvider().l;

  List<ReviewPlatform> _platforms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final platforms = await ReviewPlatformsService().getPlatforms();
    if (mounted) setState(() { _platforms = platforms; _loading = false; });
  }

  IconData _iconForPlatform(String icon) {
    switch (icon) {
      case 'ebay': return Icons.store;
      case 'shopping': return Icons.shopping_bag;
      case 'thumb': return Icons.thumb_up;
      case 'verified': return Icons.verified;
      case 'favorite': return Icons.favorite;
      default: return Icons.star_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(isWide),
          _buildContent(isWide),
          const SiteFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isWide) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: isWide ? 56 : 36, horizontal: isWide ? 64 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_navy, _navy.withValues(alpha: 0.85)],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(children: [
            Image.asset('assets/ventoz_emblem.png', width: 56, height: 56),
            const SizedBox(height: 14),
            Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (_) =>
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.star_rounded, size: 24, color: _gold),
              ),
            )),
            const SizedBox(height: 14),
            Text(
              _l.t('reviews_title'),
              style: GoogleFonts.dmSerifDisplay(fontSize: isWide ? 36 : 26, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _l.t('reviews_subtitle'),
              style: GoogleFonts.dmSans(fontSize: 15, color: const Color(0xFFCBD9EC), height: 1.5),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildContent(bool isWide) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_platforms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
        child: Center(
          child: Column(children: [
            const Icon(Icons.rate_review_outlined, size: 64, color: Color(0xFFB0C4DE)),
            const SizedBox(height: 16),
            Text(
              _l.t('reviews_geen'),
              style: GoogleFonts.dmSans(fontSize: 15, color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isWide ? 48 : 28, horizontal: isWide ? 64 : 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _platforms.map((p) => Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _ReviewPlatformPanel(
                      platform: p,
                      iconForPlatform: _iconForPlatform,
                      l: _l,
                    ),
                  ))).toList(),
                )
              : Column(
                  children: _platforms.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _ReviewPlatformPanel(
                      platform: p,
                      iconForPlatform: _iconForPlatform,
                      l: _l,
                    ),
                  )).toList(),
                ),
        ),
      ),
    );
  }
}

/// A single platform panel with header info + embedded webview preview.
class _ReviewPlatformPanel extends StatefulWidget {
  final ReviewPlatform platform;
  final IconData Function(String) iconForPlatform;
  final AppLocalizations l;

  const _ReviewPlatformPanel({
    required this.platform,
    required this.iconForPlatform,
    required this.l,
  });

  @override
  State<_ReviewPlatformPanel> createState() => _ReviewPlatformPanelState();
}

class _ReviewPlatformPanelState extends State<_ReviewPlatformPanel> {
  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC8A85C);

  WebviewController? _webviewController;
  bool _webviewReady = false;
  bool _webviewFailed = false;

  @override
  void initState() {
    super.initState();
    _initWebview();
  }

  Future<void> _initWebview() async {
    try {
      final controller = WebviewController();
      await controller.initialize();
      await controller.setBackgroundColor(const Color(0xFFF8FAFB));
      await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

      final embedUrl = widget.platform.effectiveEmbedUrl;
      if (VatService.isSafeUrl(embedUrl)) {
        await controller.loadUrl(embedUrl);
      } else {
        if (mounted) setState(() => _webviewFailed = true);
        return;
      }

      // Zoom out so the full-width page fits inside the panel
      await controller.setZoomFactor(0.55);

      if (mounted) {
        setState(() {
          _webviewController = controller;
          _webviewReady = true;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('WebView init failed: $e');
      if (mounted) setState(() => _webviewFailed = true);
    }
  }

  @override
  void dispose() {
    _webviewController?.dispose();
    super.dispose();
  }

  void _openExternal() {
    final url = widget.platform.url;
    if (VatService.isSafeUrl(url)) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.platform;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPanelHeader(p),
          _buildPreviewArea(),
          _buildFooter(p),
        ],
      ),
    );
  }

  Widget _buildPanelHeader(ReviewPlatform p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(widget.iconForPlatform(p.icon), color: _gold, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: _navy),
                ),
                if (p.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    p.description,
                    style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B), height: 1.4),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (p.score.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star, size: 16, color: Color(0xFF16A34A)),
                const SizedBox(width: 4),
                Text(
                  p.score,
                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF16A34A)),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    if (_webviewFailed) return _buildFallbackPreview();
    if (!_webviewReady) return _buildLoadingPreview();

    return SizedBox(
      height: 380,
      child: Webview(_webviewController!),
    );
  }

  Widget _buildLoadingPreview() {
    return Container(
      height: 380,
      color: const Color(0xFFF8FAFB),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            Text(
              'Reviews laden...',
              style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackPreview() {
    return InkWell(
      onTap: _openExternal,
      child: Container(
        height: 380,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFF8FAFB),
              _navy.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: _navy.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.iconForPlatform(widget.platform.icon),
                  size: 32,
                  color: _navy.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.platform.name,
                style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: _navy.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.open_in_new, size: 14, color: _navy.withValues(alpha: 0.35)),
                  const SizedBox(width: 6),
                  Text(
                    'Klik om reviews te bekijken',
                    style: GoogleFonts.dmSans(fontSize: 13, color: _navy.withValues(alpha: 0.35)),
                  ),
                ],
              ),
              if (widget.platform.score.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) =>
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      Icons.star_rounded, size: 28,
                      color: _gold.withValues(alpha: i < 5 ? 1.0 : 0.2),
                    ),
                  ),
                )),
                const SizedBox(height: 6),
                Text(
                  widget.platform.score,
                  style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: _navy.withValues(alpha: 0.5)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(ReviewPlatform p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(widget.l.t('reviews_bekijk'), style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13)),
          onPressed: _openExternal,
          style: ElevatedButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}
