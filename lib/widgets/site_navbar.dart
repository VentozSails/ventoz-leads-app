import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/cart_service.dart';
import '../services/user_service.dart';
import '../services/web_scraper_service.dart';
import '../models/catalog_product.dart';
import '../l10n/locale_provider.dart';

class SiteNavbar extends StatefulWidget {
  const SiteNavbar({super.key});

  @override
  State<SiteNavbar> createState() => _SiteNavbarState();
}

class _SiteNavbarState extends State<SiteNavbar> {
  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC8A85C);

  Map<String, int> _categoryCounts = {};
  bool _categoriesLoaded = false;

  bool get _isLoggedIn {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return false;
    final expiry = session.expiresAt;
    if (expiry != null && DateTime.fromMillisecondsSinceEpoch(expiry * 1000).isBefore(DateTime.now())) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final raw = await WebScraperService().fetchCatalog();
      final products = raw.where((p) => !p.geblokkeerd).toList();
      final counts = <String, int>{};
      for (final p in products) {
        final cat = p.categorie ?? 'overig';
        counts[cat] = (counts[cat] ?? 0) + 1;
      }
      final sorted = Map.fromEntries(
        counts.entries.toList()..sort((a, b) {
          final la = CatalogProduct(naam: '', categorie: a.key).categorieLabelForLang(LocaleProvider().lang);
          final lb = CatalogProduct(naam: '', categorie: b.key).categorieLabelForLang(LocaleProvider().lang);
          return la.compareTo(lb);
        }),
      );
      if (mounted) setState(() { _categoryCounts = sorted; _categoriesLoaded = true; });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lp = LocaleProvider();
    final l = lp.l;
    final isWide = MediaQuery.of(context).size.width >= 800;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (UserService.isImpersonating) _buildImpersonationBanner(context),
      Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            _buildLogo(context),
            if (isWide) ...[
              const SizedBox(width: 32),
              _navLink(context, l.t('nav_home'), '/'),
              _navLink(context, l.t('nav_assortiment'), '/catalogus'),
              _navLink(context, l.t('nav_impressies'), '/impressies'),
              _navLink(context, l.t('nav_over_ons'), '/#over-ons'),
              _navLink(context, l.t('nav_beoordelingen'), '/beoordelingen'),
              _navLink(context, l.t('nav_contact'), '/#contact'),
            ],
            const Spacer(),
            if (isWide) _buildLangSelector(context),
            const SizedBox(width: 4),
            _buildCartIcon(context),
            const SizedBox(width: 8),
            if (isWide) (_isLoggedIn ? _buildAccountMenu(context) : _buildAuthButton(context)),
            if (!isWide) _buildMenuButton(context),
          ],
        ),
      ),
      if (_categoriesLoaded && _categoryCounts.isNotEmpty)
        _buildCategoryBar(context),
    ]);
  }

  Widget _buildCategoryBar(BuildContext context) {
    final current = GoRouterState.of(context).matchedLocation;
    final isCatalog = current == '/catalogus';
    final queryParams = GoRouterState.of(context).uri.queryParameters;
    final activeCategory = queryParams['categorie'];

    final buttons = _categoryCounts.entries.map((e) {
      final label = CatalogProduct(naam: '', categorie: e.key).categorieLabelForLang(LocaleProvider().lang).toUpperCase();
      final isActive = isCatalog && activeCategory == e.key;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        child: InkWell(
          onTap: () => context.go('/catalogus?categorie=${e.key}'),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? _navy.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? _navy : const Color(0xFF64748B),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      );
    }).toList();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFB),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 2,
            runSpacing: 0,
            children: buttons,
          ),
        ),
      ),
    );
  }

  Widget _buildImpersonationBanner(BuildContext context) {
    return Container(
      color: const Color(0xFFE65100),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        const Icon(Icons.switch_account, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'TESTMODUS: ${UserService.impersonationLabel}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5),
          ),
        ),
        TextButton.icon(
          onPressed: () {
            UserService.stopImpersonation();
            context.go('/dashboard');
          },
          icon: const Icon(Icons.close, color: Colors.white, size: 16),
          label: const Text('Stoppen & terug naar dashboard', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildLangSelector(BuildContext context) {
    final lp = LocaleProvider();
    return PopupMenuButton<String>(
      initialValue: lp.lang,
      tooltip: lp.l.t('taal_tooltip'),
      onSelected: (lang) => lp.setLang(lang),
      constraints: const BoxConstraints(maxHeight: 420),
      itemBuilder: (_) {
        final items = <PopupMenuEntry<String>>[];
        for (final lang in LocaleProvider.primaryLangs) {
          items.add(PopupMenuItem(
            value: lang,
            child: Text(
              '${LocaleProvider.langLabels[lang]} — ${LocaleProvider.langNames[lang]}',
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: lp.lang == lang ? FontWeight.w700 : FontWeight.w400),
            ),
          ));
        }
        items.add(const PopupMenuDivider());
        for (final lang in LocaleProvider.otherLangs) {
          items.add(PopupMenuItem(
            value: lang,
            child: Text(
              '${LocaleProvider.langLabels[lang]} — ${LocaleProvider.langNames[lang]}',
              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: lp.lang == lang ? FontWeight.w700 : FontWeight.w400, color: const Color(0xFF64748B)),
            ),
          ));
        }
        return items;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(LocaleProvider.langLabels[lp.lang] ?? 'NL', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _navy)),
          const Icon(Icons.arrow_drop_down, size: 16, color: _navy),
        ]),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/'),
      borderRadius: BorderRadius.circular(4),
      child: Image.asset('assets/ventoz_text_logo.png', height: 28, fit: BoxFit.contain),
    );
  }

  Widget _navLink(BuildContext context, String label, String path) {
    final current = GoRouterState.of(context).matchedLocation;
    final isActive = current == path;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: () => context.go(path),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? _navy : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartIcon(BuildContext context) {
    final count = CartService().totalItems;
    return IconButton(
      onPressed: () => context.push('/winkelwagen'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count', style: const TextStyle(fontSize: 10)),
        backgroundColor: _gold,
        child: const Icon(Icons.shopping_bag_outlined, size: 22),
      ),
      tooltip: LocaleProvider().l.t('nav_winkelwagen'),
      color: _navy,
    );
  }

  Widget _buildAuthButton(BuildContext context) {
    final l = LocaleProvider().l;
    return ElevatedButton(
      onPressed: () => context.go('/inloggen'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(l.t('nav_inloggen'), style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildAccountMenu(BuildContext context) {
    final l = LocaleProvider().l;
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final initials = email.isNotEmpty ? email[0].toUpperCase() : '?';
    return PopupMenuButton<String>(
      tooltip: email,
      onSelected: (val) async {
        switch (val) {
          case 'dashboard':
            context.go('/dashboard');
          case 'orders':
            context.push('/dashboard/beheer');
          case 'logout':
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) context.go('/');
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Text(email, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF94A3B8))),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'dashboard',
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.dashboard_rounded, size: 18),
            title: Text(l.t('nav_dashboard'), style: GoogleFonts.dmSans(fontSize: 13)),
          ),
        ),
        PopupMenuItem(
          value: 'orders',
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.receipt_long_rounded, size: 18),
            title: Text(l.t('mijn_bestellingen'), style: GoogleFonts.dmSans(fontSize: 13)),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.logout, size: 18, color: Color(0xFFE53935)),
            title: Text(l.t('uitloggen'), style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFFE53935))),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _navy,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: _gold,
            child: Text(initials, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: _navy)),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
        ]),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu, color: _navy),
      onPressed: () => _showMobileMenu(context),
    );
  }

  void _showMobileMenu(BuildContext context) {
    final l = LocaleProvider().l;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) => SingleChildScrollView(
            controller: scrollCtrl,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              _buildLangSelector(context),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: Text(l.t('nav_home')),
                onTap: () { Navigator.pop(ctx); context.go('/'); },
              ),
              ListTile(
                leading: const Icon(Icons.sailing),
                title: Text(l.t('nav_assortiment')),
                onTap: () { Navigator.pop(ctx); context.go('/catalogus'); },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l.t('nav_impressies')),
                onTap: () { Navigator.pop(ctx); context.go('/impressies'); },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l.t('nav_over_ons')),
                onTap: () { Navigator.pop(ctx); context.go('/'); },
              ),
              ListTile(
                leading: const Icon(Icons.star_rounded),
                title: Text(l.t('nav_beoordelingen')),
                onTap: () { Navigator.pop(ctx); context.go('/beoordelingen'); },
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: Text(l.t('nav_contact')),
                onTap: () { Navigator.pop(ctx); context.go('/'); },
              ),
              ListTile(
                leading: const Icon(Icons.shopping_bag_outlined),
                title: Text(l.t('nav_winkelwagen')),
                onTap: () { Navigator.pop(ctx); context.push('/winkelwagen'); },
              ),
              if (_categoryCounts.isNotEmpty) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(l.t('categorieen'), style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                ),
                ..._categoryCounts.entries.map((e) {
                  final label = CatalogProduct(naam: '', categorie: e.key).categorieLabelForLang(LocaleProvider().lang);
                  return ListTile(
                    dense: true,
                    title: Text(label, style: GoogleFonts.dmSans(fontSize: 13)),
                    trailing: Text('${e.value}', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B))),
                    onTap: () { Navigator.pop(ctx); context.go('/catalogus?categorie=${e.key}'); },
                  );
                }),
              ],
              const Divider(),
              if (_isLoggedIn) ...[
                ListTile(
                  leading: const Icon(Icons.dashboard_rounded),
                  title: Text(l.t('nav_dashboard')),
                  onTap: () { Navigator.pop(ctx); context.go('/dashboard'); },
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_long_rounded),
                  title: Text(l.t('mijn_bestellingen')),
                  onTap: () { Navigator.pop(ctx); context.push('/dashboard/beheer'); },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Color(0xFFE53935)),
                  title: Text(l.t('uitloggen'), style: const TextStyle(color: Color(0xFFE53935))),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) context.go('/');
                  },
                ),
              ] else
                ListTile(
                  leading: const Icon(Icons.login),
                  title: Text(l.t('nav_inloggen')),
                  onTap: () { Navigator.pop(ctx); context.go('/inloggen'); },
                ),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ),
    );
  }
}
