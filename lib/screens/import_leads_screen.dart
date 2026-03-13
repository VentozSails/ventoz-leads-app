import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import '../services/leads_service.dart';
import 'dashboard_screen.dart';

class ImportLeadsScreen extends StatefulWidget {
  final Country country;

  const ImportLeadsScreen({super.key, required this.country});

  @override
  State<ImportLeadsScreen> createState() => _ImportLeadsScreenState();
}

class _ImportLeadsScreenState extends State<ImportLeadsScreen> {
  final LeadsService _service = LeadsService();
  final _pasteController = TextEditingController();

  late Country _country = widget.country;
  List<Map<String, String>> _parsedRows = [];
  List<String> _headers = [];
  Map<String, String> _columnMapping = {};
  Set<int> _duplicateIndices = {};
  Set<int> _selectedIndices = {};
  bool _importing = false;
  bool _parsed = false;
  int _importedCount = 0;
  int _failedCount = 0;
  String _status = 'Nieuw';

  static const _statusOptions = ['Nieuw', 'Aangeboden', 'Klant', 'Niet interessant'];

  static const _targetFields = [
    '-- overslaan --',
    'naam', 'contactpersoon', 'email', 'telefoon', 'adres',
    'postcode', 'plaats', 'website', 'boot_typen', 'ventoz_klantnr',
    'regio', 'categorie', 'opmerkingen', 'hoofdtaal',
    'type', 'relevantie', 'functie', 'disciplines',
    'doelgroep', 'type_water', 'jeugdwerking', 'commercieel_model',
  ];

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  void _parseInput() {
    final input = _pasteController.text.trim();
    if (input.isEmpty) return;

    final delimiter = _detectDelimiter(input);
    final codec = CsvCodec(fieldDelimiter: delimiter);
    final rows = codec.decoder.convert(input);

    if (rows.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimaal 2 rijen nodig (header + data)'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    _headers = rows.first.map((e) => e.toString().trim()).toList();

    _columnMapping = {};
    for (final header in _headers) {
      _columnMapping[header] = _guessMapping(header);
    }

    _parsedRows = [];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final map = <String, String>{};
      for (int j = 0; j < _headers.length && j < row.length; j++) {
        map[_headers[j]] = row[j].toString().trim();
      }
      _parsedRows.add(map);
    }

    _selectedIndices = Set.from(List.generate(_parsedRows.length, (i) => i));

    setState(() => _parsed = true);

    _checkDuplicates();
  }

  String _detectDelimiter(String input) {
    final firstLine = input.split('\n').first;
    if (firstLine.contains(';')) return ';';
    if (firstLine.contains('\t')) return '\t';
    return ',';
  }

  String _guessMapping(String header) {
    final h = header.toLowerCase().replaceAll(RegExp(r'[_\-\s]+'), '');
    if (h.contains('naam') || h.contains('name') || h.contains('bedrijf') || h.contains('organisatie')) return 'naam';
    if (h.contains('contact') || h.contains('persoon')) return 'contactpersoon';
    if (h.contains('email') || h.contains('mail')) return 'email';
    if (h.contains('telef') || h.contains('phone') || h.contains('tel')) return 'telefoon';
    if (h.contains('adres') || h.contains('straat') || h.contains('address')) return 'adres';
    if (h.contains('postcode') || h.contains('zip') || h.contains('plz')) return 'postcode';
    if (h.contains('plaats') || h.contains('stad') || h.contains('city') || h.contains('ort')) return 'plaats';
    if (h.contains('website') || h.contains('url') || h.contains('web')) return 'website';
    if (h.contains('boot') || h.contains('boat')) return 'boot_typen';
    if (h.contains('klantnr') || h.contains('klant')) return 'ventoz_klantnr';
    if (h.contains('provincie') || h.contains('bundesland') || h.contains('regio') || h.contains('region')) return 'regio';
    if (h.contains('categorie') || h.contains('category')) return 'categorie';
    if (h.contains('opmerking') || h.contains('remark') || h.contains('note')) return 'opmerkingen';
    if (h.contains('taal') || h.contains('lang')) return 'hoofdtaal';
    return '-- overslaan --';
  }

  Future<void> _checkDuplicates() async {
    try {
      final existing = await _service.fetchLeads(tableName: _country.tableName);
      final existingNames = existing.map((l) => l.naam.toLowerCase().trim()).toSet();
      final existingEmails = existing.where((l) => l.email != null).map((l) => l.email!.toLowerCase().trim()).toSet();

      final dupes = <int>{};
      for (int i = 0; i < _parsedRows.length; i++) {
        final mapped = _mapRow(_parsedRows[i]);
        final name = (mapped['naam'] ?? '').toLowerCase().trim();
        final email = (mapped['email'] ?? '').toLowerCase().trim();
        if (name.isNotEmpty && existingNames.contains(name)) dupes.add(i);
        if (email.isNotEmpty && existingEmails.contains(email)) dupes.add(i);
      }
      setState(() {
        _duplicateIndices = dupes;
        _selectedIndices.removeAll(dupes);
      });
    } catch (_) {}
  }

  Map<String, dynamic> _mapRow(Map<String, String> row) {
    final result = <String, dynamic>{'status': _status};
    for (final entry in _columnMapping.entries) {
      final target = entry.value;
      if (target == '-- overslaan --') continue;
      final value = row[entry.key]?.trim();
      if (value != null && value.isNotEmpty) {
        result[_dbColumn(target)] = value;
      }
    }
    return result;
  }

  String _dbColumn(String field) {
    switch (_country) {
      case Country.nl:
        if (field == 'contactpersoon') return 'contactpersonen';
        if (field == 'regio') return 'provincie';
        if (field == 'opmerkingen') return 'opmerkingen';
        return field;
      case Country.de:
        if (field == 'regio') return 'bundesland';
        return field;
      case Country.be:
        if (field == 'regio') return 'provincie';
        if (field == 'opmerkingen') return 'opmerking';
        return field;
    }
  }

  Future<void> _import() async {
    setState(() { _importing = true; _importedCount = 0; _failedCount = 0; });

    for (final i in _selectedIndices.toList()..sort()) {
      final data = _mapRow(_parsedRows[i]);
      if ((data['naam'] as String?)?.isEmpty ?? true) continue;
      try {
        await _service.insertLead(data, tableName: _country.tableName);
        _importedCount++;
      } catch (_) {
        _failedCount++;
      }
      if (mounted) setState(() {});
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_importedCount leads geïmporteerd${_failedCount > 0 ? ', $_failedCount mislukt' : ''}'),
          backgroundColor: _failedCount == 0 ? const Color(0xFF43A047) : const Color(0xFFF59E0B),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leads importeren'),
        actions: [
          if (_parsed && _selectedIndices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: _importing ? null : _import,
                icon: _importing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload, size: 18),
                label: Text(_importing
                    ? '$_importedCount / ${_selectedIndices.length}'
                    : '${_selectedIndices.length} importeren'),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _parsed ? _buildPreview() : _buildInput(),
      ),
    );
  }

  Widget _buildInput() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCountryAndStatus(),
            const SizedBox(height: 16),
            const Text('Plak hieronder je CSV-data (met header-rij)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Scheidingsteken wordt automatisch gedetecteerd (komma, puntkomma of tab)',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey[400])),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _pasteController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'naam;email;telefoon;plaats\nBedrijf A;info@a.nl;0612345678;Amsterdam\n...',
                  hintStyle: TextStyle(color: Colors.blueGrey[300], fontFamily: 'monospace', fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _parseInput,
                icon: const Icon(Icons.table_chart),
                label: const Text('Verwerken', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryAndStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.public, color: Color(0xFF455A64)),
            const SizedBox(width: 12),
            const Text('Land:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            SegmentedButton<Country>(
              segments: Country.values.map((c) => ButtonSegment(value: c, label: Text(c.label))).toList(),
              selected: {_country},
              onSelectionChanged: (s) => setState(() { _country = s.first; if (_parsed) _checkDuplicates(); }),
              showSelectedIcon: false,
            ),
            const SizedBox(width: 24),
            const Text('Status:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _status,
              items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _status = v ?? 'Nieuw'),
              underline: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCountryAndStatus(),
        const SizedBox(height: 12),
        _buildMappingBar(),
        const SizedBox(height: 12),
        if (_duplicateIndices.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber, color: Colors.orange[700], size: 18),
              const SizedBox(width: 8),
              Text('${_duplicateIndices.length} mogelijke duplicaten gevonden (gedeselecteerd)',
                  style: TextStyle(fontSize: 13, color: Colors.orange[800])),
            ]),
          ),
        Row(
          children: [
            Text('${_parsedRows.length} rijen, ${_selectedIndices.length} geselecteerd',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const Spacer(),
            TextButton(onPressed: () => setState(() => _selectedIndices = Set.from(List.generate(_parsedRows.length, (i) => i))),
                child: const Text('Alles')),
            TextButton(onPressed: () => setState(() => _selectedIndices.clear()), child: const Text('Geen')),
            TextButton.icon(
              onPressed: () => setState(() { _parsed = false; }),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Terug'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: _parsedRows.length,
            itemBuilder: (_, i) => _buildRowCard(i),
          ),
        ),
      ],
    );
  }

  Widget _buildMappingBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kolomtoewijzing', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: _headers.map((h) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(h, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 12, color: Color(0xFF90A4AE)),
                  const SizedBox(width: 4),
                  DropdownButton<String>(
                    value: _columnMapping[h],
                    isDense: true,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF37474F)),
                    underline: const SizedBox.shrink(),
                    items: _targetFields.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                    onChanged: (v) => setState(() { _columnMapping[h] = v!; _checkDuplicates(); }),
                  ),
                ],
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowCard(int index) {
    final row = _parsedRows[index];
    final isDupe = _duplicateIndices.contains(index);
    final isSelected = _selectedIndices.contains(index);
    final mapped = _mapRow(row);
    final name = mapped['naam'] ?? mapped['contactpersonen'] ?? mapped['contactpersoon'] ?? '(geen naam)';

    return Card(
      elevation: 0,
      color: isDupe
          ? Colors.orange[50]
          : isSelected
              ? Colors.white
              : Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isDupe ? Colors.orange[300]! : isSelected ? const Color(0xFF455A64) : Colors.grey[200]!),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (_) => setState(() {
          if (isSelected) {
            _selectedIndices.remove(index);
          } else {
            _selectedIndices.add(index);
          }
        }),
        activeColor: const Color(0xFF455A64),
        title: Row(
          children: [
            Expanded(child: Text(name.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            if (isDupe)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(4)),
                child: Text('Duplicaat', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange[800])),
              ),
          ],
        ),
        subtitle: Text(
          row.values.where((v) => v.isNotEmpty).take(4).join(' | '),
          style: TextStyle(fontSize: 11, color: Colors.blueGrey[500]),
          overflow: TextOverflow.ellipsis,
        ),
        dense: true,
      ),
    );
  }
}
