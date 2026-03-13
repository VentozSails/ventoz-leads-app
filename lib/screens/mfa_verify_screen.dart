import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MfaVerifyScreen extends StatefulWidget {
  const MfaVerifyScreen({super.key});

  @override
  State<MfaVerifyScreen> createState() => _MfaVerifyScreenState();
}

class _MfaVerifyScreenState extends State<MfaVerifyScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _factorId;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadFactor();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadFactor() async {
    try {
      final factors = await _supabase.auth.mfa.listFactors();
      final totpFactors =
          factors.totp.where((f) => f.status == FactorStatus.verified).toList();

      if (totpFactors.isNotEmpty) {
        setState(() => _factorId = totpFactors.first.id);
      } else {
        setState(() => _error = 'Geen MFA-factor gevonden');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading MFA factors: $e');
      setState(() => _error = 'Fout bij laden MFA. Probeer het opnieuw.');
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Voer een 6-cijferige code in');
      return;
    }
    if (_factorId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final challenge =
          await _supabase.auth.mfa.challenge(factorId: _factorId!);

      await _supabase.auth.mfa.verify(
        factorId: _factorId!,
        challengeId: challenge.id,
        code: code,
      );

      if (mounted) Navigator.pop(context, true);
    } on AuthException catch (e) {
      setState(() {
        _error = e.message.toLowerCase().contains('invalid')
            ? 'Ongeldige code. Controleer je authenticator app.'
            : e.message;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error verifying MFA code: $e');
      setState(() => _error = 'Verificatie mislukt. Probeer het opnieuw.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withAlpha(30),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.security,
                            color: Color(0xFFF59E0B), size: 36),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tweestapsverificatie',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF37474F),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Voer de 6-cijferige code uit je\nauthenticator app in',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blueGrey[400],
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        autofocus: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 8,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: '000000',
                          hintStyle: TextStyle(
                            color: Color(0xFFCFD8DC),
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 8,
                          ),
                        ),
                        onFieldSubmitted: (_) => _verify(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red[700], size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                      color: Colors.red[700], fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _verify,
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Verifiëren',
                                  style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          _supabase.auth.signOut();
                          Navigator.pop(context, false);
                        },
                        child: const Text('Terug naar inloggen'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}
