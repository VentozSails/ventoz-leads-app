import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/leads_service.dart';
import '../services/vat_service.dart';
import 'dashboard_screen.dart';

class AddLeadScreen extends StatefulWidget {
  final Country country;

  const AddLeadScreen({super.key, required this.country});

  @override
  State<AddLeadScreen> createState() => _AddLeadScreenState();
}

class _AddLeadScreenState extends State<AddLeadScreen> {
  final _formKey = GlobalKey<FormState>();
  final LeadsService _service = LeadsService();
  bool _saving = false;

  late Country _country = widget.country;

  final _naam = TextEditingController();
  final _contactpersoon = TextEditingController();
  final _email = TextEditingController();
  final _telefoon = TextEditingController();
  final _adres = TextEditingController();
  final _postcode = TextEditingController();
  final _plaats = TextEditingController();
  final _website = TextEditingController();
  final _bootTypen = TextEditingController();
  final _ventozKlantnr = TextEditingController();
  final _regio = TextEditingController();
  final _opmerkingen = TextEditingController();

  // NL-specific
  final _categorie = TextEditingController();
  final _geschatAantal = TextEditingController();
  final _erkenningen = TextEditingController();

  // BE-specific
  final _type = TextEditingController();
  final _relevantie = TextEditingController();
  final _functie = TextEditingController();
  final _disciplines = TextEditingController();
  final _doelgroep = TextEditingController();
  final _typeWater = TextEditingController();
  final _jeugdwerking = TextEditingController();
  final _commercieelModel = TextEditingController();

  String _status = 'Nieuw';
  String _hoofdtaal = 'Nederlands';

  static const _statusOptions = ['Nieuw', 'Aangeboden', 'Klant', 'Niet interessant'];
  static const _taalOptions = ['Nederlands', 'Frans', 'Duits', 'Engels'];

  @override
  void dispose() {
    for (final c in [_naam, _contactpersoon, _email, _telefoon, _adres, _postcode,
        _plaats, _website, _bootTypen, _ventozKlantnr, _regio, _opmerkingen,
        _categorie, _geschatAantal, _erkenningen, _type, _relevantie, _functie,
        _disciplines, _doelgroep, _typeWater, _jeugdwerking, _commercieelModel]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> _buildData() {
    final base = <String, dynamic>{
      'naam': _naam.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'telefoon': _telefoon.text.trim().isEmpty ? null : _telefoon.text.trim(),
      'adres': _adres.text.trim().isEmpty ? null : _adres.text.trim(),
      'postcode': _postcode.text.trim().isEmpty ? null : _postcode.text.trim(),
      'plaats': _plaats.text.trim().isEmpty ? null : _plaats.text.trim(),
      'website': _website.text.trim().isEmpty ? null : _website.text.trim(),
      'boot_typen': _bootTypen.text.trim().isEmpty ? null : _bootTypen.text.trim(),
      'ventoz_klantnr': _ventozKlantnr.text.trim().isEmpty ? null : _ventozKlantnr.text.trim(),
      'status': _status,
    };

    switch (_country) {
      case Country.nl:
        base['contactpersonen'] = _contactpersoon.text.trim().isEmpty ? null : _contactpersoon.text.trim();
        base['provincie'] = _regio.text.trim().isEmpty ? null : _regio.text.trim();
        base['categorie'] = _categorie.text.trim().isEmpty ? null : _categorie.text.trim();
        base['geschat_aantal_boten'] = _geschatAantal.text.trim().isEmpty ? null : _geschatAantal.text.trim();
        base['erkenningen'] = _erkenningen.text.trim().isEmpty ? null : _erkenningen.text.trim();
        base['opmerkingen'] = _opmerkingen.text.trim().isEmpty ? null : _opmerkingen.text.trim();
      case Country.de:
        base['contactpersoon'] = _contactpersoon.text.trim().isEmpty ? null : _contactpersoon.text.trim();
        base['bundesland'] = _regio.text.trim().isEmpty ? null : _regio.text.trim();
        base['categorie'] = _categorie.text.trim().isEmpty ? null : _categorie.text.trim();
      case Country.be:
        base['contactpersoon'] = _contactpersoon.text.trim().isEmpty ? null : _contactpersoon.text.trim();
        base['provincie'] = _regio.text.trim().isEmpty ? null : _regio.text.trim();
        base['hoofdtaal'] = _hoofdtaal;
        base['type'] = _type.text.trim().isEmpty ? null : _type.text.trim();
        base['relevantie'] = _relevantie.text.trim().isEmpty ? null : _relevantie.text.trim();
        base['functie'] = _functie.text.trim().isEmpty ? null : _functie.text.trim();
        base['disciplines'] = _disciplines.text.trim().isEmpty ? null : _disciplines.text.trim();
        base['doelgroep'] = _doelgroep.text.trim().isEmpty ? null : _doelgroep.text.trim();
        base['type_water'] = _typeWater.text.trim().isEmpty ? null : _typeWater.text.trim();
        base['jeugdwerking'] = _jeugdwerking.text.trim().isEmpty ? null : _jeugdwerking.text.trim();
        base['commercieel_model'] = _commercieelModel.text.trim().isEmpty ? null : _commercieelModel.text.trim();
        base['opmerking'] = _opmerkingen.text.trim().isEmpty ? null : _opmerkingen.text.trim();
    }

    return base;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await _service.insertLead(_buildData(), tableName: _country.tableName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_naam.text.trim()} toegevoegd aan ${_country.label}'), backgroundColor: const Color(0xFF43A047)),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error adding lead: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Toevoegen mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFEF4444)),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lead toevoegen')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCountrySelector(),
                  const SizedBox(height: 20),
                  _buildSection('Basisgegevens', [
                    _buildField(_naam, 'Naam *', required: true),
                    Row(children: [
                      Expanded(child: _buildField(_contactpersoon, 'Contactpersoon')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildField(_email, 'E-mail', type: TextInputType.emailAddress,
                        validator: (v) => v != null && v.trim().isNotEmpty && !VatService.isValidEmail(v) ? 'Ongeldig e-mailadres' : null)),
                    ]),
                    Row(children: [
                      Expanded(child: _buildField(_telefoon, 'Telefoon', type: TextInputType.phone)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildField(_website, 'Website')),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('Adres', [
                    _buildField(_adres, 'Adres'),
                    Row(children: [
                      SizedBox(width: 120, child: _buildField(_postcode, 'Postcode')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildField(_plaats, 'Plaats')),
                      const SizedBox(width: 12),
                      SizedBox(width: 180, child: _buildField(_regio, _country.regionLabel)),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('Status & Details', [
                    Row(children: [
                      Expanded(child: _buildDropdown('Status', _status, _statusOptions, (v) => setState(() => _status = v!))),
                      const SizedBox(width: 12),
                      Expanded(child: _buildField(_ventozKlantnr, 'Ventoz klantnr')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildField(_bootTypen, 'Boot typen')),
                    ]),
                    if (_country == Country.be)
                      _buildDropdown('Hoofdtaal', _hoofdtaal, _taalOptions, (v) => setState(() => _hoofdtaal = v!)),
                  ]),
                  if (_country == Country.nl) ...[
                    const SizedBox(height: 16),
                    _buildSection('Nederland-specifiek', [
                      Row(children: [
                        Expanded(child: _buildField(_categorie, 'Categorie')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField(_geschatAantal, 'Geschat aantal boten')),
                      ]),
                      _buildField(_erkenningen, 'Erkenningen'),
                    ]),
                  ],
                  if (_country == Country.be) ...[
                    const SizedBox(height: 16),
                    _buildSection('België-specifiek', [
                      Row(children: [
                        Expanded(child: _buildField(_type, 'Type')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField(_relevantie, 'Relevantie')),
                      ]),
                      Row(children: [
                        Expanded(child: _buildField(_functie, 'Functie')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField(_disciplines, 'Disciplines')),
                      ]),
                      Row(children: [
                        Expanded(child: _buildField(_doelgroep, 'Doelgroep')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField(_typeWater, 'Type water')),
                      ]),
                      Row(children: [
                        Expanded(child: _buildField(_jeugdwerking, 'Jeugdwerking')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildField(_commercieelModel, 'Commercieel model')),
                      ]),
                    ]),
                  ],
                  const SizedBox(height: 16),
                  _buildSection('Opmerkingen', [
                    _buildField(_opmerkingen, 'Opmerkingen', maxLines: 3),
                  ]),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Opslaan...' : 'Lead opslaan', style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountrySelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.public, color: Color(0xFF455A64)),
            const SizedBox(width: 12),
            const Text('Land:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(width: 12),
            SegmentedButton<Country>(
              segments: Country.values.map((c) => ButtonSegment(value: c, label: Text(c.label))).toList(),
              selected: {_country},
              onSelectionChanged: (s) => setState(() => _country = s.first),
              showSelectedIcon: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF37474F))),
            const SizedBox(height: 12),
            ...children.expand((w) => [w, const SizedBox(height: 10)]),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, {bool required = false, TextInputType? type, int maxLines = 1, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: validator ?? (required ? (v) => (v == null || v.trim().isEmpty) ? 'Verplicht' : null : null),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: onChanged,
    );
  }
}
