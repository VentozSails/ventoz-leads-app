import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'crypto_service.dart';

enum SmtpEncryption {
  starttls('STARTTLS', 587),
  ssl('SSL/TLS', 465),
  none('Geen', 25);

  final String label;
  final int defaultPort;
  const SmtpEncryption(this.label, this.defaultPort);

  static SmtpEncryption fromString(String? value) {
    if (value == null) return SmtpEncryption.starttls;
    return SmtpEncryption.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SmtpEncryption.starttls,
    );
  }
}

class SmtpSettings {
  final String host;
  final int port;
  final String username;
  final String password;
  final String fromName;
  final String fromEmail;
  final SmtpEncryption encryption;
  final bool allowInvalidCertificate;

  const SmtpSettings({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.fromName,
    required this.fromEmail,
    this.encryption = SmtpEncryption.starttls,
    this.allowInvalidCertificate = false,
  });

  factory SmtpSettings.fromJson(Map<String, dynamic> json) {
    // Backwards compatibility: old format used 'ssl' boolean
    SmtpEncryption enc;
    if (json.containsKey('encryption')) {
      enc = SmtpEncryption.fromString(json['encryption'] as String?);
    } else {
      final oldSsl = (json['ssl'] as bool?) ?? true;
      enc = oldSsl ? SmtpEncryption.starttls : SmtpEncryption.none;
    }

    return SmtpSettings(
      host: (json['host'] as String?) ?? '',
      port: (json['port'] as int?) ?? enc.defaultPort,
      username: (json['username'] as String?) ?? '',
      password: (json['password'] as String?) ?? '',
      fromName: (json['from_name'] as String?) ?? 'Ventoz B.V.',
      fromEmail: (json['from_email'] as String?) ?? '',
      encryption: enc,
      allowInvalidCertificate: (json['allow_invalid_certificate'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'from_name': fromName,
        'from_email': fromEmail,
        'encryption': encryption.name,
        'allow_invalid_certificate': allowInvalidCertificate,
      };

  bool get isConfigured =>
      host.isNotEmpty &&
      username.isNotEmpty &&
      password.isNotEmpty &&
      fromEmail.isNotEmpty;
}

class SmtpService {
  final _client = Supabase.instance.client;
  static const _tableName = 'app_settings';
  static const _settingKey = 'smtp_config';

  static const _secretFields = ['password'];

  Future<SmtpSettings?> loadSettings() async {
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

      return SmtpSettings.fromJson(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSettings(SmtpSettings settings) async {
    try {
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
    } catch (e) {
      throw Exception('SMTP-instellingen opslaan mislukt: $e');
    }
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

  static String _textToHtml(String text) {
    var html = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');

    html = html.replaceAllMapped(
      RegExp(r'(https?://[^\s<&]+)'),
      (m) {
        final url = m.group(1)!;
        return '<!--[if mso]>'
            '<v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" href="$url" '
            'style="height:40px;v-text-anchor:middle;width:220px;" arcsize="10%" '
            'strokecolor="#37474F" fillcolor="#455A64">'
            '<center style="color:#ffffff;font-family:Arial,sans-serif;font-size:14px;font-weight:bold;">Bekijk product &rarr;</center>'
            '</v:roundrect><![endif]-->'
            '<!--[if !mso]><!-->'
            '<a href="$url" target="_blank" '
            'style="display:inline-block;background-color:#455A64;color:#ffffff;'
            'font-family:Arial,Helvetica,sans-serif;font-size:14px;font-weight:bold;'
            'text-decoration:none;padding:12px 28px;border-radius:6px;'
            'mso-hide:all;">Bekijk product &rarr;</a>'
            '<!--<![endif]-->';
      },
    );

    html = html.replaceAllMapped(
      RegExp(r'━+\n\s*UW KORTINGSCODE:\s*(\S+)\n━+'),
      (m) {
        final code = m.group(1)!;
        return '<table width="100%" cellpadding="0" cellspacing="0" style="margin:16px 0;">'
            '<tr><td align="center" style="background-color:#FFF8E1;border:2px solid #F59E0B;'
            'border-radius:8px;padding:16px;">'
            '<span style="font-size:12px;color:#92400E;">UW KORTINGSCODE</span><br/>'
            '<span style="font-size:24px;font-weight:800;letter-spacing:2px;color:#78350F;">$code</span>'
            '</td></tr></table>';
      },
    );

    html = html.replaceAllMapped(
      RegExp(r'VENTOZ_PRODUCT_LIST_START\n((?:VENTOZ_PRODUCT\|[^\n]*\n)*)VENTOZ_PRODUCT_LIST_END'),
      (m) {
        final lines = m.group(1)!.trim().split('\n');
        final rows = StringBuffer();
        for (final line in lines) {
          final parts = line.replaceFirst('VENTOZ_PRODUCT|', '').split('|');
          final name = parts.isNotEmpty ? _escHtml(parts[0]) : '';
          final url = parts.length > 1 ? _sanitizeHref(parts[1]) : '';
          if (url.isNotEmpty) {
            rows.write(
              '<tr><td style="padding:10px 16px;border-bottom:1px solid #e2e8f0;">'
              '<a href="$url" target="_blank" '
              'style="color:#455A64;font-weight:600;font-size:15px;text-decoration:none;">'
              '&#9654; $name</a>'
              '</td><td style="padding:10px 16px;border-bottom:1px solid #e2e8f0;text-align:right;">'
              '<a href="$url" target="_blank" '
              'style="display:inline-block;background-color:#455A64;color:#ffffff;'
              'font-size:12px;font-weight:600;text-decoration:none;padding:6px 16px;border-radius:4px;">'
              'Bekijk &rarr;</a>'
              '</td></tr>');
          } else {
            rows.write(
              '<tr><td colspan="2" style="padding:10px 16px;border-bottom:1px solid #e2e8f0;'
              'color:#455A64;font-weight:600;font-size:15px;">'
              '&#9654; $name</td></tr>');
          }
        }
        return '<table width="100%" cellpadding="0" cellspacing="0" style="margin:16px 0;border:1px solid #e2e8f0;border-radius:8px;overflow:hidden;">'
            '<tr><td colspan="2" style="background-color:#37474F;padding:12px 16px;'
            'color:#ffffff;font-weight:700;font-size:14px;font-family:Arial,sans-serif;">'
            '&#9875; Geselecteerde zeilen</td></tr>'
            '${rows.toString()}'
            '</table>';
      },
    );

    html = html.replaceAllMapped(
      RegExp(r'✦\s+(.+)'),
      (m) => '<strong style="color:#37474F;">${m.group(1)}</strong>',
    );

    html = html.replaceAll('\n', '<br/>\n');

    return '''<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background-color:#f8fafc;">
<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f8fafc;">
<tr><td align="center" style="padding:24px 16px;">
<table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:8px;border:1px solid #e2e8f0;">
<tr><td style="background-color:#37474F;padding:20px 28px;border-radius:8px 8px 0 0;">
<span style="color:#ffffff;font-size:18px;font-weight:700;font-family:Arial,Helvetica,sans-serif;">Ventoz Sails</span>
</td></tr>
<tr><td style="padding:28px;font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:1.7;color:#334155;">
$html
</td></tr>
<tr><td style="padding:16px 28px;background-color:#f8fafc;border-radius:0 0 8px 8px;border-top:1px solid #e2e8f0;">
<span style="font-size:11px;color:#94a3b8;font-family:Arial,sans-serif;">Ventoz B.V. &middot; www.ventoz.nl</span>
</td></tr>
</table>
</td></tr></table>
</body></html>''';
  }

  Future<void> sendEmail({
    required SmtpSettings settings,
    required String toAddress,
    required String subject,
    required String body,
  }) async {
    final smtpServer = SmtpServer(
      settings.host,
      port: settings.port,
      username: settings.username,
      password: settings.password,
      ssl: settings.encryption == SmtpEncryption.ssl,
      ignoreBadCertificate: settings.allowInvalidCertificate,
      allowInsecure: settings.encryption == SmtpEncryption.none,
    );

    final cleanBody = body.replaceFirst(RegExp(r'^Onderwerp:.*\n\n'), '');
    final htmlBody = _textToHtml(cleanBody);

    final message = Message()
      ..from = Address(settings.fromEmail, settings.fromName)
      ..recipients.add(toAddress)
      ..bccRecipients.add(settings.fromEmail)
      ..subject = subject
      ..text = cleanBody
      ..html = htmlBody;

    try {
      await send(message, smtpServer);
    } on MailerException catch (e) {
      final msg = e.message;
      String hint = '';
      if (msg.contains('Authentication') || msg.contains('535') || msg.contains('Username and Password not accepted')) {
        hint = '\nControleer je gebruikersnaam en wachtwoord (bij Gmail: gebruik een App Password).';
      } else if (msg.contains('Connection refused') || msg.contains('SocketException')) {
        hint = '\nControleer de server (host) en poort. Probeer poort 587 of 465.';
      } else if (msg.contains('certificate') || msg.contains('STARTTLS') || msg.contains('HandshakeException')) {
        hint = '\nSSL/TLS probleem. Probeer de SSL-instelling aan/uit te schakelen.';
      }
      throw Exception('SMTP-fout: $msg$hint');
    }
  }

  static String _escHtml(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  static String _sanitizeHref(String url) {
    final trimmed = url.trim();
    final lower = trimmed.toLowerCase();
    if (!lower.startsWith('https://') && !lower.startsWith('http://')) return '';
    return trimmed.replaceAll('"', '%22').replaceAll("'", '%27').replaceAll('<', '%3C').replaceAll('>', '%3E');
  }
}
