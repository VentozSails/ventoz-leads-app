import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/company_settings_service.dart';
import '../services/user_service.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final _svc = CompanySettingsService();
  final _userService = UserService();
  bool _loading = true;
  bool _saving = false;

  final _naamCtrl = TextEditingController();
  final _taglineCtrl = TextEditingController();
  final _adresCtrl = TextEditingController();
  final _postcodeCtrl = TextEditingController();
  final _woonplaatsCtrl = TextEditingController();
  final _landCtrl = TextEditingController();
  final _telefoonCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _kvkCtrl = TextEditingController();
  final _btwCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _bicCtrl = TextEditingController();
  final _accentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_naamCtrl, _taglineCtrl, _adresCtrl, _postcodeCtrl, _woonplaatsCtrl,
        _landCtrl, _telefoonCtrl, _emailCtrl, _kvkCtrl, _btwCtrl, _ibanCtrl, _bicCtrl, _accentCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.bedrijfsgegevensBewerken) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
        );
      }
      return;
    }
    final s = await _svc.getSettings();
    if (!mounted) return;
    setState(() {
      _naamCtrl.text = s.naam;
      _taglineCtrl.text = s.tagline;
      _adresCtrl.text = s.adres;
      _postcodeCtrl.text = s.postcode;
      _woonplaatsCtrl.text = s.woonplaats;
      _landCtrl.text = s.land;
      _telefoonCtrl.text = s.telefoon;
      _emailCtrl.text = s.email;
      _kvkCtrl.text = s.kvk;
      _btwCtrl.text = s.btwNummer;
      _ibanCtrl.text = s.iban;
      _bicCtrl.text = s.bic;
      _accentCtrl.text = s.accentKleur;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _svc.saveSettings(CompanySettings(
        naam: _naamCtrl.text.trim(),
        tagline: _taglineCtrl.text.trim(),
        adres: _adresCtrl.text.trim(),
        postcode: _postcodeCtrl.text.trim(),
        woonplaats: _woonplaatsCtrl.text.trim(),
        land: _landCtrl.text.trim(),
        telefoon: _telefoonCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        kvk: _kvkCtrl.text.trim(),
        btwNummer: _btwCtrl.text.trim(),
        iban: _ibanCtrl.text.trim(),
        bic: _bicCtrl.text.trim(),
        accentKleur: _accentCtrl.text.trim(),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bedrijfsgegevens opgeslagen'), backgroundColor: Color(0xFF43A047),
        ));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving company settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Opslaan mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFE53935),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/ventoz_logo.png', width: 28, height: 28)),
          const SizedBox(width: 10),
          const Text('Bedrijfsgegevens'),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _section('Algemeen', [
                      _field(_naamCtrl, 'Bedrijfsnaam', Icons.business),
                      _field(_taglineCtrl, 'Tagline', Icons.short_text),
                      _field(_emailCtrl, 'E-mail', Icons.email),
                      _field(_telefoonCtrl, 'Telefoon', Icons.phone),
                    ]),
                    const SizedBox(height: 20),
                    _section('Adres', [
                      _field(_adresCtrl, 'Straat + nummer', Icons.location_on),
                      Row(children: [
                        Expanded(flex: 2, child: _field(_postcodeCtrl, 'Postcode', Icons.markunread_mailbox)),
                        const SizedBox(width: 12),
                        Expanded(flex: 3, child: _field(_woonplaatsCtrl, 'Woonplaats', Icons.location_city)),
                      ]),
                      _field(_landCtrl, 'Land', Icons.public),
                    ]),
                    const SizedBox(height: 20),
                    _section('Registratie & Bankgegevens', [
                      _field(_kvkCtrl, 'KvK-nummer', Icons.badge),
                      _field(_btwCtrl, 'BTW-nummer', Icons.receipt),
                      _field(_ibanCtrl, 'IBAN', Icons.account_balance),
                      _field(_bicCtrl, 'BIC', Icons.swap_horiz),
                    ]),
                    const SizedBox(height: 20),
                    _section('Branding', [
                      _field(_accentCtrl, 'Accentkleur (hex)', Icons.palette),
                      const SizedBox(height: 8),
                      _buildColorPreview(),
                    ]),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save, size: 18),
                        label: Text(_saving ? 'Opslaan...' : 'Opslaan'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF455A64))),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20), isDense: true),
      ),
    );
  }

  Widget _buildColorPreview() {
    final hex = _accentCtrl.text.trim().replaceAll('#', '');
    Color color = const Color(0xFF455A64);
    if (hex.length == 6) {
      try { color = Color(int.parse('FF$hex', radix: 16)); } catch (_) {}
    }
    return Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8))),
      const SizedBox(width: 12),
      Text('Voorbeeld', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    ]);
  }
}
