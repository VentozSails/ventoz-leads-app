import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_service.dart';
import '../services/web_scraper_service.dart';
import 'featured_products_screen.dart';
import 'orders_screen.dart';
import 'statistics_screen.dart';
import 'email_overview_screen.dart';
import 'email_templates_screen.dart';
import 'smtp_settings_screen.dart';
import 'kortingscodes_screen.dart';
import 'payment_settings_screen.dart';
import 'payment_methods_screen.dart';
import 'company_settings_screen.dart';
import 'order_template_editor_screen.dart';
import 'user_management_screen.dart';
import 'product_editor_screen.dart';
import 'review_platforms_screen.dart';
import 'about_text_screen.dart';
import 'webshop_content_screen.dart';
import 'admin_impressions_screen.dart';
import 'admin_category_videos_screen.dart';
import 'product_catalogus_screen.dart';
import 'admin_locked_accounts_screen.dart';
import 'admin_audit_log_screen.dart';
import 'admin_weights_screen.dart';
import 'admin_boxes_screen.dart';
import 'admin_myparcel_settings_screen.dart';
import 'admin_myparcel_overview_screen.dart';
import 'admin_shipping_screen.dart';
import 'role_permissions_screen.dart';
import 'admin_suppliers_screen.dart';
import 'admin_category_descriptions_screen.dart';
import 'legal_text_screen.dart';
import 'imap_settings_screen.dart';
import '../services/login_security_service.dart';
import '../services/customer_service.dart';
import 'mfa_enroll_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _slate = Color(0xFF334155);
  static const _gold = Color(0xFFD4A843);

  final _userService = UserService();
  final _scraperService = WebScraperService();

  String _userName = '';
  String _userRole = '';
  bool _isRealOwner = false;
  UserPermissions _permissions = const UserPermissions();

  int _productCount = 0;
  int _pendingOrderCount = 0;
  int _shippingReadyCount = 0;
  int _lockedCount = 0;
  int _customerCount = 0;
  int _lowStockCount = 0;
  int _syncErrorCount = 0;
  bool _statsLoaded = false;

  final Set<String> _collapsedSections = {};

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadStats();
  }

  Future<void> _loadUserInfo() async {
    final user = await _userService.getCurrentUser();
    final realOwner = await _userService.isRealOwner();
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    final effectiveRole = user != null ? _userService.resolveEffectiveRole(user) : UserType.user;
    setState(() {
      _userName = user?.voornaam ?? user?.email.split('@').first ?? 'Beheerder';
      _isRealOwner = realOwner;
      _permissions = perms;
      _userRole = effectiveRole.label;
    });
    await _enforceMfaIfRequired(user, realOwner, effectiveRole);
  }

  Future<void> _enforceMfaIfRequired(AppUser? user, bool isOwner, UserType effectiveRole) async {
    final needsMfa = isOwner || effectiveRole.mfaRequired;
    if (!needsMfa) return;
    try {
      final factors = await Supabase.instance.client.auth.mfa.listFactors();
      final hasMfa = factors.totp.any((f) => f.status == FactorStatus.verified);
      if (!hasMfa && mounted) {
        final enrolled = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const MfaEnrollScreen()),
        );
        if (enrolled != true && mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.security, color: Color(0xFFE53935), size: 40),
              title: const Text('MFA Verplicht'),
              content: const Text(
                'Als medewerker, beheerder of eigenaar is tweestapsverificatie (MFA) verplicht.\n\n'
                'Je moet MFA instellen om de app te kunnen gebruiken.',
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await Supabase.instance.client.auth.signOut();
                    if (mounted) context.go('/inloggen');
                  },
                  child: const Text('Uitloggen'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MfaEnrollScreen()));
                  },
                  child: const Text('MFA Instellen'),
                ),
              ],
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final productCount = await _scraperService.catalogCount();
      int pendingCount = 0;
      int shippingReady = 0;
      try {
        final pending = await Supabase.instance.client.from('orders').select('id').inFilter('status', ['concept', 'betaling_gestart']);
        pendingCount = (pending as List).length;
      } catch (_) {}
      try {
        final paid = await Supabase.instance.client.from('orders').select('id').eq('status', 'betaald');
        shippingReady = (paid as List).length;
      } catch (_) {}
      int lockedCount = 0;
      try {
        final locked = await LoginSecurityService().getLockedAccounts();
        lockedCount = locked.length;
      } catch (_) {}
      int customerCount = 0;
      try {
        customerCount = await CustomerService().getCustomerCount();
      } catch (_) {}
      int lowStock = 0;
      int syncErrors = 0;
      try {
        final inv = await Supabase.instance.client.from('inventory_items').select('voorraad_actueel').lt('voorraad_actueel', 5).gte('voorraad_actueel', 1);
        lowStock = (inv as List).length;
      } catch (_) {}
      try {
        final log = await Supabase.instance.client.from('marketplace_sync_log').select('id').eq('status', 'fout').limit(100);
        syncErrors = (log as List).length;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _productCount = productCount;
        _pendingOrderCount = pendingCount;
        _shippingReadyCount = shippingReady;
        _lockedCount = lockedCount;
        _customerCount = customerCount;
        _lowStockCount = lowStock;
        _syncErrorCount = syncErrors;
        _statsLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _statsLoaded = true);
    }
  }

  void _navigate(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Uitloggen'),
        content: const Text('Weet je zeker dat je wilt uitloggen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
            child: const Text('Uitloggen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/');
  }

  void _showImpersonationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.switch_account, color: Color(0xFF455A64), size: 28),
            ),
            const SizedBox(height: 16),
            Text('Bekijk als...', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: _navy)),
            const SizedBox(height: 6),
            Text(
              'Test de app vanuit het perspectief van een ander type gebruiker.',
              style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ...ImpersonationProfile.presets.entries.map((entry) {
              final profile = entry.value;
              final icon = switch (profile.userType) {
                UserType.wederverkoper => Icons.storefront,
                UserType.klant => Icons.person,
                UserType.admin => Icons.admin_panel_settings,
                UserType.prospect => Icons.mail_outline,
                UserType.user => Icons.person_outline,
                _ => Icons.person_outline,
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, size: 18, color: _slate),
                  ),
                  title: Text(profile.label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  tileColor: Colors.grey[50],
                  dense: true,
                  trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCBD5E1)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await UserService.startImpersonation(profile);
                    if (!profile.userType.hasDashboardAccess && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Testmodus: ${profile.label} — geen dashboard-toegang'), backgroundColor: const Color(0xFFE65100)),
                      );
                      context.go('/');
                      return;
                    }
                    _loadUserInfo();
                    setState(() {});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Testmodus: ${profile.label}'), backgroundColor: const Color(0xFFE65100)),
                      );
                    }
                  },
                ),
              );
            }),
            const SizedBox(height: 12),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
          ]),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = ['januari', 'februari', 'maart', 'april', 'mei', 'juni',
      'juli', 'augustus', 'september', 'oktober', 'november', 'december'];
    final days = ['maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag', 'zondag'];
    final dateStr = '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]} ${now.year}';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(children: [
        _buildSidebar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async { await _loadStats(); await _loadUserInfo(); },
            child: LayoutBuilder(
              builder: (context, constraints) {
                return CustomScrollView(slivers: [
                  SliverToBoxAdapter(child: _buildHeader(dateStr)),
                  SliverToBoxAdapter(child: _buildQuickStats()),
                  if (_lowStockCount > 0 || _syncErrorCount > 0 || _shippingReadyCount > 0 || _pendingOrderCount > 0 || _lockedCount > 0)
                    SliverToBoxAdapter(child: _buildMeldingenSection()),
                  if (_permissions.bestellingenVerzenden || _permissions.alleBestellingenBeheren ||
                      _permissions.zendingenOverzicht || _permissions.statistiekenBekijken)
                    SliverToBoxAdapter(child: _buildQuickActions()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                    sliver: SliverList(delegate: SliverChildListDelegate(_buildSections())),
                  ),
                ]);
              },
            ),
          ),
        ),
      ]),
    );
  }

  // ────────────────────────────────────────────────────
  // SIDEBAR
  // ────────────────────────────────────────────────────

  Widget _buildSidebar() {
    return Container(
      width: 68,
      decoration: BoxDecoration(
        color: _navy,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10)],
      ),
      child: Column(children: [
        const SizedBox(height: 18),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white.withValues(alpha: 0.08)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset('assets/ventoz_logo.png', width: 40, height: 40),
          ),
        ),
        const SizedBox(height: 28),
        _sideBtn(Icons.dashboard_rounded, 'Dashboard', selected: true, onTap: () {}),
        _sideBtn(Icons.storefront_rounded, 'Catalogus', onTap: () => context.push('/dashboard/beheer')),
        _sideBtn(Icons.language_rounded, 'Website', onTap: () => context.go('/')),
        const Spacer(),
        if (_isRealOwner)
          _sideBtn(
            UserService.isImpersonating ? Icons.person_off_rounded : Icons.switch_account_rounded,
            UserService.isImpersonating ? 'Stop test' : 'Bekijk als...',
            onTap: () {
              if (UserService.isImpersonating) {
                UserService.stopImpersonation();
                _loadUserInfo();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Testmodus gestopt'), backgroundColor: Color(0xFF2E7D32)),
                );
              } else {
                _showImpersonationDialog();
              }
            },
            accent: UserService.isImpersonating,
          ),
        _sideBtn(Icons.logout_rounded, 'Uitloggen', onTap: _logout),
        const SizedBox(height: 18),
      ]),
    );
  }

  Widget _sideBtn(IconData icon, String tooltip, {bool selected = false, bool accent = false, VoidCallback? onTap}) {
    final color = accent ? const Color(0xFFE65100) : selected ? Colors.white : Colors.white54;
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 200),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.white.withValues(alpha: 0.08),
          child: Container(
            width: 52, height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────
  // HEADER
  // ────────────────────────────────────────────────────

  Widget _buildHeader(String dateStr) {
    return Container(
      margin: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF152D45), Color(0xFF1B4965)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _navy.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('DASHBOARD', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white30, letterSpacing: 2)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _gold.withValues(alpha: 0.25)),
              ),
              child: Text(_userRole, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: _gold)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            'Welkom terug, $_userName',
            style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15),
          ),
          const SizedBox(height: 3),
          Text(dateStr, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white38)),
        ])),
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.asset('assets/ventoz_logo.png', width: 52, height: 52),
          ),
        ),
      ]),
    );
  }

  // ────────────────────────────────────────────────────
  // QUICK STATS
  // ────────────────────────────────────────────────────

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 2),
      child: Row(children: [
        _stat('Producten', _statsLoaded ? '$_productCount' : '—', Icons.inventory_2_rounded, const Color(0xFF1B4965)),
        const SizedBox(width: 10),
        _stat('Klanten', _statsLoaded && _customerCount > 0 ? '$_customerCount' : '—', Icons.people_rounded, const Color(0xFF00838F),
            onTap: _permissions.klantenBeheren ? () => context.push('/dashboard/klanten') : null),
        const SizedBox(width: 10),
        _stat('Openstaand', _statsLoaded ? '$_pendingOrderCount' : '—', Icons.pending_actions_rounded, const Color(0xFFE65100),
            badge: _pendingOrderCount > 0),
        const SizedBox(width: 10),
        _stat('Te verzenden', _statsLoaded ? '$_shippingReadyCount' : '—', Icons.local_shipping_outlined, const Color(0xFF00897B),
            badge: _shippingReadyCount > 0,
            onTap: _permissions.bestellingenVerzenden && _shippingReadyCount > 0 ? () => _navigate(const AdminShippingScreen()) : null),
        const SizedBox(width: 10),
        _stat('Geblokkeerd', _statsLoaded ? '$_lockedCount' : '—', Icons.lock_outline_rounded, const Color(0xFFC62828),
            badge: _lockedCount > 0,
            onTap: _permissions.geblokkeerdeAccountsBeheren && _lockedCount > 0 ? () => _navigate(const AdminLockedAccountsScreen()) : null),
      ]),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color, {bool badge = false, VoidCallback? onTap}) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: color.withValues(alpha: 0.04),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: badge ? color.withValues(alpha: 0.3) : const Color(0xFFE8ECF1)),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(value, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w800, color: badge ? color : _navy)),
                Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
              ])),
              if (onTap != null) Icon(Icons.chevron_right_rounded, size: 16, color: color.withValues(alpha: 0.5)),
            ]),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────
  // MELDINGEN & TAKEN
  // ────────────────────────────────────────────────────

  Widget _buildMeldingenSection() {
    final items = <Widget>[];
    if (_shippingReadyCount > 0 && _permissions.bestellingenVerzenden) {
      items.add(_meldingTile('Te verzenden', '$_shippingReadyCount order(s) klaar voor verzending', Icons.local_shipping_rounded, const Color(0xFF00897B),
          onTap: () => _navigate(const AdminShippingScreen())));
    }
    if (_pendingOrderCount > 0 && _permissions.alleBestellingenBeheren) {
      items.add(_meldingTile('Openstaande orders', '$_pendingOrderCount order(s) wachten op actie', Icons.pending_actions_rounded, const Color(0xFFE65100),
          onTap: () => _navigate(const OrdersScreen(adminView: true))));
    }
    if (_lowStockCount > 0 && _permissions.voorraadBeheren) {
      items.add(_meldingTile('Lage voorraad', '$_lowStockCount product(en) onder 5 stuks', Icons.warning_amber_rounded, const Color(0xFFF57F17),
          onTap: () => context.push('/dashboard/voorraad')));
    }
    if (_syncErrorCount > 0 && _permissions.marktplaatsKoppelingen) {
      items.add(_meldingTile('Sync-fouten', '$_syncErrorCount sync-fout(en) op marktplaatsen', Icons.sync_problem_rounded, const Color(0xFFE53935),
          onTap: () => context.push('/dashboard/marktplaatsen')));
    }
    if (_lockedCount > 0 && _permissions.geblokkeerdeAccountsBeheren) {
      items.add(_meldingTile('Geblokkeerde accounts', '$_lockedCount account(s) geblokkeerd', Icons.lock_outline_rounded, const Color(0xFFC62828),
          onTap: () => _navigate(const AdminLockedAccountsScreen())));
    }
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 10, 28, 2),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.notifications_active_rounded, size: 18, color: const Color(0xFF92400E)),
              const SizedBox(width: 8),
              Text('Aandacht nodig', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF92400E))),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 8, children: items),
          ],
        ),
      ),
    );
  }

  Widget _meldingTile(String title, String desc, IconData icon, Color color, {VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: _navy)),
              Text(desc, style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF64748B))),
            ]),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: color.withValues(alpha: 0.6)),
          ]),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────
  // QUICK ACTIONS (prominent row for daily tasks)
  // ────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    final actions = <Widget>[];
    if (_permissions.bestellingenVerzenden) {
      actions.add(_quickAction('Bestellingen\nverzenden', Icons.local_shipping_rounded, const Color(0xFF00897B),
          badge: _shippingReadyCount > 0 ? '$_shippingReadyCount' : null,
          onTap: () => _navigate(const AdminShippingScreen())));
    }
    if (_permissions.alleBestellingenBeheren) {
      actions.add(_quickAction('Orderbeheer', Icons.receipt_long_rounded, const Color(0xFF1565C0),
          badge: _pendingOrderCount > 0 ? '$_pendingOrderCount' : null,
          onTap: () => _navigate(const OrdersScreen(adminView: true))));
    }
    if (_permissions.zendingenOverzicht) {
      actions.add(_quickAction('Zendingen\noverzicht', Icons.track_changes_rounded, const Color(0xFF5C6BC0),
          onTap: () => _navigate(const AdminMyParcelOverviewScreen())));
    }
    if (_permissions.statistiekenBekijken) {
      actions.add(_quickAction('Statistieken', Icons.insights_rounded, const Color(0xFF6A1B9A),
          onTap: () => _navigate(const StatisticsScreen())));
    }
    if (actions.isEmpty) return const SizedBox.shrink();
    final spaced = <Widget>[];
    for (int i = 0; i < actions.length; i++) {
      if (i > 0) spaced.add(const SizedBox(width: 12));
      spaced.add(actions[i]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 2),
      child: Row(children: spaced),
    );
  }

  Widget _quickAction(String label, IconData icon, Color color, {String? badge, VoidCallback? onTap}) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: color.withValues(alpha: 0.06),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8ECF1)),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: _navy, height: 1.2))),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                  child: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              const SizedBox(width: 3),
              Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey.shade300),
            ]),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────
  // SECTIONS
  // ────────────────────────────────────────────────────

  List<Widget> _buildSections() {
    final p = _permissions;

    return [
      // ── 1. Relaties ──
      if (p.klantenBeheren || p.leadsInzien || p.voorraadBeheren)
        _section('Relaties', Icons.people_rounded, [
          if (p.klantenBeheren)
            _tile('Klanten', 'Klantenregister met omzet en facturen', Icons.people_rounded, const Color(0xFF1B4965),
                badge: _statsLoaded && _customerCount > 0 ? '$_customerCount' : null,
                onTap: () => context.push('/dashboard/klanten')),
          if (p.leadsInzien)
            _tile('Prospects', 'Leads NL, DE, BE bekijken en e-mailen', Icons.people_alt_rounded, const Color(0xFF00838F),
                onTap: () => context.push('/dashboard/beheer')),
          if (p.voorraadBeheren)
            _tile('Leveranciers', 'Inloggegevens en websites', Icons.factory_rounded, const Color(0xFF4E342E),
                onTap: () => _navigate(const AdminSuppliersScreen())),
        ]),

      // ── 2. Producten ──
      if (p.productenBewerken || p.uitgelichteProducten || p.productenBlokkeren)
        _section('Producten', Icons.inventory_2_rounded, [
          _tile('Productcatalogus', 'Bekijk en beheer alle producten', Icons.storefront_rounded, const Color(0xFF1B4965),
              badge: _statsLoaded ? '$_productCount' : null, onTap: () => context.push('/dashboard/beheer')),
          if (p.productenBewerken)
            _tile('Product bewerken', 'Override-velden en afbeeldingen', Icons.edit_note_rounded, const Color(0xFF2E7D32),
                onTap: () => _navigate(const ProductEditorScreen())),
          if (p.uitgelichteProducten)
            _tile('Uitgelichte producten', 'Homepage slider beheren', Icons.star_rounded, _gold,
                onTap: () => _navigate(const FeaturedProductsScreen())),
          if (p.productenBlokkeren)
            _tile('Afgewezen items', 'Geblokkeerde producten', Icons.block_rounded, const Color(0xFFE53935),
                onTap: () => _navigate(const ProductCatalogusScreen(showBlocked: true))),
        ]),

      // ── 3. Voorraadbeheer ──
      if (p.voorraadBeheren || p.voorraadImporteren || p.eanCodesBeheren)
        _section('Voorraadbeheer', Icons.warehouse_rounded, [
          if (p.voorraadBeheren)
            _tile('Voorraadoverzicht', 'Alle producten en varianten', Icons.inventory_rounded, const Color(0xFF2E7D32),
                onTap: () => context.push('/dashboard/voorraad')),
          if (p.voorraadBeheren)
            _tile('Zeilnummers & letters', 'Voorraad stickers', Icons.format_list_numbered_rounded, const Color(0xFF00838F),
                onTap: () => context.push('/dashboard/zeil-voorraad')),
          if (p.voorraadBeheren)
            _tile('Voorraadlog', 'Alle mutaties en correcties', Icons.history_rounded, const Color(0xFF37474F),
                onTap: () => context.push('/dashboard/voorraadlog')),
          if (p.voorraadBeheren)
            _tile('Voorraad Archief', 'Gearchiveerde items', Icons.archive_rounded, const Color(0xFF6D4C41),
                onTap: () => context.push('/dashboard/voorraad/archief')),
          if (p.voorraadImporteren)
            _tile('CSV importeren', 'Voorraad bijwerken via bestand', Icons.upload_file_rounded, const Color(0xFF1565C0),
                onTap: () => context.push('/dashboard/voorraad/import')),
          if (p.eanCodesBeheren)
            _tile('EAN-codes', 'Barcode-register beheren', Icons.qr_code_rounded, const Color(0xFF6A1B9A),
                onTap: () => context.push('/dashboard/ean-beheer')),
        ]),

      // ── 4. Prijzen & Kanalen ──
      if (p.marktplaatsKoppelingen || p.verkoopkanalenBeheren)
        _section('Prijzen & Kanalen', Icons.attach_money_rounded, [
          if (p.marktplaatsKoppelingen)
            _tile('Kanaaloverzicht', 'Prijzen en plaatsingen per product per kanaal', Icons.grid_view_rounded, const Color(0xFF0070E0),
                onTap: () => context.push('/dashboard/kanaaloverzicht')),
          if (p.marktplaatsKoppelingen)
            _tile('Marktplaatsen', 'Listings, eBay matching, orders, feed', Icons.shopping_bag_rounded, const Color(0xFF0070E0),
                onTap: () => context.push('/dashboard/marktplaatsen')),
          if (p.verkoopkanalenBeheren)
            _tile('Verkoopkanalen', 'Kanalen configureren', Icons.tune_rounded, const Color(0xFF00695C),
                onTap: () => context.push('/dashboard/verkoopkanalen')),
        ]),

      // ── 5. Orders & Verzending ──
      if (p.alleBestellingenBeheren || p.bestellingenVerzenden || p.zendingenOverzicht)
        _section('Orders & Verzending', Icons.local_shipping_rounded, [
          if (p.bestellingenVerzenden)
            _tile('Bestellingen verzenden', 'Betaalde orders klaarzetten', Icons.local_shipping_rounded, const Color(0xFF00897B),
                badge: _shippingReadyCount > 0 ? '$_shippingReadyCount' : null, onTap: () => _navigate(const AdminShippingScreen())),
          if (p.alleBestellingenBeheren)
            _tile('Orderbeheer', 'Alle bestellingen beheren', Icons.receipt_long_rounded, const Color(0xFF1565C0),
                badge: _pendingOrderCount > 0 ? '$_pendingOrderCount' : null, onTap: () => _navigate(const OrdersScreen(adminView: true))),
          if (p.eigenBestelhistorie)
            _tile('Mijn bestellingen', 'Je eigen bestelhistorie', Icons.shopping_bag_rounded, const Color(0xFF5C6BC0),
                onTap: () => _navigate(const OrdersScreen())),
          if (p.zendingenOverzicht)
            _tile('Zendingen', 'MyParcel overzicht', Icons.track_changes_rounded, const Color(0xFF1565C0),
                onTap: () => _navigate(const AdminMyParcelOverviewScreen())),
        ]),

      // ── Eigen bestellingen (klant/wederverkoper, alleen als geen admin) ──
      if (p.eigenBestelhistorie && !p.alleBestellingenBeheren)
        _section('Bestellingen', Icons.shopping_bag_rounded, [
          _tile('Mijn bestellingen', 'Je eigen bestelhistorie', Icons.shopping_bag_rounded, const Color(0xFF5C6BC0),
              onTap: () => _navigate(const OrdersScreen())),
        ]),

      // ── 6. Logistiek & Inkoop ──
      if (p.productgewichtenBeheren || p.verpakkingenBeheren || p.voorraadBeheren)
        _section('Logistiek & Inkoop', Icons.local_shipping_outlined, [
          if (p.voorraadBeheren)
            _tile('Leveranciers', 'Inloggegevens en websites', Icons.factory_rounded, const Color(0xFF4E342E),
                onTap: () => _navigate(const AdminSuppliersScreen())),
          if (p.productgewichtenBeheren)
            _tile('Productgewichten', 'Gewichten per product', Icons.scale_rounded, const Color(0xFF558B2F),
                onTap: () => _navigate(const AdminWeightsScreen())),
          if (p.verpakkingenBeheren)
            _tile('Verpakkingen', 'Dozen en gewichten', Icons.inventory_2_rounded, const Color(0xFF6D4C41),
                onTap: () => _navigate(const AdminBoxesScreen())),
        ]),

      // ── 7. Website Content ──
      if (p.aboutTekstBewerken || p.impressiesBeheren || p.categoryVideosBeheren || p.reviewPlatformsBeheren)
        _section('Website & Content', Icons.web_rounded, [
          if (p.aboutTekstBewerken)
            _tile('Over Ventoz tekst', 'Landingspagina tekst bewerken', Icons.article_rounded, const Color(0xFF00695C),
                onTap: () => _navigate(const AboutTextScreen())),
          if (p.aboutTekstBewerken)
            _tile('Webshop Content', 'Hero banner & USP teksten', Icons.web_rounded, const Color(0xFF7B1FA2),
                onTap: () => _navigate(const WebshopContentScreen())),
          if (p.aboutTekstBewerken)
            _tile('Legal pagina\'s', 'Voorwaarden, privacy, garantie', Icons.gavel_rounded, const Color(0xFF4E342E),
                onTap: () => _navigate(const LegalTextScreen())),
          if (p.aboutTekstBewerken)
            _tile('Categorieteksten', 'Beschrijvingen per categorie', Icons.description_rounded, const Color(0xFF5C6BC0),
                onTap: () => _navigate(const AdminCategoryDescriptionsScreen())),
          if (p.impressiesBeheren)
            _tile('Impressies', "Foto's van zeilen in actie", Icons.photo_library_rounded, const Color(0xFF0277BD),
                onTap: () => _navigate(const AdminImpressionsScreen())),
          if (p.categoryVideosBeheren)
            _tile("Video's per categorie", 'YouTube-videos koppelen', Icons.ondemand_video_rounded, const Color(0xFFC62828),
                onTap: () => _navigate(const AdminCategoryVideosScreen())),
          if (p.reviewPlatformsBeheren)
            _tile('Beoordelingen', 'eBay, ValuedShops en meer', Icons.star_rounded, const Color(0xFFF57F17),
                onTap: () => _navigate(const ReviewPlatformsScreen())),
        ]),

      // ── 8. Marketing & Communicatie ──
      if (p.statistiekenBekijken || p.leadEmailsVersturen || p.kortingscodesBeheren)
        _section('Marketing & Communicatie', Icons.campaign_rounded, [
          if (p.statistiekenBekijken)
            _tile('Statistieken', 'Conversies en campagnes', Icons.insights_rounded, const Color(0xFF6A1B9A),
                onTap: () => _navigate(const StatisticsScreen())),
          if (p.leadEmailsVersturen)
            _tile('E-mail overzicht', 'Verzonden e-mails en logboek', Icons.inbox_rounded, const Color(0xFF00695C),
                onTap: () => _navigate(const EmailOverviewScreen())),
          if (p.kortingscodesBeheren)
            _tile('Kortingscodes', 'Codes aanmaken en beheren', Icons.local_offer_rounded, const Color(0xFFE65100),
                onTap: () => _navigate(const KortingscodesScreen())),
        ]),

      // ── 9. Beheer & Beveiliging ──
      if (p.gebruikersBeheren || p.geblokkeerdeAccountsBeheren || p.activiteitenlogBekijken || p.testmodus)
        _section('Beheer & Beveiliging', Icons.admin_panel_settings_rounded, [
          if (p.gebruikersBeheren)
            _tile('Gebruikersbeheer', 'Rollen, rechten en accounts', Icons.group_rounded, const Color(0xFF4E342E),
                onTap: () => _navigate(const UserManagementScreen())),
          if (p.geblokkeerdeAccountsBeheren)
            _tile('Geblokkeerde accounts', 'Accounts vrijgeven', Icons.lock_rounded, const Color(0xFFC62828),
                badge: _lockedCount > 0 ? '$_lockedCount' : null, onTap: () => _navigate(const AdminLockedAccountsScreen())),
          if (p.activiteitenlogBekijken)
            _tile('Activiteitenlog', 'Login- en accountgebeurtenissen', Icons.history_rounded, const Color(0xFF37474F),
                onTap: () => _navigate(const AdminAuditLogScreen())),
          if (_isRealOwner)
            _tile(
              UserService.isImpersonating ? 'Testmodus stoppen' : 'Bekijk als...',
              UserService.isImpersonating ? 'Actief: ${UserService.impersonationLabel}' : 'App testen als ander gebruikerstype',
              UserService.isImpersonating ? Icons.person_off_rounded : Icons.switch_account_rounded,
              UserService.isImpersonating ? const Color(0xFFE65100) : const Color(0xFF5C6BC0),
              onTap: () {
                if (UserService.isImpersonating) {
                  UserService.stopImpersonation();
                  _loadUserInfo();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Testmodus gestopt'), backgroundColor: Color(0xFF2E7D32)),
                  );
                } else {
                  _showImpersonationDialog();
                }
              },
            ),
        ]),

      // ── 9. Instellingen ──
      if (p.bedrijfsgegevensBewerken || p.smtpInstellingen || p.emailTemplatesBeheren ||
          p.orderTemplatesBewerken || p.myparcelInstellingen || p.betaalgatewayInstellingen ||
          p.rollenRechtenToewijzen)
        _section('Instellingen', Icons.settings_rounded, [
          if (p.bedrijfsgegevensBewerken)
            _tile('Bedrijfsgegevens', 'Naam, adres, KvK, BTW', Icons.business_rounded, const Color(0xFF455A64),
                onTap: () => _navigate(const CompanySettingsScreen())),
          if (p.betaalgatewayInstellingen)
            _tile('Betaalinstellingen', 'Gateways configureren', Icons.credit_card_rounded, const Color(0xFF1B5E20),
                onTap: () => _navigate(const PaymentSettingsScreen())),
          if (p.betaalmethodenOverzicht)
            _tile('Betaalmethoden', 'Actieve methoden overzicht', Icons.payment_rounded, const Color(0xFF0277BD),
                onTap: () => _navigate(const PaymentMethodsScreen())),
          if (p.myparcelInstellingen)
            _tile('MyParcel', 'API-koppeling en verzendopties', Icons.rocket_launch_rounded, const Color(0xFF00897B),
                onTap: () => _navigate(const AdminMyParcelSettingsScreen())),
          if (p.smtpInstellingen)
            _tile('E-mail / SMTP', 'SMTP-server configureren', Icons.email_rounded, const Color(0xFF546E7A),
                onTap: () => _navigate(const SmtpSettingsScreen())),
          if (p.smtpInstellingen)
            _tile('IMAP Order Import', 'Orders ophalen via e-mail', Icons.mark_email_read_rounded, const Color(0xFF1565C0),
                onTap: () => _navigate(const ImapSettingsScreen())),
          if (p.emailTemplatesBeheren)
            _tile('E-mail templates', 'Templates voor lead-mailing', Icons.mail_rounded, const Color(0xFF37474F),
                onTap: () => _navigate(const EmailTemplatesScreen())),
          if (p.orderTemplatesBewerken)
            _tile('Order-templates', 'Bevestiging- en factuur-layout', Icons.code_rounded, const Color(0xFF4527A0),
                onTap: () => _navigate(const OrderTemplateEditorScreen())),
          if (p.rollenRechtenToewijzen)
            _tile('Rolrechten', 'Autorisatiematrix per rol', Icons.security_rounded, const Color(0xFF5C6BC0),
                onTap: () => _navigate(const RolePermissionsScreen())),
        ]),
    ];
  }

  // ────────────────────────────────────────────────────
  // SECTION
  // ────────────────────────────────────────────────────

  static const _sectionAccents = <String, Color>{
    'Producten':              Color(0xFF1B4965),
    'Marktplaatsen & Kanalen': Color(0xFF0070E0),
    'Orders & Verzending':    Color(0xFF00897B),
    'Bestellingen':           Color(0xFF5C6BC0),
    'Klanten & Marketing':    Color(0xFF00838F),
    'Voorraad':               Color(0xFF2E7D32),
    'Logistiek & Inkoop':     Color(0xFF6D4C41),
    'Website & Content':      Color(0xFF0277BD),
    'Beheer & Beveiliging':   Color(0xFFC62828),
    'Instellingen':           Color(0xFF546E7A),
  };

  Widget _section(String title, IconData icon, List<Widget> tiles) {
    final accent = _sectionAccents[title] ?? _slate;
    final collapsed = _collapsedSections.contains(title);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8ECF1)),
          boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          Positioned(left: 0, top: 0, bottom: 0, width: 3, child: ColoredBox(color: accent)),
          Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 14, collapsed ? 12 : 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              InkWell(
                onTap: () => setState(() {
                  if (collapsed) {
                    _collapsedSections.remove(title);
                  } else {
                    _collapsedSections.add(title);
                  }
                }),
                borderRadius: BorderRadius.circular(6),
                hoverColor: accent.withValues(alpha: 0.04),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(children: [
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Icon(icon, size: 13, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Text(title, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w800, color: _navy, letterSpacing: 0.1)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: accent.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(6)),
                      child: Text('${tiles.length}', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w700, color: accent)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Container(height: 1, color: const Color(0xFFEDF0F4))),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: collapsed ? -0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: _slate.withValues(alpha: 0.4)),
                    ),
                  ]),
                ),
              ),
              if (!collapsed) ...[
                const SizedBox(height: 10),
                LayoutBuilder(builder: (context, box) {
                  final cols = box.maxWidth > 1200 ? 5 : box.maxWidth > 960 ? 4 : box.maxWidth > 640 ? 3 : 2;
                  return GridView.count(
                    crossAxisCount: cols,
                    mainAxisSpacing: 7,
                    crossAxisSpacing: 7,
                    childAspectRatio: 3.0,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: tiles,
                  );
                }),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  // ────────────────────────────────────────────────────
  // TILE
  // ────────────────────────────────────────────────────

  Widget _tile(String title, String desc, IconData icon, Color color, {String? badge, VoidCallback? onTap}) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: color.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFEDF0F4)),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(title, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: _navy), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(desc, style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF94A3B8)), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                child: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey.shade300),
          ]),
        ),
      ),
    );
  }
}
