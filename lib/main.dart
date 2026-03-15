import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'router/app_router.dart' show appRouter, authNotifier, initRouterPermissionHook;
import 'services/user_service.dart';
import 'theme/app_theme.dart';
import 'l10n/locale_provider.dart';

const _envUrl = String.fromEnvironment('SUPABASE_URL');
const _envKey = String.fromEnvironment('SUPABASE_ANON_KEY');

const _fallbackUrl = 'https://xfskhdirwocfsfmcahkf.supabase.co';
const _fallbackKey = 'sb_publishable_WNzI0Ur7IInbJSDlZmGZFg_xrkYeGJ8';

String get _supabaseUrl => _envUrl.isNotEmpty ? _envUrl : _fallbackUrl;
String get _supabaseKey => _envKey.isNotEmpty ? _envKey : _fallbackKey;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootstrapApp());
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  bool _ready = false;
  bool _configError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final url = _supabaseUrl;
    final key = _supabaseKey;
    if (url.isEmpty || key.isEmpty || url.contains('your_supabase')) {
      if (mounted) setState(() { _configError = true; _ready = true; });
      return;
    }

    await Supabase.initialize(
      url: url,
      anonKey: key,
    );

    // Always clear persisted session so the user must log in fresh on every app start.
    // signOut(local) only clears the local token; it does not invalidate the
    // server-side refresh token, so this is safe even if no session exists yet.
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}

    authNotifier.init();
    initRouterPermissionHook();

    if (kDebugMode) {
      final schemaErrors = UserPermissions.validateSchema();
      for (final e in schemaErrors) {
        debugPrint('⚠️ UserPermissions schema drift: $e');
      }
      assert(schemaErrors.isEmpty, 'UserPermissions schema is out of sync! See debug console.');
    }

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_configError) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
          appBar: AppBar(title: const Text('Ventoz Sails')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.vpn_key_off, size: 48, color: Color(0xFFF59E0B)),
                  SizedBox(height: 16),
                  Text('Supabase niet geconfigureerd',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    'Build met --dart-define=SUPABASE_URL=…\n'
                    'en --dart-define=SUPABASE_ANON_KEY=…',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: LocaleProvider(),
      builder: (context, _) => MaterialApp.router(
        title: 'Ventoz Sails',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: appRouter,
      ),
    );
  }
}
