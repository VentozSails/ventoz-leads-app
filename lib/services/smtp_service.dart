import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  /// Sends an invitation email to a newly invited user with a registration link
  /// and MFA setup instructions (when applicable).
  ///
  /// On web, delegates to the `send-invite-email` Supabase Edge Function
  /// because browsers cannot open raw TCP sockets for SMTP.
  /// On native platforms, sends directly via the mailer package.
  Future<void> sendInviteEmail({
    required String toEmail,
    required String userTypeLabel,
    required bool mfaRequired,
    required String appUrl,
  }) async {
    // Always use the Edge Function for invite emails — direct SMTP requires
    // raw TCP sockets which are unavailable on web and unreliable on some
    // desktop environments (Windows UWP / sandbox).
    await _sendInviteViaEdgeFunction(
      toEmail: toEmail,
      userTypeLabel: userTypeLabel,
      mfaRequired: mfaRequired,
      appUrl: appUrl,
    );
  }

  Future<void> _sendInviteViaEdgeFunction({
    required String toEmail,
    required String userTypeLabel,
    required bool mfaRequired,
    required String appUrl,
  }) async {
    final response = await _client.functions.invoke(
      'send-invite-email',
      body: {
        'to_email': toEmail,
        'user_type_label': userTypeLabel,
        'mfa_required': mfaRequired,
        'app_url': appUrl,
      },
    );

    if (response.status != 200) {
      String errorMsg = 'Uitnodigingsmail versturen mislukt';
      try {
        final data = jsonDecode(response.data as String? ?? '{}');
        if (data is Map && data['error'] != null) {
          errorMsg = data['error'] as String;
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  Future<void> _sendInviteViaSMTP({
    required String toEmail,
    required String userTypeLabel,
    required bool mfaRequired,
    required String appUrl,
  }) async {
    final settings = await loadSettings();
    if (settings == null || !settings.isConfigured) {
      throw Exception(
        'SMTP is niet geconfigureerd. Ga naar Instellingen > SMTP om e-mail in te stellen.',
      );
    }

    final registerUrl = appUrl.endsWith('/')
        ? '${appUrl}inloggen'
        : '$appUrl/inloggen';

    final subject = 'Uitnodiging Ventoz — maak je account aan';

    final mfaSection = mfaRequired
        ? '''
<tr><td style="padding:20px 28px 0;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#FFF8E1;border:1px solid #F59E0B;border-radius:8px;">
<tr><td style="padding:16px 20px;">
<strong style="color:#92400E;font-size:14px;">&#128274; Tweefactorauthenticatie (MFA) vereist</strong>
<p style="margin:8px 0 0;font-size:13px;line-height:1.6;color:#78350F;">
Als $userTypeLabel is MFA verplicht. Na je eerste login word je gevraagd om MFA in te richten.<br/>
Installeer alvast een authenticator-app op je telefoon:
</p>
<ul style="margin:8px 0 0;padding-left:20px;font-size:13px;color:#78350F;line-height:1.8;">
<li><strong>Google Authenticator</strong> (Android / iOS)</li>
<li><strong>Microsoft Authenticator</strong> (Android / iOS)</li>
</ul>
</td></tr>
</table>
</td></tr>'''
        : '';

    final html = '''<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background-color:#f8fafc;">
<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f8fafc;">
<tr><td align="center" style="padding:24px 16px;">
<table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:8px;border:1px solid #e2e8f0;">

<tr><td style="background-color:#37474F;padding:20px 28px;border-radius:8px 8px 0 0;">
<span style="color:#ffffff;font-size:18px;font-weight:700;font-family:Arial,Helvetica,sans-serif;">Ventoz Sails</span>
</td></tr>

<tr><td style="padding:28px;font-family:Arial,Helvetica,sans-serif;">
<h2 style="margin:0 0 8px;font-size:20px;color:#1E293B;">Welkom bij Ventoz!</h2>
<p style="font-size:14px;line-height:1.7;color:#334155;margin:0 0 20px;">
Je bent uitgenodigd als <strong>$userTypeLabel</strong> voor het Ventoz platform.
Om aan de slag te gaan, maak je een account aan met dit e-mailadres
(<strong>${_escHtml(toEmail)}</strong>).
</p>

<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f1f5f9;border-radius:8px;margin-bottom:20px;">
<tr><td style="padding:20px;text-align:center;">
<p style="margin:0 0 4px;font-size:13px;color:#64748B;">Stap 1: Ga naar het registratiescherm</p>
<p style="margin:0 0 16px;font-size:13px;color:#64748B;">Stap 2: Klik op <em>"Uitgenodigd? Account aanmaken"</em></p>
<!--[if mso]>
<v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" href="$registerUrl"
style="height:44px;v-text-anchor:middle;width:260px;" arcsize="12%"
strokecolor="#37474F" fillcolor="#455A64">
<center style="color:#ffffff;font-family:Arial,sans-serif;font-size:15px;font-weight:bold;">Account aanmaken &rarr;</center>
</v:roundrect><![endif]-->
<!--[if !mso]><!-->
<a href="$registerUrl" target="_blank"
style="display:inline-block;background-color:#455A64;color:#ffffff;
font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:bold;
text-decoration:none;padding:12px 32px;border-radius:6px;">Account aanmaken &rarr;</a>
<!--<![endif]-->
</td></tr>
</table>

<p style="font-size:13px;line-height:1.6;color:#64748B;margin:0;">
Werkt de knop niet? Kopieer deze link in je browser:<br/>
<a href="$registerUrl" style="color:#455A64;word-break:break-all;">$registerUrl</a>
</p>
</td></tr>
$mfaSection
<tr><td style="padding:20px 28px;font-family:Arial,Helvetica,sans-serif;">
<p style="font-size:13px;line-height:1.6;color:#64748B;margin:0;">
Vragen? Neem contact op met de Ventoz beheerder die je heeft uitgenodigd.
</p>
</td></tr>

<tr><td style="padding:16px 28px;background-color:#f8fafc;border-radius:0 0 8px 8px;border-top:1px solid #e2e8f0;">
<span style="font-size:11px;color:#94a3b8;font-family:Arial,sans-serif;">Ventoz B.V. &middot; ventoz.com</span>
</td></tr>
</table>
</td></tr></table>
</body></html>''';

    final plainText = 'Welkom bij Ventoz!\n\n'
        'Je bent uitgenodigd als $userTypeLabel voor het Ventoz platform.\n'
        'Maak je account aan met dit e-mailadres ($toEmail).\n\n'
        'Ga naar: $registerUrl\n'
        'Klik op "Uitgenodigd? Account aanmaken" en maak je account aan.\n\n'
        '${mfaRequired ? 'Let op: MFA (tweefactorauthenticatie) is verplicht voor jouw rol.\n'
            'Installeer alvast Google Authenticator of Microsoft Authenticator op je telefoon.\n\n' : ''}'
        'Vragen? Neem contact op met de Ventoz beheerder die je heeft uitgenodigd.\n\n'
        'Ventoz B.V. — ventoz.com';

    final smtpServer = SmtpServer(
      settings.host,
      port: settings.port,
      username: settings.username,
      password: settings.password,
      ssl: settings.encryption == SmtpEncryption.ssl,
      ignoreBadCertificate: settings.allowInvalidCertificate,
      allowInsecure: settings.encryption == SmtpEncryption.none,
    );

    final message = Message()
      ..from = Address(settings.fromEmail, settings.fromName)
      ..recipients.add(toEmail)
      ..bccRecipients.add(settings.fromEmail)
      ..subject = subject
      ..text = plainText
      ..html = html;

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
      throw Exception('Uitnodigingsmail versturen mislukt: $msg$hint');
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
