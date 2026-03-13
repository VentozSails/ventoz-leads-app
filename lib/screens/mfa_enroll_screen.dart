import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MfaEnrollScreen extends StatefulWidget {
  const MfaEnrollScreen({super.key});

  @override
  State<MfaEnrollScreen> createState() => _MfaEnrollScreenState();
}

class _MfaEnrollScreenState extends State<MfaEnrollScreen> {
  final _codeController = TextEditingController();
  bool _loading = true;
  bool _verifying = false;
  String? _error;
  String? _factorId;
  String? _qrUri;
  String? _secret;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _enroll();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _enroll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Remove ALL existing TOTP factors to avoid duplicate name errors
      try {
        final existing = await _supabase.auth.mfa.listFactors();
        for (final factor in existing.totp) {
          try {
            await _supabase.auth.mfa.unenroll(factor.id);
          } catch (_) {}
        }
      } catch (_) {}

      // Use unique friendly name to avoid conflicts with stale factors
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await _supabase.auth.mfa.enroll(
        factorType: FactorType.totp,
        friendlyName: 'Ventoz-$timestamp',
        issuer: 'Ventoz Sails',
      );

      final secret = response.totp?.secret;
      final userEmail = _supabase.auth.currentUser?.email ?? 'user';
      final otpauthUri = secret != null
          ? 'otpauth://totp/Ventoz%20Leads:$userEmail?secret=$secret&issuer=Ventoz%20Leads&algorithm=SHA1&digits=6&period=30'
          : null;

      setState(() {
        _factorId = response.id;
        _qrUri = otpauthUri;
        _secret = secret;
        _loading = false;
      });
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error enrolling MFA: $e');
      setState(() {
        _error = 'Fout bij MFA-registratie. Probeer het opnieuw.';
        _loading = false;
      });
    }
  }

  Future<void> _verifyAndActivate() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Voer een 6-cijferige code in');
      return;
    }
    if (_factorId == null) return;

    setState(() {
      _verifying = true;
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MFA succesvol ingeschakeld!'),
            backgroundColor: Color(0xFF43A047),
          ),
        );
        Navigator.pop(context, true);
      }
    } on AuthException catch (e) {
      setState(() {
        _error = e.message.toLowerCase().contains('invalid')
            ? 'Ongeldige code. Controleer de code uit je app.'
            : e.message;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error verifying MFA: $e');
      setState(() => _error = 'Verificatie mislukt. Probeer het opnieuw.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('MFA Instellen', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/login_bg.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0.0, -0.1),
          ),
          Container(color: const Color(0xFF37474F).withValues(alpha: 0.55)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Card(
                    elevation: 12,
                    shadowColor: Colors.black45,
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _loading ? _buildLoading() : _buildContent(),
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

  Widget _buildLoading() {
    return const Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('MFA wordt voorbereid...'),
      ],
    );
  }

  Widget _buildContent() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 48, color: Color(0xFF455A64)),
            const SizedBox(height: 16),
            const Text(
              'Tweestapsverificatie instellen',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF37474F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan de QR-code met een authenticator app\n(Google Authenticator, Authy, Microsoft Authenticator)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.blueGrey[500]),
            ),
            const SizedBox(height: 24),
            _buildStep(1, 'Scan de QR-code'),
            const SizedBox(height: 12),
            if (_qrUri != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCFD8DC)),
                ),
                child: QrImageView(
                  data: _qrUri!,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF37474F),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF37474F),
                  ),
                ),
              ),
            if (_secret != null) ...[
              const SizedBox(height: 16),
              _buildStep(2, 'Of voer handmatig deze sleutel in'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: SelectableText(
                        _secret!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF37474F),
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _secret!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Gekopieerd!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            _buildStep(3, 'Voer de verificatiecode in'),
            const SizedBox(height: 12),
            SizedBox(
              width: 200,
              child: TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: TextStyle(
                    color: Color(0xFFCFD8DC),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 6,
                  ),
                ),
                onFieldSubmitted: (_) => _verifyAndActivate(),
              ),
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
                    Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: TextStyle(color: Colors.red[700], fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _verifying ? null : _verifyAndActivate,
                icon: _verifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.verified_user),
                label: Text(_verifying ? 'Bezig...' : 'MFA Activeren',
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFF455A64),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF455A64),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
