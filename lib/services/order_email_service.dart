import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'order_service.dart';
import 'invoice_service.dart';
import 'smtp_service.dart';
import 'shipping_service.dart';
import 'company_settings_service.dart';

class OrderEmailService {
  final SmtpService _smtpService = SmtpService();
  final OrderService _orderService = OrderService();
  final CompanySettingsService _companyService = CompanySettingsService();

  final _supabase = Supabase.instance.client;

  static String _fmtEuro(double amount) =>
      '&euro; ${amount.toStringAsFixed(2).replaceAll('.', ',')}';

  static String _fmtEuroPlain(double amount) =>
      'EUR ${amount.toStringAsFixed(2).replaceAll('.', ',')}';

  Future<String?> _loadTemplate(String type) async {
    try {
      final rows = await _supabase
          .from('order_email_templates')
          .select('html_template')
          .eq('template_type', type)
          .limit(1);
      if (rows.isNotEmpty) return rows.first['html_template'] as String?;
    } catch (_) {}
    return null;
  }

  static Future<void> saveTemplate(String type, String html) async {
    await Supabase.instance.client.from('order_email_templates').upsert({
      'template_type': type,
      'html_template': html,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'template_type');
  }

  static Future<Map<String, String>> loadTemplates() async {
    try {
      final rows = await Supabase.instance.client
          .from('order_email_templates')
          .select();
      final map = <String, String>{};
      for (final row in rows) {
        map[row['template_type'] as String] = row['html_template'] as String;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<void> sendOrderConfirmation(Order order) async {
    final settings = await _smtpService.loadSettings();
    if (settings == null || !settings.isConfigured) {
      throw Exception('SMTP is niet geconfigureerd. Ga naar Beheer > E-mailinstellingen om SMTP in te stellen.');
    }

    final lang = InvoiceService.langFromCountry(order.landCode);
    final tr = await InvoiceService.loadTranslationsPublic(lang);
    final et = await _loadEmailTranslations(lang);
    final company = await _companyService.getSettings();
    String t(String key) => et[key] ?? tr[key] ?? key;

    String html;
    final dbTemplate = await _loadTemplate('bevestiging');
    if (dbTemplate != null && dbTemplate.isNotEmpty) {
      html = _applyPlaceholders(dbTemplate, order, t, company);
    } else {
      html = _buildConfirmationHtml(order, t, lang, company);
    }
    final subject = '${t('bevestiging_onderwerp')} ${order.orderNummer}';

    final smtpServer = _buildSmtpServer(settings);

    final customerMessage = Message()
      ..from = Address(settings.fromEmail, settings.fromName)
      ..recipients.add(order.userEmail)
      ..bccRecipients.add(company.email)
      ..subject = subject
      ..html = html
      ..text = '${t('bevestiging_bedankt')}\n\n${t('ordernummer')}: ${order.orderNummer}\n${t('totaal')}: ${_fmtEuroPlain(order.totaal)}';

    try {
      await send(customerMessage, smtpServer);
      if (order.id != null) {
        await _orderService.markConfirmationSent(order.id!);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('OrderEmailService.sendOrderConfirmation error: $e');
      rethrow;
    }
  }

  Future<void> sendShippingNotification(Order order) async {
    final settings = await _smtpService.loadSettings();
    if (settings == null || !settings.isConfigured) {
      throw Exception('SMTP is niet geconfigureerd. Ga naar Beheer > E-mailinstellingen om SMTP in te stellen.');
    }

    final lang = InvoiceService.langFromCountry(order.landCode);
    final tr = await InvoiceService.loadTranslationsPublic(lang);
    final et = await _loadEmailTranslations(lang);
    final company = await _companyService.getSettings();
    String t(String key) => et[key] ?? tr[key] ?? key;

    String html;
    final dbTemplate = await _loadTemplate('verzending');
    if (dbTemplate != null && dbTemplate.isNotEmpty) {
      html = _applyPlaceholders(dbTemplate, order, t, company);
    } else {
      html = _buildShippingHtml(order, t, lang, company);
    }
    final subject = '${t('verzending_onderwerp')} ${order.orderNummer}';

    final smtpServer = _buildSmtpServer(settings);

    final message = Message()
      ..from = Address(settings.fromEmail, settings.fromName)
      ..recipients.add(order.userEmail)
      ..bccRecipients.add(company.email)
      ..subject = subject
      ..html = html
      ..text = '${t('verzending_tekst')}\n\n${t('track_trace_label')}: ${order.trackTraceUrl ?? order.trackTraceCode ?? ''}';

    Uint8List? pdfBytes;
    try {
      pdfBytes = await InvoiceService.generatePdfBytes(order);
    } catch (_) {}

    if (pdfBytes != null) {
      final fileName = 'Ventoz Sails - ${t('factuur_titel')} ${order.factuurNummer ?? order.orderNummer}.pdf';
      message.attachments.add(StreamAttachment(
        Stream.value(pdfBytes),
        'application/pdf',
        fileName: fileName,
      ));
    }

    try {
      await send(message, smtpServer);
      if (order.id != null) {
        await _orderService.markShippingEmailSent(order.id!);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('OrderEmailService.sendShippingNotification error: $e');
      rethrow;
    }
  }

  SmtpServer _buildSmtpServer(SmtpSettings settings) {
    return SmtpServer(
      settings.host,
      port: settings.port,
      username: settings.username,
      password: settings.password,
      ssl: settings.encryption == SmtpEncryption.ssl,
      ignoreBadCertificate: settings.allowInvalidCertificate,
      allowInsecure: settings.encryption == SmtpEncryption.none,
    );
  }

  static final Map<String, Map<String, String>> _emailTrCache = {};

  static const _emailFallback = <String, Map<String, String>>{
    'bevestiging_onderwerp': {
      'nl': 'Orderbevestiging Ventoz —', 'en': 'Order Confirmation Ventoz —',
      'de': 'Bestellbestätigung Ventoz —', 'fr': 'Confirmation de commande Ventoz —',
    },
    'bevestiging_bedankt': {
      'nl': 'Bedankt voor je bestelling!', 'en': 'Thank you for your order!',
      'de': 'Vielen Dank für Ihre Bestellung!', 'fr': 'Merci pour votre commande !',
    },
    'bevestiging_samenvatting': {
      'nl': 'Hieronder een samenvatting van je bestelling:', 'en': 'Below is a summary of your order:',
      'de': 'Nachfolgend eine Zusammenfassung Ihrer Bestellung:', 'fr': 'Voici un résumé de votre commande :',
    },
    'bevestiging_factuur_later': {
      'nl': 'Je factuur ontvang je bij verzending van je bestelling.', 'en': 'You will receive your invoice when your order ships.',
      'de': 'Ihre Rechnung erhalten Sie beim Versand Ihrer Bestellung.', 'fr': 'Vous recevrez votre facture lors de l\'expédition de votre commande.',
    },
    'verzending_onderwerp': {
      'nl': 'Je bestelling is verzonden! —', 'en': 'Your order has been shipped! —',
      'de': 'Ihre Bestellung wurde versandt! —', 'fr': 'Votre commande a été expédiée ! —',
    },
    'verzending_tekst': {
      'nl': 'Goed nieuws! Je bestelling is onderweg.', 'en': 'Great news! Your order is on its way.',
      'de': 'Gute Nachrichten! Ihre Bestellung ist unterwegs.', 'fr': 'Bonne nouvelle ! Votre commande est en route.',
    },
    'track_trace_label': {
      'nl': 'Volg je pakket', 'en': 'Track your parcel',
      'de': 'Sendungsverfolgung', 'fr': 'Suivez votre colis',
    },
    'verzonden_via': {
      'nl': 'Verzonden via', 'en': 'Shipped via',
      'de': 'Versandt über', 'fr': 'Expédié par',
    },
    'tracking_code': {
      'nl': 'Trackingcode', 'en': 'Tracking code',
      'de': 'Sendungsnummer', 'fr': 'Numéro de suivi',
    },
    'factuur_bijgevoegd': {
      'nl': 'Je factuur is bijgevoegd als PDF.', 'en': 'Your invoice is attached as a PDF.',
      'de': 'Ihre Rechnung ist als PDF beigefügt.', 'fr': 'Votre facture est jointe en PDF.',
    },
    'vragen': {
      'nl': 'Heb je vragen? Neem gerust contact op.', 'en': 'Any questions? Feel free to contact us.',
      'de': 'Haben Sie Fragen? Kontaktieren Sie uns gerne.', 'fr': 'Des questions ? N\'hésitez pas à nous contacter.',
    },
  };

  Future<Map<String, String>> _loadEmailTranslations(String lang) async {
    if (_emailTrCache.containsKey(lang)) return _emailTrCache[lang]!;

    try {
      final rows = await Supabase.instance.client
          .from('factuur_vertalingen')
          .select('sleutel, tekst')
          .eq('taal', lang);
      if (rows.isNotEmpty) {
        final map = <String, String>{};
        for (final row in rows) {
          map[row['sleutel'] as String] = row['tekst'] as String;
        }
        _emailTrCache[lang] = map;
        return map;
      }
    } catch (_) {}

    final map = <String, String>{};
    for (final entry in _emailFallback.entries) {
      map[entry.key] = entry.value[lang] ?? entry.value['en'] ?? entry.value['nl'] ?? entry.key;
    }
    _emailTrCache[lang] = map;
    return map;
  }

  String _applyPlaceholders(String template, Order order, String Function(String) t, CompanySettings company) {
    final df = order.createdAt?.toLocal();
    final dateStr = df != null
        ? '${df.day.toString().padLeft(2, '0')}-${df.month.toString().padLeft(2, '0')}-${df.year}'
        : '';
    final shipping = ShippingService.getRate(order.landCode);

    final productRows = StringBuffer();
    for (final r in order.regels) {
      productRows.write('''<tr>
  <td style="padding:10px 16px;border-bottom:1px solid #e2e8f0;font-size:14px;color:#334155;">${_esc(r.productNaam)}</td>
  <td style="padding:10px 8px;border-bottom:1px solid #e2e8f0;text-align:center;font-size:14px;color:#64748B;">${r.aantal}</td>
  <td style="padding:10px 16px;border-bottom:1px solid #e2e8f0;text-align:right;font-size:14px;color:#334155;">${_fmtEuro(r.regelTotaal)}</td>
</tr>''');
    }

    final carrierName = OrderService.carriers[order.trackTraceCarrier?.toLowerCase()] ?? order.trackTraceCarrier ?? '';

    return template
        .replaceAll('{{ordernummer}}', _esc(order.orderNummer))
        .replaceAll('{{datum}}', dateStr)
        .replaceAll('{{product_tabel}}', productRows.toString())
        .replaceAll('{{subtotaal}}', _fmtEuro(order.subtotaal))
        .replaceAll('{{btw}}', order.btwVerlegd ? _fmtEuro(0) : _fmtEuro(order.btwBedrag))
        .replaceAll('{{totaal}}', _fmtEuro(order.totaal))
        .replaceAll('{{verzendkosten}}', _fmtEuro(order.verzendkosten))
        .replaceAll('{{betaalmethode}}', _esc(order.betaalMethode ?? ''))
        .replaceAll('{{klantnaam}}', _esc(order.naam ?? order.userEmail))
        .replaceAll('{{bedrijfsnaam}}', _esc(company.naam))
        .replaceAll('{{carrier}}', _esc(carrierName))
        .replaceAll('{{trackcode}}', _esc(order.trackTraceCode ?? ''))
        .replaceAll('{{trackurl}}', _sanitizeUrl(order.trackTraceUrl ?? ''))
        .replaceAll('{{verzendland}}', _esc(shipping.countryName))
        .replaceAll('{{bedrijfs_adres}}', _esc(company.fullAddress))
        .replaceAll('{{bedrijfs_email}}', _esc(company.email));
  }

  String _buildConfirmationHtml(Order order, String Function(String) t, String lang, CompanySettings company) {
    final df = order.createdAt?.toLocal();
    final dateStr = df != null
        ? '${df.day.toString().padLeft(2, '0')}-${df.month.toString().padLeft(2, '0')}-${df.year}'
        : '';
    final shipping = ShippingService.getRate(order.landCode);

    final productRows = StringBuffer();
    for (final r in order.regels) {
      productRows.write('''
<tr>
  <td style="padding:10px 16px;border-bottom:1px solid #e2e8f0;font-size:14px;color:#334155;">${_esc(r.productNaam)}</td>
  <td style="padding:10px 8px;border-bottom:1px solid #e2e8f0;text-align:center;font-size:14px;color:#64748B;">${r.aantal}</td>
  <td style="padding:10px 16px;border-bottom:1px solid #e2e8f0;text-align:right;font-size:14px;color:#334155;">${_fmtEuro(r.regelTotaal)}</td>
</tr>''');
    }

    return '''<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"></head>
<body style="margin:0;padding:0;background-color:#f1f5f9;">
<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f1f5f9;">
<tr><td align="center" style="padding:32px 16px;">
<table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.06);">

<tr><td style="background:linear-gradient(135deg,#37474F 0%,#546E7A 100%);padding:28px 32px;">
  <table width="100%"><tr>
    <td><span style="color:#ffffff;font-size:22px;font-weight:800;font-family:Arial,Helvetica,sans-serif;letter-spacing:0.5px;">${_esc(company.naam)}</span>
    <br/><span style="color:#B0BEC5;font-size:12px;font-family:Arial,sans-serif;">${_esc(company.tagline)}</span></td>
    <td align="right"><span style="color:#ffffff;font-size:11px;font-family:Arial,sans-serif;">${company.naam.toLowerCase()}.nl</span></td>
  </tr></table>
</td></tr>

<tr><td style="padding:32px;font-family:Arial,Helvetica,sans-serif;">
  <h1 style="margin:0 0 8px 0;font-size:24px;color:#1E293B;">${_esc(t('bevestiging_bedankt'))}</h1>
  <p style="margin:0 0 24px 0;font-size:14px;line-height:1.6;color:#64748B;">${_esc(t('bevestiging_samenvatting'))}</p>

  <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:20px;background-color:#F8FAFC;border-radius:8px;border:1px solid #E2E8F0;">
    <tr>
      <td style="padding:14px 16px;font-size:13px;color:#64748B;font-weight:600;">${_esc(t('ordernummer'))}</td>
      <td style="padding:14px 16px;font-size:14px;color:#1E293B;font-weight:700;text-align:right;">${_esc(order.orderNummer)}</td>
    </tr>
    <tr>
      <td style="padding:6px 16px 14px;font-size:13px;color:#64748B;">${_esc(t('factuurdatum'))}</td>
      <td style="padding:6px 16px 14px;font-size:14px;color:#1E293B;text-align:right;">$dateStr</td>
    </tr>
    ${order.betaalMethode != null ? '<tr><td style="padding:6px 16px 14px;font-size:13px;color:#64748B;">${_esc(t('betaalmethode'))}</td><td style="padding:6px 16px 14px;font-size:14px;color:#1E293B;text-align:right;">${_esc(order.betaalMethode!)}</td></tr>' : ''}
  </table>

  <table width="100%" cellpadding="0" cellspacing="0" style="border:1px solid #E2E8F0;border-radius:8px;overflow:hidden;margin-bottom:20px;">
    <tr style="background-color:#455A64;">
      <td style="padding:10px 16px;color:#ffffff;font-size:12px;font-weight:700;">${_esc(t('omschrijving'))}</td>
      <td style="padding:10px 8px;color:#ffffff;font-size:12px;font-weight:700;text-align:center;">${_esc(t('aantal'))}</td>
      <td style="padding:10px 16px;color:#ffffff;font-size:12px;font-weight:700;text-align:right;">${_esc(t('totaal'))}</td>
    </tr>
    $productRows
  </table>

  <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
    <tr><td style="padding:4px 16px;font-size:13px;color:#64748B;">${_esc(t('totaal_excl_btw'))}</td><td style="padding:4px 16px;text-align:right;font-size:13px;color:#64748B;">${_fmtEuro(order.subtotaal)}</td></tr>
    <tr><td style="padding:4px 16px;font-size:13px;color:#64748B;">${_esc(t('totaal_btw'))}</td><td style="padding:4px 16px;text-align:right;font-size:13px;color:#64748B;">${order.btwVerlegd ? _fmtEuro(0) : _fmtEuro(order.btwBedrag)}</td></tr>
    ${order.verzendkosten > 0 ? '<tr><td style="padding:4px 16px;font-size:13px;color:#64748B;">${_esc(t('verzendkosten_naar'))} ${_esc(shipping.countryName)}</td><td style="padding:4px 16px;text-align:right;font-size:13px;color:#64748B;">${_fmtEuro(order.verzendkosten)}</td></tr>' : ''}
    <tr><td colspan="2" style="padding:8px 16px 0;"><hr style="border:none;border-top:2px solid #455A64;margin:0;"></td></tr>
    <tr><td style="padding:8px 16px;font-size:16px;font-weight:800;color:#1E293B;">${_esc(t('te_betalen'))}</td><td style="padding:8px 16px;text-align:right;font-size:18px;font-weight:800;color:#455A64;">${_fmtEuro(order.totaal)}</td></tr>
  </table>

  <p style="font-size:13px;color:#64748B;line-height:1.6;margin:0 0 8px 0;">${_esc(t('bevestiging_factuur_later'))}</p>
  <p style="font-size:13px;color:#64748B;line-height:1.6;margin:0;">${_esc(t('vragen'))}</p>
</td></tr>

<tr><td style="padding:20px 32px;background-color:#F8FAFC;border-top:1px solid #E2E8F0;">
  <table width="100%"><tr>
    <td style="font-size:11px;color:#94A3B8;font-family:Arial,sans-serif;">${_esc(company.naam)} · ${_esc(company.fullAddress)}</td>
    <td align="right" style="font-size:11px;color:#94A3B8;font-family:Arial,sans-serif;">${_esc(company.emailFooter)}</td>
  </tr></table>
</td></tr>

</table>
</td></tr></table>
</body></html>''';
  }

  String _buildShippingHtml(Order order, String Function(String) t, String lang, CompanySettings company) {
    final carrierName = OrderService.carriers[order.trackTraceCarrier?.toLowerCase()] ?? order.trackTraceCarrier ?? '';
    final trackUrl = order.trackTraceUrl ?? '';
    final trackCode = order.trackTraceCode ?? '';

    return '''<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"></head>
<body style="margin:0;padding:0;background-color:#f1f5f9;">
<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f1f5f9;">
<tr><td align="center" style="padding:32px 16px;">
<table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.06);">

<tr><td style="background:linear-gradient(135deg,#37474F 0%,#546E7A 100%);padding:28px 32px;">
  <table width="100%"><tr>
    <td><span style="color:#ffffff;font-size:22px;font-weight:800;font-family:Arial,Helvetica,sans-serif;letter-spacing:0.5px;">${_esc(company.naam)}</span>
    <br/><span style="color:#B0BEC5;font-size:12px;font-family:Arial,sans-serif;">${_esc(company.tagline)}</span></td>
    <td align="right"><span style="color:#ffffff;font-size:11px;font-family:Arial,sans-serif;">${company.naam.toLowerCase()}.nl</span></td>
  </tr></table>
</td></tr>

<tr><td style="padding:32px;font-family:Arial,Helvetica,sans-serif;">
  <h1 style="margin:0 0 8px 0;font-size:24px;color:#1E293B;">📦 ${_esc(t('verzending_tekst'))}</h1>
  <p style="margin:0 0 24px 0;font-size:14px;line-height:1.6;color:#64748B;">${_esc(t('ordernummer'))}: <strong>${_esc(order.orderNummer)}</strong></p>

  <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;background:linear-gradient(135deg,#E8F5E9 0%,#F1F8E9 100%);border-radius:12px;border:1px solid #C8E6C9;">
    <tr><td style="padding:24px;text-align:center;">
      <p style="margin:0 0 6px;font-size:13px;color:#2E7D32;font-weight:600;">${_esc(t('verzonden_via'))} $carrierName</p>
      <p style="margin:0 0 16px;font-size:12px;color:#558B2F;">${_esc(t('tracking_code'))}: <strong>$trackCode</strong></p>
      ${trackUrl.isNotEmpty ? '<a href="${_sanitizeUrl(trackUrl)}" target="_blank" style="display:inline-block;background-color:#2E7D32;color:#ffffff;font-family:Arial,sans-serif;font-size:15px;font-weight:700;text-decoration:none;padding:14px 36px;border-radius:8px;">${_esc(t('track_trace_label'))} →</a>' : ''}
    </td></tr>
  </table>

  <p style="font-size:13px;color:#64748B;line-height:1.6;margin:0 0 8px 0;">${_esc(t('factuur_bijgevoegd'))}</p>
  <p style="font-size:13px;color:#64748B;line-height:1.6;margin:0;">${_esc(t('vragen'))}</p>
</td></tr>

<tr><td style="padding:20px 32px;background-color:#F8FAFC;border-top:1px solid #E2E8F0;">
  <table width="100%"><tr>
    <td style="font-size:11px;color:#94A3B8;font-family:Arial,sans-serif;">${_esc(company.naam)} · ${_esc(company.fullAddress)}</td>
    <td align="right" style="font-size:11px;color:#94A3B8;font-family:Arial,sans-serif;">${_esc(company.emailFooter)}</td>
  </tr></table>
</td></tr>

</table>
</td></tr></table>
</body></html>''';
  }

  String getDefaultConfirmationHtml() => _buildConfirmationHtml(
    _dummyOrder(), (k) => k, 'nl', const CompanySettings(),
  );

  String getDefaultShippingHtml() => _buildShippingHtml(
    _dummyOrder(), (k) => k, 'nl', const CompanySettings(),
  );

  static Order _dummyOrder() => Order(
    orderNummer: 'V-2026-00001',
    userEmail: 'klant@voorbeeld.nl',
    naam: 'Jan de Vries',
    regels: [
      OrderRegel(productId: 'demo-1', productNaam: 'Optimist Zeil Competition', aantal: 1, stukprijs: 395.00, regelTotaal: 395.00),
      OrderRegel(productId: 'demo-2', productNaam: 'Fokkenlijn 6mm x 8m', aantal: 2, stukprijs: 12.50, regelTotaal: 25.00),
    ],
    subtotaal: 347.11,
    btwBedrag: 72.89,
    totaal: 420.00,
    verzendkosten: 0,
    btwPercentage: 21,
    status: 'betaald',
  );

  static String _esc(String text) =>
      text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  static String _sanitizeUrl(String url) {
    if (url.isEmpty) return '';
    final lower = url.trim().toLowerCase();
    if (!lower.startsWith('https://') && !lower.startsWith('http://')) return '';
    return url.replaceAll('"', '%22').replaceAll("'", '%27').replaceAll('<', '%3C').replaceAll('>', '%3E');
  }
}
