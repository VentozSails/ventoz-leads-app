import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'order_service.dart';
import 'shipping_service.dart';
import 'company_settings_service.dart';

class InvoiceService {
  static final _defaultAccentColor = PdfColor.fromHex('#455A64');

  static final Map<String, Map<String, String>> _cache = {};

  static const _fallback = <String, Map<String, String>>{
    'factuur_titel': {'nl': 'FACTUUR', 'en': 'INVOICE', 'de': 'RECHNUNG', 'fr': 'FACTURE'},
    'tav': {'nl': 'T.a.v.', 'en': 'Att.', 'de': 'z.Hd.', 'fr': "À l'attention de"},
    'factuurnummer': {'nl': 'Factuurnummer', 'en': 'Invoice number', 'de': 'Rechnungsnummer', 'fr': 'Numéro de facture'},
    'factuurdatum': {'nl': 'Factuurdatum', 'en': 'Invoice date', 'de': 'Rechnungsdatum', 'fr': 'Date de facture'},
    'betaald_op': {'nl': 'Betaald op', 'en': 'Paid on', 'de': 'Bezahlt am', 'fr': 'Payé le'},
    'ordernummer': {'nl': 'Ordernummer', 'en': 'Order number', 'de': 'Bestellnummer', 'fr': 'Numéro de commande'},
    'betaalmethode': {'nl': 'Betaalmethode', 'en': 'Payment method', 'de': 'Zahlungsmethode', 'fr': 'Mode de paiement'},
    'btw_vat': {'nl': 'BTW/VAT', 'en': 'VAT', 'de': 'MwSt.', 'fr': 'TVA'},
    'omschrijving': {'nl': 'Omschrijving', 'en': 'Description', 'de': 'Beschreibung', 'fr': 'Description'},
    'aantal': {'nl': 'Aantal', 'en': 'Quantity', 'de': 'Menge', 'fr': 'Quantité'},
    'prijs': {'nl': 'Prijs', 'en': 'Price', 'de': 'Preis', 'fr': 'Prix'},
    'totaal': {'nl': 'Totaal', 'en': 'Total', 'de': 'Gesamt', 'fr': 'Total'},
    'totaal_excl_btw': {'nl': 'Totaal excl. BTW/VAT', 'en': 'Total excl. VAT', 'de': 'Gesamt exkl. MwSt.', 'fr': 'Total HT'},
    'totaal_btw': {'nl': 'Totaal BTW/VAT', 'en': 'Total VAT', 'de': 'Gesamt MwSt.', 'fr': 'Total TVA'},
    'te_betalen': {'nl': 'Te betalen', 'en': 'Amount due', 'de': 'Zu zahlen', 'fr': 'Montant dû'},
    'verzendkosten_naar': {'nl': 'Verzendkosten naar', 'en': 'Shipping costs to', 'de': 'Versandkosten nach', 'fr': 'Frais de livraison vers'},
    'btw_verlegd_titel': {'nl': 'BTW verlegd / VAT Reverse Charge', 'en': 'VAT Reverse Charge', 'de': 'Steuerschuldnerschaft / Reverse Charge', 'fr': 'Autoliquidation de la TVA'},
    'btw_verlegd_tekst': {
      'nl': 'BTW verlegd op grond van artikel 138 Richtlijn 2006/112/EG (intracommunautaire levering). BTW wordt verlegd naar de afnemer.',
      'en': 'VAT reverse charged according to article 138 Directive 2006/112/EC (intra-Community supply). VAT to be accounted for by the recipient.',
      'de': 'Steuerschuldnerschaft gemäß Artikel 138 Richtlinie 2006/112/EG (innergemeinschaftliche Lieferung). Die MwSt. ist vom Leistungsempfänger abzuführen.',
      'fr': "TVA autoliquidée conformément à l'article 138 de la directive 2006/112/CE (livraison intracommunautaire). La TVA est à acquitter par le destinataire.",
    },
    'betaald_via': {'nl': 'Betaald via', 'en': 'Paid via', 'de': 'Bezahlt über', 'fr': 'Payé par'},
    'opmerkingen': {'nl': 'Opmerkingen', 'en': 'Notes', 'de': 'Anmerkungen', 'fr': 'Remarques'},
    'klant_btw': {'nl': 'Klant BTW/VAT', 'en': 'Customer VAT', 'de': 'Kunden-USt-IdNr.', 'fr': 'TVA client'},
    'leverancier_btw': {'nl': 'Ventoz BTW/VAT', 'en': 'Ventoz VAT', 'de': 'Ventoz USt-IdNr.', 'fr': 'TVA Ventoz'},
  };

  static String _langFromCountry(String countryCode) {
    switch (countryCode.toUpperCase()) {
      case 'NL':
        return 'nl';
      case 'DE':
      case 'AT':
      case 'CH':
        return 'de';
      case 'FR':
        return 'fr';
      case 'GB':
      case 'IE':
        return 'en';
      case 'ES':
        return 'es';
      case 'IT':
        return 'it';
      case 'PT':
        return 'pt';
      case 'PL':
        return 'pl';
      case 'SE':
        return 'sv';
      case 'DK':
        return 'da';
      case 'FI':
        return 'fi';
      case 'BE':
        return 'nl';
      default:
        return 'en';
    }
  }

  static Future<Map<String, String>> _loadTranslations(String lang) async {
    if (_cache.containsKey(lang)) return _cache[lang]!;

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
        _cache[lang] = map;
        return map;
      }
    } catch (_) {}

    final map = <String, String>{};
    for (final entry in _fallback.entries) {
      map[entry.key] = entry.value[lang] ?? entry.value['en'] ?? entry.value['nl'] ?? entry.key;
    }
    _cache[lang] = map;
    return map;
  }

  static String langFromCountry(String countryCode) => _langFromCountry(countryCode);

  static Future<Map<String, String>> loadTranslationsPublic(String lang) => _loadTranslations(lang);

  static CompanySettings? _companyCache;

  static Future<CompanySettings> _getCompany() async {
    _companyCache ??= await CompanySettingsService().getSettings();
    return _companyCache!;
  }

  static PdfColor _accentFromCompany(CompanySettings c) {
    try {
      return PdfColor.fromHex(c.accentKleur);
    } catch (_) {
      return _defaultAccentColor;
    }
  }

  static Future<Uint8List> generatePdfBytes(Order order) async {
    final lang = _langFromCountry(order.landCode);
    final tr = await _loadTranslations(lang);
    final company = await _getCompany();
    final accent = _accentFromCompany(company);
    String t(String key) => tr[key] ?? _fallback[key]?[lang] ?? _fallback[key]?['en'] ?? key;

    final pdf = pw.Document(
      title: '${company.naam} ${t('factuur_titel')} ${order.factuurNummer ?? order.orderNummer}',
      author: '${company.naam} ${company.tagline}',
    );
    final df = DateFormat('dd-MM-yyyy');

    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/ventoz_logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 35, 40, 30),
      build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildTopSection(order, df, logoImage, t, company: company, accent: accent),
          pw.SizedBox(height: 24),
          _buildAddressAndMeta(order, df, t, company: company),
          pw.SizedBox(height: 22),
          _buildProductTable(order, t, accent: accent),
          pw.SizedBox(height: 6),
          _buildTotalsSection(order, t, accent: accent),
          pw.SizedBox(height: 14),
          _buildNotes(order, t, company: company),
          pw.Spacer(),
          _buildFooter(company: company),
        ],
      ),
    ));

    return pdf.save();
  }

  static Future<void> generateAndSave(Order order, BuildContext context) async {
    final lang = _langFromCountry(order.landCode);
    final tr = await _loadTranslations(lang);
    final company = await _getCompany();
    final accent = _accentFromCompany(company);
    String t(String key) => tr[key] ?? _fallback[key]?[lang] ?? _fallback[key]?['en'] ?? key;

    final pdf = pw.Document(
      title: '${company.naam} ${t('factuur_titel')} ${order.factuurNummer ?? order.orderNummer}',
      author: '${company.naam} ${company.tagline}',
    );
    final df = DateFormat('dd-MM-yyyy');

    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/ventoz_logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 35, 40, 30),
      build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildTopSection(order, df, logoImage, t, company: company, accent: accent),
          pw.SizedBox(height: 24),
          _buildAddressAndMeta(order, df, t, company: company),
          pw.SizedBox(height: 22),
          _buildProductTable(order, t, accent: accent),
          pw.SizedBox(height: 6),
          _buildTotalsSection(order, t, accent: accent),
          pw.SizedBox(height: 14),
          _buildNotes(order, t, company: company),
          pw.Spacer(),
          _buildFooter(company: company),
        ],
      ),
    ));

    final bytes = await pdf.save();
    final fileName = '${company.naam} - ${t('factuur_titel')} ${order.factuurNummer ?? order.orderNummer}.pdf';

    if (!context.mounted) return;
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  static pw.Widget _buildTopSection(Order order, DateFormat df, pw.MemoryImage? logo, String Function(String) t,
      {CompanySettings? company, PdfColor? accent}) {
    final c = company ?? CompanySettings.fromJson({});
    final a = accent ?? _defaultAccentColor;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logo != null) pw.Image(logo, width: 48, height: 48),
              if (logo != null) pw.SizedBox(width: 10),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(c.naam, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: a)),
                  pw.Text(c.tagline, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(t('factuur_titel'), style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: a, letterSpacing: 2)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildAddressAndMeta(Order order, DateFormat df, String Function(String) t,
      {CompanySettings? company}) {
    final shipping = ShippingService.getRate(order.landCode);

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8FAFB'),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(t('tav'), style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                if (order.bedrijfsnaam != null && order.bedrijfsnaam!.isNotEmpty)
                  pw.Text(order.bedrijfsnaam!, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                if (order.naam != null)
                  pw.Text(order.naam!, style: const pw.TextStyle(fontSize: 11)),
                pw.Text(order.effectiefFactuurAdres, style: const pw.TextStyle(fontSize: 11)),
                pw.Text(
                  '${order.effectiefFactuurPostcode} ${order.effectiefFactuurWoonplaats}'.trim(),
                  style: const pw.TextStyle(fontSize: 11),
                ),
                pw.Text(shipping.countryName, style: const pw.TextStyle(fontSize: 11)),
                if (order.btwNummer != null && order.btwNummer!.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text('${t('klant_btw')}: ${order.btwNummer}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          flex: 2,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _metaRow(t('factuurnummer'), order.factuurNummer ?? order.orderNummer),
              _metaRow(t('factuurdatum'), order.createdAt != null ? df.format(order.createdAt!.toLocal()) : '-'),
              if (order.betaaldOp != null)
                _metaRow(t('betaald_op'), df.format(order.betaaldOp!.toLocal())),
              _metaRow(t('ordernummer'), order.orderNummer),
              if (order.betaalMethode != null && order.betaalMethode!.isNotEmpty)
                _metaRow(t('betaalmethode'), order.betaalMethode!),
              pw.SizedBox(height: 8),
              _metaRow(t('btw_vat'), '${order.btwPercentage.toStringAsFixed(order.btwPercentage == order.btwPercentage.roundToDouble() ? 0 : 1)}%'),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _metaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildProductTable(Order order, String Function(String) t,
      {PdfColor? accent}) {
    final a = accent ?? _defaultAccentColor;
    final shipping = ShippingService.getRate(order.landCode);
    final rows = <List<String>>[];

    for (final r in order.regels) {
      rows.add([
        r.productNaam,
        _fmtQty(r.aantal),
        _fmtAmount(r.stukprijs),
        _fmtAmount(r.regelTotaal),
      ]);
    }

    if (order.verzendkosten > 0) {
      rows.add([
        '${t('verzendkosten_naar')} ${shipping.countryName}',
        '1,00',
        _fmtAmount(order.verzendkosten),
        _fmtAmount(order.verzendkosten),
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: a),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      oddCellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      headers: [t('omschrijving'), t('aantal'), t('prijs'), t('totaal')],
      data: rows,
    );
  }

  static pw.Widget _buildTotalsSection(Order order, String Function(String) t,
      {PdfColor? accent}) {
    final a = accent ?? _defaultAccentColor;
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 260,
        child: pw.Column(
          children: [
            _totalLine(t('totaal_excl_btw'), _fmtEuro(order.subtotaal)),
            if (order.btwVerlegd)
              _totalLine(t('totaal_btw'), _fmtEuro(0), subtle: true)
            else
              _totalLine(t('totaal_btw'), _fmtEuro(order.btwBedrag), subtle: true),
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 6),
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: pw.BoxDecoration(
                color: a,
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(t('te_betalen'), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.Text(_fmtEuro(order.totaal), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _totalLine(String label, String value, {bool subtle = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, color: subtle ? PdfColors.grey600 : PdfColors.black)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, color: subtle ? PdfColors.grey600 : PdfColors.black)),
        ],
      ),
    );
  }

  static pw.Widget _buildNotes(Order order, String Function(String) t,
      {CompanySettings? company}) {
    final c = company ?? CompanySettings.fromJson({});
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (order.btwVerlegd) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.amber300),
              borderRadius: pw.BorderRadius.circular(3),
              color: PdfColor.fromHex('#FFFDE7'),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(t('btw_verlegd_titel'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text(
                  t('btw_verlegd_tekst'),
                  style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
                ),
                if (order.btwNummer != null && order.btwNummer!.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text('${t('klant_btw')}: ${order.btwNummer}  |  ${t('leverancier_btw')}: ${c.btwNummer}',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 8),
        ],
        if (order.betaalMethode != null && order.betaalMethode!.isNotEmpty)
          pw.Text(
            '${t('betaald_via')}: ${order.betaalMethode}${order.betaalReferentie != null ? ' (ref: ${order.betaalReferentie})' : ''}',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        if (order.opmerkingen != null && order.opmerkingen!.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text('${t('opmerkingen')}:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.Text(order.opmerkingen!, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ],
      ],
    );
  }

  static pw.Widget _buildFooter({CompanySettings? company}) {
    final c = company ?? CompanySettings.fromJson({});
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300, height: 1),
        pw.SizedBox(height: 6),
        pw.Text(
          '| ${c.naam} | ${c.adres} | ${c.postcode} ${c.woonplaats} | ${c.land} '
          '| ${c.telefoon} | ${c.email} | KvK: ${c.kvk} |',
          style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '| BTW/VAT: ${c.btwNummer} | IBAN: ${c.iban} | BIC: ${c.bic}',
          style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  static String _fmtAmount(double amount) {
    return amount.toStringAsFixed(2).replaceAll('.', ',');
  }

  static String _fmtQty(int qty) {
    return '${qty.toStringAsFixed(0)},00';
  }

  static String _fmtEuro(double amount) {
    return '€ ${amount.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}
