import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'order_service.dart';
import 'crypto_service.dart';

class PaymentConfig {
  final String serviceId;
  final String serviceSecret;
  final String atCode;
  final String apiToken;
  final bool testMode;

  const PaymentConfig({
    required this.serviceId,
    this.serviceSecret = '',
    this.atCode = '',
    required this.apiToken,
    this.testMode = true,
  });

  factory PaymentConfig.fromJson(Map<String, dynamic> json) => PaymentConfig(
    serviceId: json['service_id'] as String? ?? '',
    serviceSecret: json['service_secret'] as String? ?? '',
    atCode: json['at_code'] as String? ?? '',
    apiToken: json['api_token'] as String? ?? '',
    testMode: (json['test_mode'] as bool?) ?? true,
  );

  Map<String, dynamic> toJson() => {
    'service_id': serviceId,
    'service_secret': serviceSecret,
    'at_code': atCode,
    'api_token': apiToken,
    'test_mode': testMode,
  };

  bool get isConfigured =>
      serviceId.isNotEmpty && apiToken.isNotEmpty && atCode.isNotEmpty;
}

class PayNlTransaction {
  final String transactionId;
  final String paymentUrl;
  final String? statusUrl;

  const PayNlTransaction({
    required this.transactionId,
    required this.paymentUrl,
    this.statusUrl,
  });
}

class PayNlService {
  static const _connectUrl = 'https://connect.pay.nl/v1';
  static const _restUrl = 'https://rest.pay.nl/v2';
  static const _settingsKey = 'payment_config';

  final _supabase = Supabase.instance.client;

  static const _secretFields = ['service_secret', 'api_token'];

  bool hasUndecryptableSecrets = false;

  Future<PaymentConfig?> getConfig() async {
    hasUndecryptableSecrets = false;
    try {
      final List<dynamic> rows = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', _settingsKey);
      if (rows.isEmpty) return null;
      final raw = rows.first['value'];
      if (raw is Map<String, dynamic> && raw.containsKey('pay_nl')) {
        var payNl = Map<String, dynamic>.from(raw['pay_nl'] as Map<String, dynamic>);
        bool decrypted = false;
        try {
          final dec = await _supabase.rpc('decrypt_settings_secrets', params: {
            'p_settings': payNl, 'p_secret_fields': _secretFields,
          });
          if (dec is Map<String, dynamic>) { payNl = dec; decrypted = true; }
        } catch (_) {}
        if (!decrypted) {
          for (final f in _secretFields) {
            if (payNl[f] is String) {
              final val = payNl[f] as String;
              if (val.startsWith('ENC:')) {
                final result = CryptoService.decrypt(val);
                if (result.startsWith('ENC:')) {
                  payNl[f] = '';
                  hasUndecryptableSecrets = true;
                } else {
                  payNl[f] = result;
                }
              }
            }
          }
        }
        return PaymentConfig.fromJson(payNl);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConfig(PaymentConfig config) async {
    final existing = await _getRawConfig();
    final json = config.toJson();
    existing['pay_nl'] = json;
    await _supabase.from('app_settings').upsert({
      'key': _settingsKey,
      'value': existing,
    }, onConflict: 'key');
  }

  Future<Map<String, dynamic>> _getRawConfig() async {
    try {
      final List<dynamic> rows = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', _settingsKey);
      if (rows.isNotEmpty) {
        final raw = rows.first['value'];
        if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
      }
    } catch (_) {}
    return {};
  }

  Future<bool> testConnection() async {
    final config = await getConfig();
    if (config == null) {
      lastTestError = 'Geen Pay.nl configuratie gevonden. Sla eerst je instellingen op.';
      return false;
    }
    if (!config.isConfigured) {
      final missing = <String>[];
      if (config.serviceId.isEmpty) missing.add('Service ID');
      if (config.atCode.isEmpty) missing.add('AT-code');
      if (config.apiToken.isEmpty) missing.add('API token');
      lastTestError = 'Configuratie onvolledig: ${missing.join(', ')} ontbreekt.';
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse('$_restUrl/services/${config.serviceId}'),
        headers: _merchantHeaders(config),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return true;
      if (response.statusCode == 401 || response.statusCode == 403) {
        lastTestError = 'Authenticatie mislukt (HTTP ${response.statusCode}). Controleer AT-code en API token.';
      } else {
        lastTestError = 'HTTP ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}';
      }
      return false;
    } on TimeoutException {
      lastTestError = 'Verbinding time-out na 15 seconden. Controleer je internetverbinding.';
      return false;
    } catch (e) {
      lastTestError = 'Verbindingsfout: $e';
      return false;
    }
  }

  String? lastTestError;

  Future<PayNlTransaction> createTransaction({
    required Order order,
    required String returnUrl,
    String? exchangeUrl,
    int? paymentOptionId,
  }) async {
    final config = await getConfig();
    if (config == null || !config.isConfigured) {
      throw Exception('Pay.nl is niet geconfigureerd. Configureer eerst de betaalinstellingen.');
    }

    final body = <String, dynamic>{
      'serviceId': config.serviceId,
      'amount': {
        'value': (order.totaal * 100).round(),
        'currency': order.valuta,
      },
      'returnUrl': returnUrl,
      'reference': order.orderNummer,
      'description': 'Ventoz bestelling ${order.orderNummer}',
      'optimize': {
        'flow': 'fastCheckout',
        'shippingAddress': false,
        'billingAddress': false,
      },
      'order': {
        'countryCode': order.landCode,
        'deliveryDate': DateTime.now().add(const Duration(days: 7)).toIso8601String().split('T')[0],
        'invoiceDate': DateTime.now().toIso8601String().split('T')[0],
        'deliveryAddress': {
          'streetName': order.adres ?? '',
          'zipCode': order.postcode ?? '',
          'city': order.woonplaats ?? '',
          'countryCode': order.landCode,
        },
        'products': order.regels.map((r) => <String, dynamic>{
          'id': r.productId,
          'description': r.productNaam,
          'price': {'value': (r.stukprijs * 100).round()},
          'quantity': r.aantal,
          'vatPercentage': order.btwPercentage,
        }).toList(),
      },
    };
    if (paymentOptionId != null) {
      body['paymentMethod'] = {'id': paymentOptionId};
    }
    if (exchangeUrl != null) body['exchangeUrl'] = exchangeUrl;
    if (config.testMode) {
      body['integration'] = {'test': true};
    }

    final response = await http.post(
      Uri.parse('$_connectUrl/orders'),
      headers: {
        ..._merchantHeaders(config),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final rawBody = response.body.trim();

    if (response.statusCode != 200 && response.statusCode != 201) {
      if (rawBody.isEmpty) {
        throw Exception('Pay.nl fout: HTTP ${response.statusCode} (lege response). Controleer je SL-code, AT-code en API token.');
      }
      try {
        final errorBody = jsonDecode(rawBody);
        final msg = errorBody['message']
            ?? errorBody['detail']
            ?? (errorBody['violations'] is List ? (errorBody['violations'] as List).map((v) => v['description'] ?? v).join('; ') : null)
            ?? rawBody;
        throw Exception('Pay.nl fout: $msg');
      } on FormatException {
        throw Exception('Pay.nl fout: HTTP ${response.statusCode} — $rawBody');
      }
    }

    if (rawBody.isEmpty) {
      throw Exception('Pay.nl gaf een leeg antwoord (HTTP ${response.statusCode}). Controleer of je service-ID correct is.');
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(rawBody) as Map<String, dynamic>;
    } on FormatException {
      throw Exception('Pay.nl antwoord is geen geldige JSON: ${rawBody.substring(0, rawBody.length.clamp(0, 200))}');
    }

    return PayNlTransaction(
      transactionId: data['id'] as String? ?? '',
      paymentUrl: data['links']?['redirect'] as String? ?? data['links']?['checkout'] as String? ?? '',
      statusUrl: data['links']?['status'] as String?,
    );
  }

  Future<String> getTransactionStatus(String transactionId) async {
    final config = await getConfig();
    if (config == null || !config.isConfigured) return 'UNKNOWN';

    try {
      final response = await http.get(
        Uri.parse('$_connectUrl/orders/$transactionId/status'),
        headers: _merchantHeaders(config),
      );

      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        final data = jsonDecode(response.body.trim());
        final status = data['status']?['action'] as String?;
        return status ?? 'UNKNOWN';
      }
    } catch (_) {}
    return 'UNKNOWN';
  }

  /// Fetch full service config including checkoutOptions, checkoutSequence, etc.
  Future<Map<String, dynamic>?> getServiceConfig() async {
    final config = await getConfig();
    if (config == null || !config.isConfigured) return null;

    for (final auth in [
      if (config.serviceSecret.isNotEmpty)
        <String, String>{
          'Authorization': 'Basic ${base64Encode(utf8.encode('${config.serviceId}:${config.serviceSecret}'))}',
          'Accept': 'application/json',
        },
      _merchantHeaders(config),
    ]) {
      try {
        final response = await http.get(
          Uri.parse('$_restUrl/services/config'),
          headers: auth,
        );
        if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
          final data = jsonDecode(response.body.trim());
          if (data is Map<String, dynamic> && data.containsKey('checkoutOptions')) {
            return data;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// Convenience: returns just checkoutOptions list.
  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    final svcConfig = await getServiceConfig();
    if (svcConfig == null) return [];
    final options = svcConfig['checkoutOptions'];
    if (options is List && options.isNotEmpty) {
      return options.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Pay.nl API auth: AT-code + API token
  Map<String, String> _merchantHeaders(PaymentConfig config) => {
    'Authorization': 'Basic ${base64Encode(utf8.encode('${config.atCode}:${config.apiToken}'))}',
    'Accept': 'application/json',
  };
}
