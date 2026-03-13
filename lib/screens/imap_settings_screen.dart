import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/imap_order_service.dart';
import '../services/user_service.dart';

class ImapSettingsScreen extends StatefulWidget {
  const ImapSettingsScreen({super.key});

  @override
  State<ImapSettingsScreen> createState() => _ImapSettingsScreenState();
}

class _ImapSettingsScreenState extends State<ImapSettingsScreen> {
  static const _navy = Color(0xFF0D1B2A);

  final _service = ImapOrderService();
  final _userService = UserService();
  final _formKey = GlobalKey<FormState>();

  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '993');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _enableJew = true;
  bool _enableEbay = true;
  bool _enableBol = true;
  bool _enableAmazon = true;

  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _fetching = false;
  bool _obscurePassword = true;
  String? _testResult;
  ImportResult? _fetchResult;

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
    super.dispose();
  }

  Future<void> _load() async {
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.smtpInstellingen) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
      );
      return;
    }
    final settings = await _service.loadSettings();
    if (settings != null && mounted) {
      _hostCtrl.text = settings.host;
      _portCtrl.text = settings.port.toString();
      _userCtrl.text = settings.username;
      _passCtrl.text = settings.password;
      _enableJew = settings.enableJew;
      _enableEbay = settings.enableEbay;
      _enableBol = settings.enableBol;
      _enableAmazon = settings.enableAmazon;
    }
    if (mounted) setState(() => _loading = false);
  }

  ImapSettings _buildSettings() => ImapSettings(
    host: _hostCtrl.text.trim(),
    port: int.tryParse(_portCtrl.text.trim()) ?? 993,
    username: _userCtrl.text.trim(),
    password: _passCtrl.text,
    enableJew: _enableJew,
    enableEbay: _enableEbay,
    enableBol: _enableBol,
    enableAmazon: _enableAmazon,
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.saveSettings(_buildSettings());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('IMAP-instellingen opgeslagen'), backgroundColor: Color(0xFF2E7D32)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout: $e'), backgroundColor: const Color(0xFFE53935)),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _testing = true; _testResult = null; });
    final result = await _service.testConnection(_buildSettings());
    if (mounted) setState(() { _testing = false; _testResult = result; });
  }

  Future<void> _fetchOrders() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _fetching = true; _fetchResult = null; });
    try {
      await _service.saveSettings(_buildSettings());
      final result = await _service.fetchNewOrders(_buildSettings());
      if (mounted) setState(() { _fetching = false; _fetchResult = result; });
    } catch (e) {
      if (mounted) {
        setState(() => _fetching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout: $e'), backgroundColor: const Color(0xFFE53935)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text('IMAP Order Import', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoBanner(),
                        const SizedBox(height: 24),
                        _buildSection('IMAP-verbinding', Icons.email_rounded, [
                          _field('IMAP Server', _hostCtrl, hint: 'bijv. mail.ventoz.nl'),
                          const SizedBox(height: 12),
                          _field('Poort', _portCtrl, hint: '993 (SSL/TLS)', keyboardType: TextInputType.number),
                          const SizedBox(height: 12),
                          _field('Gebruikersnaam', _userCtrl, hint: 'info@ventoz.nl'),
                          const SizedBox(height: 12),
                          _passwordField(),
                        ]),
                        const SizedBox(height: 24),
                        _buildSection('Verkoopkanalen', Icons.storefront_rounded, [
                          _channelToggle('Webshop (jeeigenweb.nl)', '🌐', _enableJew, (v) => setState(() => _enableJew = v)),
                          _channelToggle('eBay', '🏷️', _enableEbay, (v) => setState(() => _enableEbay = v)),
                          _channelToggle('Bol.com', '📦', _enableBol, (v) => setState(() => _enableBol = v)),
                          _channelToggle('Amazon', '📦', _enableAmazon, (v) => setState(() => _enableAmazon = v)),
                        ]),
                        const SizedBox(height: 24),
                        _buildActions(),
                        if (_testResult != null) ...[
                          const SizedBox(height: 16),
                          _buildResultBanner(_testResult!, _testResult!.contains('geslaagd')),
                        ],
                        if (_fetchResult != null) ...[
                          const SizedBox(height: 16),
                          _buildFetchResultCard(_fetchResult!),
                        ],
                        const SizedBox(height: 32),
                        _buildSecurityNote(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFD4F0)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, color: Color(0xFF1565C0), size: 22),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Automatisch orders importeren',
            style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: _navy),
          ),
          const SizedBox(height: 4),
          Text(
            'Verbind met je e-mail postvak om ordernotificaties van je webshop, eBay, Bol.com en Amazon automatisch te importeren.',
            style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF475569), height: 1.5),
          ),
        ])),
      ]),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 20, color: const Color(0xFF455A64)),
          const SizedBox(width: 10),
          Text(title, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
        ]),
        const SizedBox(height: 18),
        ...children,
      ]),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint, TextInputType? keyboardType}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF94A3B8)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      style: GoogleFonts.dmSans(fontSize: 14),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Verplicht' : null,
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passCtrl,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Wachtwoord',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      style: GoogleFonts.dmSans(fontSize: 14),
      validator: (v) => (v == null || v.isEmpty) ? 'Verplicht' : null,
    );
  }

  Widget _channelToggle(String label, String emoji, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile(
        title: Text('$emoji  $label', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500)),
        value: value,
        onChanged: onChanged,
        dense: true,
        activeColor: const Color(0xFF1565C0),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildActions() {
    return Row(children: [
      ElevatedButton.icon(
        onPressed: _saving ? null : _save,
        icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save, size: 18),
        label: Text(_saving ? 'Opslaan...' : 'Opslaan'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      const SizedBox(width: 12),
      OutlinedButton.icon(
        onPressed: _testing ? null : _testConnection,
        icon: _testing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering, size: 18),
        label: Text(_testing ? 'Testen...' : 'Test verbinding'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: const BorderSide(color: Color(0xFF1565C0)),
          foregroundColor: const Color(0xFF1565C0),
        ),
      ),
      const SizedBox(width: 12),
      ElevatedButton.icon(
        onPressed: _fetching ? null : _fetchOrders,
        icon: _fetching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.download_rounded, size: 18),
        label: Text(_fetching ? 'Ophalen...' : 'Nu ophalen'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00897B),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]);
  }

  Widget _buildResultBanner(String text, bool success) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: success ? const Color(0xFFF0FFF4) : const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: success ? const Color(0xFF81C784) : const Color(0xFFEF9A9A)),
      ),
      child: Row(children: [
        Icon(success ? Icons.check_circle : Icons.error, color: success ? const Color(0xFF2E7D32) : const Color(0xFFC62828), size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: GoogleFonts.dmSans(fontSize: 13, color: _navy))),
      ]),
    );
  }

  Widget _buildFetchResultCard(ImportResult result) {
    final success = !result.hasError && (result.imported > 0 || result.paymentsConfirmed > 0 || result.markedShipped > 0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: result.hasError ? const Color(0xFFFFF5F5)
            : success ? const Color(0xFFF0FFF4)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: result.hasError ? const Color(0xFFEF9A9A)
              : success ? const Color(0xFF81C784)
              : const Color(0xFFE8ECF1),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            result.hasError ? Icons.error : success ? Icons.check_circle : Icons.info_outline,
            color: result.hasError ? const Color(0xFFC62828)
                : success ? const Color(0xFF2E7D32)
                : const Color(0xFF64748B),
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            result.hasError ? 'Import mislukt' : success ? 'Import voltooid' : 'Geen nieuwe orders',
            style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: _navy),
          ),
        ]),
        const SizedBox(height: 8),
        Text(result.summary, style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF475569))),
        if (!result.hasError && result.perChannel.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 6, children: result.perChannel.entries.map((e) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8ECF1)),
              ),
              child: Text(
                '${e.key.label}: ${e.value}',
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _navy),
              ),
            );
          }).toList()),
        ],
      ]),
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8ECF1)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.security, size: 18, color: Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(child: Text(
          'Je wachtwoord wordt versleuteld opgeslagen (AES-256). '
          'De verbinding gebruikt TLS/SSL (poort 993) of STARTTLS (poort 143). '
          'E-mailinhoud wordt alleen in het geheugen verwerkt en niet opgeslagen.',
          style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B), height: 1.5),
        )),
      ]),
    );
  }
}
