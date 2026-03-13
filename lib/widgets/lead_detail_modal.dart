import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../services/leads_service.dart';
import '../theme/app_theme.dart';
import '../screens/dashboard_screen.dart';

class LeadDetailModal extends StatefulWidget {
  final Lead lead;
  final ValueChanged<Lead> onSaved;
  final Country country;

  const LeadDetailModal({
    super.key,
    required this.lead,
    required this.onSaved,
    required this.country,
  });

  @override
  State<LeadDetailModal> createState() => _LeadDetailModalState();
}

class _LeadDetailModalState extends State<LeadDetailModal> {
  final _formKey = GlobalKey<FormState>();
  final LeadsService _service = LeadsService();
  bool _saving = false;

  late final Map<String, TextEditingController> _ctrls;
  late String _status;

  static const _statusOptions = ['Nieuw', 'Aangeboden', 'Klant', 'Niet interessant'];

  @override
  void initState() {
    super.initState();
    final l = widget.lead;
    _status = l.status;
    _ctrls = {
      'naam': TextEditingController(text: l.naam),
      'categorie': TextEditingController(text: l.categorie ?? ''),
      'nr': TextEditingController(text: l.nr ?? ''),
      'ventoz_klantnr': TextEditingController(text: l.ventozKlantnr ?? ''),
      'adres': TextEditingController(text: l.adres ?? ''),
      'postcode': TextEditingController(text: l.postcode ?? ''),
      'plaats': TextEditingController(text: l.plaats ?? ''),
      'region': TextEditingController(text: l.region ?? ''),
      'contactpersonen': TextEditingController(text: l.contactpersonen ?? ''),
      'telefoon': TextEditingController(text: l.telefoon ?? ''),
      'email': TextEditingController(text: l.email ?? ''),
      'website': TextEditingController(text: l.website ?? ''),
      'boot_typen': TextEditingController(text: l.typeBoten ?? ''),
      'geschat_aantal_boten': TextEditingController(text: l.geschatAantalBoten ?? ''),
      'erkenningen': TextEditingController(text: l.erkenningen ?? ''),
      'opmerkingen': TextEditingController(text: l.opmerkingen ?? ''),
      // BE-specific
      'regio': TextEditingController(text: l.regio ?? ''),
      'type': TextEditingController(text: l.type ?? ''),
      'relevantie': TextEditingController(text: l.relevantie ?? ''),
      'hoofdtaal': TextEditingController(text: l.hoofdtaal ?? ''),
      'functie': TextEditingController(text: l.functie ?? ''),
      'disciplines': TextEditingController(text: l.disciplines ?? ''),
      'doelgroep': TextEditingController(text: l.doelgroep ?? ''),
      'type_water': TextEditingController(text: l.typeWater ?? ''),
      'jeugdwerking': TextEditingController(text: l.jeugdwerking ?? ''),
      'commercieel_model': TextEditingController(text: l.commercieelModel ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _val(String key) {
    final v = _ctrls[key]!.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final updated = Lead(
      id: widget.lead.id,
      nr: _val('nr'),
      ventozKlantnr: _val('ventoz_klantnr'),
      region: _val('region'),
      categorie: _val('categorie'),
      naam: _ctrls['naam']!.text.trim(),
      adres: _val('adres'),
      postcode: _val('postcode'),
      plaats: _val('plaats'),
      contactpersonen: _val('contactpersonen'),
      telefoon: _val('telefoon'),
      email: _val('email'),
      website: _val('website'),
      typeBoten: _val('boot_typen'),
      geschatAantalBoten: _val('geschat_aantal_boten'),
      erkenningen: _val('erkenningen'),
      opmerkingen: _val('opmerkingen'),
      status: _status,
      // BE-specific
      regio: _val('regio'),
      type: _val('type'),
      relevantie: _val('relevantie'),
      hoofdtaal: _val('hoofdtaal'),
      functie: _val('functie'),
      disciplines: _val('disciplines'),
      doelgroep: _val('doelgroep'),
      typeWater: _val('type_water'),
      jeugdwerking: _val('jeugdwerking'),
      commercieelModel: _val('commercieel_model'),
    );

    try {
      final saved = await _service.updateLead(updated, tableName: widget.country.tableName);
      if (mounted) {
        widget.onSaved(saved);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opslaan mislukt: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 750;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: isWide ? 720 : screenWidth * 0.95,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: _buildFormFields(isWide),
                ),
              ),
            ),
            _buildActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields(bool isWide) {
    switch (widget.country) {
      case Country.nl:
        return _buildNlFields(isWide);
      case Country.de:
        return _buildDeFields(isWide);
      case Country.be:
        return _buildBeFields(isWide);
    }
  }

  Widget _buildNlFields(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Bedrijfsinfo'),
        _fieldGrid(isWide, [
          _field('naam', 'Naam', required: true),
          _field('categorie', 'Categorie'),
          _field('nr', 'Nr'),
          _field('ventoz_klantnr', 'Ventoz Klantnr'),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('Adres'),
        _fieldGrid(isWide, [
          _field('adres', 'Adres'),
          _field('postcode', 'Postcode'),
          _field('plaats', 'Plaats'),
          _field('region', 'Provincie'),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('Contact'),
        _fieldGrid(isWide, [
          _field('contactpersonen', 'Contactpersoon(en)'),
          _field('telefoon', 'Telefoon'),
          _field('email', 'E-mail'),
          _field('website', 'Website'),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('Boten'),
        _fieldGrid(isWide, [
          _field('boot_typen', 'Type boten / materiaal'),
          _field('geschat_aantal_boten', 'Geschat # boten'),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('Overig'),
        _fieldGrid(isWide, [
          _field('erkenningen', 'Erkenningen'),
          _statusDropdown(),
        ]),
        const SizedBox(height: 12),
        TextFormField(
          controller: _ctrls['opmerkingen'],
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Opmerkingen', alignLabelWithHint: true),
        ),
        _buildLastAction(),
      ],
    );
  }

  Widget _buildDeFields(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Betriebsinfo'),
        _fieldGrid(isWide, [
          _field('naam', 'Name', required: true),
          _field('categorie', 'Kategorie'),
          _field('nr', 'Nr'),
          _field('ventoz_klantnr', 'Ventoz Kundennr'),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('Adresse'),
        _fieldGrid(isWide, [
          _field('adres', 'Adresse'),
          _field('postcode', 'PLZ'),
          _field('plaats', 'Ort'),
          _field('region', 'Bundesland'),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('Kontakt'),
        _fieldGrid(isWide, [
          _field('contactpersonen', 'Ansprechpartner'),
          _field('telefoon', 'Telefon'),
          _field('email', 'E-Mail'),
          _field('website', 'Website'),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('Boote'),
        _fieldGrid(isWide, [
          _field('boot_typen', 'Bootstypen'),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('Sonstiges'),
        _fieldGrid(isWide, [
          _statusDropdown(),
        ]),
        _buildLastAction(),
      ],
    );
  }

  Widget _buildBeFields(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Organisatie'),
        _fieldGrid(isWide, [
          _field('naam', 'Naam', required: true),
          _field('type', 'Type'),
          _field('ventoz_klantnr', 'Ventoz Klantnr'),
          _field('relevantie', 'Relevantie'),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('Adres'),
        _fieldGrid(isWide, [
          _field('adres', 'Adres'),
          _field('postcode', 'Postcode'),
          _field('plaats', 'Plaats'),
          _field('region', 'Provincie'),
          _field('regio', 'Regio'),
          _field('hoofdtaal', 'Hoofdtaal'),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('Contact'),
        _fieldGrid(isWide, [
          _field('contactpersonen', 'Contactpersoon'),
          _field('functie', 'Functie'),
          _field('telefoon', 'Telefoon'),
          _field('email', 'E-mail'),
          _field('website', 'Website'),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('Activiteiten'),
        _fieldGrid(isWide, [
          _field('disciplines', 'Disciplines'),
          _field('doelgroep', 'Doelgroep'),
          _field('type_water', 'Type water'),
          _field('jeugdwerking', 'Jeugdwerking'),
          _field('commercieel_model', 'Commercieel model'),
        ]),
        const SizedBox(height: 20),
        _sectionTitle('Boten & Status'),
        _fieldGrid(isWide, [
          _field('boot_typen', 'Type boten'),
          _statusDropdown(),
        ]),
        const SizedBox(height: 12),
        TextFormField(
          controller: _ctrls['opmerkingen'],
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Opmerking', alignLabelWithHint: true),
        ),
        _buildLastAction(),
      ],
    );
  }

  Widget _buildLastAction() {
    if (widget.lead.laatsteActie == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        'Laatste actie: ${_formatDate(widget.lead.laatsteActie!)}',
        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF37474F),
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
      child: Row(
        children: [
          const Icon(Icons.business, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Lead Details', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                Row(
                  children: [
                    Flexible(child: Text(widget.lead.naam, style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13), overflow: TextOverflow.ellipsis)),
                    if (widget.lead.isKlant) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF43A047),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Klant', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(widget.country.label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuleren')),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, size: 18),
            label: const Text('Opslaan'),
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF37474F))),
    );
  }

  Widget _fieldGrid(bool isWide, List<Widget> children) {
    if (!isWide) {
      return Column(
        children: children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 12), child: w)).toList(),
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: 16),
            if (i + 1 < children.length) Expanded(child: children[i + 1]) else const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }

  Widget _field(String key, String label, {bool required = false}) {
    return TextFormField(
      controller: _ctrls[key],
      decoration: InputDecoration(labelText: label),
      validator: required ? (v) => v == null || v.trim().isEmpty ? '$label is verplicht' : null : null,
    );
  }

  Widget _statusDropdown() {
    if (widget.lead.isKlant) {
      return InputDecorator(
        decoration: const InputDecoration(labelText: 'Status'),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.statusColor('Klant').withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Klant', style: TextStyle(color: AppTheme.statusColor('Klant'), fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.lock_outline, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _statusOptions.contains(_status) ? _status : _statusOptions.first,
      decoration: const InputDecoration(labelText: 'Status'),
      items: _statusOptions.map((s) {
        return DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: AppTheme.statusColor(s))));
      }).toList(),
      onChanged: (v) {
        if (v != null) setState(() => _status = v);
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
