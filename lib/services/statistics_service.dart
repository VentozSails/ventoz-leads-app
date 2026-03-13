import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardStats {
  final int totaalLeads;
  final int totaalKlanten;
  final int mails30Dagen;
  final double conversieRatio;

  final Map<String, int> leadsPerLand;
  final Map<String, int> leadsPerStatus;
  final Map<String, int> productenInMails;
  final Map<String, int> kortingscodesGebruikt;

  // Funnel
  final int funnelNieuw;
  final int funnelContact;
  final int funnelAangeboden;
  final int funnelKlant;

  // Recent activity
  final int mails7Dagen;
  final int mailsTotaal;

  const DashboardStats({
    required this.totaalLeads,
    required this.totaalKlanten,
    required this.mails30Dagen,
    required this.conversieRatio,
    required this.leadsPerLand,
    required this.leadsPerStatus,
    required this.productenInMails,
    required this.kortingscodesGebruikt,
    required this.funnelNieuw,
    required this.funnelContact,
    required this.funnelAangeboden,
    required this.funnelKlant,
    required this.mails7Dagen,
    required this.mailsTotaal,
  });
}

class StatisticsService {
  final _client = Supabase.instance.client;

  Future<DashboardStats> fetchStats() async {
    final results = await Future.wait([
      _client.from('leads_nl').select('status, ventoz_klantnr'),
      _client.from('leads_de').select('status, ventoz_klantnr'),
      _client.from('leads_be').select('status, ventoz_klantnr'),
      _client.from('email_logs').select('lead_id, producten, kortingscode, verzonden_op, verzonden_via'),
    ]);

    final nlLeads = (results[0] as List).cast<Map<String, dynamic>>();
    final deLeads = (results[1] as List).cast<Map<String, dynamic>>();
    final beLeads = (results[2] as List).cast<Map<String, dynamic>>();
    final emailLogs = (results[3] as List).cast<Map<String, dynamic>>();

    final allLeads = [...nlLeads, ...deLeads, ...beLeads];

    final leadsPerLand = {
      'Nederland': nlLeads.length,
      'Duitsland': deLeads.length,
      'België': beLeads.length,
    };

    final statusCounts = <String, int>{};
    int klanten = 0;
    for (final lead in allLeads) {
      final status = (lead['status'] as String?) ?? 'Nieuw';
      final klantnr = lead['ventoz_klantnr'] as String?;
      final isKlant = status == 'Klant' || (klantnr != null && klantnr.trim().isNotEmpty);
      final effectiveStatus = isKlant ? 'Klant' : status;
      statusCounts[effectiveStatus] = (statusCounts[effectiveStatus] ?? 0) + 1;
      if (isKlant) klanten++;
    }

    final now = DateTime.now();
    final d30 = now.subtract(const Duration(days: 30));
    final d7 = now.subtract(const Duration(days: 7));

    int mails30 = 0;
    int mails7 = 0;
    final emailedLeadIds = <int>{};
    final productenCount = <String, int>{};
    final codeCount = <String, int>{};

    for (final log in emailLogs) {
      final via = (log['verzonden_via'] as String?) ?? '';
      if (via == 'conversie') continue;
      final leadId = log['lead_id'] as int;
      emailedLeadIds.add(leadId);

      final verzondenOp = DateTime.tryParse((log['verzonden_op'] as String?) ?? '');
      if (verzondenOp != null) {
        if (verzondenOp.isAfter(d30)) mails30++;
        if (verzondenOp.isAfter(d7)) mails7++;
      }

      final producten = log['producten'] as String?;
      if (producten != null && producten.trim().isNotEmpty) {
        for (final p in producten.split(',')) {
          final name = p.trim();
          if (name.isNotEmpty) productenCount[name] = (productenCount[name] ?? 0) + 1;
        }
      }

      final code = log['kortingscode'] as String?;
      if (code != null && code.trim().isNotEmpty) {
        codeCount[code] = (codeCount[code] ?? 0) + 1;
      }
    }

    final total = allLeads.length;
    final conversie = total > 0 ? (klanten / total * 100) : 0.0;

    // Funnel: Nieuw > Contact (emailed) > Aangeboden (status) > Klant (klantnr)
    final funnelAangeboden = statusCounts['Aangeboden'] ?? 0;
    final funnelKlant = klanten;

    return DashboardStats(
      totaalLeads: total,
      totaalKlanten: klanten,
      mails30Dagen: mails30,
      conversieRatio: conversie,
      leadsPerLand: leadsPerLand,
      leadsPerStatus: statusCounts,
      productenInMails: productenCount,
      kortingscodesGebruikt: codeCount,
      funnelNieuw: total,
      funnelContact: emailedLeadIds.length,
      funnelAangeboden: funnelAangeboden,
      funnelKlant: funnelKlant,
      mails7Dagen: mails7,
      mailsTotaal: emailLogs.length,
    );
  }
}
