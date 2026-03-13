import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuditEntry {
  final String? id;
  final String actorEmail;
  final String action;
  final String? targetEmail;
  final String? details;
  final DateTime createdAt;

  const AuditEntry({
    this.id,
    required this.actorEmail,
    required this.action,
    this.targetEmail,
    this.details,
    required this.createdAt,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: json['id'] as String?,
        actorEmail: json['actor_email'] as String? ?? '',
        action: json['action'] as String? ?? '',
        targetEmail: json['target_email'] as String?,
        details: json['details'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );

  String get actionLabel => switch (action) {
        'login_success' => 'Inloggen geslaagd',
        'login_failed' => 'Inloggen mislukt',
        'account_locked' => 'Account geblokkeerd',
        'account_unlocked' => 'Account vrijgegeven',
        'user_invited' => 'Gebruiker uitgenodigd',
        'user_registered' => 'Gebruiker geregistreerd',
        'order_placed' => 'Bestelling geplaatst',
        'order_shipped' => 'Bestelling verzonden',
        _ => action,
      };
}

class AuditService {
  static final AuditService _instance = AuditService._();
  factory AuditService() => _instance;
  AuditService._();

  final _client = Supabase.instance.client;
  static const _table = 'audit_log';

  Future<void> log({
    required String action,
    String? actorEmail,
    String? targetEmail,
    String? details,
  }) async {
    final actor = actorEmail ?? _client.auth.currentUser?.email ?? 'systeem';
    try {
      await _client.from(_table).insert({
        'actor_email': actor,
        'action': action,
        'target_email': targetEmail,
        'details': details,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('AuditService.log error: $e');
    }
  }

  Future<List<AuditEntry>> getRecentLogs({int limit = 100}) async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List).map((r) => AuditEntry.fromJson(r)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('AuditService.getRecentLogs error: $e');
      return [];
    }
  }
}
