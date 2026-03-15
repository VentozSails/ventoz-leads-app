import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_service.dart';
import '../services/vat_service.dart';
import '../services/login_security_service.dart';
import '../services/audit_service.dart';
import 'mfa_verify_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();
  final LoginSecurityService _securityService = LoginSecurityService();
  final AuditService _auditService = AuditService();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;
  _ScreenMode _mode = _ScreenMode.login;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _loading = true; _error = null; });

    final email = _emailController.text.trim();

    try {
      final locked = await _securityService.isAccountLocked(email);
      if (locked) {
        setState(() => _error = 'Dit account is geblokkeerd na te veel mislukte inlogpogingen. Neem contact op met Ventoz om het te laten vrijgeven.');
        return;
      }

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: _passwordController.text,
      );

      if (!mounted) return;

      final assuranceLevel = _supabase.auth.mfa.getAuthenticatorAssuranceLevel();

      if (assuranceLevel.currentLevel == AuthenticatorAssuranceLevels.aal1 &&
          assuranceLevel.nextLevel == AuthenticatorAssuranceLevels.aal2) {
        final verified = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const MfaVerifyScreen()),
        );

        if (verified == true && mounted) {
          if (!await _checkAuthorization()) return;
          await _securityService.clearAttempts(email);
          await _auditService.log(action: 'login_success', actorEmail: email);
          widget.onLoginSuccess();
        }
      } else if (response.session != null) {
        if (!await _checkAuthorization()) return;
        await _securityService.clearAttempts(email);
        await _auditService.log(action: 'login_success', actorEmail: email);
        widget.onLoginSuccess();
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
        await _securityService.recordFailedAttempt(email);
        await _auditService.log(action: 'login_failed', actorEmail: email, details: 'Verkeerd wachtwoord');
        final locked = await _securityService.isAccountLocked(email);
        if (locked) {
          setState(() => _error = 'Dit account is geblokkeerd wegens te veel mislukte pogingen. Neem contact op met Ventoz.');
          return;
        }
        setState(() => _error = 'E-mail of wachtwoord is onjuist.');
      } else {
        setState(() => _error = _translateAuthError(e.message));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Login unexpected error: $e');
      final errStr = e.toString();
      if (errStr.contains('SocketException') || errStr.contains('ClientException') || errStr.contains('TimeoutException')) {
        setState(() => _error = 'Geen verbinding met de server. Controleer je internetverbinding.');
      } else {
        setState(() => _error = 'Er is een onverwachte fout opgetreden. Probeer het opnieuw.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _checkAuthorization() async {
    final authorized = await _userService.isUserAuthorized();
    if (!authorized) {
      await _supabase.auth.signOut();
      if (mounted) {
        setState(() {
          _error = 'Geen toegang. Neem contact op met de beheerder om een uitnodiging aan te vragen.';
        });
      }
      return false;
    }
    await _userService.promoteIfNeeded();
    return true;
  }

  String _translateAuthError(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('invalid login credentials') || lower.contains('invalid_credentials')
        || lower.contains('user not found')) {
      return 'E-mail of wachtwoord is onjuist';
    }
    if (lower.contains('email not confirmed')) {
      return 'Je e-mailadres is nog niet bevestigd. Check je inbox (ook spam) voor de bevestigingsmail en klik op de link.';
    }
    if (lower.contains('too many requests') || lower.contains('rate limit')) {
      return 'Te veel pogingen. Probeer het later opnieuw.';
    }
    return 'E-mail of wachtwoord is onjuist';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/login_bg.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0.0, -0.1),
          ),
          Container(color: const Color(0xFF37474F).withValues(alpha: 0.55)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 12,
                  shadowColor: Colors.black45,
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: switch (_mode) {
                      _ScreenMode.login => _buildLoginForm(),
                      _ScreenMode.invitedRegister => _InvitedRegisterForm(
                        userService: _userService,
                        onBack: () => setState(() { _mode = _ScreenMode.login; _error = null; }),
                        onRegistered: _onRegistered,
                      ),
                      _ScreenMode.selfRegister => _SelfRegisterForm(
                        userService: _userService,
                        onBack: () => setState(() { _mode = _ScreenMode.login; _error = null; }),
                        onRegistered: _onRegistered,
                      ),
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onRegistered() {
    setState(() { _mode = _ScreenMode.login; _error = null; });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account aangemaakt! Je kunt nu inloggen.'),
        backgroundColor: Color(0xFF43A047),
        duration: Duration(seconds: 4),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildEmailField(),
          const SizedBox(height: 16),
          _buildPasswordField(),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _buildErrorBanner(),
          ],
          const SizedBox(height: 24),
          _buildLoginButton(),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() { _mode = _ScreenMode.invitedRegister; _error = null; }),
            child: Text('Uitgenodigd? Account aanmaken', style: TextStyle(color: Colors.blueGrey[600], fontSize: 13)),
          ),
          TextButton(
            onPressed: () => setState(() { _mode = _ScreenMode.selfRegister; _error = null; }),
            child: Text('Zelf registreren (catalogus)', style: TextStyle(color: Colors.blueGrey[400], fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset('assets/ventoz_logo.png', width: 64, height: 64),
      ),
      const SizedBox(height: 12),
      const Text('Ventoz Sails', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF37474F), letterSpacing: -0.5)),
      const SizedBox(height: 4),
      Text('Log in om door te gaan', style: TextStyle(fontSize: 13, color: Colors.blueGrey[400])),
    ]);
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      decoration: const InputDecoration(labelText: 'E-mailadres', prefixIcon: Icon(Icons.email_outlined)),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Voer een e-mailadres in';
        if (!VatService.isValidEmail(val.trim())) return 'Voer een geldig e-mailadres in';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      onFieldSubmitted: (_) => _login(),
      decoration: InputDecoration(
        labelText: 'Wachtwoord',
        prefixIcon: const Icon(Icons.lock_outlined),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (val) {
        if (val == null || val.isEmpty) return 'Voer een wachtwoord in';
        return null;
      },
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50], borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, color: Colors.red[700], size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13))),
      ]),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity, height: 48,
      child: ElevatedButton(
        onPressed: _loading ? null : _login,
        child: _loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Inloggen', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

enum _ScreenMode { login, invitedRegister, selfRegister }

// ─── Invited registration (existing flow) ───

class _InvitedRegisterForm extends StatefulWidget {
  final UserService userService;
  final VoidCallback onBack;
  final VoidCallback onRegistered;

  const _InvitedRegisterForm({required this.userService, required this.onBack, required this.onRegistered});

  @override
  State<_InvitedRegisterForm> createState() => _InvitedRegisterFormState();
}

class _InvitedRegisterFormState extends State<_InvitedRegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Voer een wachtwoord in';
    if (value.length < 8) return 'Minimaal 8 tekens';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Minstens 1 hoofdletter';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Minstens 1 kleine letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Minstens 1 cijfer';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/~`]').hasMatch(value)) return 'Minstens 1 speciaal teken';
    return null;
  }

  double _passwordStrength(String password) {
    if (password.isEmpty) return 0;
    double score = 0;
    if (password.length >= 8) score += 0.2;
    if (password.length >= 12) score += 0.1;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 0.2;
    if (RegExp(r'[a-z]').hasMatch(password)) score += 0.1;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 0.2;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/~`]').hasMatch(password)) score += 0.2;
    return score.clamp(0, 1);
  }

  Color _strengthColor(double s) {
    if (s < 0.3) return const Color(0xFFEF4444);
    if (s < 0.6) return const Color(0xFFF59E0B);
    if (s < 0.8) return const Color(0xFF3B82F6);
    return const Color(0xFF10B981);
  }

  String _strengthLabel(double s) {
    if (s < 0.3) return 'Zwak';
    if (s < 0.6) return 'Matig';
    if (s < 0.8) return 'Goed';
    return 'Sterk';
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    try {
      final invited = await widget.userService.isEmailInvited(email);
      if (!invited) {
        setState(() => _error = 'Dit e-mailadres is niet uitgenodigd. Vraag de beheerder om een uitnodiging.');
        return;
      }

      final client = Supabase.instance.client;

      // Create user via admin API (pre-confirmed, no confirmation email)
      final res = await client.functions.invoke('confirm-user', body: {
        'action': 'create',
        'email': email,
        'password': password,
      });

      final body = res.data;
      if (body is Map && body['error'] != null) {
        final err = body['error'].toString().toLowerCase();
        if (err.contains('already been registered') || err.contains('already exists') || err.contains('duplicate')) {
          // Account exists — confirm it and tell user to log in
          try {
            await client.functions.invoke('confirm-user', body: {'email': email});
          } catch (_) {}
          try { await widget.userService.markAsRegistered(email); } catch (_) {}
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Je account bestaat al en is geactiveerd. Je kunt nu inloggen.'),
              backgroundColor: Color(0xFF43A047),
            ));
            widget.onRegistered();
          }
          return;
        }
        setState(() => _error = _translateCreateError(body['error'].toString()));
        return;
      }

      try {
        await widget.userService.markAsRegistered(email);
      } catch (e) {
        if (kDebugMode) debugPrint('markAsRegistered failed (non-fatal): $e');
      }

      if (mounted) {
        widget.onRegistered();
      }
    } on AuthException catch (e) {
      setState(() => _error = _translateRegisterError(e.message));
    } catch (e) {
      if (kDebugMode) debugPrint('Register error: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('duplicate') || errStr.contains('already')) {
        setState(() => _error = 'Er bestaat al een account met dit e-mailadres. Probeer in te loggen.');
      } else if (errStr.contains('rate limit')) {
        setState(() => _error = 'Te veel pogingen. Wacht een paar minuten en probeer het opnieuw.');
      } else {
        setState(() => _error = 'Fout bij registratie: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _translateRegisterError(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('already registered') || lower.contains('already exists')) {
      return 'Er bestaat al een account met dit e-mailadres. Probeer in te loggen.';
    }
    if (lower.contains('password')) return 'Wachtwoord voldoet niet aan de eisen.';
    if (lower.contains('rate limit')) return 'Te veel pogingen. Wacht een paar minuten en probeer het opnieuw.';
    return msg;
  }

  String _translateCreateError(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('rate limit')) return 'Te veel pogingen. Wacht een paar minuten en probeer het opnieuw.';
    if (lower.contains('password')) return 'Wachtwoord voldoet niet aan de eisen.';
    if (lower.contains('already')) return 'Er bestaat al een account met dit e-mailadres. Probeer in te loggen.';
    return 'Registratie mislukt: $msg';
  }

  @override
  Widget build(BuildContext context) {
    final strength = _passwordStrength(_passCtrl.text);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/ventoz_logo.png', width: 60, height: 60)),
          const SizedBox(height: 12),
          const Text('Account aanmaken', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF37474F))),
          const SizedBox(height: 4),
          Text('Alleen voor uitgenodigde gebruikers', style: TextStyle(fontSize: 13, color: Colors.blueGrey[400])),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mailadres (zoals opgegeven door beheerder)', prefixIcon: Icon(Icons.email_outlined)),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Vul je e-mailadres in';
              if (!VatService.isValidEmail(v.trim())) return 'Ongeldig e-mailadres';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscure1,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Wachtwoord', prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure1 = !_obscure1),
              ),
            ),
            validator: _validatePassword,
          ),
          if (_passCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: strength, backgroundColor: Colors.grey[200], color: _strengthColor(strength), minHeight: 6),
              )),
              const SizedBox(width: 8),
              Text(_strengthLabel(strength), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _strengthColor(strength))),
            ]),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _passConfirmCtrl,
            obscureText: _obscure2,
            decoration: InputDecoration(
              labelText: 'Wachtwoord herhalen', prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure2 = !_obscure2),
              ),
            ),
            validator: (v) { if (v != _passCtrl.text) return 'Wachtwoorden komen niet overeen'; return null; },
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red[200]!)),
              child: Row(children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13))),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _register,
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Account aanmaken', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onBack,
            child: Text('Terug naar inloggen', style: TextStyle(color: Colors.blueGrey[600], fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─── Self-registration for generic users ───

class _SelfRegisterForm extends StatefulWidget {
  final UserService userService;
  final VoidCallback onBack;
  final VoidCallback onRegistered;

  const _SelfRegisterForm({required this.userService, required this.onBack, required this.onRegistered});

  @override
  State<_SelfRegisterForm> createState() => _SelfRegisterFormState();
}

class _SelfRegisterFormState extends State<_SelfRegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  final _voornaamCtrl = TextEditingController();
  final _achternaamCtrl = TextEditingController();
  final _telefoonCtrl = TextEditingController();
  final _btwCtrl = TextEditingController();
  final _bedrijfCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;

  bool _isParticulier = true;
  String _landCode = 'NL';
  bool _btwGevalideerd = false;
  bool _validatingVat = false;
  String? _vatError;
  String? _vatName;

  bool get _isEuCountry => VatService.isEuCountry(_landCode);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    _voornaamCtrl.dispose();
    _achternaamCtrl.dispose();
    _telefoonCtrl.dispose();
    _btwCtrl.dispose();
    _bedrijfCtrl.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Voer een wachtwoord in';
    if (value.length < 8) return 'Minimaal 8 tekens';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Minstens 1 hoofdletter';
    if (!RegExp(r'[a-z]').hasMatch(value)) return 'Minstens 1 kleine letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Minstens 1 cijfer';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/~`]').hasMatch(value)) return 'Minstens 1 speciaal teken';
    return null;
  }

  Future<void> _validateVat() async {
    final raw = _btwCtrl.text.trim();
    if (raw.isEmpty) return;
    setState(() { _validatingVat = true; _vatError = null; _vatName = null; });

    final result = await VatService().validateVat(raw);
    if (!mounted) return;
    setState(() {
      _validatingVat = false;
      _btwGevalideerd = result.valid;
      _vatName = result.name;
      _vatError = result.valid ? null : result.error;
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isParticulier && _isEuCountry && _btwCtrl.text.trim().isNotEmpty && !_btwGevalideerd) {
      setState(() => _error = 'Valideer eerst je BTW-nummer via de VIES-check.');
      return;
    }

    final isBtwVerlegd = !_isParticulier && _btwGevalideerd && _landCode != 'NL' && _isEuCountry;

    setState(() { _loading = true; _error = null; });

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    try {
      final client = Supabase.instance.client;
      final response = await client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'https://ventozsails.github.io/ventoz-leads-app/inloggen',
      );

      if (response.user == null) {
        setState(() => _error = 'Account aanmaken mislukt. Probeer het opnieuw.');
        return;
      }

      try {
        final newUser = AppUser(
          email: email,
          authUserId: response.user!.id,
          userType: UserType.klant,
          status: InviteStatus.geregistreerd,
          permissions: UserPermissions.klantPreset,
          isParticulier: _isParticulier,
          voornaam: _voornaamCtrl.text.trim().isEmpty ? null : _voornaamCtrl.text.trim(),
          achternaam: _achternaamCtrl.text.trim().isEmpty ? null : _achternaamCtrl.text.trim(),
          telefoon: _telefoonCtrl.text.trim().isEmpty ? null : _telefoonCtrl.text.trim(),
          bedrijfsnaam: _isParticulier ? null : _bedrijfCtrl.text.trim(),
          btwNummer: _isParticulier ? null : _btwCtrl.text.trim(),
          btwGevalideerd: _btwGevalideerd,
          btwValidatieDatum: _btwGevalideerd ? DateTime.now() : null,
          btwVerlegd: isBtwVerlegd,
          landCode: _landCode,
        );

        await client.from('ventoz_users').upsert(newUser.toDbRow(), onConflict: 'email');
      } catch (_) {}

      final needsConfirmation = response.user!.emailConfirmedAt == null;
      await client.auth.signOut();

      if (mounted) {
        if (needsConfirmation) {
          _showConfirmationDialog();
        } else {
          widget.onRegistered();
        }
      }
    } on AuthException catch (e) {
      final lower = e.message.toLowerCase();
      if (lower.contains('already registered') || lower.contains('already exists')) {
        setState(() => _error = 'Er bestaat al een account met dit e-mailadres.');
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      setState(() => _error = 'Er is een onverwachte fout opgetreden. Probeer het opnieuw.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.mark_email_read, color: Color(0xFF43A047), size: 48),
        title: const Text('Account aangemaakt'),
        content: const Text(
          'Je account is succesvol aangemaakt!\n\n'
          'Je ontvangt een bevestigingsmail. Klik op de link in de mail '
          'om je e-mailadres te bevestigen.\n\n'
          'Daarna kun je inloggen met je e-mailadres en wachtwoord.',
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onRegistered();
            },
            child: const Text('Naar inlogscherm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/ventoz_logo.png', width: 60, height: 60)),
          const SizedBox(height: 12),
          const Text('Registreren', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF37474F))),
          const SizedBox(height: 4),
          Text('Toegang tot de Ventoz productcatalogus', style: TextStyle(fontSize: 13, color: Colors.blueGrey[400])),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mailadres', prefixIcon: Icon(Icons.email_outlined)),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Vul je e-mailadres in';
              if (!VatService.isValidEmail(v.trim())) return 'Ongeldig e-mailadres';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscure1,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Wachtwoord', prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure1 = !_obscure1),
              ),
            ),
            validator: _validatePassword,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passConfirmCtrl,
            obscureText: _obscure2,
            decoration: InputDecoration(
              labelText: 'Wachtwoord herhalen', prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure2 = !_obscure2),
              ),
            ),
            validator: (v) { if (v != _passCtrl.text) return 'Wachtwoorden komen niet overeen'; return null; },
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _voornaamCtrl,
                decoration: const InputDecoration(labelText: 'Voornaam', prefixIcon: Icon(Icons.person_outline), isDense: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vul je voornaam in';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _achternaamCtrl,
                decoration: const InputDecoration(labelText: 'Achternaam', isDense: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vul je achternaam in';
                  return null;
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _telefoonCtrl,
            decoration: const InputDecoration(labelText: 'Telefoonnummer', prefixIcon: Icon(Icons.phone_outlined), isDense: true),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _landCode,
                decoration: const InputDecoration(labelText: 'Land', prefixIcon: Icon(Icons.public), isDense: true),
                items: VatService.sortedCountryEntries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _landCode = v;
                      if (!VatService.isEuCountry(v)) {
                        _btwCtrl.clear();
                        _btwGevalideerd = false;
                        _vatError = null;
                        _vatName = null;
                      }
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Text(_isParticulier ? 'Particulier' : 'Bedrijf',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey[600])),
                Switch(
                  value: !_isParticulier,
                  onChanged: (v) => setState(() => _isParticulier = !v),
                  activeTrackColor: const Color(0xFF455A64),
                ),
              ],
            ),
          ]),
          if (!_isParticulier) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _bedrijfCtrl,
              decoration: const InputDecoration(labelText: 'Bedrijfsnaam', prefixIcon: Icon(Icons.business)),
              validator: (v) {
                if (!_isParticulier && (v == null || v.trim().isEmpty)) return 'Vul de bedrijfsnaam in';
                return null;
              },
            ),
            if (_isEuCountry) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _btwCtrl,
                    decoration: InputDecoration(
                      labelText: 'BTW-nummer (bijv. NL123456789B01)',
                      prefixIcon: const Icon(Icons.receipt_long),
                      suffixIcon: _validatingVat
                          ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                          : _btwGevalideerd
                              ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32))
                              : _vatError != null
                                  ? const Icon(Icons.cancel, color: Color(0xFFEF4444))
                                  : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _validatingVat ? null : _validateVat,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
                    child: const Text('VIES', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ]),
              if (_vatError != null)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text(_vatError!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12))),
              if (_vatName != null)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text('Geregistreerd: $_vatName', style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12))),
              if (_btwGevalideerd && _landCode != 'NL')
                Padding(padding: const EdgeInsets.only(top: 4), child: Text('BTW wordt verlegd (ICP)', style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w500))),
            ],
            if (!_isEuCountry)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Geen BTW van toepassing (buiten EU)', style: TextStyle(fontSize: 12, color: Colors.blueGrey[500])),
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red[200]!)),
              child: Row(children: [
                Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13))),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _register,
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Registreren', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Als klant krijg je toegang tot de productcatalogus, bestelhistorie en bezorgstatus. Neem contact op met Ventoz voor meer mogelijkheden.',
                style: TextStyle(fontSize: 11, color: Colors.blue[800]),
              )),
            ]),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onBack,
            child: Text('Terug naar inloggen', style: TextStyle(color: Colors.blueGrey[600], fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
