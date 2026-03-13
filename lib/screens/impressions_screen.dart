import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/impressions_service.dart';
import '../l10n/locale_provider.dart';
import '../widgets/site_footer.dart';

class ImpressionsScreen extends StatefulWidget {
  const ImpressionsScreen({super.key});

  @override
  State<ImpressionsScreen> createState() => _ImpressionsScreenState();
}

class _ImpressionsScreenState extends State<ImpressionsScreen> {
  final _locale = LocaleProvider();
  List<Impression> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _locale.addListener(_onLocaleChanged);
    _load();
  }

  @override
  void dispose() {
    _locale.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final items = await ImpressionsService().getImpressions(forceRefresh: true);
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final l = _locale.l;
    final width = MediaQuery.of(context).size.width;
    final crossCount = width >= 1200 ? 4 : (width >= 800 ? 3 : 2);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(slivers: [
              SliverToBoxAdapter(child: _buildHeader(l)),
              if (_items.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(l.t('impressies_leeg'),
                          style: GoogleFonts.dmSans(fontSize: 16, color: Colors.grey.shade500)),
                    ]),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildTile(_items[index], index),
                      childCount: _items.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
              const SliverToBoxAdapter(child: SiteFooter()),
            ]),
    );
  }

  Widget _buildHeader(dynamic l) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1B4965)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/ventoz_logo.png', width: 40, height: 40),
              ),
              const SizedBox(width: 14),
              Text(
                l.t('impressies_titel'),
                style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              l.t('impressies_subtitel'),
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFFB0BEC5), height: 1.5),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildTile(Impression item, int index) {
    return GestureDetector(
      onTap: () => _showLightbox(index),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned.fill(
            child: Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: const Color(0xFFE2E8F0),
                child: const Center(child: Icon(Icons.broken_image, size: 40, color: Color(0xFF94A3B8))),
              ),
            ),
          ),
          if (item.caption != null && item.caption!.isNotEmpty)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                  ),
                ),
                child: Text(
                  item.caption!,
                  style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ]),
      ),
    );
  }

  void _showLightbox(int startIndex) {
    showDialog(
      context: context,
      builder: (ctx) => _Lightbox(items: _items, startIndex: startIndex),
    );
  }
}

class _Lightbox extends StatefulWidget {
  final List<Impression> items;
  final int startIndex;
  const _Lightbox({required this.items, required this.startIndex});

  @override
  State<_Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<_Lightbox> {
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.startIndex;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_current];
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Image.network(
                      item.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const SizedBox(
                        width: 300, height: 300,
                        child: Center(child: Icon(Icons.broken_image, size: 64, color: Colors.white54)),
                      ),
                    ),
                  ),
                  if (item.caption != null && item.caption!.isNotEmpty)
                    Container(
                      width: double.infinity,
                      color: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Text(
                        item.caption!,
                        style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8, right: 8,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        if (widget.items.length > 1) ...[
          Positioned(
            left: 8, top: 0, bottom: 0,
            child: Center(
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                ),
                onPressed: () => setState(() {
                  _current = (_current - 1 + widget.items.length) % widget.items.length;
                }),
              ),
            ),
          ),
          Positioned(
            right: 8, top: 0, bottom: 0,
            child: Center(
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                ),
                onPressed: () => setState(() {
                  _current = (_current + 1) % widget.items.length;
                }),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
