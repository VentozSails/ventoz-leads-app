import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/myparcel_service.dart';
import '../services/packaging_service.dart';
import '../services/user_service.dart';

class AdminMyParcelSettingsScreen extends StatefulWidget {
  const AdminMyParcelSettingsScreen({super.key});

  @override
  State<AdminMyParcelSettingsScreen> createState() => _AdminMyParcelSettingsScreenState();
}

class _AdminMyParcelSettingsScreenState extends State<AdminMyParcelSettingsScreen> {
  static const _navy = Color(0xFF0D1B2A);

  final _service = MyParcelService();
  final _packagingService = PackagingService();
  final _userService = UserService();

  final _apiKeyCtrl = TextEditingController();
  final _senderNameCtrl = TextEditingController();
  final _senderStreetCtrl = TextEditingController();
  final _senderNumberCtrl = TextEditingController();
  final _senderPostalCtrl = TextEditingController();
  final _senderCityCtrl = TextEditingController();
  final _senderCcCtrl = TextEditingController();
  final _senderEmailCtrl = TextEditingController();
  final _senderPhoneCtrl = TextEditingController();
  final _maxGewichtCtrl = TextEditingController();
  final _maxOmtrekCtrl = TextEditingController();

  int _defaultCarrierId = 1;
  String _defaultBoxId = '';
  List<PackagingBox> _boxes = [];

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool? _testResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _senderNameCtrl.dispose();
    _senderStreetCtrl.dispose();
    _senderNumberCtrl.dispose();
    _senderPostalCtrl.dispose();
    _senderCityCtrl.dispose();
    _senderCcCtrl.dispose();
    _senderEmailCtrl.dispose();
    _senderPhoneCtrl.dispose();
    _maxGewichtCtrl.dispose();
    _maxOmtrekCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.myparcelInstellingen) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
        );
      }
      return;
    }
    final config = await _service.getConfig();
    _boxes = await _packagingService.getAll();
    if (!mounted) return;
    setState(() {
      if (config != null) {
        _apiKeyCtrl.text = config.apiKey;
        _defaultCarrierId = config.defaultCarrierId;
        _defaultBoxId = config.defaultBoxId;
        _senderNameCtrl.text = config.senderName;
        _senderStreetCtrl.text = config.senderStreet;
        _senderNumberCtrl.text = config.senderNumber;
        _senderPostalCtrl.text = config.senderPostalCode;
        _senderCityCtrl.text = config.senderCity;
        _senderCcCtrl.text = config.senderCc;
        _senderEmailCtrl.text = config.senderEmail;
        _senderPhoneCtrl.text = config.senderPhone;
        _maxGewichtCtrl.text = config.maxGewichtGram.toString();
        _maxOmtrekCtrl.text = config.maxOmtrekCm.toString();
      } else {
        _senderNameCtrl.text = 'Ventoz Sails';
        _senderStreetCtrl.text = 'Dorpsstraat';
        _senderNumberCtrl.text = '111';
        _senderPostalCtrl.text = '7948BN';
        _senderCityCtrl.text = 'Nijeveen';
        _senderCcCtrl.text = 'NL';
        _senderEmailCtrl.text = 'info@ventoz.nl';
        _senderPhoneCtrl.text = '0610193845';
        _maxGewichtCtrl.text = '31500';
        _maxOmtrekCtrl.text = '176';
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.saveConfig(MyParcelConfig(
        apiKey: _apiKeyCtrl.text.trim(),
        defaultCarrierId: _defaultCarrierId,
        defaultBoxId: _defaultBoxId,
        senderName: _senderNameCtrl.text.trim(),
        senderStreet: _senderStreetCtrl.text.trim(),
        senderNumber: _senderNumberCtrl.text.trim(),
        senderPostalCode: _senderPostalCtrl.text.trim(),
        senderCity: _senderCityCtrl.text.trim(),
        senderCc: _senderCcCtrl.text.trim(),
        senderEmail: _senderEmailCtrl.text.trim(),
        senderPhone: _senderPhoneCtrl.text.trim(),
        maxGewichtGram: int.tryParse(_maxGewichtCtrl.text) ?? 31500,
        maxOmtrekCm: int.tryParse(_maxOmtrekCtrl.text) ?? 176,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MyParcel instellingen opgeslagen'), backgroundColor: Color(0xFF43A047)),
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving MyParcel settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opslaan mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFE53935)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    await _save();
    setState(() { _testing = true; _testResult = null; });
    final ok = await _service.testConnection();
    if (mounted) setState(() { _testing = false; _testResult = ok; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/ventoz_logo.png', width: 28, height: 28)),
          const SizedBox(width: 10),
          const Text('MyParcel Instellingen'),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildApiSection(),
                    const SizedBox(height: 24),
                    _buildDefaultsSection(),
                    const SizedBox(height: 24),
                    _buildLimitsSection(),
                    const SizedBox(height: 24),
                    _buildSenderSection(),
                    const SizedBox(height: 24),
                    _buildActions(),
                  ]),
                ),
              ),
            ),
    );
  }

  Widget _buildApiSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.vpn_key, size: 22, color: Color(0xFF455A64)),
            const SizedBox(width: 8),
            Text('API koppeling', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: _navy)),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('API key aanmaken', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF455A64))),
              SizedBox(height: 2),
              Text('MyParcel Backoffice → Instellingen → Integratie → API key', style: TextStyle(fontSize: 11, color: Color(0xFF78909C))),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'Je MyParcel API key',
              prefixIcon: Icon(Icons.key, size: 20),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildDefaultsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.tune, size: 22, color: Color(0xFF455A64)),
            const SizedBox(width: 8),
            Text('Standaardinstellingen', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: _navy)),
          ]),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _defaultCarrierId,
            decoration: const InputDecoration(
              labelText: 'Standaard vervoerder',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: MyParcelService.carriers.entries.map((e) =>
              DropdownMenuItem(value: e.key, child: Text(e.value)),
            ).toList(),
            onChanged: (v) => setState(() => _defaultCarrierId = v ?? 1),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _defaultBoxId.isEmpty ? null : _defaultBoxId,
            decoration: const InputDecoration(
              labelText: 'Standaard verpakking',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Geen standaard')),
              ..._boxes.map((b) => DropdownMenuItem(value: b.id, child: Text(b.label))),
            ],
            onChanged: (v) => setState(() => _defaultBoxId = v ?? ''),
          ),
        ]),
      ),
    );
  }

  Widget _buildLimitsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.warning_amber, size: 22, color: Color(0xFF455A64)),
            const SizedBox(width: 8),
            Text('Verzendlimieten', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: _navy)),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
            child: const Text(
              'Bij het aanmaken van een concept worden gewicht en afmetingen gecontroleerd. '
              'Als deze limieten worden overschreden, verschijnt een waarschuwing met de optie om de order te splitsen.',
              style: TextStyle(fontSize: 11, color: Color(0xFF78909C)),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(
              controller: _maxGewichtCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max gewicht (gram)',
                hintText: '31500',
                suffixText: 'g',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: TextField(
              controller: _maxOmtrekCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Max omtrek (cm)',
                hintText: '176',
                suffixText: 'cm',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            )),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Omtrek = 2 \u00D7 (breedte + hoogte) + lengte. PostNL standaard: 31.500g / 176 cm.',
            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ]),
      ),
    );
  }

  Widget _buildSenderSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.business, size: 22, color: Color(0xFF455A64)),
            const SizedBox(width: 8),
            Text('Afzenderadres', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: _navy)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _senderNameCtrl,
            decoration: const InputDecoration(labelText: 'Naam', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(flex: 3, child: TextField(
              controller: _senderStreetCtrl,
              decoration: const InputDecoration(labelText: 'Straat', border: OutlineInputBorder(), isDense: true),
            )),
            const SizedBox(width: 10),
            Expanded(child: TextField(
              controller: _senderNumberCtrl,
              decoration: const InputDecoration(labelText: 'Nr.', border: OutlineInputBorder(), isDense: true),
            )),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(
              controller: _senderPostalCtrl,
              decoration: const InputDecoration(labelText: 'Postcode', border: OutlineInputBorder(), isDense: true),
            )),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: TextField(
              controller: _senderCityCtrl,
              decoration: const InputDecoration(labelText: 'Plaats', border: OutlineInputBorder(), isDense: true),
            )),
            const SizedBox(width: 10),
            SizedBox(width: 70, child: TextField(
              controller: _senderCcCtrl,
              decoration: const InputDecoration(labelText: 'Land', border: OutlineInputBorder(), isDense: true),
            )),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(
              controller: _senderEmailCtrl,
              decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder(), isDense: true),
            )),
            const SizedBox(width: 10),
            Expanded(child: TextField(
              controller: _senderPhoneCtrl,
              decoration: const InputDecoration(labelText: 'Telefoon', border: OutlineInputBorder(), isDense: true),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _buildActions() {
    return Column(children: [
      if (_testResult != null) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _testResult! ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(_testResult! ? Icons.check_circle : Icons.error,
              size: 18, color: _testResult! ? const Color(0xFF43A047) : const Color(0xFFE53935)),
            const SizedBox(width: 8),
            Text(
              _testResult! ? 'Verbinding met MyParcel succesvol!' : 'Verbinding mislukt. Controleer je API key.',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: _testResult! ? const Color(0xFF43A047) : const Color(0xFFE53935)),
            ),
          ]),
        ),
      ],
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: _testing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_tethering, size: 18),
            label: Text(_testing ? 'Testen...' : 'Verbinding testen'),
            onPressed: _testing ? null : _testConnection,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, size: 18),
            label: Text(_saving ? 'Opslaan...' : 'Opslaan'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
            onPressed: _saving ? null : _save,
          ),
        ),
      ]),
    ]);
  }
}
