import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../models/email_log.dart';
import '../models/lead.dart';
import 'email_log_service.dart';

import 'export_web.dart' if (dart.library.io) 'export_io.dart' as platform;

class ExportService {
  static final _codec = CsvCodec(fieldDelimiter: ';', lineDelimiter: '\n');

  static List<dynamic> _emailCols(int leadId, Map<int, LeadEmailInfo> emailInfo) {
    final info = emailInfo[leadId];
    if (info == null) return ['Nee', 0, ''];
    return ['Ja', info.count, DateFormat('dd-MM-yyyy HH:mm').format(info.lastSentDate)];
  }

  static String leadsToCsv(List<Lead> leads, String country, {Map<int, LeadEmailInfo> emailInfo = const {}}) {
    switch (country) {
      case 'nl':
        return _codec.encode([
          ['ID', 'Nr', 'Ventoz Klantnr', 'Naam', 'Provincie', 'Categorie', 'Adres', 'Postcode', 'Plaats', 'Contactpersonen', 'Telefoon', 'E-mail', 'Website', 'Boot typen', 'Geschat aantal boten', 'Erkenningen', 'Opmerkingen', 'Status', 'Laatste actie', 'Email verstuurd', 'Aantal emails', 'Laatste email'],
          ...leads.map((l) => [l.id, l.nr ?? '', l.ventozKlantnr ?? '', l.naam, l.region ?? '', l.categorie ?? '', l.adres ?? '', l.postcode ?? '', l.plaats ?? '', l.contactpersonen ?? '', l.telefoon ?? '', l.email ?? '', l.website ?? '', l.typeBoten ?? '', l.geschatAantalBoten ?? '', l.erkenningen ?? '', l.opmerkingen ?? '', l.status, l.laatsteActie != null ? DateFormat('dd-MM-yyyy HH:mm').format(l.laatsteActie!) : '', ..._emailCols(l.id, emailInfo)]),
        ]);
      case 'de':
        return _codec.encode([
          ['ID', 'Nr', 'Ventoz Klantnr', 'Naam', 'Bundesland', 'Categorie', 'Adres', 'Postcode', 'Plaats', 'Contactpersoon', 'Telefoon', 'E-mail', 'Website', 'Boot typen', 'Status', 'Laatste actie', 'Email verstuurd', 'Aantal emails', 'Laatste email'],
          ...leads.map((l) => [l.id, l.nr ?? '', l.ventozKlantnr ?? '', l.naam, l.region ?? '', l.categorie ?? '', l.adres ?? '', l.postcode ?? '', l.plaats ?? '', l.contactpersonen ?? '', l.telefoon ?? '', l.email ?? '', l.website ?? '', l.typeBoten ?? '', l.status, l.laatsteActie != null ? DateFormat('dd-MM-yyyy HH:mm').format(l.laatsteActie!) : '', ..._emailCols(l.id, emailInfo)]),
        ]);
      case 'be':
        return _codec.encode([
          ['ID', 'Ventoz Klantnr', 'Naam', 'Type', 'Relevantie', 'Regio', 'Provincie', 'Plaats', 'Postcode', 'Adres', 'Website', 'Hoofdtaal', 'E-mail', 'Telefoon', 'Contactpersoon', 'Functie', 'Disciplines', 'Doelgroep', 'Type water', 'Jeugdwerking', 'Commercieel model', 'Opmerkingen', 'Boot typen', 'Status', 'Laatste actie', 'Email verstuurd', 'Aantal emails', 'Laatste email'],
          ...leads.map((l) => [l.id, l.ventozKlantnr ?? '', l.naam, l.type ?? '', l.relevantie ?? '', l.regio ?? '', l.region ?? '', l.plaats ?? '', l.postcode ?? '', l.adres ?? '', l.website ?? '', l.hoofdtaal ?? '', l.email ?? '', l.telefoon ?? '', l.contactpersonen ?? '', l.functie ?? '', l.disciplines ?? '', l.doelgroep ?? '', l.typeWater ?? '', l.jeugdwerking ?? '', l.commercieelModel ?? '', l.opmerkingen ?? '', l.typeBoten ?? '', l.status, l.laatsteActie != null ? DateFormat('dd-MM-yyyy HH:mm').format(l.laatsteActie!) : '', ..._emailCols(l.id, emailInfo)]),
        ]);
      default:
        return _codec.encode([
          ['Land', 'ID', 'Ventoz Klantnr', 'Naam', 'Regio', 'Adres', 'Postcode', 'Plaats', 'Contactpersoon', 'Telefoon', 'E-mail', 'Website', 'Boot typen', 'Status', 'Laatste actie', 'Email verstuurd', 'Aantal emails', 'Laatste email'],
          ...leads.map((l) => ['', l.id, l.ventozKlantnr ?? '', l.naam, l.region ?? '', l.adres ?? '', l.postcode ?? '', l.plaats ?? '', l.contactpersonen ?? '', l.telefoon ?? '', l.email ?? '', l.website ?? '', l.typeBoten ?? '', l.status, l.laatsteActie != null ? DateFormat('dd-MM-yyyy HH:mm').format(l.laatsteActie!) : '', ..._emailCols(l.id, emailInfo)]),
        ]);
    }
  }

  static String allLeadsToCsv(Map<String, List<Lead>> leadsPerCountry, {Map<int, LeadEmailInfo> emailInfo = const {}}) {
    final rows = <List<dynamic>>[
      ['Land', 'ID', 'Ventoz Klantnr', 'Naam', 'Regio/Provincie', 'Adres', 'Postcode', 'Plaats', 'Contactpersoon', 'Telefoon', 'E-mail', 'Website', 'Boot typen', 'Categorie', 'Hoofdtaal', 'Opmerkingen', 'Status', 'Laatste actie', 'Email verstuurd', 'Aantal emails', 'Laatste email'],
    ];
    for (final entry in leadsPerCountry.entries) {
      for (final l in entry.value) {
        rows.add([entry.key, l.id, l.ventozKlantnr ?? '', l.naam, l.region ?? l.regio ?? '', l.adres ?? '', l.postcode ?? '', l.plaats ?? '', l.contactpersonen ?? '', l.telefoon ?? '', l.email ?? '', l.website ?? '', l.typeBoten ?? '', l.categorie ?? '', l.hoofdtaal ?? '', l.opmerkingen ?? '', l.status, l.laatsteActie != null ? DateFormat('dd-MM-yyyy HH:mm').format(l.laatsteActie!) : '', ..._emailCols(l.id, emailInfo)]);
      }
    }
    return _codec.encode(rows);
  }

  static String emailLogsToCsv(List<EmailLog> logs) {
    final rows = <List<dynamic>>[
      ['Lead', 'Aan', 'Onderwerp', 'Status', 'Via', 'Template', 'Producten', 'Kortingscode', 'Datum', 'Foutmelding'],
      ...logs.map((e) => [
            e.leadNaam,
            e.verzondenAan,
            e.onderwerp ?? '',
            e.status.label,
            e.verzondenVia,
            e.templateNaam ?? '',
            e.producten ?? '',
            e.kortingscode ?? '',
            e.verzondenOp != null ? DateFormat('dd-MM-yyyy HH:mm').format(e.verzondenOp!) : '',
            e.foutmelding ?? '',
          ]),
    ];
    return _codec.encode(rows);
  }

  static String statisticsToCsv(Map<String, dynamic> stats) {
    final rows = <List<dynamic>>[
      ['Statistiek', 'Waarde'],
      ['Totaal Leads', stats['totaalLeads'] ?? 0],
      ['Totaal Klanten', stats['totaalKlanten'] ?? 0],
      ['Conversie Ratio', stats['conversieRatio'] ?? '0%'],
      ['Mails (30 dagen)', stats['mails30Dagen'] ?? 0],
      ['Mails (7 dagen)', stats['mails7Dagen'] ?? 0],
      ['Mails Totaal', stats['mailsTotaal'] ?? 0],
      [],
      ['Land', 'Aantal Leads'],
      ...((stats['leadsPerLand'] as Map<String, int>?) ?? {}).entries.map((e) => [e.key, e.value]),
      [],
      ['Status', 'Aantal'],
      ...((stats['leadsPerStatus'] as Map<String, int>?) ?? {}).entries.map((e) => [e.key, e.value]),
      [],
      ['Product', 'Keer Aangeboden'],
      ...((stats['productenInMails'] as Map<String, int>?) ?? {}).entries.map((e) => [e.key, e.value]),
      [],
      ['Kortingscode', 'Keer Gebruikt'],
      ...((stats['kortingscodesGebruikt'] as Map<String, int>?) ?? {}).entries.map((e) => [e.key, e.value]),
    ];
    return _codec.encode(rows);
  }

  static Future<String?> downloadCsv(String csv, String filename) async {
    if (kIsWeb) {
      platform.downloadCsvWeb(csv, filename);
      return null;
    } else {
      return platform.saveCsvDesktop(csv, filename);
    }
  }
}
