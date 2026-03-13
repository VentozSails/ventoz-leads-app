import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Customer {
  final String? id;
  final String klantnummer;
  final String? authUserId;
  final String email;
  final String? voornaam;
  final String? achternaam;
  final String? bedrijfsnaam;
  final String? adres;
  final String? postcode;
  final String? woonplaats;
  final String landCode;
  final String? telefoon;
  final String? btwNummer;
  final String? opmerkingen;
  final String? snelstartId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Customer({
    this.id,
    this.klantnummer = '',
    this.authUserId,
    required this.email,
    this.voornaam,
    this.achternaam,
    this.bedrijfsnaam,
    this.adres,
    this.postcode,
    this.woonplaats,
    this.landCode = 'NL',
    this.telefoon,
    this.btwNummer,
    this.opmerkingen,
    this.snelstartId,
    this.createdAt,
    this.updatedAt,
  });

  String get volledigeNaam {
    final parts = <String>[];
    if (voornaam != null && voornaam!.isNotEmpty) parts.add(voornaam!);
    if (achternaam != null && achternaam!.isNotEmpty) parts.add(achternaam!);
    if (parts.isEmpty) return email;
    return parts.join(' ');
  }

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'] as String?,
    klantnummer: (json['klantnummer'] as String?) ?? '',
    authUserId: json['auth_user_id'] as String?,
    email: (json['email'] as String?) ?? '',
    voornaam: json['voornaam'] as String?,
    achternaam: json['achternaam'] as String?,
    bedrijfsnaam: json['bedrijfsnaam'] as String?,
    adres: json['adres'] as String?,
    postcode: json['postcode'] as String?,
    woonplaats: json['woonplaats'] as String?,
    landCode: (json['land_code'] as String?) ?? 'NL',
    telefoon: json['telefoon'] as String?,
    btwNummer: json['btw_nummer'] as String?,
    opmerkingen: json['opmerkingen'] as String?,
    snelstartId: json['snelstart_id'] as String?,
    createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
  );

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'email': email,
      'land_code': landCode,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (klantnummer.isNotEmpty) m['klantnummer'] = klantnummer;
    if (authUserId != null) m['auth_user_id'] = authUserId;
    if (voornaam != null) m['voornaam'] = voornaam;
    if (achternaam != null) m['achternaam'] = achternaam;
    if (bedrijfsnaam != null) m['bedrijfsnaam'] = bedrijfsnaam;
    if (adres != null) m['adres'] = adres;
    if (postcode != null) m['postcode'] = postcode;
    if (woonplaats != null) m['woonplaats'] = woonplaats;
    if (telefoon != null) m['telefoon'] = telefoon;
    if (btwNummer != null) m['btw_nummer'] = btwNummer;
    if (opmerkingen != null) m['opmerkingen'] = opmerkingen;
    if (snelstartId != null) m['snelstart_id'] = snelstartId;
    return m;
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

  Future<List<Customer>> getAll({String? search}) async {
    try {
      var query = _client.from(_table).select();
      if (search != null && search.trim().isNotEmpty) {
        final s = '%${search.trim()}%';
        query = query.or('email.ilike.$s,voornaam.ilike.$s,achternaam.ilike.$s,klantnummer.ilike.$s,bedrijfsnaam.ilike.$s');
      }
      final List<dynamic> rows = await query.order('created_at', ascending: false);
      return rows.cast<Map<String, dynamic>>().map(Customer.fromJson).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('CustomerService.getAll error: $e');
      return [];
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

  // External customer numbers

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
      final List<dynamic> rows = await _client.from(_table).select('id');
      return rows.length;
    } catch (_) {
      return 0;
    }
  }
}
