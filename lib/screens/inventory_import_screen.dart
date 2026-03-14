import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/file_reader.dart';
import '../services/inventory_service.dart';
import '../services/packaging_service.dart';
import '../services/user_service.dart';
import 'inventory_dashboard_screen.dart';

class InventoryImportScreen extends StatefulWidget {
  const InventoryImportScreen({super.key});

  static const routeName = '/dashboard/voorraad/import';

  @override
  State<InventoryImportScreen> createState() => _InventoryImportScreenState();
}

enum ImportType { voorraad, gewichten, verpakkingen }
enum ImportMode { bijwerken, vervangen }

class _InventoryImportScreenState extends State<InventoryImportScreen> {
  static const _navy = Color(0xFF1E3A5F);

  final InventoryService _inventoryService = InventoryService();
  final PackagingService _packagingService = PackagingService();
  final UserService _userService = UserService();

  ImportType _importType = ImportType.voorraad;
  ImportMode _importMode = ImportMode.bijwerken;
  int _step = 0;
  String? _fileName;
  List<CsvImportRow> _rows = [];
  List<CsvImportRow> _packagingRows = [];
  bool _updateWeights = true;
  bool _updatePrices = true;
  bool _loading = false;
  String? _error;
  int _importedCount = 0;
  ImportVerificationReport? _verificationReport;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final perms = await _userService.getCurrentUserPermissions();
    if (!perms.voorraadImporteren) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geen toegang'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
      return;
    }
  }

  Future<void> _pickFile() async {
    setState(() {
      _loading = true;
      _error = null;
      _fileName = null;
      _rows = [];
      _packagingRows = [];
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty || !mounted) {
        setState(() => _loading = false);
        return;
      }

      final file = result.files.first;
      List<int>? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await readFileBytes(file.path!);
      }
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Bestand kon niet worden gelezen.';
        });
        return;
      }

      final content = String.fromCharCodes(bytes);
      final rows = _inventoryService.parseCsv(content);

      if (rows.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Geen geldige rijen gevonden in het CSV-bestand.';
        });
        return;
      }

      if (_importType == ImportType.verpakkingen) {
        final pkgRows = _inventoryService.extractPackagingRows(rows);
        if (pkgRows.isEmpty) {
          setState(() {
            _loading = false;
            _error = 'Geen verpakkingen/dozen gevonden in het CSV-bestand. '
                'Zorg dat productnamen "doos", "verpakking" of "karton" bevatten.';
          });
          return;
        }
        setState(() {
          _fileName = file.name;
          _rows = rows;
          _packagingRows = pkgRows;
          _step = 2;
          _loading = false;
        });
      } else {
        setState(() {
          _fileName = file.name;
          _rows = rows;
          _step = 1;
          _loading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('InventoryImport pickFile error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Fout bij laden: $e';
        });
      }
    }
  }

  Future<void> _matchAndPreview() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _inventoryService.matchImportRows(_rows);

      for (final row in _rows) {
        final hasId = (row.productNaam?.isNotEmpty == true) ||
            (row.eanCode?.isNotEmpty == true) ||
            (row.artikelnummer?.isNotEmpty == true) ||
            (row.leverancierCode?.isNotEmpty == true);
        if (!hasId) {
          row.matchedStatus = 'error';
        }
      }

      if (mounted) {
        setState(() {
          _step = 2;
          _loading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('InventoryImport matchImportRows error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Fout bij matchen: $e';
        });
      }
    }
  }

  Future<void> _doImport() async {
    if (_importType == ImportType.voorraad &&
        _importMode == ImportMode.vervangen) {
      final confirmed = await _showReplaceConfirmation();
      if (!confirmed) return;
    }

    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      int count = 0;
      switch (_importType) {
        case ImportType.voorraad:
          final importable =
              _rows.where((r) => r.matchedStatus != 'error').toList();
          if (importable.isEmpty) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Geen items om te importeren.'),
                backgroundColor: Color(0xFFF59E0B),
              ),
            );
            setState(() => _loading = false);
            return;
          }
          if (_importMode == ImportMode.vervangen) {
            count = await _inventoryService.replaceAllWithCsvRows(
              importable,
              updateWeights: _updateWeights,
              updatePrices: _updatePrices,
            );
          } else {
            count = await _inventoryService.importCsvRows(
              importable,
              updateWeights: _updateWeights,
              updatePrices: _updatePrices,
            );
          }
          break;

        case ImportType.gewichten:
          count = await _inventoryService.importWeightsCsv(_rows);
          break;

        case ImportType.verpakkingen:
          count = await _importPackagingRows();
          break;
      }

      // Post-import verification for voorraad
      ImportVerificationReport? report;
      if (_importType == ImportType.voorraad) {
        try {
          report = await _inventoryService.verifyImport(_rows);
        } catch (e) {
          if (kDebugMode) debugPrint('Verification error: $e');
        }
      }

      if (mounted) {
        setState(() {
          _step = 3;
          _importedCount = count;
          _verificationReport = report;
          _loading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('InventoryImport import error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Import mislukt: $e';
        });
      }
    }
  }

  Future<bool> _showReplaceConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Voorraad volledig vervangen?'),
            content: const Text(
              'Alle bestaande voorraadgegevens en mutatiehistorie worden '
              'verwijderd en vervangen door de data uit dit CSV-bestand.\n\n'
              'Dit kan niet ongedaan worden gemaakt.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuleren'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                ),
                child: const Text('Ja, vervangen'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<int> _importPackagingRows() async {
    int count = 0;
    for (final row in _packagingRows) {
      final naam = row.productNaam ?? 'Onbekende verpakking';
      final gewicht = row.gewichtGram ?? row.gewichtVerpakkingGram ?? 0;
      try {
        await _packagingService.save(PackagingBox(
          naam: naam,
          gewicht: gewicht,
          sortOrder: count,
        ));
        count++;
      } catch (e) {
        if (kDebugMode) debugPrint('Import packaging row error: $e');
      }
    }
    return count;
  }

  int get _matchedCount =>
      _rows.where((r) => r.matchedStatus == 'matched').length;
  int get _newCount => _rows.where((r) => r.matchedStatus == 'new').length;
  int get _errorCount =>
      _rows.where((r) => r.matchedStatus == 'error').length;
  int get _importableCount =>
      _rows.where((r) => r.matchedStatus != 'error').length;

  IconData _statusIcon(CsvImportRow row) {
    switch (row.matchedStatus) {
      case 'matched':
        return Icons.check_circle;
      case 'new':
        return Icons.add_circle;
      case 'error':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Color _statusColor(CsvImportRow row) {
    switch (row.matchedStatus) {
      case 'matched':
        return const Color(0xFF22C55E);
      case 'new':
        return const Color(0xFFF59E0B);
      case 'error':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  void _reset() {
    setState(() {
      _step = 0;
      _fileName = null;
      _rows = [];
      _packagingRows = [];
      _error = null;
      _importedCount = 0;
      _verificationReport = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voorraad importeren'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildStepperContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFEF4444)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  if (_step == 0) _reset();
                });
              },
              child: const Text('Opnieuw proberen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStepIndicator(),
          const SizedBox(height: 24),
          if (_step == 0) _buildStep0TypeSelect(),
          if (_step == 1) _buildStep1Preview(),
          if (_step == 2) _buildStep2Confirm(),
          if (_step == 3) _buildStep3Result(),
          const SizedBox(height: 24),
          _buildHelpSection(),
          const SizedBox(height: 12),
          _buildExcelInstructions(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _stepDot(0, 'Type & bestand'),
            _stepConnector(_step > 0),
            _stepDot(1, 'Preview'),
            _stepConnector(_step > 1),
            _stepDot(2, 'Importeren'),
          ],
        ),
      ),
    );
  }

  Widget _stepDot(int step, String label) {
    final active = _step == step ||
        (_importType == ImportType.verpakkingen && step == 1 && _step == 2);
    final done = _step > step &&
        !(_importType == ImportType.verpakkingen && step == 1 && _step == 2);
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: done
                  ? const Color(0xFF22C55E)
                  : active
                      ? _navy
                      : const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: done
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Center(
                    child: Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: active ? Colors.white : const Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: active ? _navy : const Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _stepConnector(bool active) {
    return Container(
      width: 24,
      height: 2,
      color: active ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
    );
  }

  // ── Step 0: Import type + mode selection + file pick ──

  Widget _buildStep0TypeSelect() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Stap 1: Importtype & modus',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecteer welk type gegevens en hoe je wilt importeren.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),

            // Import type chips
            const Text('Importtype',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _importTypeChip(
                  ImportType.voorraad,
                  Icons.inventory_2,
                  'Voorraad',
                  'Voorraadaantallen, prijzen, leverancierscodes',
                ),
                _importTypeChip(
                  ImportType.gewichten,
                  Icons.scale,
                  'Gewichten',
                  'Productgewichten bijwerken in catalogus',
                ),
                _importTypeChip(
                  ImportType.verpakkingen,
                  Icons.all_inbox,
                  'Verpakkingen',
                  'Dozen herkennen uit voorraadlijst',
                ),
              ],
            ),

            // Import mode (only for voorraad)
            if (_importType == ImportType.voorraad) ...[
              const SizedBox(height: 20),
              const Text('Importmodus',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _importModeChip(ImportMode.bijwerken)),
                  const SizedBox(width: 8),
                  Expanded(child: _importModeChip(ImportMode.vervangen)),
                ],
              ),
            ],

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: Text(_fileName != null
                  ? 'Ander CSV-bestand kiezen'
                  : 'CSV-bestand kiezen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Geselecteerd: $_fileName',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_rows.length} rijen gevonden',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _rows.isNotEmpty
                    ? () {
                        if (_importType == ImportType.verpakkingen) {
                          // Already at step 2 after file pick
                        } else {
                          _matchAndPreview();
                        }
                      }
                    : null,
                child: const Text('Doorgaan naar preview'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _importTypeChip(
      ImportType type, IconData icon, String label, String description) {
    final selected = _importType == type;
    return GestureDetector(
      onTap: () => setState(() {
        _importType = type;
        _fileName = null;
        _rows = [];
        _packagingRows = [];
        _step = 0;
      }),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              selected ? _navy.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          border: Border.all(
            color: selected ? _navy : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: selected ? _navy : const Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? _navy : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _importModeChip(ImportMode mode) {
    final selected = _importMode == mode;
    final isBijwerken = mode == ImportMode.bijwerken;

    return GestureDetector(
      onTap: () => setState(() => _importMode = mode),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? (isBijwerken
                  ? _navy.withValues(alpha: 0.08)
                  : const Color(0xFFFEF2F2))
              : const Color(0xFFF8FAFC),
          border: Border.all(
            color: selected
                ? (isBijwerken ? _navy : const Color(0xFFEF4444))
                : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isBijwerken ? Icons.merge_type : Icons.swap_horiz,
                  size: 18,
                  color: selected
                      ? (isBijwerken ? _navy : const Color(0xFFEF4444))
                      : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 6),
                Text(
                  isBijwerken ? 'Bijwerken' : 'Vervangen',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? (isBijwerken ? _navy : const Color(0xFFEF4444))
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isBijwerken
                  ? 'Bestaande data bijwerken met nieuwe waarden. Niet-gewijzigde items blijven behouden.'
                  : 'Alle bestaande voorraaddata verwijderen en volledig opnieuw vullen vanuit het CSV-bestand.',
              style: TextStyle(
                fontSize: 10,
                color: selected && !isBijwerken
                    ? const Color(0xFFB91C1C)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: Preview & matching (voorraad/gewichten) ──

  Widget _buildStep1Preview() {
    final isGewichten = _importType == ImportType.gewichten;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isGewichten
                  ? 'Stap 2: Preview gewichten'
                  : 'Stap 2: Preview & matching',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isGewichten
                  ? '${_rows.where((r) => r.gewichtGram != null && r.gewichtGram! > 0).length} rijen met gewichtgegevens'
                  : '$_matchedCount gematched, $_newCount nieuw, $_errorCount fouten',
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            if (!isGewichten &&
                _importType == ImportType.voorraad &&
                _importMode == ImportMode.vervangen)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 16, color: Color(0xFFEF4444)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Modus: VERVANGEN — alle bestaande voorraaddata wordt verwijderd bij import.',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFFB91C1C)),
                      ),
                    ),
                  ],
                ),
              ),
            if (!isGewichten) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Gewichten bijwerken'),
                value: _updateWeights,
                onChanged: (v) => setState(() => _updateWeights = v),
                activeTrackColor: _navy.withValues(alpha: 0.5),
              ),
              SwitchListTile(
                title: const Text('Prijzen bijwerken'),
                value: _updatePrices,
                onChanged: (v) => setState(() => _updatePrices = v),
                activeTrackColor: _navy.withValues(alpha: 0.5),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor:
                        WidgetStateProperty.all(_navy.withValues(alpha: 0.1)),
                    columns: isGewichten
                        ? const [
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Product')),
                            DataColumn(label: Text('EAN')),
                            DataColumn(label: Text('Artikelnr')),
                            DataColumn(label: Text('Gewicht')),
                            DataColumn(label: Text('Gew. verp.')),
                          ]
                        : const [
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Product')),
                            DataColumn(label: Text('Kleur')),
                            DataColumn(label: Text('VE-code')),
                            DataColumn(label: Text('Voorraad')),
                            DataColumn(label: Text('Inkoop')),
                            DataColumn(label: Text('Categorie')),
                          ],
                    rows: _rows.take(50).map((row) {
                      if (isGewichten) {
                        return DataRow(cells: [
                          DataCell(Icon(
                            _statusIcon(row),
                            color: _statusColor(row),
                            size: 20,
                          )),
                          DataCell(Text(
                            row.matchedProductNaam ?? row.productNaam ?? '-',
                            style: const TextStyle(fontSize: 12),
                          )),
                          DataCell(Text(
                            row.eanCode ?? '-',
                            style: const TextStyle(fontSize: 12),
                          )),
                          DataCell(Text(
                            row.artikelnummer ?? '-',
                            style: const TextStyle(fontSize: 12),
                          )),
                          DataCell(Text(
                            row.gewichtGram != null
                                ? '${row.gewichtGram} g'
                                : '-',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: row.gewichtGram != null
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFF94A3B8),
                            ),
                          )),
                          DataCell(Text(
                            row.gewichtVerpakkingGram != null
                                ? '${row.gewichtVerpakkingGram} g'
                                : '-',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: row.gewichtVerpakkingGram != null
                                  ? const Color(0xFF1565C0)
                                  : const Color(0xFF94A3B8),
                            ),
                          )),
                        ]);
                      }
                      return DataRow(cells: [
                        DataCell(Icon(
                          _statusIcon(row),
                          color: _statusColor(row),
                          size: 20,
                        )),
                        DataCell(Text(
                          row.matchedProductNaam ?? row.productNaam ?? '-',
                          style: const TextStyle(fontSize: 12),
                        )),
                        DataCell(Text(
                          row.kleur ?? '-',
                          style: const TextStyle(fontSize: 12),
                        )),
                        DataCell(Text(
                          row.leverancierCode ?? '-',
                          style: const TextStyle(
                              fontSize: 12, fontFamily: 'monospace'),
                        )),
                        DataCell(Text(
                          '${row.voorraad ?? 0}',
                          style: const TextStyle(fontSize: 12),
                        )),
                        DataCell(Text(
                          row.inkoopPrijs != null
                              ? '\u20AC${row.inkoopPrijs!.toStringAsFixed(2).replaceAll('.', ',')}'
                              : '-',
                          style: const TextStyle(fontSize: 12),
                        )),
                        DataCell(Text(
                          row.categorie ?? '-',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8)),
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
            if (_rows.length > 50)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '... en nog ${_rows.length - 50} rijen',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isGewichten
                  ? (_rows
                          .where((r) =>
                              r.gewichtGram != null && r.gewichtGram! > 0)
                          .isNotEmpty
                      ? _doImport
                      : null)
                  : (_importableCount > 0 ? _doImport : null),
              style: ElevatedButton.styleFrom(
                backgroundColor: _importMode == ImportMode.vervangen
                    ? const Color(0xFFEF4444)
                    : _navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(isGewichten
                  ? 'Gewichten importeren'
                  : _importMode == ImportMode.vervangen
                      ? 'Vervang voorraad met $_importableCount items'
                      : 'Importeer $_importableCount items'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Confirm (voorraad uses step 2 too, verpakkingen preview) ──

  Widget _buildStep2Confirm() {
    if (_importType == ImportType.verpakkingen) {
      return _buildPackagingPreview();
    }
    return _buildStep1Preview();
  }

  Widget _buildPackagingPreview() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Gevonden verpakkingen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_packagingRows.length} verpakking${_packagingRows.length == 1 ? '' : 'en'} herkend uit het CSV-bestand.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Na import kun je de namen aanpassen in het verpakkingenscherm.',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(_navy.withValues(alpha: 0.1)),
                  columns: const [
                    DataColumn(label: Text('Naam')),
                    DataColumn(label: Text('Gewicht')),
                    DataColumn(label: Text('Categorie')),
                  ],
                  rows: _packagingRows.map((row) {
                    return DataRow(cells: [
                      DataCell(Text(
                        row.productNaam ?? '-',
                        style: const TextStyle(fontSize: 12),
                      )),
                      DataCell(Text(
                        row.gewichtGram != null
                            ? '${row.gewichtGram} g'
                            : (row.gewichtVerpakkingGram != null
                                ? '${row.gewichtVerpakkingGram} g'
                                : '-'),
                        style: const TextStyle(fontSize: 12),
                      )),
                      DataCell(Text(
                        row.categorie ?? '-',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _packagingRows.isNotEmpty ? _doImport : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                  'Importeer ${_packagingRows.length} verpakking${_packagingRows.length == 1 ? '' : 'en'}'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 3: Result ──

  Widget _buildStep3Result() {
    final typeLabel = switch (_importType) {
      ImportType.voorraad => 'voorraaditem${_importedCount == 1 ? '' : 's'}',
      ImportType.gewichten =>
        'productgewicht${_importedCount == 1 ? '' : 'en'}',
      ImportType.verpakkingen =>
        'verpakking${_importedCount == 1 ? '' : 'en'}',
    };

    final modeLabel = _importType == ImportType.voorraad &&
            _importMode == ImportMode.vervangen
        ? ' (volledig vervangen)'
        : '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle,
              color: Color(0xFF22C55E),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              '$_importedCount $typeLabel ge\u00efmporteerd$modeLabel',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _navy,
              ),
              textAlign: TextAlign.center,
            ),
            if (_verificationReport != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _verificationReport!.isOk
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _verificationReport!.isOk
                        ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                        : const Color(0xFFEF4444).withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _verificationReport!.isOk ? Icons.verified : Icons.warning_amber_rounded,
                          size: 18,
                          color: _verificationReport!.isOk ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _verificationReport!.isOk ? 'Verificatie geslaagd' : 'Verificatie: afwijkingen gevonden',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _verificationReport!.isOk ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'CSV: ${_verificationReport!.csvTotalRows} rijen, '
                      '${_verificationReport!.csvProductCount} producten, '
                      '${_verificationReport!.csvTotalStock} stk\n'
                      'DB:  ${_verificationReport!.dbTotalRows} rijen, '
                      '${_verificationReport!.dbProductCount} producten, '
                      '${_verificationReport!.dbTotalStock} stk',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.5),
                    ),
                    if (_verificationReport!.mismatches.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      ...(_verificationReport!.mismatches.take(10).map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('• ${m.description}', style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B))),
                      ))),
                      if (_verificationReport!.mismatches.length > 10)
                        Text('... en ${_verificationReport!.mismatches.length - 10} meer', style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B))),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text('Nieuwe import'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const InventoryDashboardScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.dashboard),
                    label: const Text('Voorraadoverzicht'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: const Text(
          'Verwachte CSV-indeling',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'De eerste rij moet kolomkoppen bevatten. Ondersteunde kolommen (hoofdletterongevoelig):',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),
                const Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    Chip(label: Text('categorie')),
                    Chip(label: Text('product')),
                    Chip(label: Text('kleur')),
                    Chip(label: Text('artikelnummer')),
                    Chip(label: Text('ean')),
                    Chip(label: Text('voorraad')),
                    Chip(label: Text('minimaal')),
                    Chip(label: Text('besteld')),
                    Chip(label: Text('inkoop')),
                    Chip(label: Text('vliegtuig_kosten')),
                    Chip(label: Text('invoertax_admin')),
                    Chip(label: Text('inkoop_totaal')),
                    Chip(label: Text('netto_inkoop')),
                    Chip(label: Text('netto_inkoop_waarde')),
                    Chip(label: Text('import_kosten')),
                    Chip(label: Text('bruto_inkoop')),
                    Chip(label: Text('verkoopprijs_incl')),
                    Chip(label: Text('verkoopprijs_excl')),
                    Chip(label: Text('verkoop_waarde_excl')),
                    Chip(label: Text('verkoop_waarde_incl')),
                    Chip(label: Text('marge')),
                    Chip(label: Text('gewicht')),
                    Chip(label: Text('gewicht_verpakking')),
                    Chip(label: Text('vervoer')),
                    Chip(label: Text('code')),
                    Chip(label: Text('opmerking')),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Scheidingsteken: komma of puntkomma. Codering: UTF-8.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 16, color: Color(0xFFF9A825)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bij importtype "Verpakkingen" worden rijen met "doos", '
                          '"verpakking" of "karton" in de productnaam automatisch herkend.',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF6D4C00)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExcelInstructions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(Icons.help_outline, color: _navy, size: 20),
        title: const Text(
          'Excel naar CSV omzetten',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _navy,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Het Ventoz voorraad-Excelbestand moet eerst worden omgezet naar een CSV-bestand. '
                  'Er zijn twee methoden:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 16),

                // Method 1: Python script
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Methode 1: Automatisch (aanbevolen)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF166534),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Gebruik het meegeleverde Python-script dat het Excelbestand '
                        'correct verwerkt (inclusief productnamen, categorieën, '
                        'en filtering van totaalrijen en dozen):\n\n'
                        '1. Zet het Excel-bestand op je bureaublad\n'
                        '2. Open een terminal/opdrachtprompt\n'
                        '3. Navigeer naar de app-map: tools/\n'
                        '4. Voer uit: python generate_import_csv.py\n'
                        '5. Het CSV-bestand verschijnt op je bureaublad '
                        'in de map ventoz_import_csv/',
                        style: TextStyle(fontSize: 12, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Method 2: Manual
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Methode 2: Handmatig via Excel',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF9A3412),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '1. Open het Excelbestand\n'
                        '2. Controleer dat kolom A een categorie bevat en '
                        'kolom B de productnaam. Vul lege productnamen aan '
                        '(Excel herhaalt de naam niet bij varianten)\n'
                        '3. Verwijder de totaalrij onderaan (rij met "totaal")\n'
                        '4. Verwijder de dozen-rijen (Wit kleinste, groot, etc.)\n'
                        '5. Voeg bovenaan een header-rij toe met kolomnamen: '
                        'categorie;product;kleur;artikelnummer;gewicht;'
                        'gewicht_verpakking;...;code;marge\n'
                        '6. Kies Opslaan als > CSV (gescheiden door lijstscheidingsteken)\n'
                        '7. Kies codering: UTF-8',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9A3412)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Color(0xFF2563EB)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Belangrijk: het Excel-bestand bevat per product meerdere '
                          'bestelrijen (VE-codes) zonder herhaalde productnaam. '
                          'Bij handmatige export moet je de productnaam zelf invullen '
                          'bij elke rij. Het Python-script doet dit automatisch.',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF1E40AF)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
