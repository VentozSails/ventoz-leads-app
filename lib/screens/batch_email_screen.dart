import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../models/email_template.dart';
import '../models/product.dart';
import '../models/kortingscode.dart';
import '../models/email_log.dart';
import '../services/email_templates_service.dart';
import '../services/producten_service.dart';
import '../services/kortingscodes_service.dart';
import '../services/smtp_service.dart';
import '../services/email_log_service.dart';
import '../services/leads_service.dart';
import '../services/user_service.dart';
import '../widgets/lead_detail_modal.dart';
import 'dashboard_screen.dart';

class BatchEmailScreen extends StatefulWidget {
  final List<Lead> leads;
  final Country country;
  final Map<int, LeadEmailInfo> sentLeadInfo;
  final VoidCallback onDone;

  const BatchEmailScreen({
    super.key,
    required this.leads,
    required this.country,
    required this.sentLeadInfo,
    required this.onDone,
  });

  @override
  State<BatchEmailScreen> createState() => _BatchEmailScreenState();
}

enum _Phase { overview, stepper, sending, done }

class _BatchEmailScreenState extends State<BatchEmailScreen> {
  final EmailTemplatesService _templateService = EmailTemplatesService();
  final ProductenService _productenService = ProductenService();
  final KortingscodesService _kortingscodesService = KortingscodesService();
  final SmtpService _smtpService = SmtpService();
  final EmailLogService _emailLogService = EmailLogService();
  final LeadsService _leadsService = LeadsService();

  late List<Lead> _leads;
  _Phase _phase = _Phase.overview;

  // Shared config
  List<EmailTemplate> _templates = [];
  EmailTemplate? _selectedTemplate;
  List<Product> _producten = [];
  final Set<int> _selectedProductIds = {};
  Kortingscode? _currentKortingscode;
  SmtpSettings? _smtpSettings;
  bool _loading = true;

  // Action config
  int _kortingspercentage = 10;
  DateTime? _geldigTot;
  int _proefperiodeDagen = 30;

  // Download link invite
  bool _includeDownloadLink = false;
  UserType _inviteUserType = UserType.prospect;
  double _resellerKorting = 15;

  // Stepper
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Map<int, String> _customBodies = {};

  // Sending
  int _sendProgress = 0;
  final List<String> _sendErrors = [];
  int _sendSuccess = 0;

  @override
  void initState() {
    super.initState();
    _leads = List.of(widget.leads);
    _loadAll();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _templateService.fetchTemplates(),
        _productenService.fetchProducten(),
        _smtpService.loadSettings(),
      ]);
      if (mounted) {
        setState(() {
          _templates = results[0] as List<EmailTemplate>;
          _producten = results[1] as List<Product>;
          _smtpSettings = results[2] as SmtpSettings?;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Product> get _selectedProducts =>
      _producten.where((p) => _selectedProductIds.contains(p.id)).toList();

  String get _selectedProductNamen =>
      _selectedProducts.map((p) => p.naam).join(', ');

  List<(String, String?)> get _selectedProductTuples =>
      _selectedProducts.map((p) => (p.naam, p.webshopUrl)).toList();

  void _toggleProduct(int id) {
    setState(() {
      if (_selectedProductIds.contains(id)) {
        _selectedProductIds.remove(id);
      } else {
        _selectedProductIds.add(id);
      }
    });
    _resolveKortingscode();
  }

  Future<void> _resolveKortingscode() async {
    if (_selectedProductIds.isEmpty) {
      setState(() => _currentKortingscode = null);
      return;
    }
    try {
      final code = await _kortingscodesService.findOrCreate(
        _selectedProductIds.toList(),
        _selectedProductNamen,
        kortingspercentage: _kortingspercentage,
        geldigTot: _geldigTot,
        proefperiodeDagen: _proefperiodeDagen,
      );
      if (mounted) setState(() => _currentKortingscode = code);
    } catch (_) {}
  }

  String _buildKortingscodeBlock() {
    if (_currentKortingscode == null) return '';
    final k = _currentKortingscode!;
    final buf = StringBuffer();
    buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('   UW KORTINGSCODE: ${k.code}');
    buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('• ${k.kortingspercentage}% korting op uw bestelling');
    buf.writeln('• ${k.proefperiodeLabel} gratis uitproberen');
    if (k.geldigTot != null) {
      buf.writeln('• Geldig tot: ${k.geldigTotLabel}');
    }
    buf.writeln('Gebruik deze code bij uw bestelling op ventoz.nl');
    buf.write('Geldig voor: ${k.productNamen}');
    return buf.toString();
  }

  String _buildDownloadBlock() {
    if (!_includeDownloadLink) return '';
    final buf = StringBuffer();
    buf.writeln('');
    buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('   VENTOZ SAILS APP');
    buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('');
    buf.writeln('Download onze app voor exclusieve toegang tot de');
    buf.writeln('volledige catalogus, actuele prijzen en eenvoudig bestellen.');
    buf.writeln('');
    buf.writeln('▶ Download nu: https://ventoz.nl/sails-app');
    buf.writeln('');
    buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    return buf.toString();
  }

  Future<void> _inviteLeadAsUser(Lead lead) async {
    if (lead.email == null || lead.email!.isEmpty) return;
    try {
      await UserService().inviteFromLead(
        email: lead.email!,
        userType: _inviteUserType,
        bedrijfsnaam: lead.naam,
        landCode: _guessLeadCountry(lead),
        kortingsPercentage: _inviteUserType == UserType.wederverkoper ? _resellerKorting : null,
      );
    } catch (_) {}
  }

  String _guessLeadCountry(Lead lead) {
    switch (widget.country) {
      case Country.be: return 'BE';
      case Country.de: return 'DE';
      default: return 'NL';
    }
  }

  String _getSubjectForLead(Lead lead) {
    if (_selectedTemplate != null) {
      return lead.applyToTemplate(
        _selectedTemplate!.onderwerp,
        gekozenZeil: _selectedProducts.isNotEmpty ? _selectedProductNamen : null,
        kortingscode: _currentKortingscode?.code,
        kortingscodeBlok: _buildKortingscodeBlock(),
        geldigTot: _currentKortingscode?.geldigTotLabel,
        proefperiode: _currentKortingscode?.proefperiodeLabel ?? '$_proefperiodeDagen dagen',
        kortingspercentage: _kortingspercentage.toString(),
        selectedProducts: _selectedProducts.isNotEmpty ? _selectedProductTuples : null,
        downloadBlok: _buildDownloadBlock(),
      );
    }
    return 'Exclusief aanbod voor ${lead.naam} – ${_currentKortingscode?.proefperiodeLabel ?? '1 maand'} gratis + $_kortingspercentage% korting';
  }

  String _getBodyForLead(Lead lead) {
    if (_customBodies.containsKey(lead.id)) return _customBodies[lead.id]!;

    if (_selectedTemplate != null) {
      final subject = _getSubjectForLead(lead);
      final prods = _selectedProducts.isNotEmpty ? _selectedProductTuples : null;
      final body = lead.applyToTemplate(
        _selectedTemplate!.inhoud,
        gekozenZeil: _selectedProducts.isNotEmpty ? _selectedProductNamen : null,
        kortingscode: _currentKortingscode?.code,
        kortingscodeBlok: _buildKortingscodeBlock(),
        geldigTot: _currentKortingscode?.geldigTotLabel,
        proefperiode: _currentKortingscode?.proefperiodeLabel ?? '$_proefperiodeDagen dagen',
        kortingspercentage: _kortingspercentage.toString(),
        selectedProducts: prods,
        downloadBlok: _buildDownloadBlock(),
      );
      return 'Onderwerp: $subject\n\n$body';
    }
    return _buildFallbackForLead(lead);
  }

  String _buildFallbackForLead(Lead lead) {
    final product = _selectedProducts.isNotEmpty ? _selectedProductNamen : lead.suggestedProduct;
    final contactName = lead.contactpersonen?.split(',').first.trim() ?? lead.naam;
    final aantalBoten = lead.geschatAantalBoten ?? 'uw vloot';
    final codeBlock = _buildKortingscodeBlock();

    final proefLabel = _currentKortingscode?.proefperiodeLabel ?? '$_proefperiodeDagen dagen';
    final geldigLabel = _geldigTot != null ? '\nActie geldig tot ${_geldigTot!.day}-${_geldigTot!.month}-${_geldigTot!.year}.\n' : '';

    return '''Onderwerp: Exclusief aanbod voor ${lead.naam} – $proefLabel gratis + $_kortingspercentage% korting

Beste $contactName,

Mijn naam is [Uw naam] van Ventoz – specialist in kwalitatieve zeilen.

Ik begrijp dat u werkt met $aantalBoten boten${lead.typeBoten != null ? ' (${lead.typeBoten})' : ''}. Onze $product is een uitstekende match.

SPECIAAL AANBOD:
1. Bestel met $_kortingspercentage% korting
${codeBlock.isNotEmpty ? '\n$codeBlock\n' : ''}
2. $proefLabel gratis uitproberen
3. Betaal achteraf of retourneer kosteloos (binnen $_proefperiodeDagen dagen)
$geldigLabel${_includeDownloadLink ? '\n${_buildDownloadBlock()}\n' : ''}
Met vriendelijke groet,
[Uw naam] · Ventoz B.V.
www.ventoz.nl''';
  }

  int get _leadsWithoutEmail => _leads.where((l) => l.email == null || l.email!.isEmpty).length;
  int get _leadsWithoutContact => _leads.where((l) => l.contactpersonen == null || l.contactpersonen!.isEmpty).length;
  int get _leadsPreviouslySent => _leads.where((l) => widget.sentLeadInfo.containsKey(l.id)).length;

  void _replaceLead(Lead updated) {
    setState(() {
      final idx = _leads.indexWhere((l) => l.id == updated.id);
      if (idx >= 0) _leads[idx] = updated;
    });
  }

  void _removeLead(int index) {
    setState(() => _leads.removeAt(index));
  }

  void _goToStepper() {
    setState(() {
      _phase = _Phase.stepper;
      _currentPage = 0;
    });
  }

  Future<void> _saveAllDrafts() async {
    final sendableLeads = _leads.where((l) => l.email != null && l.email!.isNotEmpty).toList();
    if (sendableLeads.isEmpty) return;

    int saved = 0;
    for (final lead in sendableLeads) {
      final result = await _emailLogService.save(EmailLog(
        leadId: lead.id,
        leadNaam: lead.naam,
        templateNaam: _selectedTemplate?.naam,
        kortingscode: _currentKortingscode?.code,
        producten: _selectedProducts.isNotEmpty ? _selectedProductNamen : null,
        verzondenAan: lead.email!,
        verzondenVia: 'smtp',
        status: EmailStatus.concept,
        onderwerp: _getSubjectForLead(lead),
        inhoud: _getBodyForLead(lead),
      ));
      if (result != null) saved++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$saved van ${sendableLeads.length} concepten opgeslagen'),
          backgroundColor: const Color(0xFF43A047),
        ),
      );
    }
  }

  Future<void> _sendAll() async {
    if (_smtpSettings == null || !_smtpSettings!.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMTP niet geconfigureerd. Ga naar Instellingen.')),
      );
      return;
    }

    final sendableLeads = _leads.where((l) => l.email != null && l.email!.isNotEmpty).toList();
    if (sendableLeads.isEmpty) return;

    setState(() {
      _phase = _Phase.sending;
      _sendProgress = 0;
      _sendSuccess = 0;
      _sendErrors.clear();
    });

    for (int i = 0; i < sendableLeads.length; i++) {
      final lead = sendableLeads[i];
      try {
        await _smtpService.sendEmail(
          settings: _smtpSettings!,
          toAddress: lead.email!,
          subject: _getSubjectForLead(lead),
          body: _getBodyForLead(lead),
        );
        _emailLogService.log(EmailLog(
          leadId: lead.id,
          leadNaam: lead.naam,
          templateNaam: _selectedTemplate?.naam,
          kortingscode: _currentKortingscode?.code,
          producten: _selectedProducts.isNotEmpty ? _selectedProductNamen : null,
          verzondenAan: lead.email!,
          verzondenVia: 'smtp',
          status: EmailStatus.verzonden,
          onderwerp: _getSubjectForLead(lead),
          inhoud: _getBodyForLead(lead),
        ));
        await _leadsService.updateStatus(lead.id, 'Aangeboden', tableName: widget.country.tableName);
        if (_includeDownloadLink) {
          await _inviteLeadAsUser(lead);
        }
        _sendSuccess++;
      } catch (e) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        _emailLogService.log(EmailLog(
          leadId: lead.id,
          leadNaam: lead.naam,
          templateNaam: _selectedTemplate?.naam,
          kortingscode: _currentKortingscode?.code,
          producten: _selectedProducts.isNotEmpty ? _selectedProductNamen : null,
          verzondenAan: lead.email!,
          verzondenVia: 'smtp',
          status: EmailStatus.mislukt,
          onderwerp: _getSubjectForLead(lead),
          inhoud: _getBodyForLead(lead),
          foutmelding: msg,
        ));
        _sendErrors.add('${lead.naam}: $msg');
      }
      if (mounted) setState(() => _sendProgress = i + 1);
    }

    if (mounted) setState(() => _phase = _Phase.done);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF37474F),
        foregroundColor: Colors.white,
        title: Text(_phaseTitle()),
        leading: _phase == _Phase.sending
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (_phase == _Phase.stepper) {
                    setState(() => _phase = _Phase.overview);
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : switch (_phase) {
              _Phase.overview => _buildOverview(),
              _Phase.stepper => _buildStepper(),
              _Phase.sending => _buildSending(),
              _Phase.done => _buildDone(),
            },
    );
  }

  String _phaseTitle() {
    return switch (_phase) {
      _Phase.overview => 'Batch e-mail (${_leads.length} leads)',
      _Phase.stepper => 'E-mail ${_currentPage + 1} van ${_leads.length}',
      _Phase.sending => 'Verzenden...',
      _Phase.done => 'Resultaat',
    };
  }

  // ========== PHASE 1: OVERVIEW ==========

  Widget _buildOverview() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWarnings(),
                const SizedBox(height: 16),
                _buildTemplateSelector(),
                const SizedBox(height: 16),
                _buildProductSelector(),
                if (_selectedProductIds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildActionConfig(),
                ],
                if (_currentKortingscode != null) ...[
                  const SizedBox(height: 10),
                  _buildKortingscodeCard(),
                ],
                const SizedBox(height: 16),
                _buildDownloadLinkSection(),
                const SizedBox(height: 16),
                _buildLeadList(),
              ],
            ),
          ),
        ),
        _buildOverviewActions(),
      ],
    );
  }

  Widget _buildWarnings() {
    final warnings = <Widget>[];
    if (_leadsWithoutEmail > 0) {
      warnings.add(_warningTile(Icons.error, const Color(0xFFEF4444), '$_leadsWithoutEmail lead(s) zonder e-mailadres — worden overgeslagen'));
    }
    if (_leadsWithoutContact > 0) {
      warnings.add(_warningTile(Icons.warning_amber, const Color(0xFFF59E0B), '$_leadsWithoutContact lead(s) zonder contactpersoon'));
    }
    if (_leadsPreviouslySent > 0) {
      warnings.add(_warningTile(Icons.info_outline, const Color(0xFF3B82F6), '$_leadsPreviouslySent lead(s) eerder gemaild'));
    }
    if (warnings.isEmpty) {
      return _warningTile(Icons.check_circle, const Color(0xFF10B981), 'Alle leads zijn compleet');
    }
    return Column(children: warnings);
  }

  Widget _warningTile(IconData icon, Color color, String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildTemplateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Template (voor alle leads)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: _selectedTemplate?.id,
          decoration: const InputDecoration(hintText: 'Standaard e-mail'),
          isExpanded: true,
          items: [
            const DropdownMenuItem<int>(value: null, child: Text('Standaard e-mail', style: TextStyle(color: Color(0xFF94A3B8)))),
            ..._templates.map((t) => DropdownMenuItem<int>(value: t.id, child: Text(t.naam))),
          ],
          onChanged: (id) {
            setState(() {
              _selectedTemplate = id == null ? null : _templates.firstWhere((t) => t.id == id);
              _customBodies.clear();
            });
          },
        ),
      ],
    );
  }

  Widget _buildProductSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB0BEC5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.asset('assets/ventoz_logo.png', width: 18, height: 18)),
              const SizedBox(width: 8),
              Text(
                _selectedProducts.isNotEmpty
                    ? '${_selectedProducts.length} product(en) geselecteerd'
                    : 'Producten selecteren (optioneel)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF37474F)),
              ),
              const Spacer(),
              if (_selectedProductIds.isNotEmpty)
                TextButton(onPressed: () { setState(() => _selectedProductIds.clear()); _resolveKortingscode(); }, child: const Text('Wis', style: TextStyle(fontSize: 11))),
            ],
          ),
          if (_selectedProducts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _selectedProducts.map((p) => Chip(
                label: Text(p.naam, style: const TextStyle(fontSize: 11)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => _toggleProduct(p.id),
                visualDensity: VisualDensity.compact,
                backgroundColor: Colors.white,
              )).toList(),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _producten.length,
              itemBuilder: (_, i) {
                final p = _producten[i];
                final selected = _selectedProductIds.contains(p.id);
                return CheckboxListTile(
                  value: selected,
                  onChanged: (_) => _toggleProduct(p.id),
                  title: Text(p.naam, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: const Color(0xFF455A64),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionConfig() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: Color(0xFF455A64), size: 18),
              SizedBox(width: 8),
              Text('Actie-instellingen', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF37474F))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Korting (%)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int>(
                      initialValue: _kortingspercentage,
                      isDense: true,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: [5, 10, 15, 20, 25].map((v) => DropdownMenuItem(value: v, child: Text('$v%', style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() { _kortingspercentage = v; _customBodies.clear(); });
                        if (_selectedProductIds.isNotEmpty) _resolveKortingscode();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Proefperiode', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int>(
                      initialValue: _proefperiodeDagen,
                      isDense: true,
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 14, child: Text('2 weken', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 30, child: Text('1 maand', style: TextStyle(fontSize: 13))),
                        DropdownMenuItem(value: 60, child: Text('2 maanden', style: TextStyle(fontSize: 13))),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() { _proefperiodeDagen = v; _customBodies.clear(); });
                        if (_selectedProductIds.isNotEmpty) _resolveKortingscode();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Geldig tot', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _geldigTot ?? DateTime.now().add(const Duration(days: 90)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (d != null) {
                          setState(() { _geldigTot = d; _customBodies.clear(); });
                          if (_selectedProductIds.isNotEmpty) _resolveKortingscode();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Text(
                              _geldigTot != null ? '${_geldigTot!.day}-${_geldigTot!.month}-${_geldigTot!.year}' : 'Onbeperkt',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_geldigTot != null) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                    tooltip: 'Onbeperkt maken',
                    onPressed: () {
                      setState(() { _geldigTot = null; _customBodies.clear(); });
                      if (_selectedProductIds.isNotEmpty) _resolveKortingscode();
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKortingscodeCard() {
    final code = _currentKortingscode!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer, color: Color(0xFFF59E0B), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(code.code, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF78350F), letterSpacing: 1.5)),
                Text('${code.kortingspercentage}% · ${code.proefperiodeLabel} proef · tot ${code.geldigTotLabel}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFB45309))),
                Text(code.productNamen, style: const TextStyle(fontSize: 10, color: Color(0xFFB45309)), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadLinkSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _includeDownloadLink ? const Color(0xFFE8F5E9) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _includeDownloadLink ? const Color(0xFF66BB6A) : const Color(0xFFE0E0E0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Row(children: [
            Icon(Icons.download, size: 20, color: Color(0xFF455A64)),
            SizedBox(width: 8),
            Expanded(child: Text('Downloadlink Ventoz Sails App toevoegen',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF37474F)))),
          ]),
          subtitle: const Padding(
            padding: EdgeInsets.only(left: 28),
            child: Text('Alle ontvangers worden automatisch uitgenodigd als app-gebruiker',
              style: TextStyle(fontSize: 11, color: Color(0xFF78909C))),
          ),
          value: _includeDownloadLink,
          onChanged: (v) => setState(() => _includeDownloadLink = v ?? false),
        ),
        if (_includeDownloadLink) ...[
          const SizedBox(height: 12),
          Row(children: [
            const SizedBox(width: 28),
            const Text('Type: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            SegmentedButton<UserType>(
              segments: const [
                ButtonSegment(value: UserType.prospect, label: Text('Prospect', style: TextStyle(fontSize: 12))),
                ButtonSegment(value: UserType.wederverkoper, label: Text('Wederverkoper', style: TextStyle(fontSize: 12))),
              ],
              selected: {_inviteUserType},
              onSelectionChanged: (v) => setState(() => _inviteUserType = v.first),
              style: ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ]),
          if (_inviteUserType == UserType.wederverkoper) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.discount, size: 16, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 6),
                  Text('Korting: ${_resellerKorting.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                ]),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
                  child: Slider(
                    value: _resellerKorting, min: 5, max: 30, divisions: 25,
                    activeColor: const Color(0xFF2E7D32),
                    label: '${_resellerKorting.toStringAsFixed(0)}%',
                    onChanged: (v) => setState(() => _resellerKorting = v),
                  ),
                ),
                const Text('Wederverkopers moeten eerst een geldig BTW-nummer invoeren.',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFFE65100))),
              ]),
            ),
          ],
        ],
      ]),
    );
  }

  Widget _buildLeadList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Leads (${_leads.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        ...List.generate(_leads.length, (i) => _buildLeadCard(i)),
      ],
    );
  }

  Widget _buildLeadCard(int index) {
    final lead = _leads[index];
    final noEmail = lead.email == null || lead.email!.isEmpty;
    final noContact = lead.contactpersonen == null || lead.contactpersonen!.isEmpty;
    final wasSent = widget.sentLeadInfo.containsKey(lead.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: noEmail ? const Color(0xFFEF4444) : noContact ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lead.naam, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    lead.email ?? 'Geen e-mail',
                    style: TextStyle(fontSize: 12, color: noEmail ? const Color(0xFFEF4444) : const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            if (noEmail) const Tooltip(message: 'Geen e-mailadres', child: Icon(Icons.error, size: 16, color: Color(0xFFEF4444))),
            if (!noEmail && noContact) const Tooltip(message: 'Geen contactpersoon', child: Icon(Icons.warning_amber, size: 16, color: Color(0xFFF59E0B))),
            if (wasSent) const Tooltip(message: 'Eerder gemaild', child: Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.mark_email_read, size: 16, color: Color(0xFF3B82F6)))),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              tooltip: 'Bewerk lead',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => LeadDetailModal(lead: lead, country: widget.country, onSaved: _replaceLead),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Color(0xFFEF4444)),
              tooltip: 'Verwijder uit batch',
              onPressed: () => _removeLead(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewActions() {
    final sendableCount = _leads.where((l) => l.email != null && l.email!.isNotEmpty).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          Text('$sendableCount van ${_leads.length} verstuurbaar', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuleren')),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('Bekijk e-mails'),
            onPressed: sendableCount == 0 ? null : _goToStepper,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // ========== PHASE 2: STEPPER ==========

  Widget _buildStepper() {
    return Column(
      children: [
        _buildStepperIndicator(),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _leads.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => _buildStepperPage(i),
          ),
        ),
        _buildStepperActions(),
      ],
    );
  }

  Widget _buildStepperIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          Text(
            _leads[_currentPage].naam,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF455A64), borderRadius: BorderRadius.circular(12)),
            child: Text('${_currentPage + 1} / ${_leads.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperPage(int index) {
    final lead = _leads[index];
    final body = _getBodyForLead(lead);
    final noEmail = lead.email == null || lead.email!.isEmpty;
    final noContact = lead.contactpersonen == null || lead.contactpersonen!.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (noEmail || noContact)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: noEmail ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: noEmail ? const Color(0xFFFCA5A5) : const Color(0xFFFCD34D)),
              ),
              child: Row(
                children: [
                  Icon(noEmail ? Icons.error : Icons.warning_amber, size: 16, color: noEmail ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(noEmail ? 'Geen e-mailadres — wordt overgeslagen' : 'Geen contactpersoon opgegeven', style: const TextStyle(fontSize: 12))),
                  TextButton(
                    onPressed: () {
                      showDialog(context: context, builder: (_) => LeadDetailModal(lead: lead, country: widget.country, onSaved: _replaceLead));
                    },
                    child: const Text('Bewerk', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _previewRow('Aan', lead.email ?? '—'),
                _previewRow('Onderwerp', _getSubjectForLead(lead)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: body.replaceFirst(RegExp(r'^Onderwerp:.*\n\n'), '')),
            maxLines: 20,
            onChanged: (v) => _customBodies[lead.id] = 'Onderwerp: ${_getSubjectForLead(lead)}\n\n$v',
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.6, fontFamily: 'monospace'),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text('$label:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)))),
        ],
      ),
    );
  }

  Widget _buildStepperActions() {
    final sendableCount = _leads.where((l) => l.email != null && l.email!.isNotEmpty).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Vorige'),
            onPressed: _currentPage > 0
                ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                : null,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('Volgende'),
            onPressed: _currentPage < _leads.length - 1
                ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                : null,
          ),
          const Spacer(),
          OutlinedButton.icon(
            icon: const Icon(Icons.save_outlined, size: 16),
            label: Text('Bewaar $sendableCount concepten'),
            onPressed: sendableCount == 0 ? null : _saveAllDrafts,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E88E5),
              side: const BorderSide(color: Color(0xFF1E88E5)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.send, size: 16),
            label: Text('Verstuur $sendableCount e-mails'),
            onPressed: sendableCount == 0 || _smtpSettings?.isConfigured != true ? null : _sendAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF455A64),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ========== PHASE 3: SENDING ==========

  Widget _buildSending() {
    final total = _leads.where((l) => l.email != null && l.email!.isNotEmpty).length;
    final progress = total > 0 ? _sendProgress / total : 0.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                backgroundColor: const Color(0xFFE2E8F0),
                color: const Color(0xFF455A64),
              ),
            ),
            const SizedBox(height: 24),
            Text('$_sendProgress van $total', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            const Text('E-mails worden verzonden...', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
            if (_sendErrors.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('${_sendErrors.length} mislukt', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  // ========== PHASE 4: DONE ==========

  Widget _buildDone() {
    final total = _leads.where((l) => l.email != null && l.email!.isNotEmpty).length;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _sendErrors.isEmpty ? Icons.check_circle : Icons.warning_amber,
              size: 64,
              color: _sendErrors.isEmpty ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 20),
            Text(
              _sendErrors.isEmpty ? 'Alle e-mails verzonden!' : 'Verzending voltooid',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _resultChip(Icons.check_circle, const Color(0xFF10B981), '$_sendSuccess succesvol'),
                if (_sendErrors.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  _resultChip(Icons.error, const Color(0xFFEF4444), '${_sendErrors.length} mislukt'),
                ],
                if (total - _sendSuccess - _sendErrors.length > 0) ...[
                  const SizedBox(width: 12),
                  _resultChip(Icons.skip_next, const Color(0xFF94A3B8), '${total - _sendSuccess - _sendErrors.length} overgeslagen'),
                ],
              ],
            ),
            if (_sendErrors.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Foutmeldingen:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFFDC2626))),
                    const SizedBox(height: 6),
                    ..._sendErrors.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $e', style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B))),
                    )),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Terug naar dashboard'),
              onPressed: () {
                widget.onDone();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF455A64),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultChip(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
