import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/email_log.dart';

class LeadEmailInfo {
  final DateTime lastSentDate;
  final int count;
  const LeadEmailInfo({required this.lastSentDate, required this.count});
}

class EmailLogService {
  final _client = Supabase.instance.client;

  Future<EmailLog?> save(EmailLog entry) async {
    try {
      final List<dynamic> result = await _client
          .from('email_logs')
          .insert(entry.toJson())
          .select();
      if (result.isNotEmpty) {
        return EmailLog.fromJson(result.first as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> log(EmailLog entry) async {
    try {
      await _client.from('email_logs').insert(entry.toJson());
    } catch (_) {}
  }

  Future<void> update(int id, Map<String, dynamic> fields) async {
    await _client.from('email_logs').update(fields).eq('id', id);
  }

  Future<void> markSent(int id) async {
    await update(id, {
      'status': EmailStatus.verzonden.name,
      'foutmelding': null,
    });
  }

  Future<void> markFailed(int id, String error) async {
    await update(id, {
      'status': EmailStatus.mislukt.name,
      'foutmelding': error,
    });
  }

  Future<void> markArchived(int id) async {
    await update(id, {'status': EmailStatus.gearchiveerd.name});
  }

  Future<void> updateDraft(int id, {String? onderwerp, String? inhoud, String? verzondenAan}) async {
    final fields = <String, dynamic>{};
    if (onderwerp != null) fields['onderwerp'] = onderwerp;
    if (inhoud != null) fields['inhoud'] = inhoud;
    if (verzondenAan != null) fields['verzonden_aan'] = verzondenAan;
    if (fields.isNotEmpty) await update(id, fields);
  }

  Future<void> delete(int id) async {
    await _client.from('email_logs').delete().eq('id', id);
  }

  Future<List<EmailLog>> fetchAll({EmailStatus? status, int? leadId, int limit = 200}) async {
    try {
      var query = _client.from('email_logs').select();
      if (status != null) {
        query = query.eq('status', status.name);
      }
      if (leadId != null) {
        query = query.eq('lead_id', leadId);
      }
      final List<dynamic> response = await query
          .order('verzonden_op', ascending: false)
          .limit(limit);
      return response
          .map((row) => EmailLog.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<EmailLog>> fetchDrafts() async {
    return fetchAll(status: EmailStatus.concept);
  }

  Future<List<EmailLog>> fetchForLead(int leadId) async {
    return fetchAll(leadId: leadId);
  }

  Future<void> logConversion(int leadId, String leadNaam, String kortingscode) async {
    try {
      await _client.from('email_logs').insert({
        'lead_id': leadId,
        'lead_naam': leadNaam,
        'kortingscode': kortingscode,
        'verzonden_aan': '',
        'verzonden_via': 'conversie',
        'status': EmailStatus.conversie.name,
      });
    } catch (_) {}
  }

  Future<Map<int, LeadEmailInfo>> fetchSentLeadIds() async {
    try {
      final List<dynamic> response = await _client
          .from('email_logs')
          .select('lead_id, verzonden_op')
          .neq('verzonden_via', 'conversie')
          .eq('status', EmailStatus.verzonden.name)
          .order('verzonden_op', ascending: false);

      final Map<int, List<DateTime>> grouped = {};
      for (final row in response) {
        final map = row as Map<String, dynamic>;
        final leadId = map['lead_id'] as int;
        final dt = DateTime.tryParse((map['verzonden_op'] as String?) ?? '');
        if (dt != null) {
          grouped.putIfAbsent(leadId, () => []).add(dt);
        }
      }

      return grouped.map((id, dates) => MapEntry(
        id,
        LeadEmailInfo(lastSentDate: dates.first, count: dates.length),
      ));
    } catch (_) {
      return {};
    }
  }

  Future<Set<int>> fetchFailedLeadIds() async {
    try {
      final List<dynamic> response = await _client
          .from('email_logs')
          .select('lead_id')
          .eq('status', EmailStatus.mislukt.name);
      return response.map((row) => (row as Map<String, dynamic>)['lead_id'] as int).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<int> archiveOldEmails({int olderThanDays = 180}) async {
    try {
      final cutoff = DateTime.now().subtract(Duration(days: olderThanDays)).toIso8601String();
      final List<dynamic> response = await _client
          .from('email_logs')
          .update({'status': EmailStatus.gearchiveerd.name})
          .eq('status', EmailStatus.verzonden.name)
          .lt('verzonden_op', cutoff)
          .select('id');
      return response.length;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, int>> countByStatus() async {
    try {
      final List<dynamic> response = await _client
          .from('email_logs')
          .select('status');
      final counts = <String, int>{};
      for (final row in response) {
        final s = (row as Map<String, dynamic>)['status'] as String? ?? 'verzonden';
        counts[s] = (counts[s] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }
}
