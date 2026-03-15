import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'order_service.dart';
import 'crypto_service.dart';

class BuckarooConfig {
  final String websiteKey;
  final String secretKey;
  final bool testMode;

  const BuckarooConfig({
    required this.websiteKey,
    required this.secretKey,
    this.testMode = true,
  });

  factory BuckarooConfig.fromJson(Map<String, dynamic> json) => BuckarooConfig(
        websiteKey: json['website_key'] as String? ?? '',
        secretKey: json['secret_key'] as String? ?? '',
        testMode: (json['test_mode'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {
        'website_key': websiteKey,
        'secret_key': secretKey,
        'test_mode': testMode,
      };

  bool get isConfigured => websiteKey.isNotEmpty && secretKey.isNotEmpty;
}

class BuckarooTransaction {
  final String transactionKey;
  final String paymentUrl;
  final String? statusCode;

  const BuckarooTransaction({
    required this.transactionKey,
    required this.paymentUrl,
    this.statusCode,
  });
}

class BuckarooService {
  static const _testUrl = 'https://testcheckout.buckaroo.nl/json';
  static const _liveUrl = 'https://checkout.buckaroo.nl/json';
  static const _settingsKey = 'payment_config';

  final _supabase = Supabase.instance.client;

  String _baseUrl(bool testMode) => testMode ? _testUrl : _liveUrl;

  static const _secretFields = ['secret_key'];

  Future<BuckarooConfig?> getConfig() async {
    try {
      final List<dynamic> rows = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', _settingsKey);
      if (rows.isEmpty) return null;
      final raw = rows.first['value'];
      if (raw is Map<String, dynamic> && raw.containsKey('buckaroo')) {
        var buc = Map<String, dynamic>.from(raw['buckaroo'] as Map<String, dynamic>);
        try {
          final dec = await _supabase.rpc('decrypt_settings_secrets', params: {
            'p_settings': buc, 'p_secret_fields': _secretFields,
          });
          if (dec is Map<String, dynamic>) buc = dec;
        } catch (_) {
          for (final f in _secretFields) {
            if (buc[f] is String) {
              final val = buc[f] as String;
              if (val.startsWith('ENC:')) {
                buc[f] = CryptoService.decrypt(val);
              }
            }
          }
        }
        return BuckarooConfig.fromJson(buc);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConfig(BuckarooConfig config) async {
    final existing = await _getRawConfig();
    var json = config.toJson();
    try {
      final enc = await _supabase.rpc('encrypt_settings_secrets', params: {
        'p_settings': json, 'p_secret_fields': _secretFields,
      });
      if (enc is Map<String, dynamic>) json = enc;
    } catch (_) {
      // Server-side encryption unavailable; store as-is (plain text) rather
      // than using local encryption that may not be decryptable elsewhere.
    }
    existing['buckaroo'] = json;
    await _supabase.from('app_settings').upsert({
      'key': _settingsKey,
      'value': existing,
    }, onConflict: 'key');
  }

  Future<String> getActiveGateway() async {
    final raw = await _getRawConfig();
    final gateways = raw['active_gateways'];
    if (gateways is List && gateways.isNotEmpty) {
      return gateways.join(',');
    }
    return raw['active_gateway'] as String? ?? 'pay_nl';
  }

  Future<Set<String>> getActiveGateways() async {
    final raw = await _getRawConfig();
    final gateways = raw['active_gateways'];
    if (gateways is List && gateways.isNotEmpty) {
      return gateways.cast<String>().toSet();
    }
    final legacy = raw['active_gateway'] as String?;
    if (legacy == null || legacy == 'none') return {};
    return {legacy};
  }

  Future<void> setActiveGateways(Set<String> gateways) async {
    final existing = await _getRawConfig();
    existing['active_gateways'] = gateways.toList();
    existing.remove('active_gateway');
    await _supabase.from('app_settings').upsert({
      'key': _settingsKey,
      'value': existing,
    }, onConflict: 'key');
  }

  Future<void> setActiveGateway(String gateway) async {
    if (gateway == 'none') {
      await setActiveGateways({});
    } else {
      await setActiveGateways({gateway});
    }
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
    if (config == null || !config.isConfigured) {
      lastTestError = 'Configuratie onvolledig. Vul alle verplichte velden in.';
      return false;
    }

    try {
      final url = '${_baseUrl(config.testMode)}/Transaction/Specification/ideal';
      final headers = _buildAuthHeaders(
        config: config,
        httpMethod: 'GET',
        requestUri: url,
        content: '',
      );
      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return true;
      lastTestError = 'HTTP ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}';
      return false;
    } catch (e) {
      lastTestError = e.toString();
      return false;
    }
  }

  String? lastTestError;

  Future<BuckarooTransaction> createTransaction({
    required Order order,
    required String returnUrl,
    String? pushUrl,
    String? serviceName,
  }) async {
    final config = await getConfig();
    if (config == null || !config.isConfigured) {
      throw Exception('Buckaroo is niet geconfigureerd. Configureer eerst de betaalinstellingen.');
    }

    final url = '${_baseUrl(config.testMode)}/Transaction';

    final body = <String, dynamic>{
      'Currency': order.valuta,
      'AmountDebit': order.totaal,
      'Invoice': order.orderNummer,
      'Description': 'Ventoz bestelling ${order.orderNummer}',
      'ReturnURL': returnUrl,
      'ReturnURLCancel': '$returnUrl?status=cancel',
      'ReturnURLError': '$returnUrl?status=error',
      'ReturnURLReject': '$returnUrl?status=reject',
      'Services': {
        'ServiceList': [
          {
            'Name': serviceName ?? 'ideal',
            'Action': 'Pay',
          }
        ],
      },
    };

    if (pushUrl != null) body['PushURL'] = pushUrl;

    final jsonBody = jsonEncode(body);
    final headers = _buildAuthHeaders(
      config: config,
      httpMethod: 'POST',
      requestUri: url,
      content: jsonBody,
    );
    headers['Content-Type'] = 'application/json';

    final response = await http.post(Uri.parse(url), headers: headers, body: jsonBody);
    final rawBody = response.body.trim();

    if (response.statusCode != 200 && response.statusCode != 201) {
      if (rawBody.isEmpty) {
        throw Exception('Buckaroo fout: HTTP ${response.statusCode} (lege response).');
      }
      try {
        final errorBody = jsonDecode(rawBody);
        final msg = errorBody['Status']?['SubCode']?['Description']
            ?? errorBody['RequestErrors']?.toString()
            ?? rawBody;
        throw Exception('Buckaroo fout: $msg');
      } on FormatException {
        throw Exception('Buckaroo fout: HTTP ${response.statusCode} — $rawBody');
      }
    }

    if (rawBody.isEmpty) {
      throw Exception('Buckaroo gaf een leeg antwoord (HTTP ${response.statusCode}).');
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(rawBody) as Map<String, dynamic>;
    } on FormatException {
      throw Exception('Buckaroo antwoord is geen geldige JSON: ${rawBody.substring(0, rawBody.length.clamp(0, 200))}');
    }

    final key = data['Key'] as String? ?? '';
    final redirectUrl = data['RequiredAction']?['RedirectURL'] as String? ?? '';
    final statusCode = data['Status']?['Code']?['Code']?.toString();

    return BuckarooTransaction(
      transactionKey: key,
      paymentUrl: redirectUrl,
      statusCode: statusCode,
    );
  }

  Future<String> getTransactionStatus(String transactionKey) async {
    final config = await getConfig();
    if (config == null || !config.isConfigured) return 'UNKNOWN';

    try {
      final url = '${_baseUrl(config.testMode)}/Transaction/Status/$transactionKey';
      final headers = _buildAuthHeaders(
        config: config,
        httpMethod: 'GET',
        requestUri: url,
        content: '',
      );
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        final data = jsonDecode(response.body.trim());
        final code = data['Status']?['Code']?['Code'];
        if (code == 190) return 'PAID';
        if (code == 490 || code == 491 || code == 492) return 'FAILED';
        if (code == 790) return 'PENDING';
        if (code == 791) return 'PENDING_PROCESSING';
        if (code == 792) return 'PENDING';
        if (code == 890 || code == 891) return 'CANCELLED';
        return 'UNKNOWN';
      }
    } catch (_) {}
    return 'UNKNOWN';
  }

  Map<String, String> _buildAuthHeaders({
    required BuckarooConfig config,
    required String httpMethod,
    required String requestUri,
    required String content,
  }) {
    final nonce = _generateNonce();
    final timeStamp = (DateTime.now().toUtc().millisecondsSinceEpoch / 1000).round().toString();

    final uri = Uri.parse(requestUri);
    final uriWithoutScheme = '${uri.host}${uri.path}';
    final encodedUri = Uri.encodeComponent(uriWithoutScheme).toLowerCase();

    String contentHash = '';
    if (content.isNotEmpty) {
      contentHash = base64Encode(md5.convert(utf8.encode(content)).bytes);
    }

    final rawSignature = '${config.websiteKey}$httpMethod$encodedUri$timeStamp$nonce$contentHash';
    final keyBytes = base64Decode(config.secretKey);
    final hmacBytes = Hmac(sha256, keyBytes).convert(utf8.encode(rawSignature)).bytes;
    final hmacHash = base64Encode(hmacBytes);

    return {
      'Authorization': 'hmac ${config.websiteKey}:$hmacHash:$nonce:$timeStamp',
      'Accept': 'application/json',
      'Culture': 'nl-NL',
    };
  }

  String _generateNonce() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(16, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
