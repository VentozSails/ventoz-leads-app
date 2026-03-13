import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_service.dart';
import '../services/vat_service.dart';
import '../widgets/site_footer.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC8A85C);
  static const _slate = Color(0xFF64748B);

  final _formKey = GlobalKey<FormState>();
  bool _isReseller = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _success;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _voornaamCtrl = TextEditingController();
  final _achternaamCtrl = TextEditingController();
  final _telefoonCtrl = TextEditingController();
  final _bedrijfsnaamCtrl = TextEditingController();
  final _btwNummerCtrl = TextEditingController();
  String _landCode = 'NL';
  bool _btwValid = false;
  bool _btwChecking = false;

  static const _countries = [
    ('NL', 'Nederland'), ('BE', 'België'), ('DE', 'Duitsland'),
    ('FR', 'Frankrijk'), ('GB', 'Verenigd Koninkrijk'), ('AT', 'Oostenrijk'),
    ('DK', 'Denemarken'), ('SE', 'Zweden'), ('IT', 'Italië'),
    ('ES', 'Spanje'), ('PL', 'Polen'),
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _voornaamCtrl.dispose();
    _achternaamCtrl.dispose();
    _telefoonCtrl.dispose();
    _bedrijfsnaamCtrl.dispose();
    _btwNummerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    return SingleChildScrollView(
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 24, vertical: 32),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF0F1B33), Color(0xFF1B2A4A)]),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Account aanmaken', style: GoogleFonts.dmSerifDisplay(fontSize: 28, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  'Maak een account aan om bestellingen te plaatsen en je orderhistorie bij te houden.',
                  style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFFB0C4DE)),
                ),
              ]),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 16, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildAccountTypeToggle(),
                  const SizedBox(height: 24),
                  _buildSection('Accountgegevens', [
                    _field(_emailCtrl, 'E-mailadres', required: true, keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Vereist';
                        if (!VatService.isValidEmail(v.trim())) return 'Ongeldig e-mailadres';
                        return null;
                      }),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      style: GoogleFonts.dmSans(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Wachtwoord',
                        labelStyle: GoogleFonts.dmSans(fontSize: 14),
                        helperText: 'Min. 8 tekens, hoofdletter, cijfer, speciaal teken',
                        helperStyle: GoogleFonts.dmSans(fontSize: 11),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: true,
                      style: GoogleFonts.dmSans(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Bevestig wachtwoord',
                        labelStyle: GoogleFonts.dmSans(fontSize: 14),
                      ),
                      validator: (v) => v != _passwordCtrl.text ? 'Wachtwoorden komen niet overeen' : null,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Persoonlijke gegevens', [
                    Row(children: [
                      Expanded(child: _field(_voornaamCtrl, 'Voornaam', required: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _field(_achternaamCtrl, 'Achternaam', required: true)),
                    ]),
                    const SizedBox(height: 12),
                    _field(_telefoonCtrl, 'Telefoonnummer', keyboardType: TextInputType.phone),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _landCode,
                      decoration: InputDecoration(
                        labelText: 'Land',
                        labelStyle: GoogleFonts.dmSans(fontSize: 14),
                      ),
                      items: _countries.map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2, style: GoogleFonts.dmSans(fontSize: 14)))).toList(),
                      onChanged: (v) => setState(() => _landCode = v ?? 'NL'),
                    ),
                  ]),
                  if (_isReseller) ...[
                    const SizedBox(height: 24),
                    _buildSection('Bedrijfsgegevens (wederverkoper)', [
                      _field(_bedrijfsnaamCtrl, 'Bedrijfsnaam', required: true),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _btwNummerCtrl,
                            style: GoogleFonts.dmSans(fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'BTW-nummer',
                              labelStyle: GoogleFonts.dmSans(fontSize: 14),
                              hintText: 'NL000000000B01',
                              helperText: _btwValid ? 'BTW-nummer gevalideerd' : null,
                              helperStyle: GoogleFonts.dmSans(fontSize: 11, color: Colors.green),
                              suffixIcon: _btwChecking
                                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                                  : _btwValid
                                      ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                                      : null,
                            ),
                            validator: (v) => _isReseller && (v == null || v.trim().isEmpty) ? 'Vereist voor wederverkopers' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _btwChecking ? null : _validateBtw,
                            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
                            child: Text('Valideer', style: GoogleFonts.dmSans(fontSize: 13)),
                          ),
                        ),
                      ]),
                    ]),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: GoogleFonts.dmSans(fontSize: 13, color: Colors.red))),
                      ]),
                    ),
                  ],
                  if (_success != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_success!, style: GoogleFonts.dmSans(fontSize: 13, color: Colors.green.shade800))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _navy,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('Account aanmaken', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/inloggen'),
                      child: Text('Heb je al een account? Log in', style: GoogleFonts.dmSans(color: _navy, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
        const SiteFooter(),
      ]),
    );
  }

  Widget _buildAccountTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Expanded(child: _typeBtn('Particulier / Klant', !_isReseller, () => setState(() => _isReseller = false))),
        const SizedBox(width: 4),
        Expanded(child: _typeBtn('Wederverkoper', _isReseller, () => setState(() => _isReseller = true))),
      ]),
    );
  }

  Widget _typeBtn(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? _navy : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Text(label, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : _slate))),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: _navy)),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    ]);
  }

  Widget _field(TextEditingController ctrl, String label, {
    bool required = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.dmSans(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.dmSans(fontSize: 14),
      ),
      validator: validator ?? (required ? (v) => (v == null || v.trim().isEmpty) ? 'Vereist' : null : null),
    );
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Vereist';
    if (v.length < 8) return 'Minimaal 8 tekens';
    if (!v.contains(RegExp(r'[A-Z]'))) return 'Voeg een hoofdletter toe';
    if (!v.contains(RegExp(r'[a-z]'))) return 'Voeg een kleine letter toe';
    if (!v.contains(RegExp(r'[0-9]'))) return 'Voeg een cijfer toe';
    if (!v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/~`]'))) return 'Voeg een speciaal teken toe';
    return null;
  }

  Future<void> _validateBtw() async {
    final btw = _btwNummerCtrl.text.trim();
    if (btw.isEmpty) return;
    setState(() { _btwChecking = true; _btwValid = false; _error = null; });
    try {
      final result = await VatService().validateVat(btw);
      if (mounted) {
        setState(() {
          _btwChecking = false;
          _btwValid = result.valid;
          if (!result.valid) _error = result.error ?? 'BTW-nummer kon niet gevalideerd worden';
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error validating VAT number: $e');
      if (mounted) setState(() { _btwChecking = false; _error = 'Fout bij validatie. Probeer het opnieuw.'; });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isReseller && !_btwValid) {
      setState(() => _error = 'Valideer eerst het BTW-nummer');
      return;
    }

    final isBtwVerlegd = _isReseller && _btwValid && _landCode != 'NL';

    setState(() { _loading = true; _error = null; });

    final email = _emailCtrl.text.trim();
    try {
      final client = Supabase.instance.client;
      final supabaseUrl = client.rest.url.replaceAll('/rest/v1', '');
      final res = await client.auth.signUp(
        email: email,
        password: _passwordCtrl.text,
        emailRedirectTo: supabaseUrl,
      );

      if (res.user == null) {
        setState(() { _loading = false; _error = 'Account aanmaken mislukt. Probeer het opnieuw.'; });
        return;
      }

      try {
        final newUser = AppUser(
          email: email,
          authUserId: res.user!.id,
          userType: _isReseller ? UserType.wederverkoper : UserType.klant,
          status: InviteStatus.geregistreerd,
          permissions: _isReseller ? UserPermissions.wederverkoperPreset : UserPermissions.klantPreset,
          isParticulier: !_isReseller,
          voornaam: _voornaamCtrl.text.trim().isEmpty ? null : _voornaamCtrl.text.trim(),
          achternaam: _achternaamCtrl.text.trim().isEmpty ? null : _achternaamCtrl.text.trim(),
          telefoon: _telefoonCtrl.text.trim().isEmpty ? null : _telefoonCtrl.text.trim(),
          bedrijfsnaam: _isReseller ? _bedrijfsnaamCtrl.text.trim() : null,
          btwNummer: _isReseller ? _btwNummerCtrl.text.trim() : null,
          btwGevalideerd: _btwValid,
          btwValidatieDatum: _btwValid ? DateTime.now() : null,
          btwVerlegd: isBtwVerlegd,
          landCode: _landCode,
        );
        await client.from('ventoz_users').upsert(newUser.toDbRow(), onConflict: 'email');
      } catch (_) {}

      await client.auth.signOut();

      if (mounted) {
        setState(() {
          _loading = false;
          _success = 'Account aangemaakt! Controleer je e-mail om je account te bevestigen.';
        });
      }
    } on AuthException catch (e) {
      final lower = e.message.toLowerCase();
      if (lower.contains('already registered') || lower.contains('already exists')) {
        setState(() { _loading = false; _error = 'Er bestaat al een account met dit e-mailadres.'; });
      } else {
        setState(() { _loading = false; _error = e.message; });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error during registration: $e');
      if (mounted) setState(() { _loading = false; _error = 'Er is een onverwachte fout opgetreden. Probeer het opnieuw.'; });
    }
  }
}
