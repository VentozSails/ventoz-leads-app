import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/smtp_service.dart';
import '../services/vat_service.dart';
import '../services/user_service.dart';

class SmtpSettingsScreen extends StatefulWidget {
  const SmtpSettingsScreen({super.key});

  @override
  State<SmtpSettingsScreen> createState() => _SmtpSettingsScreenState();
}

class _SmtpSettingsScreenState extends State<SmtpSettingsScreen> {
  final SmtpService _service = SmtpService();
  final _userService = UserService();
  final _formKey = GlobalKey<FormState>();

  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '587');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _fromNameCtrl = TextEditingController(text: 'Ventoz B.V.');
  final _fromEmailCtrl = TextEditingController();
  SmtpEncryption _encryption = SmtpEncryption.starttls;
  bool _allowInvalidCert = false;

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _fromNameCtrl.dispose();
    _fromEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.smtpInstellingen) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
        );
      }
      return;
    }
    final settings = await _service.loadSettings();
    if (settings != null && mounted) {
      _hostCtrl.text = settings.host;
      _portCtrl.text = settings.port.toString();
      _userCtrl.text = settings.username;
      _passCtrl.text = settings.password;
      _fromNameCtrl.text = settings.fromName;
      _fromEmailCtrl.text = settings.fromEmail;
      _encryption = settings.encryption;
      _allowInvalidCert = settings.allowInvalidCertificate;
    }
    if (mounted) setState(() => _loading = false);
  }

  SmtpSettings _buildSettings() => SmtpSettings(
        host: _hostCtrl.text.trim(),
        port: int.tryParse(_portCtrl.text.trim()) ?? _encryption.defaultPort,
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
        fromName: _fromNameCtrl.text.trim(),
        fromEmail: _fromEmailCtrl.text.trim(),
        encryption: _encryption,
        allowInvalidCertificate: _allowInvalidCert,
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.saveSettings(_buildSettings());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMTP-instellingen opgeslagen')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opslaan mislukt: $e')),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _testing = true);
    try {
      final settings = _buildSettings();

      // First save settings so the Edge Function can read them
      await _service.saveSettings(settings);

      // Send test email via send-invite-email Edge Function (contact_form mode)
      // to avoid Socket constructor issues on Windows/Web
      final client = Supabase.instance.client;
      final response = await client.functions.invoke(
        'send-invite-email',
        body: {
          'mode': 'contact_form',
          'to_email': settings.fromEmail,
          'subject': 'Ventoz Sails – SMTP Test',
          'html_body': '<h2>SMTP Test</h2><p>Dit is een testbericht vanuit de Ventoz Sails app.</p><p>Als je dit ontvangt, werkt de SMTP-configuratie correct.</p>',
          'plain_body': 'Dit is een testbericht vanuit de Ventoz Sails app.\n\nAls je dit ontvangt, werkt de SMTP-configuratie correct.',
        },
      );

      if (response.status != 200) {
        String errorMsg = 'SMTP test mislukt';
        try {
          final data = response.data;
          if (data is Map && data['error'] != null) {
            errorMsg = data['error'] as String;
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Testmail verzonden naar ${settings.fromEmail}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test mislukt: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
    if (mounted) setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF37474F),
        foregroundColor: Colors.white,
        title: const Text('E-mail Instellingen'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Afzender'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fromNameCtrl,
                      decoration: const InputDecoration(labelText: 'Afzendernaam', hintText: 'Ventoz B.V.'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Verplicht' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fromEmailCtrl,
                      decoration: const InputDecoration(labelText: 'E-mailadres', hintText: 'app@ventoz.nl'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v == null || !VatService.isValidEmail(v) ? 'Ongeldig e-mailadres' : null,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('SMTP-server'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _hostCtrl,
                            decoration: const InputDecoration(labelText: 'Server (host)', hintText: 'smtp.gmail.com'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Verplicht' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _portCtrl,
                            decoration: const InputDecoration(labelText: 'Poort'),
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || int.tryParse(v) == null ? 'Ongeldig' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _userCtrl,
                      decoration: const InputDecoration(labelText: 'Gebruikersnaam', hintText: 'app@ventoz.nl'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Verplicht' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passCtrl,
                      decoration: InputDecoration(
                        labelText: 'Wachtwoord / App Password',
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (v) => v == null || v.isEmpty ? 'Verplicht' : null,
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Versleuteling', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        SegmentedButton<SmtpEncryption>(
                          segments: SmtpEncryption.values
                            .where((e) => e != SmtpEncryption.none)
                            .map((e) => ButtonSegment<SmtpEncryption>(
                            value: e,
                            label: Text(e.label),
                            icon: const Icon(Icons.lock),
                          )).toList(),
                          selected: {_encryption},
                          onSelectionChanged: (selected) {
                            setState(() {
                              _encryption = selected.first;
                              _portCtrl.text = _encryption.defaultPort.toString();
                            });
                          },
                          showSelectedIcon: false,
                          style: ButtonStyle(
                            textStyle: WidgetStatePropertyAll(const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          switch (_encryption) {
                            SmtpEncryption.starttls => 'Start onversleuteld, dan opwaarderen naar TLS (poort 587, meest gebruikt)',
                            SmtpEncryption.ssl => 'Direct versleutelde verbinding (poort 465)',
                            SmtpEncryption.none => 'Onbeveiligde verbinding (niet aanbevolen)',
                          },
                          style: TextStyle(fontSize: 12, color: Colors.blueGrey[400]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Row(
                        children: [
                          if (_allowInvalidCert) Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                          ),
                          const Expanded(child: Text('Ongeldig TLS-certificaat toestaan', style: TextStyle(fontSize: 14))),
                        ],
                      ),
                      subtitle: Text(
                        _allowInvalidCert
                            ? 'WAARSCHUWING: certificaatfouten worden genegeerd. Dit maakt de verbinding kwetsbaar voor man-in-the-middle aanvallen. Gebruik alleen als de mailserver geen geldig certificaat heeft.'
                            : 'Uit — alleen geldige certificaten worden geaccepteerd (aanbevolen)',
                        style: TextStyle(fontSize: 12, color: _allowInvalidCert ? Colors.orange[700] : Colors.blueGrey[400]),
                      ),
                      value: _allowInvalidCert,
                      onChanged: (v) => setState(() => _allowInvalidCert = v),
                      activeTrackColor: Colors.orange[200],
                      inactiveTrackColor: Colors.grey[200],
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: _testing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.send_outlined, size: 18),
                            label: const Text('Test versturen'),
                            onPressed: _testing ? null : _testConnection,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF59E0B),
                              side: const BorderSide(color: Color(0xFFF59E0B)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: _saving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save, size: 18),
                            label: const Text('Opslaan'),
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF455A64),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SMTP-configuratie', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E40AF))),
                SizedBox(height: 4),
                Text(
                  'Configureer hier je SMTP-server om e-mails direct vanuit de app te versturen (bijv. via app@ventoz.nl). '
                  'Bij Gmail gebruik je een App Password (niet je gewone wachtwoord).',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)));
  }
}
