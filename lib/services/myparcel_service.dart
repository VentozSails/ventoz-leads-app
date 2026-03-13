import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'crypto_service.dart';

class MyParcelConfig {
  final String apiKey;
  final int defaultCarrierId;
  final String defaultBoxId;
  final String senderName;
  final String senderStreet;
  final String senderNumber;
  final String senderPostalCode;
  final String senderCity;
  final String senderCc;
  final String senderEmail;
  final String senderPhone;
  final int maxGewichtGram;
  final int maxOmtrekCm;

  const MyParcelConfig({
    required this.apiKey,
    this.defaultCarrierId = 1,
    this.defaultBoxId = '',
    this.senderName = 'Ventoz Sails',
    this.senderStreet = 'Dorpsstraat',
    this.senderNumber = '111',
    this.senderPostalCode = '7948BN',
    this.senderCity = 'Nijeveen',
    this.senderCc = 'NL',
    this.senderEmail = 'info@ventoz.nl',
    this.senderPhone = '0610193845',
    this.maxGewichtGram = 31500,
    this.maxOmtrekCm = 176,
  });

  bool get isConfigured => apiKey.isNotEmpty;

  factory MyParcelConfig.fromJson(Map<String, dynamic> json) => MyParcelConfig(
    apiKey: json['api_key'] as String? ?? '',
    defaultCarrierId: (json['default_carrier_id'] as num?)?.toInt() ?? 1,
    defaultBoxId: json['default_box_id'] as String? ?? '',
    senderName: json['sender_name'] as String? ?? 'Ventoz Sails',
    senderStreet: json['sender_street'] as String? ?? 'Dorpsstraat',
    senderNumber: json['sender_number'] as String? ?? '111',
    senderPostalCode: json['sender_postal_code'] as String? ?? '7948BN',
    senderCity: json['sender_city'] as String? ?? 'Nijeveen',
    senderCc: json['sender_cc'] as String? ?? 'NL',
    senderEmail: json['sender_email'] as String? ?? 'info@ventoz.nl',
    senderPhone: json['sender_phone'] as String? ?? '0610193845',
    maxGewichtGram: (json['max_gewicht_gram'] as num?)?.toInt() ?? 31500,
    maxOmtrekCm: (json['max_omtrek_cm'] as num?)?.toInt() ?? 176,
  );

  Map<String, dynamic> toJson() => {
    'api_key': apiKey,
    'default_carrier_id': defaultCarrierId,
    'default_box_id': defaultBoxId,
    'sender_name': senderName,
    'sender_street': senderStreet,
    'sender_number': senderNumber,
    'sender_postal_code': senderPostalCode,
    'sender_city': senderCity,
    'sender_cc': senderCc,
    'sender_email': senderEmail,
    'sender_phone': senderPhone,
    'max_gewicht_gram': maxGewichtGram,
    'max_omtrek_cm': maxOmtrekCm,
  };
}

class MyParcelShipmentResult {
  final int shipmentId;
  final String? barcode;
  final String? trackTraceUrl;

  const MyParcelShipmentResult({
    required this.shipmentId,
    this.barcode,
    this.trackTraceUrl,
  });
}

class MyParcelService {
  static final MyParcelService _instance = MyParcelService._();
  factory MyParcelService() => _instance;
  MyParcelService._();

  static const _baseUrl = 'https://api.myparcel.nl';
  static const _settingsKey = 'myparcel_config';
  final _supabase = Supabase.instance.client;

  static const carriers = <int, String>{
    1: 'PostNL',
    4: 'DPD',
    9: 'DHL For You',
    10: 'DHL Parcel Connect',
    11: 'DHL Europlus',
  };

  static const carrierKeyToId = <String, int>{
    'postnl': 1,
    'dpd': 4,
    'dhl': 9,
    'dhl_parcel_connect': 10,
    'dhl_europlus': 11,
  };

  static const packageTypes = <int, String>{
    1: 'Pakket',
    2: 'Brievenbuspakje',
    3: 'Brief',
    4: 'Digitale postzegel',
    5: 'Pallet',
    6: 'Pakket klein',
  };

  static const insuranceAmounts = <int, String>{
    0: 'Geen verzekering',
    10000: '€ 100',
    25000: '€ 250',
    50000: '€ 500',
    100000: '€ 1.000',
    200000: '€ 2.000',
    500000: '€ 5.000',
  };

  Map<String, String> _headers(String apiKey) => {
    'Authorization': 'bearer ${base64Encode(utf8.encode(apiKey))}',
    'User-Agent': 'CustomApiCall/2',
  };

  static const _secretFields = ['api_key'];

  Future<MyParcelConfig?> getConfig() async {
    try {
      final rows = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', _settingsKey);
      if ((rows as List).isNotEmpty) {
        var val = rows.first['value'];
        if (val is Map<String, dynamic>) {
          try {
            final dec = await _supabase.rpc('decrypt_settings_secrets', params: {
              'p_settings': val, 'p_secret_fields': _secretFields,
            });
            if (dec is Map<String, dynamic>) val = dec;
          } catch (_) {
            for (final f in _secretFields) {
              if (val[f] is String) val[f] = CryptoService.decrypt(val[f] as String);
            }
          }
          return MyParcelConfig.fromJson(val);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveConfig(MyParcelConfig config) async {
    var json = config.toJson();
    try {
      final enc = await _supabase.rpc('encrypt_settings_secrets', params: {
        'p_settings': json, 'p_secret_fields': _secretFields,
      });
      if (enc is Map<String, dynamic>) json = enc;
    } catch (_) {
      for (final f in _secretFields) {
        if (json[f] is String) json[f] = CryptoService.encrypt(json[f] as String);
      }
    }
    await _supabase.from('app_settings').upsert({
      'key': _settingsKey,
      'value': json,
    }, onConflict: 'key');
  }

  Future<bool> testConnection() async {
    final config = await getConfig();
    if (config == null || !config.isConfigured) return false;
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/shipments?size=1'),
        headers: {
          ..._headers(config.apiKey),
          'Accept': 'application/json;charset=utf-8',
        },
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('MyParcel testConnection failed: $e');
      return false;
    }
  }

  static const _domesticCountries = {'NL', 'BE'};
  static const _nonEuCountries = {'GB', 'UK', 'CH', 'NO', 'IS', 'LI'};

  Future<MyParcelShipmentResult> createShipment({
    required String recipientName,
    required String recipientStreet,
    required String recipientNumber,
    String? recipientNumberSuffix,
    required String recipientPostalCode,
    required String recipientCity,
    required String recipientCc,
    String? recipientEmail,
    String? recipientPhone,
    required int carrierId,
    required int weightInGrams,
    required String orderReference,
    int packageType = 1,
    int insuranceAmountCents = 0,
    bool onlyRecipient = false,
    bool signature = false,
    bool returnIfNotHome = false,
    bool largeFormat = false,
  }) async {
    final config = await getConfig();
    if (config == null || !config.isConfigured) {
      throw Exception('MyParcel niet geconfigureerd');
    }

    final cc = recipientCc.toUpperCase();
    final isDomestic = _domesticCountries.contains(cc);
    final isNonEu = _nonEuCountries.contains(cc);

    final options = <String, dynamic>{
      'package_type': packageType,
      'label_description': orderReference,
      if (onlyRecipient) 'only_recipient': 1,
      if (signature) 'signature': 1,
      if (returnIfNotHome) 'return': 1,
      if (largeFormat) 'large_format': 1,
      if (insuranceAmountCents > 0) 'insurance': {
        'amount': insuranceAmountCents,
        'currency': 'EUR',
      },
    };

    final recipient = <String, dynamic>{
      'cc': cc,
      'city': recipientCity,
      'person': recipientName,
      'email': ?recipientEmail,
      'phone': ?recipientPhone,
    };

    if (isDomestic) {
      recipient['street'] = recipientStreet;
      recipient['number'] = recipientNumber;
      if (recipientNumberSuffix != null && recipientNumberSuffix.isNotEmpty) {
        recipient['number_suffix'] = recipientNumberSuffix;
      }
      recipient['postal_code'] = recipientPostalCode.replaceAll(' ', '');
    } else {
      final fullStreet = recipientNumber.isNotEmpty
          ? '$recipientStreet $recipientNumber${recipientNumberSuffix ?? ""}'
          : recipientStreet;
      recipient['street'] = fullStreet;
      if (recipientPostalCode.isNotEmpty) {
        recipient['postal_code'] = recipientPostalCode;
      }
    }

    final shipment = <String, dynamic>{
      'reference_identifier': orderReference,
      'recipient': recipient,
      'options': options,
      'physical_properties': { 'weight': weightInGrams },
      'carrier': carrierId,
    };

    if (isNonEu) {
      shipment['customs_declaration'] = {
        'contents': 1,
        'invoice': orderReference,
        'weight': weightInGrams,
        'items': [
          {
            'description': 'Zeilproducten / Sailing products',
            'amount': 1,
            'weight': weightInGrams,
            'item_value': { 'amount': 0, 'currency': 'EUR' },
            'classification': '6306',
            'country': 'NL',
          },
        ],
      };
    }

    final body = jsonEncode({ 'data': { 'shipments': [shipment] } });

    final resp = await http.post(
      Uri.parse('$_baseUrl/shipments'),
      headers: {
        ..._headers(config.apiKey),
        'Content-Type': 'application/vnd.shipment+json;charset=utf-8;version=1.1',
      },
      body: body,
    ).timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      final errBody = resp.body;
      if (kDebugMode) debugPrint('MyParcel createShipment failed (${resp.statusCode}): $errBody');
      throw Exception('MyParcel fout (${resp.statusCode}): $errBody');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final ids = (json['data']?['ids'] as List?) ?? [];
    if (ids.isEmpty) throw Exception('Geen shipment ID ontvangen');

    final shipmentId = (ids.first['id'] as num).toInt();

    await Future.delayed(const Duration(seconds: 2));
    final details = await getShipment(shipmentId);

    return MyParcelShipmentResult(
      shipmentId: shipmentId,
      barcode: details?['barcode'] as String?,
      trackTraceUrl: _buildTrackUrl(
        details?['barcode'] as String?,
        recipientPostalCode,
        recipientCc,
      ),
    );
  }

  Future<Map<String, dynamic>?> getShipment(int shipmentId) async {
    final config = await getConfig();
    if (config == null || !config.isConfigured) return null;

    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/shipments/$shipmentId'),
        headers: {
          ..._headers(config.apiKey),
          'Accept': 'application/json;charset=utf-8',
        },
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) return null;

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final shipments = json['data']?['shipments'] as List?;
      if (shipments == null || shipments.isEmpty) return null;
      return shipments.first as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) debugPrint('MyParcel getShipment failed: $e');
      return null;
    }
  }

  Future<Uint8List?> getLabel(int shipmentId, {String format = 'A4'}) async {
    final config = await getConfig();
    if (config == null || !config.isConfigured) return null;

    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/shipment_labels/$shipmentId?format=$format&positions=1'),
        headers: {
          ..._headers(config.apiKey),
          'Accept': 'application/pdf',
        },
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200 && resp.bodyBytes.length > 100) {
        return resp.bodyBytes;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MyParcel getLabel failed: $e');
    }
    return null;
  }

  Future<bool> deleteShipment(int shipmentId) async {
    final config = await getConfig();
    if (config == null || !config.isConfigured) return false;

    try {
      final resp = await http.delete(
        Uri.parse('$_baseUrl/shipments/$shipmentId'),
        headers: {
          ..._headers(config.apiKey),
          'Content-Type': 'application/json;charset=utf-8',
        },
      ).timeout(const Duration(seconds: 15));
      return resp.statusCode == 204 || resp.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('MyParcel deleteShipment failed: $e');
      return false;
    }
  }

  Future<MyParcelShipmentResult> createReturnShipment({
    required int parentShipmentId,
    required String recipientEmail,
    required String recipientName,
    required int carrierId,
    int packageType = 1,
    int insuranceAmountCents = 0,
    bool signature = false,
  }) async {
    final config = await getConfig();
    if (config == null || !config.isConfigured) {
      throw Exception('MyParcel niet geconfigureerd');
    }

    final options = <String, dynamic>{
      'package_type': packageType,
      'only_recipient': 0,
      'return': 0,
      if (signature) 'signature': 1,
      if (insuranceAmountCents > 0) 'insurance': {
        'amount': insuranceAmountCents,
        'currency': 'EUR',
      },
    };

    final body = jsonEncode({
      'data': {
        'return_shipments': [
          {
            'parent': parentShipmentId,
            'carrier': carrierId,
            'email': recipientEmail,
            'name': recipientName,
            'options': options,
          },
        ],
      },
    });

    final resp = await http.post(
      Uri.parse('$_baseUrl/shipments'),
      headers: {
        ..._headers(config.apiKey),
        'Content-Type': 'application/vnd.return_shipment+json;charset=utf-8;version=1.1',
      },
      body: body,
    ).timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw Exception('MyParcel retour fout (${resp.statusCode}): ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final ids = (json['data']?['ids'] as List?) ?? [];
    if (ids.isEmpty) throw Exception('Geen retour shipment ID ontvangen');

    final shipmentId = (ids.first['id'] as num).toInt();
    await Future.delayed(const Duration(seconds: 2));
    final details = await getShipment(shipmentId);

    return MyParcelShipmentResult(
      shipmentId: shipmentId,
      barcode: details?['barcode'] as String?,
      trackTraceUrl: null,
    );
  }

  Future<MyParcelShipmentResult> createUnrelatedReturnShipment({
    required String recipientEmail,
    required String recipientName,
    required int carrierId,
    int packageType = 1,
    String? labelDescription,
  }) async {
    final config = await getConfig();
    if (config == null || !config.isConfigured) {
      throw Exception('MyParcel niet geconfigureerd');
    }

    final body = jsonEncode({
      'data': {
        'return_shipments': [
          {
            'carrier': carrierId,
            'email': recipientEmail,
            'name': recipientName,
            'options': {
              'package_type': packageType,
              'label_description': ?labelDescription,
            },
          },
        ],
      },
    });

    final resp = await http.post(
      Uri.parse('$_baseUrl/shipments'),
      headers: {
        ..._headers(config.apiKey),
        'Content-Type': 'application/vnd.unrelated_return_shipment+json;charset=utf-8;version=1.1',
      },
      body: body,
    ).timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw Exception('MyParcel retour fout (${resp.statusCode}): ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final ids = (json['data']?['ids'] as List?) ?? [];
    if (ids.isEmpty) throw Exception('Geen retour shipment ID ontvangen');

    return MyParcelShipmentResult(
      shipmentId: (ids.first['id'] as num).toInt(),
    );
  }

  static const shipmentStatuses = <int, String>{
    1: 'Concept',
    2: 'Geregistreerd',
    3: 'Overgedragen aan vervoerder',
    4: 'Sortering',
    5: 'Onderweg (distributie)',
    6: 'Douane',
    7: 'Bezorgd',
    8: 'Klaar voor ophalen',
    9: 'Pakket opgehaald',
    10: 'Retourzending klaar voor ophalen',
    11: 'Retourzending opgehaald',
    12: 'Afgedrukt (brief)',
    13: 'Gecrediteerd',
    14: 'Afgedrukt (digitale postzegel)',
    15: 'Afgedrukt (extern)',
    16: 'Verlopen',
    17: 'Geannuleerd',
    18: 'Afgedrukt (niet gevolgd)',
    19: 'Bezorgd op afgesproken locatie',
    30: 'Inactief — concept',
    31: 'Inactief — geregistreerd',
    32: 'Inactief — overgedragen',
    33: 'Inactief — sortering',
    34: 'Inactief — distributie',
    35: 'Inactief — douane',
    36: 'Inactief — bezorgd',
    37: 'Inactief — klaar voor ophalen',
    38: 'Inactief — opgehaald',
  };

  Future<List<Map<String, dynamic>>> getShipments({
    int page = 1,
    int size = 50,
    String? statusFilter,
    String? query,
  }) async {
    final config = await getConfig();
    if (config == null || !config.isConfigured) return [];

    try {
      final params = <String, String>{
        'page': '$page',
        'size': '$size',
        'order': 'DESC',
        'sort': 'created',
      };
      if (statusFilter != null && statusFilter.isNotEmpty) params['status'] = statusFilter;
      if (query != null && query.isNotEmpty) params['q'] = query;

      final uri = Uri.parse('$_baseUrl/shipments').replace(queryParameters: params);
      final resp = await http.get(
        uri,
        headers: {
          ..._headers(config.apiKey),
          'Accept': 'application/json;charset=utf-8',
        },
      ).timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) return [];

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>?;
      if (data == null) return [];

      if (data.containsKey('shipments')) {
        return (data['shipments'] as List).cast<Map<String, dynamic>>();
      }
      if (data.containsKey('search_results')) {
        final sr = data['search_results'] as Map<String, dynamic>;
        return (sr['shipments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      }
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('MyParcel getShipments failed: $e');
      return [];
    }
  }

  String? _buildTrackUrl(String? barcode, String postalCode, String cc) {
    if (barcode == null || barcode.isEmpty) return null;
    final pc = postalCode.replaceAll(' ', '');
    return 'https://myparcel.me/track-trace/$barcode/$pc/${cc.toUpperCase()}';
  }
}
