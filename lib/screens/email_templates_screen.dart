import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../models/email_template.dart';
import '../services/email_templates_service.dart';
import '../services/user_service.dart';

class EmailTemplatesScreen extends StatefulWidget {
  const EmailTemplatesScreen({super.key});

  @override
  State<EmailTemplatesScreen> createState() => _EmailTemplatesScreenState();
}

class _EmailTemplatesScreenState extends State<EmailTemplatesScreen> {
  final EmailTemplatesService _service = EmailTemplatesService();
  final _userService = UserService();

  List<EmailTemplate> _templates = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.emailTemplatesBeheren) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
        );
      }
      return;
    }
    try {
      final list = await _service.fetchTemplates();
      if (mounted) setState(() { _templates = list; _isLoading = false; });
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading email templates: $e');
      if (mounted) setState(() { _error = 'Er is een fout opgetreden bij het laden.'; _isLoading = false; });
    }
  }

  Future<void> _openEditor({EmailTemplate? existing}) async {
    final result = await showDialog<EmailTemplate>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TemplateEditorDialog(existing: existing),
    );
    if (result == null) return;

    try {
      if (existing != null) {
        await _service.updateTemplate(result);
      } else {
        await _service.createTemplate(result);
      }
      _load();
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving email template: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opslaan mislukt. Probeer het opnieuw.')),
        );
      }
    }
  }

  Future<void> _createSeedTemplate() async {
    const seeds = [
      EmailTemplate(
        naam: 'Persoonlijk aanbod met kortingscode',
        onderwerp: 'Speciaal voor {{naam}}: uw eigen kortingscode voor Ventoz zeilen',
        inhoud: '''Beste {{contactpersoon}},

Leuk dat we contact hebben! Ik ben [Uw naam] van Ventoz, en ik heb een aanbod samengesteld speciaal voor {{naam}} in {{plaats}}.

Op basis van uw vloot ({{boot_typen}}) heb ik de volgende zeilen voor u geselecteerd:

{{gekozen_zeil}}

Zo werkt het:

  ✦  BESTEL MET 10% KORTING
     Bestel via {{product_url}} en gebruik onderstaande
     code bij het afrekenen. De 10% korting wordt direct
     verrekend op uw bestelling.

{{kortingscode_blok}}

  ✦  1 MAAND GRATIS UITPROBEREN
     U ontvangt het zeil en mag het een volledige maand
     op het water testen. Geen risico, geen verplichtingen.

  ✦  BETAAL ACHTERAF OF RETOURNEER
     Bevalt het zeil? Dan betaalt u het bedrag (met de
     10% korting al verrekend) achteraf. Bevalt het niet?
     Stuur het retour binnen 30 dagen – u betaalt niets.

Bestellen is eenvoudig:
Ga naar {{product_url}}, voeg uw zeil(en) toe aan het winkelmandje en vul bij het afrekenen de code {{kortingscode}} in. De korting wordt direct zichtbaar.

Liever eerst persoonlijk advies? Ik denk graag met u mee over de juiste keuze voor uw {{geschat_aantal_boten}} boten. Bel of mail me gerust.

Met sportieve groet,

[Uw naam]
Ventoz B.V.
[Telefoonnummer] · [email@ventoz.nl]
www.ventoz.nl''',
      ),
      EmailTemplate(
        naam: 'Compleet aanbod met productoverzicht',
        onderwerp: 'Exclusief aanbod voor {{naam}} – 1 maand gratis + 10% korting',
        inhoud: '''Beste {{contactpersoon}},

Mijn naam is [Uw naam] en ik ben verkoopmedewerker bij Ventoz – specialist in kwalitatieve zeilen voor de watersportsector.

Na het bekijken van uw jachthaven/school begrijp ik dat u werkt met {{geschat_aantal_boten}} boten ({{boot_typen}}). Op basis daarvan denk ik dat onze {{product}} een uitstekende match is voor uw situatie.

Waarom Ventoz?
• Topkwaliteit zeilen, speciaal voor club- en schoolgebruik
• Snelle levering en persoonlijk advies
• Honderden tevreden jachthavens en zeilscholen in Nederland

SPECIAAL AANBOD – Alleen voor nieuwe klanten:

1. Bestel met 10% korting
   Bestel via onze webshop en ontvang direct 10% korting op uw bestelling.

2. 1 maand gratis uitproberen
   Ontvang het zeil en test het een volledige maand op het water – volledig risicovrij.

3. Betaal achteraf of retourneer
   Bevalt het zeil? Betaal het bedrag (al met 10% korting) achteraf.
   Niet tevreden? Stuur het binnen 30 dagen retour – u betaalt niets.

Bekijk hieronder ons volledige assortiment zeilen:

{{productlinks}}

Direct bestellen? Klik op de link van het gewenste zeil hierboven,
of neem contact met ons op voor een offerte op maat.

Ik hoor graag van u!

Met vriendelijke groet,

[Uw naam]
Ventoz B.V.
[Telefoonnummer]
[email@ventoz.nl]
www.ventoz.nl''',
      ),
      EmailTemplate(
        naam: 'Kort & krachtig met kortingscode',
        onderwerp: '{{contactpersoon}}, 10% korting op {{gekozen_zeil}} voor {{naam}}',
        inhoud: '''Hallo {{contactpersoon}},

Kort en bondig: ik heb een persoonlijke kortingscode aangemaakt voor {{naam}}.

{{kortingscode_blok}}

Ga naar {{product_url}} en gebruik code {{kortingscode}} bij het afrekenen.

Daarnaast geldt:
• 10% korting wordt direct verrekend bij bestelling
• Eerste maand gratis uitproberen
• Bevalt het? Betaal achteraf. Niet tevreden? Retourneer kosteloos.
• Persoonlijk advies op maat voor uw {{geschat_aantal_boten}} boten

Interesse? Laat het me weten – ik stuur u graag een offerte.

Groet,
[Uw naam] · Ventoz B.V.
[Telefoonnummer]
www.ventoz.nl''',
      ),
      EmailTemplate(
        naam: 'Aanbod met klikbare productlijst',
        onderwerp: 'Exclusief voor {{naam}}: geselecteerde Ventoz zeilen met {{kortingspercentage}}% korting',
        inhoud: '''Beste {{contactpersoon}},

Graag stel ik mij voor: ik ben [Uw naam] van Ventoz, specialist in kwalitatieve zeilen voor watersportverenigingen en zeilscholen in de Benelux en Duitsland.

Op basis van uw vloot ({{boot_typen}}) heb ik de volgende zeilen voor u geselecteerd. Klik op een zeil om het direct te bekijken in onze webshop:

{{product_lijst}}

Ons kennismakingsaanbod:

  ✦  {{kortingspercentage}}% KORTING BIJ BESTELLING
     Bestel via de links hierboven en gebruik uw persoonlijke
     kortingscode bij het afrekenen.

{{kortingscode_blok}}

  ✦  {{proefperiode}} GRATIS UITPROBEREN
     Ontvang het zeil en test het op het water – volledig
     risicovrij. Geen verplichtingen vooraf.

  ✦  BETAAL ACHTERAF OF RETOURNEER
     Tevreden? Betaal het bedrag (met {{kortingspercentage}}%
     korting al verrekend) na de proefperiode. Niet tevreden?
     Retourneer kosteloos.

  ✦  GELDIG TOT {{geldig_tot}}

Heeft u vragen of wilt u advies op maat? Ik help u graag persoonlijk verder.

Met sportieve groet,

[Uw naam]
Ventoz B.V.
[Telefoonnummer] · [email@ventoz.nl]
www.ventoz.nl''',
      ),
    ];

    try {
      for (final seed in seeds) {
        await _service.createTemplate(seed);
      }
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('4 voorbeeld-templates aangemaakt!')),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error creating seed templates: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aanmaken mislukt. Probeer het opnieuw.')),
        );
      }
    }
  }

  void _showPreview(EmailTemplate t) {
    const exampleLead = Lead(
      id: 0,
      naam: 'Zeilschool De Windvaan',
      plaats: 'Muiden',
      email: 'info@dewindvaan.nl',
      telefoon: '0294-123456',
      contactpersonen: 'Jan de Vries',
      typeBoten: 'Optimist, Polyvalk',
      geschatAantalBoten: '35',
      categorie: 'Zeilschool',
      erkenningen: 'CWO, Watersportverbond',
    );

    final previewSubject = exampleLead.applyToTemplate(t.onderwerp);
    final previewBody = exampleLead.applyToTemplate(t.inhoud);

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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Voorbeeld', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                            Text(t.naam, style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Text(
                    'Voorbeeld met: Zeilschool De Windvaan (Muiden, 35 boten)',
                    style: TextStyle(fontSize: 11, color: Colors.blueGrey[400], fontStyle: FontStyle.italic),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECEFF1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.subject, size: 16, color: Color(0xFF607D8B)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(previewSubject, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF37474F))),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SelectableText(
                          previewBody,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.7),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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

  Future<void> _delete(EmailTemplate t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Template verwijderen?'),
        content: Text('Weet je zeker dat je "${t.naam}" wilt verwijderen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verwijderen', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmed != true || t.id == null) return;

    try {
      await _service.deleteTemplate(t.id!);
      _load();
    } catch (e) {
      if (kDebugMode) debugPrint('Error deleting email template: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verwijderen mislukt. Probeer het opnieuw.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-mail Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Voorbeeld-template laden',
            onPressed: _createSeedTemplate,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Nieuw template'),
        backgroundColor: const Color(0xFF455A64),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFF64748B)), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Opnieuw proberen')),
          ],
        ),
      );
    }
    if (_templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mail_outline, size: 48, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            const Text('Nog geen templates', style: TextStyle(color: Color(0xFF64748B), fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Maak een nieuw template aan met de knop hieronder.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Voorbeeld-template laden'),
              onPressed: _createSeedTemplate,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: _templates.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildCard(_templates[i]),
      ),
    );
  }

  Widget _buildCard(EmailTemplate t) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openEditor(existing: t),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined, size: 18, color: Color(0xFF455A64)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.naam,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF455A64)),
                    tooltip: 'Voorbeeld bekijken',
                    onPressed: () => _showPreview(t),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                    tooltip: 'Verwijderen',
                    onPressed: () => _delete(t),
                  ),
                ],
              ),
              if (t.onderwerp.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Onderwerp: ${t.onderwerp}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                t.inhoud,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateEditorDialog extends StatefulWidget {
  final EmailTemplate? existing;
  const _TemplateEditorDialog({this.existing});

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _naamCtrl;
  late final TextEditingController _onderwerpCtrl;
  late final TextEditingController _inhoudCtrl;

  static const _placeholders = [
    '{{naam}}',
    '{{plaats}}',
    '{{email}}',
    '{{telefoon}}',
    '{{contactpersoon}}',
    '{{contactpersonen}}',
    '{{boot_typen}}',
    '{{geschat_aantal_boten}}',
    '{{categorie}}',
    '{{erkenningen}}',
    '{{product}}',
    '{{gekozen_zeil}}',
    '{{product_url}}',
    '{{bestellink}}',
    '{{productlinks}}',
    '{{product_lijst}}',
    '{{kortingscode}}',
    '{{kortingscode_blok}}',
    '{{kortingspercentage}}',
    '{{geldig_tot}}',
    '{{proefperiode}}',
    '{{download_blok}}',
  ];

  @override
  void initState() {
    super.initState();
    _naamCtrl = TextEditingController(text: widget.existing?.naam ?? '');
    _onderwerpCtrl = TextEditingController(text: widget.existing?.onderwerp ?? '');
    _inhoudCtrl = TextEditingController(text: widget.existing?.inhoud ?? '');
  }

  @override
  void dispose() {
    _naamCtrl.dispose();
    _onderwerpCtrl.dispose();
    _inhoudCtrl.dispose();
    super.dispose();
  }

  void _insertPlaceholder(String ph) {
    final text = _inhoudCtrl.text;
    final sel = _inhoudCtrl.selection;
    final pos = sel.isValid ? sel.baseOffset : text.length;
    _inhoudCtrl.text = text.substring(0, pos) + ph + text.substring(pos);
    _inhoudCtrl.selection = TextSelection.collapsed(offset: pos + ph.length);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final template = EmailTemplate(
      id: widget.existing?.id,
      naam: _naamCtrl.text.trim(),
      onderwerp: _onderwerpCtrl.text.trim(),
      inhoud: _inhoudCtrl.text.trim(),
      createdAt: widget.existing?.createdAt,
    );
    Navigator.pop(context, template);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final screenWidth = MediaQuery.of(context).size.width;

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
                  const Icon(Icons.edit_note, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'Template bewerken' : 'Nieuw template',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _naamCtrl,
                        decoration: const InputDecoration(labelText: 'Template naam'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Naam is verplicht' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _onderwerpCtrl,
                        decoration: const InputDecoration(labelText: 'E-mail onderwerp'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _inhoudCtrl,
                        maxLines: 14,
                        decoration: const InputDecoration(
                          labelText: 'E-mail inhoud',
                          alignLabelWithHint: true,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Inhoud is verplicht' : null,
                      ),
                      const SizedBox(height: 12),
                      const Text('Beschikbare placeholders:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _placeholders.map((ph) {
                          return ActionChip(
                            label: Text(ph, style: const TextStyle(fontSize: 11)),
                            onPressed: () => _insertPlaceholder(ph),
                            backgroundColor: const Color(0xFFF1F5F9),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuleren')),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save, size: 18),
                    label: Text(isEditing ? 'Bijwerken' : 'Opslaan'),
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF455A64),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
