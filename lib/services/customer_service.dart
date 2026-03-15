import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Customer {
  final String? id;
  final String klantnummer;
  final String? authUserId;
  final String email;
  final String? naam;
  final String? voornaam;
  final String? achternaam;
  final String? bedrijfsnaam;
  final String? adres;
  final String? postcode;
  final String? woonplaats;
  final String landCode;
  final String? telefoon;
  final String? mobiel;
  final String? btwNummer;
  final String? kvkNummer;
  final String? contactpersoon;
  final String? opmerkingen;
  final String? snelstartId;
  final String? snelstartKlantcode;
  final List<String> klantcodeAliases;
  final bool isZakelijk;
  final double totaleOmzet;
  final DateTime? eersteFactuurDatum;
  final DateTime? laatsteFactuurDatum;
  final int aantalFacturen;
  final List<String> factuurNummers;
  final int? bronProspectId;
  final String? bronProspectLand;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Customer({
    this.id,
    this.klantnummer = '',
    this.authUserId,
    required this.email,
    this.naam,
    this.voornaam,
    this.achternaam,
    this.bedrijfsnaam,
    this.adres,
    this.postcode,
    this.woonplaats,
    this.landCode = 'NL',
    this.telefoon,
    this.mobiel,
    this.btwNummer,
    this.kvkNummer,
    this.contactpersoon,
    this.opmerkingen,
    this.snelstartId,
    this.snelstartKlantcode,
    this.klantcodeAliases = const [],
    this.isZakelijk = false,
    this.totaleOmzet = 0,
    this.eersteFactuurDatum,
    this.laatsteFactuurDatum,
    this.aantalFacturen = 0,
    this.factuurNummers = const [],
    this.bronProspectId,
    this.bronProspectLand,
    this.createdAt,
    this.updatedAt,
  });

  String get displayNaam {
    if (naam != null && naam!.isNotEmpty) return naam!;
    final parts = <String>[];
    if (voornaam != null && voornaam!.isNotEmpty) parts.add(voornaam!);
    if (achternaam != null && achternaam!.isNotEmpty) parts.add(achternaam!);
    if (parts.isNotEmpty) return parts.join(' ');
    if (bedrijfsnaam != null && bedrijfsnaam!.isNotEmpty) return bedrijfsnaam!;
    return email;
  }

  String get typeLabel => isZakelijk ? 'Zakelijk' : 'Particulier';

  String get landLabel => landLabels[landCode] ?? landCode;

  static const landLabels = <String, String>{
    'NL': 'Nederland', 'DE': 'Duitsland', 'BE': 'België', 'GB': 'Verenigd Koninkrijk',
    'FR': 'Frankrijk', 'IT': 'Italië', 'ES': 'Spanje', 'AT': 'Oostenrijk',
    'CH': 'Zwitserland', 'SE': 'Zweden', 'DK': 'Denemarken', 'NO': 'Noorwegen',
    'FI': 'Finland', 'PT': 'Portugal', 'IE': 'Ierland', 'PL': 'Polen',
    'CZ': 'Tsjechië', 'HU': 'Hongarije', 'GR': 'Griekenland', 'HR': 'Kroatië',
    'RO': 'Roemenië', 'SI': 'Slovenië', 'SK': 'Slowakije', 'BG': 'Bulgarije',
    'LU': 'Luxemburg', 'EE': 'Estland', 'LV': 'Letland', 'LT': 'Litouwen',
    'MT': 'Malta', 'CY': 'Cyprus', 'IS': 'IJsland', 'TR': 'Turkije',
    'AU': 'Australië', 'NZ': 'Nieuw-Zeeland', 'CA': 'Canada', 'JP': 'Japan',
    'BR': 'Brazilië', 'CL': 'Chili',
  };

  factory Customer.fromJson(Map<String, dynamic> json) {
    final aliases = json['klantcode_aliases'];
    List<String> parsedAliases = [];
    if (aliases is List) {
      parsedAliases = aliases.cast<String>();
    } else if (aliases is String && aliases.startsWith('{')) {
      parsedAliases = aliases.replaceAll(RegExp(r'[{}]'), '').split(',').where((s) => s.trim().isNotEmpty).toList();
    }

    return Customer(
      id: json['id'] as String?,
      klantnummer: (json['klantnummer'] as String?) ?? '',
      authUserId: json['auth_user_id'] as String?,
      email: (json['email'] as String?) ?? '',
      naam: json['naam'] as String?,
      voornaam: json['voornaam'] as String?,
      achternaam: json['achternaam'] as String?,
      bedrijfsnaam: json['bedrijfsnaam'] as String?,
      adres: json['adres'] as String?,
      postcode: json['postcode'] as String?,
      woonplaats: json['woonplaats'] as String?,
      landCode: (json['land_code'] as String?) ?? 'NL',
      telefoon: json['telefoon'] as String?,
      mobiel: json['mobiel'] as String?,
      btwNummer: json['btw_nummer'] as String?,
      kvkNummer: json['kvk_nummer'] as String?,
      contactpersoon: json['contactpersoon'] as String?,
      opmerkingen: json['opmerkingen'] as String?,
      snelstartId: json['snelstart_id'] as String?,
      snelstartKlantcode: json['snelstart_klantcode'] as String?,
      klantcodeAliases: parsedAliases,
      isZakelijk: json['is_zakelijk'] as bool? ?? false,
      totaleOmzet: _parseDouble(json['totale_omzet']),
      eersteFactuurDatum: _parseDate(json['eerste_factuur_datum']),
      laatsteFactuurDatum: _parseDate(json['laatste_factuur_datum']),
      aantalFacturen: (json['aantal_facturen'] as int?) ?? 0,
      bronProspectId: json['bron_prospect_id'] as int?,
      bronProspectLand: json['bron_prospect_land'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'email': email,
      'land_code': landCode,
      'is_zakelijk': isZakelijk,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (klantnummer.isNotEmpty) m['klantnummer'] = klantnummer;
    if (authUserId != null) m['auth_user_id'] = authUserId;
    if (naam != null) m['naam'] = naam;
    if (voornaam != null) m['voornaam'] = voornaam;
    if (achternaam != null) m['achternaam'] = achternaam;
    if (bedrijfsnaam != null) m['bedrijfsnaam'] = bedrijfsnaam;
    if (adres != null) m['adres'] = adres;
    if (postcode != null) m['postcode'] = postcode;
    if (woonplaats != null) m['woonplaats'] = woonplaats;
    if (telefoon != null) m['telefoon'] = telefoon;
    if (mobiel != null) m['mobiel'] = mobiel;
    if (btwNummer != null) m['btw_nummer'] = btwNummer;
    if (kvkNummer != null) m['kvk_nummer'] = kvkNummer;
    if (contactpersoon != null) m['contactpersoon'] = contactpersoon;
    if (opmerkingen != null) m['opmerkingen'] = opmerkingen;
    if (snelstartId != null) m['snelstart_id'] = snelstartId;
    if (snelstartKlantcode != null) m['snelstart_klantcode'] = snelstartKlantcode;
    if (klantcodeAliases.isNotEmpty) m['klantcode_aliases'] = klantcodeAliases;
    if (totaleOmzet != 0) m['totale_omzet'] = totaleOmzet;
    if (eersteFactuurDatum != null) m['eerste_factuur_datum'] = eersteFactuurDatum!.toIso8601String().split('T')[0];
    if (laatsteFactuurDatum != null) m['laatste_factuur_datum'] = laatsteFactuurDatum!.toIso8601String().split('T')[0];
    if (aantalFacturen > 0) m['aantal_facturen'] = aantalFacturen;
    if (bronProspectId != null) m['bron_prospect_id'] = bronProspectId;
    if (bronProspectLand != null) m['bron_prospect_land'] = bronProspectLand;
    return m;
  }

  Customer copyWith({
    String? naam,
    String? voornaam,
    String? achternaam,
    String? bedrijfsnaam,
    String? email,
    String? adres,
    String? postcode,
    String? woonplaats,
    String? landCode,
    String? telefoon,
    String? mobiel,
    String? btwNummer,
    String? kvkNummer,
    String? contactpersoon,
    String? opmerkingen,
    bool? isZakelijk,
  }) {
    return Customer(
      id: id,
      klantnummer: klantnummer,
      authUserId: authUserId,
      email: email ?? this.email,
      naam: naam ?? this.naam,
      voornaam: voornaam ?? this.voornaam,
      achternaam: achternaam ?? this.achternaam,
      bedrijfsnaam: bedrijfsnaam ?? this.bedrijfsnaam,
      adres: adres ?? this.adres,
      postcode: postcode ?? this.postcode,
      woonplaats: woonplaats ?? this.woonplaats,
      landCode: landCode ?? this.landCode,
      telefoon: telefoon ?? this.telefoon,
      mobiel: mobiel ?? this.mobiel,
      btwNummer: btwNummer ?? this.btwNummer,
      kvkNummer: kvkNummer ?? this.kvkNummer,
      contactpersoon: contactpersoon ?? this.contactpersoon,
      opmerkingen: opmerkingen ?? this.opmerkingen,
      snelstartId: snelstartId,
      snelstartKlantcode: snelstartKlantcode,
      klantcodeAliases: klantcodeAliases,
      isZakelijk: isZakelijk ?? this.isZakelijk,
      totaleOmzet: totaleOmzet,
      eersteFactuurDatum: eersteFactuurDatum,
      laatsteFactuurDatum: laatsteFactuurDatum,
      aantalFacturen: aantalFacturen,
      bronProspectId: bronProspectId,
      bronProspectLand: bronProspectLand,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class ExternalCustomerNumber {
  final String? id;
  final String klantId;
  final String platform;
  final String externNummer;
  final DateTime? createdAt;

  const ExternalCustomerNumber({
    this.id,
    required this.klantId,
    required this.platform,
    required this.externNummer,
    this.createdAt,
  });

  factory ExternalCustomerNumber.fromJson(Map<String, dynamic> json) => ExternalCustomerNumber(
    id: json['id'] as String?,
    klantId: (json['klant_id'] as String?) ?? '',
    platform: (json['platform'] as String?) ?? '',
    externNummer: (json['extern_nummer'] as String?) ?? '',
    createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    'klant_id': klantId,
    'platform': platform,
    'extern_nummer': externNummer,
  };

  static const platformLabels = <String, String>{
    'website': 'Ventoz Website',
    'ebay': 'eBay',
    'amazon': 'Amazon',
    'bol_com': 'Bol.com',
    'snelstart': 'SnelStart',
    'handmatig': 'Handmatig',
  };

  String get platformLabel => platformLabels[platform] ?? platform;
}

class CustomerService {
  final _client = Supabase.instance.client;
  static const _table = 'klanten';
  static const _extTable = 'klant_externe_nummers';

  static const _allowedSortColumns = {
    'naam', 'email', 'klantnummer', 'woonplaats', 'land_code',
    'totale_omzet', 'aantal_facturen', 'laatste_factuur_datum', 'created_at',
  };

  static String _sanitizeFilter(String input) {
    return input.replaceAll(RegExp(r'[,\(\)\.\\\"]'), '');
  }

  Future<({int total, int zakelijk, int particulier})> getCounts() async {
    try {
      final allRows = <Map<String, dynamic>>[];
      int offset = 0;
      const batchSize = 1000;
      while (true) {
        final List<dynamic> batch = await _client
            .from(_table)
            .select('id, is_zakelijk')
            .range(offset, offset + batchSize - 1);
        allRows.addAll(batch.cast<Map<String, dynamic>>());
        if (batch.length < batchSize) break;
        offset += batchSize;
      }
      final total = allRows.length;
      final zakelijk = allRows.where((r) => r['is_zakelijk'] == true).length;
      return (total: total, zakelijk: zakelijk, particulier: total - zakelijk);
    } catch (e) {
      if (kDebugMode) debugPrint('CustomerService.getCounts error: $e');
      return (total: 0, zakelijk: 0, particulier: 0);
    }
  }

  Future<List<Customer>> getAll({String? search, String? landFilter, bool? zakelijkFilter, String? sortBy, bool sortAsc = true, int limit = 10000}) async {
    try {
      final orderCol = _allowedSortColumns.contains(sortBy) ? sortBy! : 'naam';
      final allRows = <Map<String, dynamic>>[];
      int offset = 0;
      const batchSize = 1000;

      while (allRows.length < limit) {
        var query = _client.from(_table).select();
        if (search != null && search.trim().isNotEmpty) {
          final s = '%${_sanitizeFilter(search.trim())}%';
          query = query.or('email.ilike.$s,naam.ilike.$s,klantnummer.ilike.$s,bedrijfsnaam.ilike.$s,woonplaats.ilike.$s,snelstart_klantcode.ilike.$s,contactpersoon.ilike.$s');
        }
        if (landFilter != null && landFilter.isNotEmpty) {
          query = query.eq('land_code', landFilter);
        }
        if (zakelijkFilter != null) {
          query = query.eq('is_zakelijk', zakelijkFilter);
        }
        final remaining = limit - allRows.length;
        final fetchSize = remaining < batchSize ? remaining : batchSize;
        final List<dynamic> rows = await query
            .order(orderCol, ascending: sortAsc)
            .range(offset, offset + fetchSize - 1);
        allRows.addAll(rows.cast<Map<String, dynamic>>());
        if (rows.length < fetchSize) break;
        offset += fetchSize;
      }

      final customers = allRows.map(Customer.fromJson).toList();
      return await _enrichWithInvoiceNumbers(customers);
    } catch (e) {
      if (kDebugMode) debugPrint('CustomerService.getAll error: $e');
      return [];
    }
  }

  Future<List<Customer>> _enrichWithInvoiceNumbers(List<Customer> customers) async {
    final ids = customers.where((c) => c.id != null).map((c) => c.id!).toList();
    if (ids.isEmpty) return customers;

    try {
      final byKlant = <String, List<String>>{};

      // Batch the inFilter to avoid URL length limits (max ~100 UUIDs per batch)
      for (int i = 0; i < ids.length; i += 100) {
        final batch = ids.sublist(i, i + 100 > ids.length ? ids.length : i + 100);
        final List<dynamic> byIdRows = await _client
            .from('orders')
            .select('klant_id, factuur_nummer')
            .inFilter('klant_id', batch)
            .not('factuur_nummer', 'is', null)
            .order('factuur_nummer', ascending: false)
            .limit(5000);

        for (final row in byIdRows.cast<Map<String, dynamic>>()) {
          final klantId = row['klant_id'] as String?;
          final nr = row['factuur_nummer'] as String?;
          if (klantId != null && nr != null && nr.isNotEmpty) {
            byKlant.putIfAbsent(klantId, () => []).add(nr);
          }
        }
      }

      // For customers without results, also try matching by email (batched)
      final noResults = customers.where((c) => c.id != null && !byKlant.containsKey(c.id) && c.email.isNotEmpty).toList();
      if (noResults.isNotEmpty) {
        final byEmail = <String, List<String>>{};
        final emails = noResults.map((c) => c.email.toLowerCase()).toList();

        for (int i = 0; i < emails.length; i += 100) {
          final batch = emails.sublist(i, i + 100 > emails.length ? emails.length : i + 100);
          final List<dynamic> byEmailRows = await _client
              .from('orders')
              .select('user_email, factuur_nummer')
              .inFilter('user_email', batch)
              .not('factuur_nummer', 'is', null)
              .order('factuur_nummer', ascending: false)
              .limit(5000);

          for (final row in byEmailRows.cast<Map<String, dynamic>>()) {
            final email = (row['user_email'] as String?)?.toLowerCase();
            final nr = row['factuur_nummer'] as String?;
            if (email != null && nr != null && nr.isNotEmpty) {
              byEmail.putIfAbsent(email, () => []).add(nr);
            }
          }
        }

        for (final c in noResults) {
          final nrs = byEmail[c.email.toLowerCase()];
          if (nrs != null && nrs.isNotEmpty) {
            byKlant[c.id!] = nrs;
          }
        }
      }

      return customers.map((c) {
        final nrs = byKlant[c.id] ?? [];
        if (nrs.isEmpty) return c;
        return Customer(
          id: c.id, klantnummer: c.klantnummer, authUserId: c.authUserId,
          email: c.email, naam: c.naam, voornaam: c.voornaam, achternaam: c.achternaam,
          bedrijfsnaam: c.bedrijfsnaam, adres: c.adres, postcode: c.postcode,
          woonplaats: c.woonplaats, landCode: c.landCode, telefoon: c.telefoon,
          mobiel: c.mobiel, btwNummer: c.btwNummer, kvkNummer: c.kvkNummer,
          contactpersoon: c.contactpersoon, opmerkingen: c.opmerkingen,
          snelstartId: c.snelstartId, snelstartKlantcode: c.snelstartKlantcode,
          klantcodeAliases: c.klantcodeAliases, isZakelijk: c.isZakelijk,
          totaleOmzet: c.totaleOmzet, eersteFactuurDatum: c.eersteFactuurDatum,
          laatsteFactuurDatum: c.laatsteFactuurDatum,
          aantalFacturen: nrs.isNotEmpty ? nrs.length : c.aantalFacturen,
          factuurNummers: nrs, bronProspectId: c.bronProspectId,
          bronProspectLand: c.bronProspectLand, createdAt: c.createdAt, updatedAt: c.updatedAt,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('_enrichWithInvoiceNumbers error: $e');
      return customers;
    }
  }

  Future<Customer?> getById(String id) async {
    try {
      final row = await _client.from(_table).select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return Customer.fromJson(row);
    } catch (e) {
      if (kDebugMode) debugPrint('CustomerService.getById error: $e');
      return null;
    }
  }

  Future<Customer?> findByEmail(String email) async {
    try {
      final row = await _client.from(_table)
          .select()
          .eq('email', email.toLowerCase().trim())
          .maybeSingle();
      if (row == null) return null;
      return Customer.fromJson(row);
    } catch (e) {
      if (kDebugMode) debugPrint('CustomerService.findByEmail error: $e');
      return null;
    }
  }

  Future<String> _generateKlantnummer() async {
    try {
      final List<dynamic> rows = await _client.from(_table)
          .select('klantnummer')
          .like('klantnummer', 'VTZ-K%')
          .order('klantnummer', ascending: false)
          .limit(1);
      if (rows.isNotEmpty) {
        final last = (rows.first as Map<String, dynamic>)['klantnummer'] as String;
        final numPart = int.tryParse(last.replaceAll(RegExp(r'[^0-9]'), ''));
        if (numPart != null) {
          return 'VTZ-K${(numPart + 1).toString().padLeft(4, '0')}';
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('_generateKlantnummer error: $e');
    }
    return 'VTZ-K0001';
  }

  Future<Customer?> findOrCreateByEmail({
    required String email,
    String? voornaam,
    String? achternaam,
    String? bedrijfsnaam,
    String? adres,
    String? postcode,
    String? woonplaats,
    String landCode = 'NL',
    String? telefoon,
    String? btwNummer,
    String? authUserId,
  }) async {
    final existing = await findByEmail(email);
    if (existing != null) {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      bool needsUpdate = false;
      if (voornaam != null && voornaam != existing.voornaam) { updates['voornaam'] = voornaam; needsUpdate = true; }
      if (achternaam != null && achternaam != existing.achternaam) { updates['achternaam'] = achternaam; needsUpdate = true; }
      if (adres != null && adres != existing.adres) { updates['adres'] = adres; needsUpdate = true; }
      if (postcode != null && postcode != existing.postcode) { updates['postcode'] = postcode; needsUpdate = true; }
      if (woonplaats != null && woonplaats != existing.woonplaats) { updates['woonplaats'] = woonplaats; needsUpdate = true; }
      if (telefoon != null && telefoon != existing.telefoon) { updates['telefoon'] = telefoon; needsUpdate = true; }
      if (authUserId != null && existing.authUserId == null) { updates['auth_user_id'] = authUserId; needsUpdate = true; }

      if (needsUpdate) {
        await _client.from(_table).update(updates).eq('id', existing.id!);
        return await getById(existing.id!);
      }
      return existing;
    }

    final klantnummer = await _generateKlantnummer();
    final json = <String, dynamic>{
      'klantnummer': klantnummer,
      'email': email.toLowerCase().trim(),
      'land_code': landCode,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (authUserId != null) json['auth_user_id'] = authUserId;
    if (voornaam != null) json['voornaam'] = voornaam;
    if (achternaam != null) json['achternaam'] = achternaam;
    if (bedrijfsnaam != null) json['bedrijfsnaam'] = bedrijfsnaam;
    if (adres != null) json['adres'] = adres;
    if (postcode != null) json['postcode'] = postcode;
    if (woonplaats != null) json['woonplaats'] = woonplaats;
    if (telefoon != null) json['telefoon'] = telefoon;
    if (btwNummer != null) json['btw_nummer'] = btwNummer;

    try {
      final rows = await _client.from(_table).insert(json).select();
      if (rows.isNotEmpty) return Customer.fromJson(rows.first);
    } catch (e) {
      if (kDebugMode) debugPrint('CustomerService.findOrCreateByEmail insert error: $e');
    }
    return null;
  }

  Future<Customer?> save(Customer customer) async {
    try {
      final json = customer.toJson();
      if (customer.id != null) {
        final rows = await _client.from(_table).update(json).eq('id', customer.id!).select();
        if (rows.isNotEmpty) return Customer.fromJson(rows.first);
      } else {
        if (!json.containsKey('klantnummer') || (json['klantnummer'] as String).isEmpty) {
          json['klantnummer'] = await _generateKlantnummer();
        }
        final rows = await _client.from(_table).insert(json).select();
        if (rows.isNotEmpty) return Customer.fromJson(rows.first);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('CustomerService.save error: $e');
      rethrow;
    }
    return null;
  }

  Future<void> delete(String id) async {
    await _client.from(_extTable).delete().eq('klant_id', id);
    await _client.from(_table).delete().eq('id', id);
  }

  Future<void> linkAuthUser(String customerId, String authUserId) async {
    await _client.from(_table).update({
      'auth_user_id': authUserId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', customerId);
  }

  Future<void> mergeOnRegistration(String email, String authUserId) async {
    final existing = await findByEmail(email);
    if (existing != null && existing.authUserId == null) {
      await linkAuthUser(existing.id!, authUserId);
    }
  }

  Future<List<ExternalCustomerNumber>> getExternalNumbers(String klantId) async {
    try {
      final List<dynamic> rows = await _client.from(_extTable)
          .select()
          .eq('klant_id', klantId)
          .order('platform', ascending: true);
      return rows.cast<Map<String, dynamic>>().map(ExternalCustomerNumber.fromJson).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('CustomerService.getExternalNumbers error: $e');
      return [];
    }
  }

  Future<void> saveExternalNumber(ExternalCustomerNumber ext) async {
    if (ext.id != null) {
      await _client.from(_extTable).update(ext.toJson()).eq('id', ext.id!);
    } else {
      await _client.from(_extTable).upsert(ext.toJson(), onConflict: 'klant_id,platform');
    }
  }

  Future<void> deleteExternalNumber(String id) async {
    await _client.from(_extTable).delete().eq('id', id);
  }

  Future<int> getCustomerCount() async {
    try {
      final counts = await getCounts();
      return counts.total;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, int>> getStats() async {
    try {
      final List<dynamic> rows = await _client.from(_table).select('is_zakelijk, land_code').limit(10000);
      int total = rows.length;
      int zakelijk = 0;
      final landen = <String, int>{};
      for (final row in rows) {
        final r = row as Map<String, dynamic>;
        if (r['is_zakelijk'] == true) zakelijk++;
        final lc = (r['land_code'] as String?) ?? 'NL';
        landen[lc] = (landen[lc] ?? 0) + 1;
      }
      return {'total': total, 'zakelijk': zakelijk, 'particulier': total - zakelijk, ...landen};
    } catch (_) {
      return {};
    }
  }
}
