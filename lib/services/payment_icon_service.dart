import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentIconService {
  static final PaymentIconService _instance = PaymentIconService._();
  factory PaymentIconService() => _instance;
  PaymentIconService._();

  static const _table = 'payment_icons';
  static const _payNlBase = 'https://static.pay.nl';
  final _supabase = Supabase.instance.client;

  final Map<String, Uint8List?> _pngCache = {};
  final Map<String, String?> _svgCache = {};
  bool _tableReady = false;
  bool _allLoaded = false;

  Future<void> _ensureTable() async {
    if (_tableReady) return;
    try {
      await _supabase.from(_table).select('method_key').limit(1);
      _tableReady = true;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('does not exist') || msg.contains('42p01')) {
        try {
          await _supabase.rpc('exec_sql', params: {
            'query': '''
              CREATE TABLE IF NOT EXISTS payment_icons (
                method_key TEXT PRIMARY KEY,
                icon_data  TEXT NOT NULL,
                format     TEXT NOT NULL DEFAULT 'svg',
                updated_at TIMESTAMPTZ DEFAULT now()
              );
              ALTER TABLE payment_icons ENABLE ROW LEVEL SECURITY;
              DO \$\$ BEGIN
                CREATE POLICY payment_icons_read ON payment_icons
                  FOR SELECT TO authenticated USING (true);
              EXCEPTION WHEN duplicate_object THEN NULL; END \$\$;
              DO \$\$ BEGIN
                CREATE POLICY payment_icons_write ON payment_icons
                  FOR ALL TO authenticated USING (is_ventoz_admin()) WITH CHECK (is_ventoz_admin());
              EXCEPTION WHEN duplicate_object THEN NULL; END \$\$;
            ''',
          });
        } catch (_) {}
      }
      _tableReady = true;
    }
  }

  String? getSvgSync(String methodName) {
    final key = normalizeKey(methodName);
    if (_svgCache.containsKey(key)) return _svgCache[key];
    for (final alt in _altNames.entries) {
      if (alt.key == key && _svgCache.containsKey(alt.value)) return _svgCache[alt.value];
      if (alt.value == key && _svgCache.containsKey(alt.key)) return _svgCache[alt.key];
    }
    return null;
  }

  Uint8List? getPngSync(String methodName) {
    final key = normalizeKey(methodName);
    if (_pngCache.containsKey(key)) return _pngCache[key];
    for (final alt in _altNames.entries) {
      if (alt.key == key && _pngCache.containsKey(alt.value)) return _pngCache[alt.value];
      if (alt.value == key && _pngCache.containsKey(alt.key)) return _pngCache[alt.key];
    }
    return null;
  }

  Future<void> loadAll({bool force = false}) async {
    if (_allLoaded && !force) return;
    await _ensureTable();
    try {
      final rows = await _supabase.from(_table).select('method_key, icon_data, format');
      for (final row in rows) {
        final key = row['method_key'] as String;
        final data = row['icon_data'] as String?;
        final fmt = row['format'] as String? ?? 'svg';
        if (data == null || data.isEmpty) continue;

        if (fmt == 'png') {
          try { _pngCache[key] = base64Decode(data); } catch (_) {}
        } else {
          _svgCache[key] = data;
        }
      }
      _allLoaded = true;
    } catch (e) {
      if (kDebugMode) debugPrint('PaymentIconService.loadAll failed: $e');
    }
  }

  Future<void> _store(String key, String data, String format) async {
    await _ensureTable();
    try {
      await _supabase.from(_table).upsert({
        'method_key': key,
        'icon_data': data,
        'format': format,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'method_key');
    } catch (e) {
      if (kDebugMode) debugPrint('PaymentIconService._store($key) failed: $e');
    }
  }

  Future<void> seedFromPayNl(List<Map<String, dynamic>> checkoutOptions) async {
    await _ensureTable();

    Set<String> existing = {};
    try {
      final rows = await _supabase.from(_table).select('method_key');
      existing = rows.map<String>((r) => r['method_key'] as String).toSet();
    } catch (_) {}

    final toFetch = <String, String>{};

    for (final opt in checkoutOptions) {
      _collectSvgUrl(opt['name'] as String?, opt['image'] as String?, existing, toFetch);
      final methods = opt['paymentMethods'] as List? ?? [];
      for (final pm in methods) {
        if (pm is! Map<String, dynamic>) continue;
        _collectSvgUrl(pm['name'] as String?, pm['image'] as String?, existing, toFetch);
      }
    }

    for (final entry in _pngFallbackUrls.entries) {
      if (!existing.contains(entry.key) && !toFetch.containsKey(entry.key)) {
        toFetch[entry.key] = 'PNG:${entry.value}';
      }
    }

    int stored = 0;
    for (final entry in toFetch.entries) {
      try {
        if (entry.value.startsWith('PNG:')) {
          final pngUrl = entry.value.substring(4);
          final bytes = await _downloadBytes(pngUrl);
          if (bytes != null) {
            await _store(entry.key, base64Encode(bytes), 'png');
            _pngCache[entry.key] = bytes;
            stored++;
          }
        } else {
          final svg = await _downloadSvg(entry.value);
          if (svg != null) {
            await _store(entry.key, svg, 'svg');
            _svgCache[entry.key] = svg;
            stored++;
          }
        }
      } catch (e) {
        debugPrint('Seed icon ${entry.key} failed: $e');
      }
    }

    if (stored > 0) {
      if (kDebugMode) debugPrint('PaymentIconService: seeded $stored icons');
    }
  }

  void _collectSvgUrl(String? name, String? imagePath, Set<String> existing, Map<String, String> toFetch) {
    if (name == null || name.isEmpty) return;
    final key = normalizeKey(name);
    if (existing.contains(key) || toFetch.containsKey(key)) return;
    if (imagePath != null && imagePath.isNotEmpty) {
      final url = imagePath.startsWith('http') ? imagePath : '$_payNlBase$imagePath';
      toFetch[key] = url;
    }
  }

  static Future<String?> _downloadSvg(String url) async {
    try {
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200 && resp.body.contains('<svg')) return resp.body;
    } catch (_) {}
    return null;
  }

  static Future<Uint8List?> _downloadBytes(String url) async {
    try {
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200 && resp.bodyBytes.length > 100) return resp.bodyBytes;
    } catch (_) {}
    return null;
  }

  static String normalizeKey(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static const _altNames = <String, String>{
    'epsuberweisung': 'eps',
    'overboekingsct': 'overboeking',
    'weropayment': 'wero',
    'vippspayment': 'vipps',
    'kbccbc': 'kbccbcbetaalknop',
    'creditdebitcard': 'creditcard',
  };

  static const _pngFallbackUrls = <String, String>{
    'ideal': 'https://raw.githubusercontent.com/mpay24/payment-logos/master/logos/color/ideal.png',
    'eps': 'https://raw.githubusercontent.com/mpay24/payment-logos/master/logos/color/eps.png',
    'giropay': 'https://raw.githubusercontent.com/mpay24/payment-logos/master/logos/color/giropay.png',
    'klarna': 'https://raw.githubusercontent.com/mpay24/payment-logos/master/logos/color/klarna.png',
    'maestro': 'https://raw.githubusercontent.com/mpay24/payment-logos/master/logos/color/maestro.png',
    'mastercard': 'https://raw.githubusercontent.com/mpay24/payment-logos/master/logos/color/mastercard.png',
    'paypal': 'https://raw.githubusercontent.com/mpay24/payment-logos/master/logos/color/paypal.png',
    'visa': 'https://raw.githubusercontent.com/mpay24/payment-logos/master/logos/color/visa.png',
  };
}
