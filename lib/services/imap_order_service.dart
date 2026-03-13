import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'crypto_service.dart';
import 'mime_decoder.dart';
import 'parsers/order_email_parser.dart';

enum SalesChannel { jew, ebay, bol, amazon }

extension SalesChannelExt on SalesChannel {
  String get label => switch (this) {
    SalesChannel.jew => 'Webshop',
    SalesChannel.ebay => 'eBay',
    SalesChannel.bol => 'Bol.com',
    SalesChannel.amazon => 'Amazon',
  };

  String get icon => switch (this) {
    SalesChannel.jew => '🌐',
    SalesChannel.ebay => '🏷️',
    SalesChannel.bol => '📦',
    SalesChannel.amazon => '📦',
  };
}

class ImapSettings {
  final String host;
  final int port;
  final String username;
  final String password;
  final bool enableJew;
  final bool enableEbay;
  final bool enableBol;
  final bool enableAmazon;
  final int lastFetchedUid;

  const ImapSettings({
    this.host = '',
    this.port = 993,
    this.username = '',
    this.password = '',
    this.enableJew = true,
    this.enableEbay = true,
    this.enableBol = true,
    this.enableAmazon = true,
    this.lastFetchedUid = 0,
  });

  bool get isConfigured =>
      host.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  factory ImapSettings.fromJson(Map<String, dynamic> json) => ImapSettings(
    host: (json['host'] as String?) ?? '',
    port: (json['port'] as int?) ?? 993,
    username: (json['username'] as String?) ?? '',
    password: (json['password'] as String?) ?? '',
    enableJew: (json['enable_jew'] as bool?) ?? true,
    enableEbay: (json['enable_ebay'] as bool?) ?? true,
    enableBol: (json['enable_bol'] as bool?) ?? true,
    enableAmazon: (json['enable_amazon'] as bool?) ?? true,
    lastFetchedUid: (json['last_fetched_uid'] as int?) ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'username': username,
    'password': password,
    'enable_jew': enableJew,
    'enable_ebay': enableEbay,
    'enable_bol': enableBol,
    'enable_amazon': enableAmazon,
    'last_fetched_uid': lastFetchedUid,
  };

  ImapSettings copyWith({
    String? host, int? port, String? username, String? password,
    bool? enableJew, bool? enableEbay, bool? enableBol, bool? enableAmazon,
    int? lastFetchedUid,
  }) => ImapSettings(
    host: host ?? this.host,
    port: port ?? this.port,
    username: username ?? this.username,
    password: password ?? this.password,
    enableJew: enableJew ?? this.enableJew,
    enableEbay: enableEbay ?? this.enableEbay,
    enableBol: enableBol ?? this.enableBol,
    enableAmazon: enableAmazon ?? this.enableAmazon,
    lastFetchedUid: lastFetchedUid ?? this.lastFetchedUid,
  );
}

class ImapOrderService {
  final _client = Supabase.instance.client;
  static const _tableName = 'app_settings';
  static const _settingKey = 'imap_order_config';
  static const _secretFields = ['password'];

  Future<ImapSettings?> loadSettings() async {
    try {
      final List<dynamic> response = await _client
          .from(_tableName)
          .select()
          .eq('key', _settingKey);
      if (response.isEmpty) return null;
      final row = response.first as Map<String, dynamic>;
      var value = row['value'] as Map<String, dynamic>;

      try {
        final decrypted = await _client.rpc('decrypt_settings_secrets', params: {
          'p_settings': value,
          'p_secret_fields': _secretFields,
        });
        if (decrypted is Map<String, dynamic>) value = decrypted;
      } catch (_) {
        value = _decryptFallback(value);
      }

      return ImapSettings.fromJson(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSettings(ImapSettings settings) async {
    var json = settings.toJson();

    try {
      final encrypted = await _client.rpc('encrypt_settings_secrets', params: {
        'p_settings': json,
        'p_secret_fields': _secretFields,
      });
      if (encrypted is Map<String, dynamic>) json = encrypted;
    } catch (_) {
      json = _encryptFallback(json);
    }

    await _client.from(_tableName).upsert({
      'key': _settingKey,
      'value': json,
    }, onConflict: 'key');
  }

  Future<void> _updateLastUid(int uid) async {
    final settings = await loadSettings();
    if (settings == null) return;
    await saveSettings(settings.copyWith(lastFetchedUid: uid));
  }

  Map<String, dynamic> _decryptFallback(Map<String, dynamic> json) {
    final result = Map<String, dynamic>.from(json);
    for (final f in _secretFields) {
      if (result[f] is String) result[f] = CryptoService.decrypt(result[f] as String);
    }
    return result;
  }

  Map<String, dynamic> _encryptFallback(Map<String, dynamic> json) {
    final result = Map<String, dynamic>.from(json);
    for (final f in _secretFields) {
      if (result[f] is String) result[f] = CryptoService.encrypt(result[f] as String);
    }
    return result;
  }

  Future<String> testConnection(ImapSettings settings) async {
    _ImapConnection? conn;
    try {
      conn = await _ImapConnection.connect(settings.host, settings.port, timeout: const Duration(seconds: 10));

      await conn.sendCommand('a001 LOGIN "${_escape(settings.username)}" "${_escape(settings.password)}"');
      final loginResp = await conn.readResponse();
      if (!loginResp.contains('a001 OK')) {
        return 'Login mislukt: controleer gebruikersnaam en wachtwoord';
      }

      await conn.sendCommand('a002 SELECT INBOX');
      final selectResp = await conn.readResponse();
      if (!selectResp.contains('a002 OK')) return 'Kan INBOX niet openen';

      final existsMatch = RegExp(r'(\d+) EXISTS').firstMatch(selectResp);
      final count = existsMatch?.group(1) ?? '?';

      await conn.sendCommand('a003 LOGOUT');
      try { await conn.readResponse(); } catch (_) {}

      return 'Verbinding geslaagd! INBOX bevat $count berichten.';
    } catch (e) {
      return 'Verbindingsfout: $e';
    } finally {
      conn?.destroy();
    }
  }

  Future<ImportResult> fetchNewOrders(ImapSettings settings) async {
    final result = ImportResult();
    _ImapConnection? conn;

    try {
      conn = await _ImapConnection.connect(settings.host, settings.port);

      await conn.sendCommand('a001 LOGIN "${_escape(settings.username)}" "${_escape(settings.password)}"');
      final loginResp = await conn.readResponse();
      if (!loginResp.contains('a001 OK')) {
        result.error = 'Login mislukt';
        return result;
      }

      await conn.sendCommand('a002 SELECT INBOX');
      final selectResp = await conn.readResponse();
      if (!selectResp.contains('a002 OK')) {
        result.error = 'Kan INBOX niet openen';
        return result;
      }

      final existsMatch = RegExp(r'(\d+) EXISTS').firstMatch(selectResp);
      final totalMessages = int.tryParse(existsMatch?.group(1) ?? '0') ?? 0;
      if (totalMessages == 0) return result;

      final sinceDate = DateTime(2026, 1, 1);
      final months = ['', 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final since = '${sinceDate.day}-${months[sinceDate.month]}-${sinceDate.year}';

      final searchQuery = settings.lastFetchedUid > 0
          ? 'a003 UID SEARCH SINCE $since UID ${settings.lastFetchedUid + 1}:*'
          : 'a003 UID SEARCH SINCE $since';
      await conn.sendCommand(searchQuery);
      final searchResp = await conn.readResponse();

      final searchLine = searchResp.split('\n').firstWhere(
        (l) => l.startsWith('* SEARCH'), orElse: () => '',
      );
      if (searchLine.isEmpty) return result;

      final uids = RegExp(r'\d+')
          .allMatches(searchLine.replaceFirst('* SEARCH', ''))
          .map((m) => int.parse(m.group(0)!))
          .toList()
        ..sort();

      if (uids.isEmpty) return result;

      result.scanned = uids.length;
      if (kDebugMode) debugPrint('IMAP: ${uids.length} emails gevonden sinds 1-Jan-2026');
      int highestUid = settings.lastFetchedUid;
      int skipped = 0;

      for (final uid in uids) {
        try {
          await conn.sendCommand('f$uid UID FETCH $uid BODY[]');
          final fetchResp = await conn.readResponse(timeout: const Duration(seconds: 15));

          final rawBody = _extractFetchBody(fetchResp);
          final mime = MimeDecoder.decode(rawBody);

          final fromRaw = mime.headers['from'] ?? _extractHeader(rawBody, 'From');
          final subjectRaw = mime.headers['subject'] ?? _extractHeader(rawBody, 'Subject');
          final dateRaw = mime.headers['date'] ?? _extractHeader(rawBody, 'Date');
          final from = MimeDecoder.decodeHeaderValue(fromRaw);
          final subject = MimeDecoder.decodeHeaderValue(subjectRaw);
          final body = mime.bestBody;
          final emailDate = _parseEmailDate(dateRaw);

          final payment = OrderEmailParserRegistry.tryParsePayment(
            from: from,
            subject: subject,
            bodyHtml: body,
          );

          if (payment != null) {
            final updated = await _processPaymentConfirmation(payment);
            if (updated) {
              result.paymentsConfirmed++;
            }
          } else {
            var parsed = OrderEmailParserRegistry.tryParse(
              from: from,
              subject: subject,
              bodyHtml: body,
              settings: settings,
            );
            if (parsed != null && parsed.orderDate == null && emailDate != null) {
              parsed = ParsedOrder(
                channel: parsed.channel,
                externalOrderId: parsed.externalOrderId,
                customerName: parsed.customerName,
                customerEmail: parsed.customerEmail,
                customerPhone: parsed.customerPhone,
                address: parsed.address,
                postcode: parsed.postcode,
                city: parsed.city,
                countryCode: parsed.countryCode,
                subtotal: parsed.subtotal,
                taxAmount: parsed.taxAmount,
                shippingCost: parsed.shippingCost,
                total: parsed.total,
                currency: parsed.currency,
                items: parsed.items,
                orderDate: emailDate,
              );
            }

            if (parsed != null) {
              final saved = await _saveOrder(parsed);
              if (saved) {
                result.imported++;
                result.perChannel[parsed.channel] = (result.perChannel[parsed.channel] ?? 0) + 1;
              } else {
                result.duplicates++;
              }
            } else {
              skipped++;
            }
          }

          if (uid > highestUid) highestUid = uid;
        } catch (e) {
          if (kDebugMode) debugPrint('IMAP: Error UID $uid: $e');
          result.errors++;
        }
      }

      if (kDebugMode) debugPrint('IMAP: $skipped emails overgeslagen (geen parser match)');

      if (highestUid > settings.lastFetchedUid) {
        await _updateLastUid(highestUid);
      }

      await conn.sendCommand('a099 LOGOUT');
      try { await conn.readResponse(); } catch (_) {}

      final markedShipped = await markOldOrdersAsShipped();
      if (markedShipped > 0) {
        result.markedShipped = markedShipped;
      }
    } catch (e) {
      result.error = 'IMAP-fout: $e';
    } finally {
      conn?.destroy();
    }

    return result;
  }

  Future<bool> _saveOrder(ParsedOrder parsed) async {
    final existing = await _client.from('orders')
        .select('id')
        .eq('betaal_referentie', '${parsed.channel.name}:${parsed.externalOrderId}')
        .maybeSingle();
    if (existing != null) return false;

    final orderNummer = '${parsed.channel.name.toUpperCase()}-${parsed.externalOrderId}';
    final naam = _formatName(parsed.customerName);
    final adres = _formatAddress(parsed.address);
    final postcode = _formatPostcode(parsed.postcode, parsed.countryCode);
    final cutoffDate = DateTime(2026, 3, 6);
    final isOld = parsed.orderDate != null && parsed.orderDate!.isBefore(cutoffDate);
    final baseStatus = parsed.channel == SalesChannel.jew ? 'concept' : 'betaald';
    final status = isOld ? 'verzonden' : baseStatus;

    final orderData = <String, dynamic>{
      'order_nummer': orderNummer,
      'user_email': parsed.customerEmail ?? 'import@${parsed.channel.name}',
      'status': status,
      'subtotaal': parsed.subtotal,
      'btw_bedrag': parsed.taxAmount,
      'btw_percentage': parsed.taxAmount > 0 && parsed.subtotal > 0
          ? (parsed.taxAmount / parsed.subtotal * 100).roundToDouble()
          : 0,
      'btw_verlegd': false,
      'verzendkosten': parsed.shippingCost,
      'totaal': parsed.total,
      'valuta': parsed.currency,
      'betaal_methode': parsed.channel.label,
      'betaal_referentie': '${parsed.channel.name}:${parsed.externalOrderId}',
      if (naam != null) 'naam': naam,
      if (adres != null) 'adres': adres,
      if (postcode != null) 'postcode': postcode,
      if (parsed.city != null) 'woonplaats': parsed.city!.trim(),
      'land_code': parsed.countryCode ?? 'NL',
      'opmerkingen': '${parsed.channel.label} #${parsed.externalOrderId}'
          '${parsed.customerPhone != null ? '\nTel: ${parsed.customerPhone}' : ''}',
      if (isOld) 'verzonden_op': cutoffDate.toIso8601String(),
    };

    final result = await _client.from('orders').insert(orderData).select().single();
    final orderId = result['id'] as String;

    if (parsed.items.isNotEmpty) {
      final regels = parsed.items.map((item) => {
        'order_id': orderId,
        'product_id': item.sku ?? item.name,
        'product_naam': item.name,
        'aantal': item.quantity,
        'stukprijs': item.unitPrice,
        'korting_percentage': 0.0,
        'regel_totaal': item.unitPrice * item.quantity,
      }).toList();
      await _client.from('order_regels').insert(regels);
    }

    return true;
  }

  String? _formatName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : w)
        .join(' ');
  }

  String? _formatAddress(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  DateTime? _parseEmailDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      return DateTime.tryParse(dateStr) ?? _parseRfc2822Date(dateStr);
    } catch (_) {
      return null;
    }
  }

  static final _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  DateTime? _parseRfc2822Date(String dateStr) {
    final m = RegExp(r'(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{1,2}):(\d{2})').firstMatch(dateStr);
    if (m == null) return null;
    final day = int.parse(m.group(1)!);
    final month = _months[m.group(2)!.toLowerCase()] ?? 1;
    final year = int.parse(m.group(3)!);
    final hour = int.parse(m.group(4)!);
    final minute = int.parse(m.group(5)!);
    return DateTime(year, month, day, hour, minute);
  }

  String? _formatPostcode(String? raw, String? cc) {
    if (raw == null || raw.trim().isEmpty) return null;
    var pc = raw.trim().toUpperCase();
    if ((cc ?? 'NL') == 'NL') {
      pc = pc.replaceAll(' ', '');
      if (pc.length == 6 && RegExp(r'^\d{4}[A-Z]{2}$').hasMatch(pc)) {
        pc = '${pc.substring(0, 4)} ${pc.substring(4)}';
      }
    }
    return pc;
  }

  Future<int> markOldOrdersAsShipped() async {
    final cutoffIso = DateTime(2026, 3, 6).toIso8601String();
    try {
      final rows = await _client.from('orders')
          .select('id, betaal_referentie')
          .or('status.eq.betaald,status.eq.concept')
          .lt('created_at', DateTime(2026, 3, 12).toIso8601String());

      int count = 0;
      for (final row in rows) {
        final ref = row['betaal_referentie'] as String? ?? '';
        if (!ref.contains(':')) continue;

        await _client.from('orders').update({
          'status': 'verzonden',
          'verzonden_op': cutoffIso,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', row['id']);
        count++;
      }
      return count;
    } catch (e) {
      if (kDebugMode) debugPrint('Fout bij markeren oude orders: $e');
      return 0;
    }
  }

  Future<bool> _processPaymentConfirmation(PaymentConfirmation payment) async {
    final betaalRef = 'jew:${payment.orderId}';
    final existing = await _client.from('orders')
        .select('id, status')
        .eq('betaal_referentie', betaalRef)
        .maybeSingle();

    if (existing == null) {
      if (kDebugMode) debugPrint('Betaalbevestiging ${payment.provider}: order ${payment.orderId} niet gevonden');
      return false;
    }

    if (existing['status'] == 'betaald') return false;

    final updates = <String, dynamic>{
      'status': 'betaald',
      'betaal_methode': payment.provider,
    };

    if (payment.customerName != null) updates['naam'] = payment.customerName;
    if (payment.customerEmail != null) updates['user_email'] = payment.customerEmail;
    if (payment.address != null) updates['adres'] = payment.address;
    if (payment.postcode != null) updates['postcode'] = payment.postcode;
    if (payment.city != null) updates['woonplaats'] = payment.city;
    if (payment.countryCode != null) updates['land_code'] = payment.countryCode;

    await _client.from('orders').update(updates).eq('id', existing['id']);
    if (kDebugMode) debugPrint('Order ${payment.orderId} bijgewerkt naar betaald via ${payment.provider}');
    return true;
  }

  // ── Helpers ──

  String _extractFetchBody(String fetchResponse) {
    final bodyStart = fetchResponse.indexOf('BODY[] {');
    if (bodyStart >= 0) {
      final braceEnd = fetchResponse.indexOf('}', bodyStart);
      if (braceEnd >= 0) {
        final afterBrace = braceEnd + 1;
        if (afterBrace < fetchResponse.length) {
          var content = fetchResponse.substring(afterBrace);
          if (content.startsWith('\r\n')) content = content.substring(2);
          else if (content.startsWith('\n')) content = content.substring(1);
          final closeParen = content.lastIndexOf(')');
          if (closeParen > 0) content = content.substring(0, closeParen);
          return content;
        }
      }
    }
    final headerStart = fetchResponse.indexOf(RegExp(r'(?:From|Date|Subject|Content-Type):', caseSensitive: false));
    if (headerStart >= 0) return fetchResponse.substring(headerStart);
    return fetchResponse;
  }

  String _extractHeader(String response, String headerName) {
    final pattern = RegExp('$headerName:\\s*(.+)', caseSensitive: false);
    final match = pattern.firstMatch(response);
    return match?.group(1)?.trim() ?? '';
  }

  String _escape(String s) => s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}

class _ImapConnection {
  Socket _socket;
  late Stream<List<int>> _stream;

  _ImapConnection._(this._socket) {
    _stream = _socket.asBroadcastStream();
  }

  static Future<_ImapConnection> connect(String host, int port, {Duration timeout = const Duration(seconds: 15)}) async {
    if (port == 993) {
      final socket = await SecureSocket.connect(host, port, timeout: timeout);
      final conn = _ImapConnection._(socket);
      final greeting = await conn.readResponse();
      if (!greeting.contains('OK')) throw Exception('Server gaf geen OK-antwoord');
      return conn;
    }

    final plain = await Socket.connect(host, port, timeout: timeout);
    final conn = _ImapConnection._(plain);
    final greeting = await conn.readResponse();
    if (!greeting.contains('OK')) throw Exception('Server gaf geen OK-antwoord');
    return conn;
  }

  Future<void> sendCommand(String command) async {
    _socket.write('$command\r\n');
    await _socket.flush();
  }

  Future<String> readResponse({Duration timeout = const Duration(seconds: 12)}) async {
    final buffer = StringBuffer();
    final completer = Completer<String>();

    late StreamSubscription<List<int>> sub;
    Timer? timer;

    timer = Timer(timeout, () {
      sub.cancel();
      if (!completer.isCompleted) completer.complete(buffer.toString());
    });

    final tagPattern = RegExp(r'^[a-zA-Z0-9]+ (OK|NO|BAD|BYE)\b', multiLine: true);

    sub = _stream.listen(
      (data) {
        final chunk = utf8.decode(data, allowMalformed: true);
        buffer.write(chunk);
        final content = buffer.toString();
        final lastLines = content.length > 200 ? content.substring(content.length - 200) : content;
        if (tagPattern.hasMatch(lastLines) ||
            (content.length < 200 && content.contains('* OK') && !content.contains('a0'))) {
          timer?.cancel();
          sub.cancel();
          if (!completer.isCompleted) completer.complete(content);
        }
      },
      onError: (e) {
        timer?.cancel();
        sub.cancel();
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        timer?.cancel();
        if (!completer.isCompleted) completer.complete(buffer.toString());
      },
    );

    return completer.future;
  }

  void destroy() {
    _socket.destroy();
  }
}

class ImportResult {
  int imported = 0;
  int duplicates = 0;
  int errors = 0;
  int paymentsConfirmed = 0;
  int scanned = 0;
  int markedShipped = 0;
  String? error;
  final Map<SalesChannel, int> perChannel = {};

  bool get hasError => error != null;
  int get total => imported + duplicates + errors;

  String get summary {
    if (hasError) return error!;
    final parts = <String>[];
    if (imported > 0) parts.add('$imported geïmporteerd');
    if (paymentsConfirmed > 0) parts.add('$paymentsConfirmed betalingen bevestigd');
    if (markedShipped > 0) parts.add('$markedShipped als verzonden gemarkeerd');
    if (duplicates > 0) parts.add('$duplicates al aanwezig');
    if (errors > 0) parts.add('$errors fouten');
    if (scanned > 0) parts.add('$scanned emails gescand');
    if (parts.isEmpty) return 'Geen nieuwe orders gevonden';
    final channelInfo = perChannel.entries
        .map((e) => '${e.key.label}: ${e.value}')
        .join(', ');
    return '${parts.join(', ')}${channelInfo.isNotEmpty ? ' ($channelInfo)' : ''}';
  }
}
