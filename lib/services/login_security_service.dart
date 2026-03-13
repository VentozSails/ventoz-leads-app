import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'audit_service.dart';

class LoginSecurityService {
  static final LoginSecurityService _instance = LoginSecurityService._();
  factory LoginSecurityService() => _instance;
  LoginSecurityService._();

  final _client = Supabase.instance.client;
  static const _usersTable = 'ventoz_users';
  static const maxAttempts = 5;

  Future<bool> isAccountLocked(String email) async {
    try {
      final result = await _client.rpc('check_account_locked', params: {'p_email': email.toLowerCase()});
      return result == true;
    } catch (e) {
      if (kDebugMode) debugPrint('LoginSecurityService.isAccountLocked error: $e');
      return false;
    }
  }

  Future<void> recordFailedAttempt(String email) async {
    try {
      await _client.rpc('record_failed_login', params: {'p_email': email.toLowerCase()});
    } catch (e) {
      debugPrint('LoginSecurityService.recordFailedAttempt error: $e');
    }
  }

  Future<void> clearAttempts(String email) async {
    try {
      await _client.rpc('clear_login_attempts', params: {'p_email': email.toLowerCase()});
    } catch (e) {
      if (kDebugMode) debugPrint('LoginSecurityService.clearAttempts error: $e');
    }
  }

  Future<void> unlockAccount(String email) async {
    try {
      await _client
          .from(_usersTable)
          .update({'locked_until': null})
          .eq('email', email.toLowerCase());
      await clearAttempts(email);
      await AuditService().log(
        action: 'account_unlocked',
        targetEmail: email.toLowerCase(),
        details: 'Handmatig vrijgegeven',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('LoginSecurityService.unlockAccount error: $e');
    }
  }

  Future<List<LockedAccount>> getLockedAccounts() async {
    try {
      final rows = await _client
          .from(_usersTable)
          .select('email, locked_until, voornaam, achternaam')
          .not('locked_until', 'is', null)
          .gt('locked_until', DateTime.now().toUtc().toIso8601String());
      final accounts = <LockedAccount>[];
      for (final row in rows) {
        accounts.add(LockedAccount(
          email: row['email'] as String? ?? '',
          naam: _buildNaam(row['voornaam'] as String?, row['achternaam'] as String?),
          lockedUntil: DateTime.tryParse(row['locked_until'] as String? ?? ''),
        ));
      }
      return accounts;
    } catch (e) {
      if (kDebugMode) debugPrint('LoginSecurityService.getLockedAccounts error: $e');
      return [];
    }
  }

  String _buildNaam(String? voornaam, String? achternaam) {
    final parts = [?voornaam, ?achternaam];
    return parts.isEmpty ? '' : parts.join(' ');
  }
}

class LockedAccount {
  final String email;
  final String naam;
  final DateTime? lockedUntil;

  const LockedAccount({
    required this.email,
    required this.naam,
    this.lockedUntil,
  });
}
