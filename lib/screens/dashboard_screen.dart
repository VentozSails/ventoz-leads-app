import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lead.dart';
import '../services/leads_service.dart';
import '../services/email_log_service.dart';
import '../services/kortingscodes_service.dart';
import '../models/kortingscode.dart';
import '../theme/app_theme.dart';
import '../widgets/offer_modal.dart';
import '../widgets/lead_detail_modal.dart';
import 'email_templates_screen.dart';
import 'kortingscodes_screen.dart';
import 'smtp_settings_screen.dart';
import 'batch_email_screen.dart';
import 'statistics_screen.dart';
import 'email_overview_screen.dart';
import 'mfa_enroll_screen.dart';
import 'user_management_screen.dart';
import '../services/user_service.dart';
import '../services/vat_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/address_form_fields.dart';
import 'add_lead_screen.dart';
import 'import_leads_screen.dart';
import 'package:intl/intl.dart';
import '../services/export_service.dart';
import 'product_catalogus_screen.dart';
import 'orders_screen.dart';
import 'inventory_dashboard_screen.dart';
import 'payment_settings_screen.dart';
import 'payment_methods_screen.dart';
import 'company_settings_screen.dart';
import 'order_template_editor_screen.dart';
import 'featured_products_screen.dart';

enum Country {
  nl('Nederland', 'leads_nl', 'Provincie', 'provincie'),
  de('Duitsland', 'leads_de', 'Bundesland', 'bundesland'),
  be('België', 'leads_be', 'Provincie', 'provincie');

  final String label;
  final String tableName;
  final String regionLabel;
  final String regionColumn;
  const Country(this.label, this.tableName, this.regionLabel, this.regionColumn);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final LeadsService _service = LeadsService();
  final EmailLogService _emailLogService = EmailLogService();
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();

  bool _isAdmin = false;
  bool _isOwner = false;
  bool _isRealOwner = false;
  UserPermissions _permissions = const UserPermissions();
  UserType _userType = UserType.user;

  bool get _hasLeadAccess => _isOwner || _isAdmin || _userType.hasLeadAccess;

  /// 'catalogus' (default for everyone) or 'leads' (admin/owner only)
  String _currentView = 'catalogus';

  bool _sidebarExpanded = true;
  static const _sidebarExpandedWidth = 220.0;
  static const _sidebarCollapsedWidth = 64.0;

  Country _selectedCountry = Country.nl;

  List<Lead> _allLeads = [];
  List<Lead> _filteredLeads = [];
  bool _isLoading = true;
  String? _errorMessage;
  Map<int, LeadEmailInfo> _sentLeadInfo = {};
  Set<int> _failedLeadIds = {};

  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  String? _activeStatusFilter;

  String? _selectedRegion;
  String? _selectedTaal;
  List<String> _availableRegions = [];
  List<String> _availableTalen = [];

  final Set<int> _selectedLeadIds = {};

  Timer? _searchDebounce;

  static const _statusOptions = ['Nieuw', 'Aangeboden', 'Klant', 'Niet interessant'];
  static const _pageSize = 50;
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _initAdmin();
    _loadLeads();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _initAdmin() async {
    final admin = await _userService.isCurrentUserAdmin();
    final perms = await _userService.getCurrentUserPermissions();
    final owner = await _userService.isCurrentUserOwner();
    final realOwner = await _userService.isRealOwner();
    final user = await _userService.getCurrentUser();
    await _userService.ensureCurrentUserRegistered();
    if (mounted) {
      setState(() {
        _isAdmin = admin;
        _permissions = perms;
        _isOwner = owner;
        _isRealOwner = realOwner;
        _userType = user != null ? _userService.resolveEffectiveRole(user) : UserType.user;
      });
      _enforceMfaIfRequired(user, realOwner);
      _enforceResellerBtwGate(user);
    }
  }

  Future<void> _enforceResellerBtwGate(AppUser? user) async {
    if (user == null) return;
    if (user.userType != UserType.wederverkoper) return;
    if (user.btwGevalideerd) return;
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ResellerBtwGateDialog(
        user: user,
        onVerified: () {
          Navigator.pop(ctx);
          _initAdmin();
        },
      ),
    );
  }

  Future<void> _enforceMfaIfRequired(AppUser? user, bool isOwner) async {
    final effectiveRole = user != null ? _userService.resolveEffectiveRole(user) : UserType.user;
    final needsMfa = isOwner || effectiveRole.mfaRequired;
    if (!needsMfa) return;
    try {
      final factors = await Supabase.instance.client.auth.mfa.listFactors();
      final hasMfa = factors.totp.any((f) => f.status == FactorStatus.verified);
      if (!hasMfa && mounted) {
        final enrolled = await Navigator.push<bool>(context,
          MaterialPageRoute(builder: (_) => const MfaEnrollScreen()));
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
                    UserService.stopImpersonation();
                    await _logout();
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

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadLeads() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final results = await Future.wait([
        _service.fetchLeads(tableName: _selectedCountry.tableName),
        _emailLogService.fetchSentLeadIds(),
        _emailLogService.fetchFailedLeadIds(),
      ]);
      if (mounted) {
        setState(() {
          _allLeads = results[0] as List<Lead>;
          _sentLeadInfo = results[1] as Map<int, LeadEmailInfo>;
          _failedLeadIds = results[2] as Set<int>;
          _isLoading = false;
          _buildRegionOptions();
        });
        _applyFilters();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading dashboard data: $e');
      if (mounted) setState(() { _errorMessage = 'Er is een fout opgetreden bij het laden.'; _isLoading = false; });
    }
  }

  void _buildRegionOptions() {
    final regions = <String>{};
    final talen = <String>{};
    for (final lead in _allLeads) {
      final r = _selectedCountry == Country.be ? lead.regio : lead.region;
      if (r != null && r.trim().isNotEmpty) regions.add(r.trim());
      if (_selectedCountry == Country.be && lead.hoofdtaal != null && lead.hoofdtaal!.trim().isNotEmpty) {
        talen.add(lead.hoofdtaal!.trim());
      }
    }
    _availableRegions = regions.toList()..sort();
    _availableTalen = talen.toList()..sort();
  }

  Future<void> _exportLeads(String mode) async {
    try {
      String csv;
      String filename;
      final now = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final emailInfo = await _emailLogService.fetchSentLeadIds();

      if (mode == 'all') {
        final results = await Future.wait([
          _service.fetchLeads(tableName: 'leads_nl'),
          _service.fetchLeads(tableName: 'leads_de'),
          _service.fetchLeads(tableName: 'leads_be'),
        ]);
        csv = ExportService.allLeadsToCsv({
          'Nederland': results[0],
          'Duitsland': results[1],
          'België': results[2],
        }, emailInfo: emailInfo);
        filename = 'ventoz_leads_alle_landen_$now.csv';
      } else {
        final countryCode = _selectedCountry.name;
        csv = ExportService.leadsToCsv(_allLeads, countryCode, emailInfo: emailInfo);
        filename = 'ventoz_leads_${_selectedCountry.label.toLowerCase()}_$now.csv';
      }

      final path = await ExportService.downloadCsv(csv, filename);
      if (path == null && mounted) return;
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Color(0xFF43A047), size: 48),
            title: const Text('Export geslaagd'),
            content: SelectableText(path!),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Sluiten'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error exporting data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFEF4444)),
        );
      }
    }
  }

  void _onCountryChanged(Set<Country> selection) {
    if (selection.isEmpty) return;
    setState(() {
      _selectedCountry = selection.first;
      _activeStatusFilter = null;
      _selectedRegion = null;
      _selectedTaal = null;
      _selectedLeadIds.clear();
      _searchController.clear();
    });
    _loadLeads();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _applyFilters);
  }

  void _onStatusFilterTap(String? status) {
    setState(() => _activeStatusFilter = _activeStatusFilter == status ? null : status);
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredLeads = _allLeads.where((lead) {
        if (_activeStatusFilter != null && lead.status != _activeStatusFilter) return false;
        if (_selectedRegion != null) {
          final r = _selectedCountry == Country.be ? lead.regio : lead.region;
          if (r?.trim() != _selectedRegion) return false;
        }
        if (_selectedTaal != null && _selectedCountry == Country.be) {
          if (lead.hoofdtaal?.trim() != _selectedTaal) return false;
        }
        if (query.isNotEmpty) {
          return lead.naam.toLowerCase().contains(query) ||
              (lead.plaats?.toLowerCase().contains(query) ?? false);
        }
        return true;
      }).toList();
      _applySorting();
      _visibleCount = _pageSize;
    });
  }

  void _applySorting() {
    _filteredLeads.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0: cmp = a.naam.compareTo(b.naam);
        case 1: cmp = (a.plaats ?? '').compareTo(b.plaats ?? '');
        case 2: cmp = (a.email ?? '').compareTo(b.email ?? '');
        case 3: cmp = a.status.compareTo(b.status);
        default: cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
  }

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
      _applySorting();
    });
  }

  Future<void> _updateStatus(Lead lead, String newStatus) async {
    if (newStatus == 'Klant' && lead.status != 'Klant') {
      _askKortingscodeForKlant(lead);
      return;
    }
    await _doUpdateStatus(lead, newStatus);
  }

  Future<void> _doUpdateStatus(Lead lead, String newStatus) async {
    try {
      await _service.updateStatus(lead.id, newStatus, tableName: _selectedCountry.tableName);
      setState(() {
        final idx = _allLeads.indexWhere((l) => l.id == lead.id);
        if (idx >= 0) _allLeads[idx] = lead.copyWith(status: newStatus);
        final fidx = _filteredLeads.indexWhere((l) => l.id == lead.id);
        if (fidx >= 0) _filteredLeads[fidx] = lead.copyWith(status: newStatus);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating lead status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status bijwerken mislukt. Probeer het opnieuw.')));
      }
    }
  }

  Future<void> _askKortingscodeForKlant(Lead lead) async {
    List<Kortingscode> codes = [];
    try { codes = await KortingscodesService().fetchAll(); } catch (_) {}
    if (!mounted) return;

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        String? selectedCode;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text('${lead.naam} → Klant'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Welke kortingscode heeft deze klant gebruikt?', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(hintText: 'Selecteer kortingscode (optioneel)'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(value: '', child: Text('Geen / onbekend', style: TextStyle(color: Color(0xFF94A3B8)))),
                      ...codes.where((c) => c.actief).map((c) => DropdownMenuItem(
                        value: c.code,
                        child: Row(children: [
                          Text(c.code, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(c.productNamen, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis)),
                        ]),
                      )),
                    ],
                    onChanged: (v) => setDialogState(() => selectedCode = v),
                  ),
                  const SizedBox(height: 8),
                  const Text('Dit helpt bij het meten van campagne-effectiviteit.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, selectedCode ?? ''),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                child: const Text('Bevestig als Klant'),
              ),
            ],
          ),
        );
      },
    );
    if (result == null || !mounted) return;
    await _doUpdateStatus(lead, 'Klant');
    if (result.isNotEmpty) {
      try { await _emailLogService.logConversion(lead.id, lead.naam, result); } catch (_) {}
    }
  }

  void _replaceLead(Lead updated) {
    setState(() {
      final idx = _allLeads.indexWhere((l) => l.id == updated.id);
      if (idx >= 0) _allLeads[idx] = updated;
      final fidx = _filteredLeads.indexWhere((l) => l.id == updated.id);
      if (fidx >= 0) _filteredLeads[fidx] = updated;
    });
  }

  void _openLeadDetail(Lead lead) {
    showDialog(context: context, barrierDismissible: true,
      builder: (_) => LeadDetailModal(lead: lead, country: _selectedCountry, onSaved: _replaceLead));
  }

  void _openOfferModal(Lead lead) {
    showDialog(context: context, barrierDismissible: true,
      builder: (_) => OfferModal(lead: lead, onStatusUpdated: () { _updateStatus(lead, 'Aangeboden'); Navigator.pop(context); }));
  }

  void _toggleLeadSelection(int leadId) {
    setState(() {
      if (_selectedLeadIds.contains(leadId)) { _selectedLeadIds.remove(leadId); }
      else { _selectedLeadIds.add(leadId); }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedLeadIds.length == _filteredLeads.length) { _selectedLeadIds.clear(); }
      else { _selectedLeadIds..clear()..addAll(_filteredLeads.map((l) => l.id)); }
    });
  }

  void _openBatchEmail() {
    final selectedLeads = _filteredLeads.where((l) => _selectedLeadIds.contains(l.id)).toList();
    if (selectedLeads.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => BatchEmailScreen(leads: selectedLeads, country: _selectedCountry, sentLeadInfo: _sentLeadInfo,
        onDone: () { _selectedLeadIds.clear(); _loadLeads(); })));
  }

  bool get _showingLeads => _currentView == 'leads' && _hasLeadAccess;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildAppBar(),
                if (UserService.isImpersonating) _buildImpersonationBanner(),
                _buildQuickAccessBar(),
                Expanded(
                  child: _showingLeads
                      ? Stack(
                          children: [
                            Column(children: [
                              _buildCountryBar(),
                              _buildStatsBar(),
                              _buildFilterBar(),
                              _buildSearchBar(),
                              Expanded(child: _buildBody()),
                            ]),
                            if (_selectedLeadIds.isNotEmpty && _permissions.leadEmailsVersturen) _buildBatchBar(),
                          ],
                        )
                      : ProductCatalogusScreen(key: ValueKey(_userType)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Quick Access Bar ───

  Widget _buildQuickAccessBar() {
    final cards = <Widget>[];

    cards.add(_quickAccessCard(
      icon: Icons.inventory_2_outlined,
      label: 'Productcatalogus',
      color: const Color(0xFF1565C0),
      onTap: () => setState(() => _currentView = 'catalogus'),
    ));

    if (_permissions.voorraadBeheren || _permissions.alleBestellingenBeheren) {
      cards.add(_quickAccessCard(
        icon: Icons.warehouse_outlined,
        label: 'Voorraad',
        color: const Color(0xFF2E7D32),
        onTap: () => context.push('/dashboard/voorraad'),
      ));
    }

    if (_permissions.verkoopkanalenBeheren || _permissions.marktplaatsKoppelingen || _permissions.alleBestellingenBeheren) {
      cards.add(_quickAccessCard(
        icon: Icons.grid_view_rounded,
        label: 'Advertenties',
        color: const Color(0xFFE53238),
        onTap: () => context.push('/dashboard/kanaaloverzicht'),
      ));
    }

    if (_permissions.klantenBeheren || _permissions.alleBestellingenBeheren) {
      cards.add(_quickAccessCard(
        icon: Icons.people_outline_rounded,
        label: 'Klanten',
        color: const Color(0xFF6366F1),
        onTap: () => context.push('/dashboard/klanten'),
      ));
    }

    if (cards.length <= 1) return const SizedBox.shrink();

    final spaced = <Widget>[];
    for (var i = 0; i < cards.length; i++) {
      if (i > 0) spaced.add(const SizedBox(width: 10));
      spaced.add(cards[i]);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(children: spaced),
    );
  }

  Widget _quickAccessCard({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: color.withValues(alpha: 0.04),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: color.withValues(alpha: 0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Sidebar ───

  Widget _buildSidebar() {
    final expanded = _sidebarExpanded;
    final width = expanded ? _sidebarExpandedWidth : _sidebarCollapsedWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: width,
      color: const Color(0xFF37474F),
      child: Column(
        children: [
          // Logo header
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 16 : 12,
              vertical: 16,
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/ventoz_logo.png', width: 36, height: 36),
                ),
                if (expanded) ...[
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Ventoz Sails',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: Color(0xFF546E7A), height: 1, indent: 12, endIndent: 12),
          const SizedBox(height: 8),

          // Nav items
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _sidebarItem(Icons.storefront, 'Assortiment',
                    selected: !_showingLeads,
                    onTap: () => setState(() => _currentView = 'catalogus'),
                  ),
                  if (_hasLeadAccess)
                    _sidebarItem(Icons.people_alt, 'Leadbeheer',
                      selected: _showingLeads,
                      onTap: () => setState(() => _currentView = 'leads'),
                    ),

                  if (_showingLeads && _permissions.wijzigen) ...[
                    const _SidebarDivider(),
                    _sidebarItem(Icons.person_add_alt_1, 'Lead toevoegen', onTap: () async {
                      final added = await Navigator.push<bool>(context,
                        MaterialPageRoute(builder: (_) => AddLeadScreen(country: _selectedCountry)));
                      if (added == true) _loadLeads();
                    }),
                    _sidebarItem(Icons.upload_file, 'Leads importeren', onTap: () async {
                      final imported = await Navigator.push<bool>(context,
                        MaterialPageRoute(builder: (_) => ImportLeadsScreen(country: _selectedCountry)));
                      if (imported == true) _loadLeads();
                    }),
                  ],

                  if (_showingLeads && _permissions.statistiekenBekijken) ...[
                    const _SidebarDivider(),
                    _sidebarItem(Icons.insights, 'Statistieken',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsScreen()))),
                  ],
                  if (_showingLeads && _permissions.leadEmailsVersturen)
                    _sidebarItem(Icons.inbox_outlined, 'E-mails',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmailOverviewScreen()))),
                  if (_showingLeads && _permissions.betaalmethodenOverzicht)
                    _sidebarItem(Icons.payment, 'Betaalmethoden',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsScreen()))),

                  if (_showingLeads && _permissions.kortingscodesBeheren)
                    _sidebarItem(Icons.local_offer_outlined, 'Kortingscodes',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KortingscodesScreen()))),
                  if (_showingLeads && _permissions.emailTemplatesBeheren)
                    _sidebarItem(Icons.mail_outline, 'E-mail Templates',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmailTemplatesScreen()))),
                  if (_showingLeads && _permissions.smtpInstellingen)
                    _sidebarItem(Icons.settings_outlined, 'E-mail Instellingen',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmtpSettingsScreen()))),

                  if (_showingLeads && _permissions.exporteren) ...[
                    const _SidebarDivider(),
                    _buildExportItem(),
                  ],

                  if (_permissions.alleBestellingenBeheren) ...[
                    const _SidebarDivider(),
                    _sidebarItem(Icons.inventory, 'Orderbeheer',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen(adminView: true)))),
                  ],
                  if (_permissions.voorraadBeheren)
                    _sidebarItem(Icons.warehouse, 'Voorraad',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryDashboardScreen()))),
                  if (_permissions.eigenBestelhistorie)
                    _sidebarItem(Icons.receipt_long, 'Mijn bestellingen',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()))),

                  if (_permissions.betaalgatewayInstellingen || _permissions.bedrijfsgegevensBewerken ||
                      _permissions.orderTemplatesBewerken || _permissions.uitgelichteProducten || _permissions.gebruikersBeheren) ...[
                    const _SidebarDivider(),
                    if (_permissions.betaalgatewayInstellingen)
                      _sidebarItem(Icons.credit_card, 'Betaalinstellingen',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentSettingsScreen()))),
                    if (_permissions.bedrijfsgegevensBewerken)
                      _sidebarItem(Icons.business, 'Bedrijfsgegevens',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanySettingsScreen()))),
                    if (_permissions.orderTemplatesBewerken)
                      _sidebarItem(Icons.article_outlined, 'Template-editor',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderTemplateEditorScreen()))),
                    if (_permissions.uitgelichteProducten)
                      _sidebarItem(Icons.star_outline, 'Uitgelichte producten',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeaturedProductsScreen()))),
                    if (_permissions.gebruikersBeheren)
                      _sidebarItem(Icons.group_outlined, 'Gebruikersbeheer',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen()))),
                  ],
                ],
              ),
            ),
          ),

          // Bottom section
          const Divider(color: Color(0xFF546E7A), height: 1, indent: 12, endIndent: 12),
          _sidebarItem(Icons.language, 'Naar website', onTap: () => context.go('/')),
          if (_showingLeads)
            _sidebarItem(Icons.refresh, 'Vernieuwen', onTap: _loadLeads),
          _sidebarItem(Icons.person_outline, 'Eigen gegevens', onTap: _showProfileDialog),
          _buildSidebarAccountItem(),
          _sidebarItem(
            expanded ? Icons.chevron_left : Icons.chevron_right,
            expanded ? 'Inklappen' : 'Uitklappen',
            onTap: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String label, {VoidCallback? onTap, bool selected = false}) {
    final expanded = _sidebarExpanded;
    return Tooltip(
      message: expanded ? '' : label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: Colors.white.withValues(alpha: 0.08),
          splashColor: Colors.white.withValues(alpha: 0.12),
          child: Container(
            height: 42,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0),
            child: Row(
              mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: selected ? Colors.white : Colors.white70),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExportItem() {
    if (_sidebarExpanded) {
      return _buildExportPopup(
        child: _sidebarItem(Icons.download, 'Leads exporteren'),
      );
    }
    return _buildExportPopup(
      child: _sidebarItem(Icons.download, 'Exporteren'),
    );
  }

  Widget _buildExportPopup({required Widget child}) {
    return PopupMenuButton<String>(
      tooltip: '',
      onSelected: _exportLeads,
      offset: const Offset(220, 0),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'current',
          child: ListTile(
            leading: const Icon(Icons.flag, size: 20),
            title: Text('${_selectedCountry.label} exporteren', style: const TextStyle(fontSize: 13)),
            subtitle: Text('${_allLeads.length} leads', style: const TextStyle(fontSize: 11)),
            dense: true, contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'all',
          child: ListTile(
            leading: Icon(Icons.public, size: 20),
            title: Text('Alle landen exporteren', style: TextStyle(fontSize: 13)),
            subtitle: Text('NL + DE + BE', style: TextStyle(fontSize: 11)),
            dense: true, contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: child,
    );
  }

  Widget _buildSidebarAccountItem() {
    if (_hasMfa == null) _checkMfaStatus();
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';
    final hasMfa = _hasMfa ?? false;

    Widget item = _sidebarItem(Icons.account_circle, _sidebarExpanded ? email : 'Account');

    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(220, 0),
      onSelected: (val) async {
        switch (val) {
          case 'impersonate':
            if (UserService.isImpersonating) { _stopImpersonation(); } else { _showImpersonationDialog(); }
          case 'mfa_enroll':
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const MfaEnrollScreen()));
            _hasMfa = null;
            if (mounted) setState(() {});
          case 'mfa_unenroll':
            await _unenrollMfa();
          case 'logout':
            UserService.stopImpersonation();
            await _logout();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(email, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF37474F), fontSize: 13)),
            const SizedBox(height: 2),
            Row(children: [
              Icon(hasMfa ? Icons.verified_user : Icons.shield_outlined,
                  size: 14, color: hasMfa ? const Color(0xFF43A047) : Colors.blueGrey[400]),
              const SizedBox(width: 4),
              Text(hasMfa ? 'MFA actief' : 'MFA niet ingesteld',
                  style: TextStyle(fontSize: 12, color: hasMfa ? const Color(0xFF43A047) : Colors.blueGrey[400])),
            ]),
            Row(children: [
              Icon(_isOwner ? Icons.stars : _isAdmin ? Icons.admin_panel_settings : Icons.person,
                  size: 14, color: _isOwner ? const Color(0xFFE65100) : _isAdmin ? const Color(0xFF455A64) : Colors.blueGrey[400]),
              const SizedBox(width: 4),
              Text(_isOwner ? 'Eigenaar' : _isAdmin ? 'Beheerder' : _userType.label,
                  style: TextStyle(fontSize: 12, color: _isOwner ? const Color(0xFFE65100) : _isAdmin ? const Color(0xFF455A64) : Colors.blueGrey[400])),
            ]),
            const Divider(),
          ]),
        ),
        if (_isRealOwner)
          PopupMenuItem(
            value: 'impersonate',
            child: ListTile(
              leading: Icon(UserService.isImpersonating ? Icons.person_off : Icons.switch_account,
                color: UserService.isImpersonating ? const Color(0xFFE65100) : null),
              title: Text(UserService.isImpersonating ? 'Testmodus stoppen' : 'Bekijk als...',
                style: TextStyle(color: UserService.isImpersonating ? const Color(0xFFE65100) : null)),
              dense: true, contentPadding: EdgeInsets.zero,
            ),
          ),
        if (!hasMfa)
          const PopupMenuItem(value: 'mfa_enroll', child: ListTile(leading: Icon(Icons.security), title: Text('MFA Inschakelen'), dense: true, contentPadding: EdgeInsets.zero)),
        if (hasMfa && !_userType.mfaRequired)
          const PopupMenuItem(value: 'mfa_unenroll', child: ListTile(leading: Icon(Icons.security, color: Color(0xFFE53935)), title: Text('MFA Uitschakelen'), dense: true, contentPadding: EdgeInsets.zero)),
        const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout, color: Color(0xFFE53935)), title: Text('Uitloggen'), dense: true, contentPadding: EdgeInsets.zero)),
      ],
      child: item,
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: 56,
      color: const Color(0xFF37474F),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerLeft,
      child: Text(
        _showingLeads ? 'Leadbeheer' : 'Assortiment',
        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      ),
    );
  }

  bool? _hasMfa;

  Future<void> _checkMfaStatus() async {
    try {
      final factors = await Supabase.instance.client.auth.mfa.listFactors();
      final has = factors.totp.any((f) => f.status == FactorStatus.verified);
      if (mounted) setState(() => _hasMfa = has);
    } catch (_) {
      if (mounted) setState(() => _hasMfa = false);
    }
  }

  Future<void> _unenrollMfa() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('MFA Uitschakelen'),
        content: const Text('Weet je zeker dat je tweestapsverificatie wilt uitschakelen?\n\nJe account is dan minder goed beveiligd.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Uitschakelen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final factors = await Supabase.instance.client.auth.mfa.listFactors();
      for (final f in factors.totp.where((f) => f.status == FactorStatus.verified)) {
        await Supabase.instance.client.auth.mfa.unenroll(f.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MFA is uitgeschakeld'), backgroundColor: Color(0xFFF59E0B)),
        );
        _hasMfa = false;
        setState(() {});
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error disabling MFA: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fout bij uitschakelen MFA. Probeer het opnieuw.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showProfileDialog() async {
    final user = await _userService.getCurrentUser();
    if (!mounted || user == null) return;

    final voornaamCtrl = TextEditingController(text: user.voornaam ?? '');
    final achternaamCtrl = TextEditingController(text: user.achternaam ?? '');
    final adresRaw = user.adres ?? '';
    final adresMatch = RegExp(r'^(.+?)\s+(\d+\S*)$').firstMatch(adresRaw.trim());
    final straatCtrl = TextEditingController(text: adresMatch?.group(1) ?? adresRaw);
    final huisnummerCtrl = TextEditingController(text: adresMatch?.group(2) ?? '');
    final postcodeCtrl = TextEditingController(text: user.postcode ?? '');
    final woonplaatsCtrl = TextEditingController(text: user.woonplaats ?? '');
    final telefoonCtrl = TextEditingController(text: user.telefoon ?? '');
    final bedrijfCtrl = TextEditingController(text: user.bedrijfsnaam ?? '');
    final ibanCtrl = TextEditingController(text: user.iban ?? '');
    String? ibanError;

    final fAdresRaw = user.factuurAdres ?? '';
    final fAdresMatch = RegExp(r'^(.+?)\s+(\d+\S*)$').firstMatch(fAdresRaw.trim());
    final fStraatCtrl = TextEditingController(text: user.hasFactuurAdres ? (fAdresMatch?.group(1) ?? fAdresRaw) : '');
    final fHuisnummerCtrl = TextEditingController(text: user.hasFactuurAdres ? (fAdresMatch?.group(2) ?? '') : '');
    final fPostcodeCtrl = TextEditingController(text: user.factuurPostcode ?? '');
    final fWoonplaatsCtrl = TextEditingController(text: user.factuurWoonplaats ?? '');
    var factuurGelijk = !user.hasFactuurAdres;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          icon: const Icon(Icons.person_outline, color: Color(0xFF455A64), size: 40),
          title: const Text('Eigen gegevens'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _readonlyField('E-mail', user.email),
                  const SizedBox(height: 6),
                  _readonlyField('Type', user.userType.label),
                  const SizedBox(height: 6),
                  _readonlyField('Land', VatService.allowedCountryLabels[user.landCode] ?? user.landCode),
                  const SizedBox(height: 16),
                  const Text('Persoonlijke gegevens', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: voornaamCtrl, decoration: const InputDecoration(labelText: 'Voornaam', border: OutlineInputBorder(), isDense: true))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: achternaamCtrl, decoration: const InputDecoration(labelText: 'Achternaam', border: OutlineInputBorder(), isDense: true))),
                  ]),
                  const SizedBox(height: 8),
                  TextField(controller: telefoonCtrl, decoration: const InputDecoration(labelText: 'Telefoon', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.phone_outlined, size: 18))),
                  const SizedBox(height: 16),
                  const Text('Bezorgadres', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  AddressFormFields(
                    postcodeCtrl: postcodeCtrl,
                    huisnummerCtrl: huisnummerCtrl,
                    straatCtrl: straatCtrl,
                    woonplaatsCtrl: woonplaatsCtrl,
                    landCode: user.landCode,
                    t: (key) => const {
                      'postcode': 'Postcode', 'huisnummer': 'Huisnr.',
                      'straat': 'Straat', 'adres': 'Adres',
                      'woonplaats': 'Woonplaats', 'verplicht': 'Verplicht',
                      'adres_niet_gevonden': 'Adres niet gevonden',
                    }[key] ?? key,
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: factuurGelijk,
                    onChanged: (v) => setDlgState(() => factuurGelijk = v ?? true),
                    title: const Text('Factuuradres is gelijk aan bezorgadres', style: TextStyle(fontSize: 13)),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  if (!factuurGelijk) ...[
                    const SizedBox(height: 8),
                    const Text('Factuuradres', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    AddressFormFields(
                      postcodeCtrl: fPostcodeCtrl,
                      huisnummerCtrl: fHuisnummerCtrl,
                      straatCtrl: fStraatCtrl,
                      woonplaatsCtrl: fWoonplaatsCtrl,
                      landCode: user.landCode,
                      t: (key) => const {
                        'postcode': 'Postcode', 'huisnummer': 'Huisnr.',
                        'straat': 'Straat', 'adres': 'Adres',
                        'woonplaats': 'Woonplaats', 'verplicht': 'Verplicht',
                        'adres_niet_gevonden': 'Adres niet gevonden',
                      }[key] ?? key,
                    ),
                  ],
                  if (user.isBedrijf) ...[
                    const SizedBox(height: 16),
                    const Text('Bedrijfsgegevens', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextField(controller: bedrijfCtrl, decoration: const InputDecoration(labelText: 'Bedrijfsnaam', border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.business, size: 18))),
                    const SizedBox(height: 8),
                    _readonlyField('BTW-nummer', user.btwNummer ?? '-',
                        icon: user.btwGevalideerd ? Icons.check_circle : Icons.cancel,
                        iconColor: user.btwGevalideerd ? const Color(0xFF2E7D32) : const Color(0xFFEF4444)),
                    if (user.btwVerlegd)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('BTW verlegd (intracommunautaire levering)', style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w500)),
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ibanCtrl,
                      decoration: InputDecoration(
                        labelText: 'IBAN',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: const Icon(Icons.account_balance, size: 18),
                        errorText: ibanError,
                      ),
                      onChanged: (v) {
                        final err = VatService.validateIban(v);
                        setDlgState(() => ibanError = err);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Sluiten')),
            ElevatedButton(
              onPressed: () async {
                if (ibanError != null) return;
                final straat = straatCtrl.text.trim();
                final nr = huisnummerCtrl.text.trim();
                final adresCombined = nr.isEmpty ? straat : '$straat $nr';
                String? fAdresCombined;
                if (!factuurGelijk) {
                  final fStraat = fStraatCtrl.text.trim();
                  final fNr = fHuisnummerCtrl.text.trim();
                  fAdresCombined = fNr.isEmpty ? fStraat : '$fStraat $fNr';
                }
                final updated = user.copyWith(
                  voornaam: voornaamCtrl.text.trim().isEmpty ? null : voornaamCtrl.text.trim(),
                  achternaam: achternaamCtrl.text.trim().isEmpty ? null : achternaamCtrl.text.trim(),
                  adres: adresCombined.isEmpty ? null : adresCombined,
                  postcode: postcodeCtrl.text.trim().isEmpty ? null : postcodeCtrl.text.trim(),
                  woonplaats: woonplaatsCtrl.text.trim().isEmpty ? null : woonplaatsCtrl.text.trim(),
                  telefoon: telefoonCtrl.text.trim().isEmpty ? null : telefoonCtrl.text.trim(),
                  factuurAdres: factuurGelijk ? null : (fAdresCombined?.isEmpty ?? true ? null : fAdresCombined),
                  factuurPostcode: factuurGelijk ? null : (fPostcodeCtrl.text.trim().isEmpty ? null : fPostcodeCtrl.text.trim()),
                  factuurWoonplaats: factuurGelijk ? null : (fWoonplaatsCtrl.text.trim().isEmpty ? null : fWoonplaatsCtrl.text.trim()),
                  bedrijfsnaam: bedrijfCtrl.text.trim().isEmpty ? null : bedrijfCtrl.text.trim(),
                  iban: ibanCtrl.text.trim().isEmpty ? null : ibanCtrl.text.replaceAll(RegExp(r'\s'), '').toUpperCase(),
                );
                try {
                  await _userService.updateOwnProfile(updated);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gegevens opgeslagen')));
                } catch (e) {
                  if (kDebugMode) debugPrint('Error saving profile: $e');
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opslaan mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFEF4444)));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
              child: const Text('Opslaan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readonlyField(String label, String value, {IconData? icon, Color? iconColor}) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: TextEditingController(text: value),
          enabled: false,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
            fillColor: const Color(0xFFF5F5F5),
            filled: true,
          ),
        ),
      ),
      if (icon != null) ...[
        const SizedBox(width: 8),
        Icon(icon, color: iconColor, size: 20),
      ],
    ]);
  }

  void _showImpersonationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.switch_account, color: Color(0xFF455A64), size: 40),
        title: const Text('Bekijk als...'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Test de app vanuit het perspectief van een ander type gebruiker. '
                'Je kunt niets wijzigen in testmodus.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
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
                final color = switch (profile.userType) {
                  UserType.wederverkoper => const Color(0xFF1565C0),
                  UserType.klant => const Color(0xFF2E7D32),
                  UserType.admin => const Color(0xFF455A64),
                  UserType.prospect => const Color(0xFFF59E0B),
                  UserType.user => Colors.blueGrey,
                  _ => Colors.blueGrey,
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    title: Text(profile.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _describeProfile(profile),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    tileColor: Colors.grey[50],
                    dense: true,
                    onTap: () {
                      Navigator.pop(ctx);
                      _startImpersonation(profile);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
        ],
      ),
    );
  }

  String _describeProfile(ImpersonationProfile p) {
    final parts = <String>[];
    parts.add(p.userType.label);
    parts.add(p.isParticulier ? 'Particulier' : 'Bedrijf');
    parts.add(p.landCode);
    if (p.kortingPermanent > 0) parts.add('${p.kortingPermanent.toStringAsFixed(0)}% korting');
    if (p.btwGevalideerd) parts.add('BTW geldig');
    if (p.isAdmin) parts.add('Admin');
    return parts.join(' \u2022 ');
  }

  Future<void> _startImpersonation(ImpersonationProfile profile) async {
    await UserService.startImpersonation(profile);

    if (!profile.userType.hasDashboardAccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Testmodus: ${profile.label} — geen dashboard-toegang, doorgestuurd naar catalogus'),
        backgroundColor: const Color(0xFFE65100),
      ));
      context.go('/');
      return;
    }

    _initAdmin();
    _loadLeads();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Testmodus: ${profile.label}'),
        backgroundColor: const Color(0xFFE65100),
      ));
    }
  }

  void _stopImpersonation() {
    UserService.stopImpersonation();
    _initAdmin();
    _loadLeads();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Testmodus gestopt - terug naar eigen account'),
        backgroundColor: Color(0xFF43A047),
      ));
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uitloggen'),
        content: const Text('Weet je zeker dat je wilt uitloggen? Je gaat terug naar de startpagina.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Uitloggen')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/');
  }

  Widget _buildImpersonationBanner() {
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
          onPressed: _stopImpersonation,
          icon: const Icon(Icons.close, color: Colors.white, size: 16),
          label: const Text('Stoppen', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildCountryBar() {
    return Container(
      color: const Color(0xFF37474F),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Center(
        child: SegmentedButton<Country>(
          segments: Country.values.map((c) => ButtonSegment<Country>(value: c, label: Text(c.label), icon: Icon(_countryIcon(c)))).toList(),
          selected: {_selectedCountry},
          onSelectionChanged: _onCountryChanged,
          showSelectedIcon: false,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white.withValues(alpha: 0.2) : Colors.transparent),
            foregroundColor: WidgetStateProperty.all(Colors.white),
            side: WidgetStateProperty.all(BorderSide(color: Colors.white.withValues(alpha: 0.3))),
            textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  IconData _countryIcon(Country c) => switch (c) { Country.nl => Icons.flag, Country.de => Icons.flag_outlined, Country.be => Icons.outlined_flag };

  Widget _buildStatsBar() {
    final counts = <String, int>{};
    for (final lead in _allLeads) { counts[lead.status] = (counts[lead.status] ?? 0) + 1; }
    return Container(
      color: const Color(0xFF37474F),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(children: [
        _statChip('Totaal', _allLeads.length, Colors.white.withValues(alpha: 0.2), null),
        const SizedBox(width: 8),
        _statChip('Nieuw', counts['Nieuw'] ?? 0, const Color(0xFF3B82F6), 'Nieuw'),
        const SizedBox(width: 8),
        _statChip('Aangeboden', counts['Aangeboden'] ?? 0, const Color(0xFFF59E0B), 'Aangeboden'),
        const SizedBox(width: 8),
        _statChip('Klant', counts['Klant'] ?? 0, const Color(0xFF10B981), 'Klant'),
      ]),
    );
  }

  Widget _statChip(String label, int count, Color color, String? filterValue) {
    final isActive = _activeStatusFilter == filterValue;
    final isTotaal = filterValue == null;
    return GestureDetector(
      onTap: () => _onStatusFilterTap(filterValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isTotaal && _activeStatusFilter == null ? Colors.white.withValues(alpha: 0.2) : isActive ? color : color.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
          border: isActive || (isTotaal && _activeStatusFilter == null) ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Text('$label: $count', style: TextStyle(color: Colors.white, fontSize: 12,
          fontWeight: isActive || (isTotaal && _activeStatusFilter == null) ? FontWeight.w800 : FontWeight.w600)),
      ),
    );
  }

  Widget _buildFilterBar() {
    if (_availableRegions.isEmpty && _availableTalen.isEmpty) return const SizedBox.shrink();
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(children: [
        const Icon(Icons.filter_list, size: 18, color: Color(0xFF64748B)),
        const SizedBox(width: 8),
        if (_availableRegions.isNotEmpty)
          Expanded(child: _filterDropdown(
            value: _selectedRegion,
            hint: _selectedCountry == Country.be ? 'Alle regio\'s' : 'Alle ${_selectedCountry.regionLabel.toLowerCase()}s',
            items: _availableRegions,
            onChanged: (v) { setState(() => _selectedRegion = v); _applyFilters(); },
          )),
        if (_selectedCountry == Country.be && _availableTalen.isNotEmpty) ...[
          const SizedBox(width: 12),
          Expanded(child: _filterDropdown(
            value: _selectedTaal, hint: 'Alle talen', items: _availableTalen,
            onChanged: (v) { setState(() => _selectedTaal = v); _applyFilters(); },
          )),
        ],
        if (_selectedRegion != null || _selectedTaal != null)
          IconButton(icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)), tooltip: 'Filters wissen',
            onPressed: () { setState(() { _selectedRegion = null; _selectedTaal = null; }); _applyFilters(); }),
      ]),
    );
  }

  Widget _filterDropdown({required String? value, required String hint, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: value != null ? const Color(0xFF455A64) : const Color(0xFFE2E8F0))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          isDense: true, isExpanded: true,
          style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
          icon: const Icon(Icons.arrow_drop_down, size: 18),
          items: [
            DropdownMenuItem<String>(value: null, child: Text(hint, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
            ...items.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Zoek op naam of plaats...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); _applyFilters(); })
              : null,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(), SizedBox(height: 16),
        Text('Leads laden...', style: TextStyle(color: Color(0xFF64748B))),
      ]));
    }
    if (_errorMessage != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
        const SizedBox(height: 16),
        Text(_errorMessage!, style: const TextStyle(color: Color(0xFF64748B)), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _loadLeads, child: const Text('Opnieuw proberen')),
      ]));
    }
    if (_filteredLeads.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.search_off, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text(_searchController.text.isEmpty ? 'Geen leads gevonden' : 'Geen resultaten voor "${_searchController.text}"',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 16)),
      ]));
    }

    final itemCount = _visibleCount.clamp(0, _filteredLeads.length);
    final hasMore = itemCount < _filteredLeads.length;
    final allSelected = _selectedLeadIds.length == _filteredLeads.length && _filteredLeads.isNotEmpty;

    return Column(
      children: [
        _buildTableHeader(allSelected),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (hasMore && n.metrics.pixels > n.metrics.maxScrollExtent - 200) {
                setState(() => _visibleCount = (_visibleCount + _pageSize).clamp(0, _filteredLeads.length));
              }
              return false;
            },
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(0, 0, 0, _selectedLeadIds.isNotEmpty ? 70 : 0),
              itemCount: itemCount + (hasMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= itemCount) {
                  return const Padding(padding: EdgeInsets.all(16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
                }
                return _buildLeadTile(_filteredLeads[i]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(bool allSelected) {
    const headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B));
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        SizedBox(width: 28, child: Checkbox(value: allSelected, tristate: _selectedLeadIds.isNotEmpty && !allSelected,
          onChanged: (_) => _toggleSelectAll(), activeColor: const Color(0xFF455A64), visualDensity: VisualDensity.compact)),
        Expanded(flex: 3, child: _sortableHeader('Naam', 0, headerStyle)),
        Expanded(flex: 2, child: _sortableHeader('Plaats', 1, headerStyle)),
        Expanded(flex: 3, child: _sortableHeader('E-mail', 2, headerStyle)),
        Expanded(flex: 2, child: _sortableHeader('Status', 3, headerStyle)),
        const SizedBox(width: 90, child: Text('Actie', style: headerStyle, textAlign: TextAlign.center)),
      ]),
    );
  }

  Widget _sortableHeader(String label, int index, TextStyle style) {
    final active = _sortColumnIndex == index;
    return InkWell(
      onTap: () => _onSort(index),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: active ? style.copyWith(color: const Color(0xFF1E293B)) : style),
        if (active) Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: const Color(0xFF1E293B)),
      ]),
    );
  }

  Widget _buildLeadTile(Lead lead) {
    final isSelected = _selectedLeadIds.contains(lead.id);
    final emailInfo = _sentLeadInfo[lead.id];
    final wasSent = emailInfo != null;
    final hasFailed = _failedLeadIds.contains(lead.id);

    return Material(
      color: isSelected ? const Color(0xFF455A64).withValues(alpha: 0.04) : Colors.white,
      child: InkWell(
        onTap: () => _openLeadDetail(lead),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
          child: Row(children: [
            if (_permissions.emailsVersturen)
              SizedBox(width: 28, child: Checkbox(value: isSelected, onChanged: (_) => _toggleLeadSelection(lead.id),
                activeColor: const Color(0xFF455A64), visualDensity: VisualDensity.compact)),
            Expanded(flex: 3, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lead.naam, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontSize: 13), overflow: TextOverflow.ellipsis),
                if (lead.contactpersonen != null && lead.contactpersonen!.isNotEmpty)
                  Text(lead.contactpersonen!, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), overflow: TextOverflow.ellipsis),
              ],
            )),
            Expanded(flex: 2, child: Text(lead.plaats ?? '—', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
            Expanded(flex: 3, child: lead.email != null
              ? Text(lead.email!, style: const TextStyle(color: Color(0xFF455A64), fontSize: 13), overflow: TextOverflow.ellipsis)
              : const Text('—', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13))),
            Expanded(flex: 2, child: lead.isKlant
                ? _buildKlantBadge()
                : _permissions.wijzigen ? _buildStatusDropdown(lead) : _buildStatusLabel(lead)),
            SizedBox(width: 110, child: Row(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              if (hasFailed)
                const Tooltip(message: 'E-mail verzending mislukt',
                  child: Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.error, size: 14, color: Color(0xFFEF4444)))),
              if (wasSent)
                Tooltip(
                  message: '${emailInfo.count}x verstuurd – laatst op ${emailInfo.lastSentDate.day}-${emailInfo.lastSentDate.month}-${emailInfo.lastSentDate.year}',
                  child: Padding(padding: const EdgeInsets.only(right: 4), child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 2),
                    Text('${emailInfo.count}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                  ])),
                ),
              if (_permissions.emailsVersturen)
                SizedBox(height: 30, child: ElevatedButton(
                  onPressed: () => _openOfferModal(lead),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: wasSent ? const Color(0xFF64748B) : Colors.blueGrey[700],
                    foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), minimumSize: Size.zero),
                  child: const Text('Actie'),
                )),
            ])),
          ]),
        ),
      ),
    );
  }

  Widget _buildStatusLabel(Lead lead) {
    final status = lead.status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppTheme.statusColor(status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(color: AppTheme.statusColor(status), fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }

  Widget _buildKlantBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppTheme.statusColor('Klant').withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Klant', style: TextStyle(color: AppTheme.statusColor('Klant'), fontWeight: FontWeight.w600, fontSize: 11)),
        const SizedBox(width: 3),
        Icon(Icons.lock_outline, size: 10, color: AppTheme.statusColor('Klant')),
      ]),
    );
  }

  Widget _buildStatusDropdown(Lead lead) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: AppTheme.statusColor(lead.status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusOptions.contains(lead.status) ? lead.status : _statusOptions.first,
          isDense: true,
          style: TextStyle(color: AppTheme.statusColor(lead.status), fontWeight: FontWeight.w600, fontSize: 11),
          dropdownColor: Colors.white,
          icon: Icon(Icons.arrow_drop_down, color: AppTheme.statusColor(lead.status), size: 16),
          items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: AppTheme.statusColor(s), fontSize: 11)))).toList(),
          onChanged: (newStatus) { if (newStatus != null && newStatus != lead.status) _updateStatus(lead, newStatus); },
        ),
      ),
    );
  }

  Widget _buildBatchBar() {
    return Positioned(left: 0, right: 0, bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFF37474F),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, -2))]),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Text('${_selectedLeadIds.length} geselecteerd', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const Spacer(),
          TextButton(onPressed: () => setState(() => _selectedLeadIds.clear()),
            child: const Text('Deselecteer', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13))),
          const SizedBox(width: 12),
          ElevatedButton.icon(icon: const Icon(Icons.send, size: 16), label: const Text('Batch e-mail'), onPressed: _openBatchEmail,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12))),
        ]),
      ),
    );
  }
}

class _ResellerBtwGateDialog extends StatefulWidget {
  final AppUser user;
  final VoidCallback onVerified;

  const _ResellerBtwGateDialog({required this.user, required this.onVerified});

  @override
  State<_ResellerBtwGateDialog> createState() => _ResellerBtwGateDialogState();
}

class _ResellerBtwGateDialogState extends State<_ResellerBtwGateDialog> {
  final _btwCtrl = TextEditingController();
  final _vatService = VatService();
  bool _verifying = false;
  String? _error;
  String? _successName;
  String _lang = 'nl';
  late AppLocalizations _l = AppLocalizations(_lang);

  @override
  void initState() {
    super.initState();
    UserService().getUserLanguage().then((lang) {
      if (mounted) setState(() { _lang = lang; _l = AppLocalizations(lang); });
    });
  }

  @override
  void dispose() {
    _btwCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final raw = _btwCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = _l.t('btw_nummer_verplicht'));
      return;
    }

    setState(() { _verifying = true; _error = null; _successName = null; });

    final result = await _vatService.validateVat(raw);

    if (!mounted) return;

    if (result.valid) {
      try {
        final userService = UserService();
        final current = await userService.getCurrentUser();
        if (current != null) {
          await userService.updateUser(current.copyWith(
            btwNummer: raw.replaceAll(RegExp(r'[\s\-.]'), '').toUpperCase(),
            btwGevalideerd: true,
            btwValidatieDatum: DateTime.now(),
          ));
        }
        setState(() {
          _verifying = false;
          _successName = result.name;
        });
        await Future.delayed(const Duration(seconds: 1));
        widget.onVerified();
      } catch (e) {
        if (kDebugMode) debugPrint('Error verifying VAT: $e');
        setState(() { _verifying = false; _error = _l.t('opslaan_mislukt'); });
      }
    } else {
      setState(() {
        _verifying = false;
        _error = result.error ?? _l.t('btw_verificatie_mislukt');
      });
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.verified_user, color: Color(0xFFE65100), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(_l.t('btw_verificatie_vereist'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
        ]),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _l.t('btw_verificatie_tekst'),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
            ),
            if (widget.user.kortingPermanent > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)),
                child: Row(children: [
                  const Icon(Icons.discount, size: 16, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 8),
                  Text('${_l.t('wederverkoperskorting')}: ${widget.user.kortingPermanent.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _btwCtrl,
              decoration: InputDecoration(
                labelText: _l.t('btw_nummer'),
                hintText: _l.t('btw_nummer_hint'),
                prefixIcon: const Icon(Icons.receipt_long, size: 20),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFE53935))),
            ],
            if (_successName != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(6)),
                child: Row(children: [
                  const Icon(Icons.check_circle, size: 16, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${_l.t('geverifieerd')}: $_successName', style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32)))),
                ]),
              ),
            ],
          ]),
        ),
        actions: [
          TextButton(
            onPressed: _verifying ? null : _logout,
            child: Text(_l.t('uitloggen'), style: const TextStyle(color: Color(0xFF78909C))),
          ),
          ElevatedButton.icon(
            icon: _verifying
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.verified, size: 18),
            label: Text(_verifying ? _l.t('verifieren_bezig') : _l.t('verifieren')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF455A64),
              foregroundColor: Colors.white,
            ),
            onPressed: _verifying ? null : _verify,
          ),
        ],
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Divider(color: Color(0xFF546E7A), height: 1, indent: 12, endIndent: 12),
    );
  }
}
