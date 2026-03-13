import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lead.dart';
import '../models/email_template.dart';
import '../models/product.dart';
import '../models/kortingscode.dart';
import '../services/email_templates_service.dart';
import '../services/producten_service.dart';
import '../services/kortingscodes_service.dart';
import '../services/smtp_service.dart';
import '../services/email_log_service.dart';
import '../services/web_scraper_service.dart';
import '../services/user_service.dart';
import '../models/catalog_product.dart';
import '../models/email_log.dart';

class OfferModal extends StatefulWidget {
  final Lead lead;
  final VoidCallback onStatusUpdated;

  const OfferModal({
    super.key,
    required this.lead,
    required this.onStatusUpdated,
  });

  @override
  State<OfferModal> createState() => _OfferModalState();
}

class _OfferModalState extends State<OfferModal> {
  final EmailTemplatesService _templateService = EmailTemplatesService();
  final ProductenService _productenService = ProductenService();
  final KortingscodesService _kortingscodesService = KortingscodesService();
  final SmtpService _smtpService = SmtpService();
  final EmailLogService _emailLogService = EmailLogService();
  late final TextEditingController _emailController;

  List<EmailTemplate> _templates = [];
  EmailTemplate? _selectedTemplate;
  bool _loadingTemplates = true;

  List<Product> _producten = [];
  final Set<int> _selectedProductIds = {};
  bool _loadingProducten = true;
  Map<String, CatalogProduct> _catalogPrices = {};

  Kortingscode? _currentKortingscode;
  bool _loadingKortingscode = false;

  // Action config
  int _kortingspercentage = 10;
  DateTime? _geldigTot;
  int _proefperiodeDagen = 30;

  SmtpSettings? _smtpSettings;
  bool _sendingSmtp = false;

  bool _includeDownloadLink = false;
  UserType _inviteUserType = UserType.prospect;
  double _resellerKorting = 15;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: _buildFallbackDraft());
    _loadTemplates();
    _loadProducten();
    _loadSmtpSettings();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      final list = await _templateService.fetchTemplates();
      if (mounted) setState(() { _templates = list; _loadingTemplates = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingTemplates = false);
    }
  }

  Future<void> _loadProducten() async {
    try {
      final results = await Future.wait([
        _productenService.fetchProducten(),
        WebScraperService().fetchCatalog(),
      ]);
      final list = results[0] as List<Product>;
      final catalog = results[1] as List<CatalogProduct>;
      final priceMap = <String, CatalogProduct>{};
      for (final cp in catalog) {
        priceMap[cp.naam.toLowerCase()] = cp;
      }
      if (mounted) {
        setState(() {
          _producten = list;
          _catalogPrices = priceMap;
          _loadingProducten = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProducten = false);
    }
  }

  Future<void> _loadSmtpSettings() async {
    final settings = await _smtpService.loadSettings();
    if (mounted) setState(() => _smtpSettings = settings);
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
      _refreshEmailPreview();
      return;
    }

    setState(() => _loadingKortingscode = true);
    try {
      final code = await _kortingscodesService.findOrCreate(
        _selectedProductIds.toList(),
        _selectedProductNamen,
        kortingspercentage: _kortingspercentage,
        geldigTot: _geldigTot,
        proefperiodeDagen: _proefperiodeDagen,
      );
      if (mounted) setState(() { _currentKortingscode = code; _loadingKortingscode = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingKortingscode = false);
    }
    _refreshEmailPreview();
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

  void _onTemplateSelected(EmailTemplate? template) {
    setState(() => _selectedTemplate = template);
    _refreshEmailPreview();
  }

  String _getSubject() {
    final lead = widget.lead;
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

  String _getBody() => _emailController.text;

  void _refreshEmailPreview() {
    final codeStr = _currentKortingscode?.code;
    final codeBlock = _buildKortingscodeBlock();
    final dlBlock = _buildDownloadBlock();
    final prods = _selectedProducts.isNotEmpty ? _selectedProductTuples : null;

    if (_selectedTemplate != null) {
      final subject = widget.lead.applyToTemplate(
        _selectedTemplate!.onderwerp,
        gekozenZeil: _selectedProducts.isNotEmpty ? _selectedProductNamen : null,
        kortingscode: codeStr,
        kortingscodeBlok: codeBlock,
        geldigTot: _currentKortingscode?.geldigTotLabel,
        proefperiode: _currentKortingscode?.proefperiodeLabel ?? '$_proefperiodeDagen dagen',
        kortingspercentage: _kortingspercentage.toString(),
        selectedProducts: prods,
        downloadBlok: dlBlock,
      );
      final body = widget.lead.applyToTemplate(
        _selectedTemplate!.inhoud,
        gekozenZeil: _selectedProducts.isNotEmpty ? _selectedProductNamen : null,
        kortingscode: codeStr,
        kortingscodeBlok: codeBlock,
        geldigTot: _currentKortingscode?.geldigTotLabel,
        proefperiode: _currentKortingscode?.proefperiodeLabel ?? '$_proefperiodeDagen dagen',
        kortingspercentage: _kortingspercentage.toString(),
        selectedProducts: prods,
        downloadBlok: dlBlock,
      );
      _emailController.text = 'Onderwerp: $subject\n\n$body';
    } else {
      _emailController.text = _buildFallbackDraft();
    }
  }

  String _buildFallbackDraft() {
    final lead = widget.lead;
    final product = _selectedProducts.isNotEmpty ? _selectedProductNamen : lead.suggestedProduct;
    final contactName = lead.contactpersonen?.split(',').first.trim() ?? lead.naam;
    final aantalBoten = lead.geschatAantalBoten ?? 'uw vloot';
    final codeBlock = _buildKortingscodeBlock();

    final proefLabel = _currentKortingscode?.proefperiodeLabel ?? '$_proefperiodeDagen dagen';
    final geldigLabel = _geldigTot != null ? 'Actie geldig tot ${_geldigTot!.day}-${_geldigTot!.month}-${_geldigTot!.year}.' : '';

    return '''Onderwerp: Exclusief aanbod voor ${lead.naam} – $proefLabel gratis + $_kortingspercentage% korting

Beste $contactName,

Mijn naam is [Uw naam] en ik ben verkoopmedewerker bij Ventoz – specialist in kwalitatieve zeilen voor de watersportsector.

Na het bekijken van uw jachthaven/school begrijp ik dat u werkt met $aantalBoten boten${lead.typeBoten != null ? ' (${lead.typeBoten})' : ''}. Op basis daarvan denk ik dat onze $product een uitstekende match is voor uw situatie.

Waarom Ventoz?
• Topkwaliteit zeilen, speciaal voor club- en schoolgebruik
• Snelle levering en persoonlijk advies
• Honderden tevreden jachthavens en zeilscholen in Nederland

SPECIAAL AANBOD – Alleen voor nieuwe klanten:

1. Bestel met $_kortingspercentage% korting
   Bestel via onze webshop en ontvang direct $_kortingspercentage% korting op uw bestelling.
${codeBlock.isNotEmpty ? '\n$codeBlock\n' : ''}
2. $proefLabel gratis uitproberen
   Ontvang het zeil en test het $proefLabel op het water – volledig risicovrij.

3. Betaal achteraf of retourneer
   Bevalt het zeil? Betaal het bedrag (al met $_kortingspercentage% korting) achteraf.
   Niet tevreden? Stuur het retour binnen $_proefperiodeDagen dagen – u betaalt niets.
${geldigLabel.isNotEmpty ? '\n$geldigLabel\n' : ''}
Ik zou graag een korte afspraak inplannen of u een offerte op maat sturen.
Heeft u vragen of wilt u meer informatie? Bel of mail mij gerust.
${_includeDownloadLink ? '\n${_buildDownloadBlock()}\n' : ''}
Met vriendelijke groet,

[Uw naam]
Ventoz B.V.
[Telefoonnummer]
[email@ventoz.nl]
www.ventoz.nl''';
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

  Future<void> _inviteLeadAsUser(String email) async {
    if (!_includeDownloadLink) return;
    final lead = widget.lead;
    try {
      final created = await UserService().inviteFromLead(
        email: email,
        userType: _inviteUserType,
        bedrijfsnaam: lead.naam,
        landCode: _guessLeadCountry(lead),
        kortingsPercentage: _inviteUserType == UserType.wederverkoper ? _resellerKorting : null,
      );
      if (created && mounted) {
        final typeLabel = _inviteUserType == UserType.wederverkoper
            ? 'wederverkoper (${_resellerKorting.toStringAsFixed(0)}% korting)'
            : 'klant (bedrijf)';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lead uitgenodigd als $typeLabel'),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 3),
        ));
      }
    } catch (_) {}
  }

  String _guessLeadCountry(Lead lead) {
    final plaats = (lead.plaats ?? '').toLowerCase();
    if (plaats.contains('belg') || plaats.contains('brux') || plaats.contains('antwerp') || plaats.contains('gent')) return 'BE';
    if (plaats.contains('berlin') || plaats.contains('münchen') || plaats.contains('hamburg')) return 'DE';
    return 'NL';
  }

  // --- Send methods ---

  Future<void> _sendViaMailto(String toAddress) async {
    final subject = Uri.encodeComponent(_getSubject());
    final body = Uri.encodeComponent(_getBody());
    final uri = Uri.parse('mailto:$toAddress?subject=$subject&body=$body');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      _logEmail(toAddress, 'mailto');
      await _inviteLeadAsUser(toAddress);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kan e-mailclient niet openen.')),
        );
      }
    }
  }

  Future<void> _sendViaSmtp(String toAddress) async {
    if (_smtpSettings == null || !_smtpSettings!.isConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMTP niet geconfigureerd. Ga naar Instellingen.')),
        );
      }
      return;
    }

    setState(() => _sendingSmtp = true);
    try {
      await _smtpService.sendEmail(
        settings: _smtpSettings!,
        toAddress: toAddress,
        subject: _getSubject(),
        body: _getBody(),
      );
      await _logEmail(toAddress, 'smtp', status: EmailStatus.verzonden);
      await _inviteLeadAsUser(toAddress);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('E-mail verzonden naar $toAddress via ${_smtpSettings!.fromEmail}')),
        );
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      await _logEmail(toAddress, 'smtp', status: EmailStatus.mislukt, foutmelding: msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
    if (mounted) setState(() => _sendingSmtp = false);
  }

  Future<void> _logEmail(String toAddress, String via, {EmailStatus status = EmailStatus.verzonden, String? foutmelding}) async {
    await _emailLogService.log(EmailLog(
      leadId: widget.lead.id,
      leadNaam: widget.lead.naam,
      templateNaam: _selectedTemplate?.naam,
      kortingscode: _currentKortingscode?.code,
      producten: _selectedProducts.isNotEmpty ? _selectedProductNamen : null,
      verzondenAan: toAddress,
      verzondenVia: via,
      status: status,
      onderwerp: _getSubject(),
      inhoud: _getBody(),
      foutmelding: foutmelding,
    ));
  }

  Future<void> _saveDraft() async {
    final lead = widget.lead;
    final saved = await _emailLogService.save(EmailLog(
      leadId: lead.id,
      leadNaam: lead.naam,
      templateNaam: _selectedTemplate?.naam,
      kortingscode: _currentKortingscode?.code,
      producten: _selectedProducts.isNotEmpty ? _selectedProductNamen : null,
      verzondenAan: lead.email ?? '',
      verzondenVia: 'smtp',
      status: EmailStatus.concept,
      onderwerp: _getSubject(),
      inhoud: _getBody(),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved != null ? 'Concept opgeslagen' : 'Opslaan mislukt'),
          backgroundColor: saved != null ? const Color(0xFF43A047) : const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _openMailClient() async {
    final lead = widget.lead;
    if (lead.email == null || lead.email!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen e-mailadres beschikbaar voor deze lead.')),
      );
      return;
    }
    _sendViaMailto(lead.email!);
  }

  Future<void> _sendSmtpToLead() async {
    final lead = widget.lead;
    if (lead.email == null || lead.email!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen e-mailadres beschikbaar voor deze lead.')),
      );
      return;
    }
    _sendViaSmtp(lead.email!);
  }

  Future<void> _sendTestSmtp() async {
    if (_smtpSettings == null || !_smtpSettings!.isConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMTP niet geconfigureerd. Ga naar Instellingen.')),
        );
      }
      return;
    }

    setState(() => _sendingSmtp = true);
    try {
      await _smtpService.sendEmail(
        settings: _smtpSettings!,
        toAddress: _smtpSettings!.fromEmail,
        subject: '[TEST] ${_getSubject()}',
        body: _getBody(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test verzonden naar ${_smtpSettings!.fromEmail} (niet gelogd)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
    if (mounted) setState(() => _sendingSmtp = false);
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _emailController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('E-mail gekopieerd naar klembord'), duration: Duration(seconds: 2)),
    );
  }

  void _showPreview() {
    final subject = _getSubject();
    final body = _getBody();
    final lead = widget.lead;
    final fromLabel = _smtpSettings?.isConfigured == true
        ? '${_smtpSettings!.fromName} <${_smtpSettings!.fromEmail}>'
        : '[E-mailprogramma afzender]';

    showDialog(
      context: context,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: screenWidth > 700 ? 640 : screenWidth * 0.95,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: const Color(0xFF37474F),
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility, color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('E-mail Voorbeeld', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _previewField('Van', fromLabel),
                      const SizedBox(height: 6),
                      _previewField('Aan', lead.email ?? '—'),
                      const SizedBox(height: 6),
                      _previewField('Onderwerp', subject),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      child: SelectableText(
                        body.replaceFirst(RegExp(r'^Onderwerp:.*\n\n'), ''),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.7),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Kopieer'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: body));
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('E-mail gekopieerd'), duration: Duration(seconds: 2)),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Sluiten')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _previewField(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text('$label:', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 700;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: isWide ? 700 : screenWidth * 0.95,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(lead),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLeadInfoRow(lead),
                    const SizedBox(height: 20),
                    _buildProductSelector(),
                    if (_selectedProductIds.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildActionConfig(),
                    ],
                    if (_currentKortingscode != null || _loadingKortingscode) ...[
                      const SizedBox(height: 12),
                      _buildKortingscodeCard(),
                    ],
                    const SizedBox(height: 20),
                    _buildDownloadLinkSection(),
                    const SizedBox(height: 20),
                    _buildOfferHighlights(),
                    const SizedBox(height: 20),
                    _buildTemplateSelector(),
                    const SizedBox(height: 16),
                    _buildEmailEditor(),
                  ],
                ),
              ),
            ),
            _buildActionBar(lead),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF455A64), borderRadius: BorderRadius.circular(8)),
                child: ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.asset('assets/ventoz_logo.png', width: 20, height: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Producten selecteren', style: TextStyle(fontSize: 11, color: Color(0xFF607D8B), fontWeight: FontWeight.w500)),
                    Text(
                      _selectedProducts.isNotEmpty
                          ? '${_selectedProducts.length} product${_selectedProducts.length == 1 ? '' : 'en'} geselecteerd'
                          : 'Geen producten geselecteerd',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF37474F)),
                    ),
                  ],
                ),
              ),
              if (_selectedProductIds.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() => _selectedProductIds.clear());
                    _resolveKortingscode();
                  },
                  child: const Text('Wis', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          if (_selectedProducts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _selectedProducts.map((p) {
                return Chip(
                  label: Text(p.naam, style: const TextStyle(fontSize: 11, color: Color(0xFF37474F))),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => _toggleProduct(p.id),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFB0BEC5)),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          _loadingProducten
              ? const SizedBox(height: 48, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
              : Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _producten.length,
                    itemBuilder: (_, i) {
                      final p = _producten[i];
                      final selected = _selectedProductIds.contains(p.id);
                      final catalogMatch = _catalogPrices[p.naam.toLowerCase()];
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (_) => _toggleProduct(p.id),
                        title: Text(p.naam, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal, color: const Color(0xFF1E293B))),
                        subtitle: catalogMatch?.prijs != null
                            ? Text(catalogMatch!.prijsFormatted, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF455A64)))
                            : null,
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

  Widget _buildKortingscodeCard() {
    if (_loadingKortingscode) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    final code = _currentKortingscode!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.local_offer, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kortingscode', style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w500)),
                Text(code.code, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF78350F), letterSpacing: 1.5)),
                Text('${code.kortingspercentage}% korting · ${code.proefperiodeLabel} proef · tot ${code.geldigTotLabel}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFB45309))),
                Text('Geldig voor: ${code.productNamen}', style: const TextStyle(fontSize: 10, color: Color(0xFFB45309))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18, color: Color(0xFF92400E)),
            tooltip: 'Kopieer code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code.code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kortingscode gekopieerd'), duration: Duration(seconds: 2)),
              );
            },
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
                        setState(() => _kortingspercentage = v);
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
                        setState(() => _proefperiodeDagen = v);
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
                          setState(() => _geldigTot = d);
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
                      setState(() => _geldigTot = null);
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

  Widget _buildTemplateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('E-mail template', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        const SizedBox(height: 8),
        _loadingTemplates
            ? const SizedBox(height: 48, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
            : DropdownButtonFormField<int>(
                initialValue: _selectedTemplate?.id,
                decoration: const InputDecoration(hintText: 'Standaard e-mail (geen template)'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<int>(value: null, child: Text('Standaard e-mail', style: TextStyle(color: Color(0xFF94A3B8)))),
                  ..._templates.map((t) => DropdownMenuItem<int>(value: t.id, child: Text(t.naam))),
                ],
                onChanged: (id) {
                  if (id == null) {
                    _onTemplateSelected(null);
                  } else {
                    _onTemplateSelected(_templates.firstWhere((t) => t.id == id));
                  }
                },
              ),
      ],
    );
  }

  Widget _buildHeader(Lead lead) {
    return Container(
      color: const Color(0xFF37474F),
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      child: Row(
        children: [
          const Icon(Icons.email_outlined, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Aanbieding Versturen', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                Text(lead.naam, style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _buildLeadInfoRow(Lead lead) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        if (lead.plaats != null) _infoChip(Icons.location_on_outlined, lead.plaats!),
        if (lead.email != null) _infoChip(Icons.email_outlined, lead.email!),
        if (lead.telefoon != null) _infoChip(Icons.phone_outlined, lead.telefoon!),
        _infoChip(Icons.directions_boat_outlined, lead.typeBoten ?? 'Onbekend boot type'),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              child: Text('Voegt een downloadblok toe aan de email en nodigt de lead uit als app-gebruiker',
                style: TextStyle(fontSize: 11, color: Color(0xFF78909C))),
            ),
            value: _includeDownloadLink,
            onChanged: (v) {
              setState(() => _includeDownloadLink = v ?? false);
              _refreshEmailPreview();
            },
          ),
          if (_includeDownloadLink) ...[
            const SizedBox(height: 12),
            Row(children: [
              const SizedBox(width: 28),
              const Text('Uitnodigen als: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              SegmentedButton<UserType>(
                segments: const [
                  ButtonSegment(value: UserType.prospect, label: Text('Prospect', style: TextStyle(fontSize: 12))),
                  ButtonSegment(value: UserType.wederverkoper, label: Text('Wederverkoper', style: TextStyle(fontSize: 12))),
                ],
                selected: {_inviteUserType},
                onSelectionChanged: (v) => setState(() => _inviteUserType = v.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
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
                    Text('Wederverkoper korting: ${_resellerKorting.toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                  ]),
                  const SizedBox(height: 4),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: _resellerKorting,
                      min: 5,
                      max: 30,
                      divisions: 25,
                      activeColor: const Color(0xFF2E7D32),
                      label: '${_resellerKorting.toStringAsFixed(0)}%',
                      onChanged: (v) => setState(() => _resellerKorting = v),
                    ),
                  ),
                  const Text('Let op: wederverkoper moet eerst een geldig BTW-nummer invoeren voordat het account actief wordt.',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFFE65100))),
                ]),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildOfferHighlights() {
    final highlights = [
      ('1 maand gratis', 'Geen risico, geen verplichtingen', Icons.card_giftcard),
      ('10% korting', 'Op de eerste bestelling', Icons.local_offer_outlined),
      ('Betaal Later', 'Via Ventoz.nl – flexibel betalen', Icons.schedule_outlined),
    ];

    return Row(
      children: highlights.map((h) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: h.$1 == '10% korting' ? 8 : 0, left: h.$1 == '10% korting' ? 8 : 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(h.$3, color: const Color(0xFF455A64), size: 20),
                const SizedBox(height: 4),
                Text(h.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF37474F)), textAlign: TextAlign.center),
                Text(h.$2, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)), textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmailEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('E-mail concept', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            Row(
              children: [
                TextButton.icon(icon: const Icon(Icons.visibility, size: 16), label: const Text('Voorbeeld'), onPressed: _showPreview),
                const SizedBox(width: 4),
                TextButton.icon(icon: const Icon(Icons.copy, size: 16), label: const Text('Kopieer'), onPressed: _copyToClipboard),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          maxLines: 18,
          style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.6, fontFamily: 'monospace'),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(Lead lead) {
    final smtpReady = _smtpSettings?.isConfigured == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.email != null ? 'Aan: ${lead.email}' : 'Geen e-mailadres beschikbaar',
                      style: TextStyle(fontSize: 12, color: lead.email != null ? const Color(0xFF475569) : const Color(0xFFEF4444)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (smtpReady)
                      Text(
                        'Van: ${_smtpSettings!.fromEmail}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuleren')),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('Concept'),
                onPressed: _saveDraft,
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1E88E5), side: const BorderSide(color: Color(0xFF1E88E5))),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                icon: const Icon(Icons.science_outlined, size: 16),
                label: const Text('Test'),
                onPressed: _sendTestSmtp,
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFF59E0B), side: const BorderSide(color: Color(0xFFF59E0B))),
              ),
              const SizedBox(width: 6),
              if (smtpReady) ...[
                ElevatedButton.icon(
                  icon: _sendingSmtp
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, size: 16),
                  label: const Text('Verstuur'),
                  onPressed: _sendingSmtp ? null : _sendSmtpToLead,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
                ),
                const SizedBox(width: 6),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(smtpReady ? 'Mailto' : 'Verstuur via mail'),
                onPressed: _openMailClient,
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF455A64)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
