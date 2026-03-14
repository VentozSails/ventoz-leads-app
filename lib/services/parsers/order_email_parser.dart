import '../imap_order_service.dart';

class ParsedOrderItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final String? sku;

  const ParsedOrderItem({
    required this.name,
    this.quantity = 1,
    this.unitPrice = 0,
    this.sku,
  });
}

class ParsedOrder {
  final SalesChannel channel;
  final String externalOrderId;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? address;
  final String? postcode;
  final String? city;
  final String? countryCode;
  final double subtotal;
  final double taxAmount;
  final double shippingCost;
  final double total;
  final String currency;
  final List<ParsedOrderItem> items;
  final DateTime? orderDate;
  final bool isPaymentConfirmation;
  final String? paymentProvider;
  final String? paymentReference;

  const ParsedOrder({
    required this.channel,
    required this.externalOrderId,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.address,
    this.postcode,
    this.city,
    this.countryCode,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.shippingCost = 0,
    this.total = 0,
    this.currency = 'EUR',
    this.items = const [],
    this.orderDate,
    this.isPaymentConfirmation = false,
    this.paymentProvider,
    this.paymentReference,
  });
}

class PaymentConfirmation {
  final String orderId;
  final double amount;
  final String provider;
  final String? transactionRef;
  final String? customerName;
  final String? customerEmail;
  final String? address;
  final String? postcode;
  final String? city;
  final String? countryCode;

  const PaymentConfirmation({
    required this.orderId,
    required this.amount,
    required this.provider,
    this.transactionRef,
    this.customerName,
    this.customerEmail,
    this.address,
    this.postcode,
    this.city,
    this.countryCode,
  });
}

abstract class OrderEmailParser {
  SalesChannel get channel;
  bool canParse({required String from, required String subject});
  ParsedOrder? parse({required String from, required String subject, required String bodyHtml});
}

abstract class PaymentEmailParser {
  String get providerName;
  bool canParse({required String from, required String subject});
  PaymentConfirmation? parse({required String from, required String subject, required String bodyHtml});
}

class OrderEmailParserRegistry {
  static final List<OrderEmailParser> _orderParsers = [
    JewOrderParser(),
    EbayOrderParser(),
    BolOrderParser(),
    AmazonOrderParser(),
  ];

  static final List<PaymentEmailParser> _paymentParsers = [
    BuckarooPaymentParser(),
    PayPalPaymentParser(),
  ];

  static ParsedOrder? tryParse({
    required String from,
    required String subject,
    required String bodyHtml,
    required ImapSettings settings,
  }) {
    for (final parser in _orderParsers) {
      if (!_isChannelEnabled(parser.channel, settings)) continue;
      if (!parser.canParse(from: from, subject: subject)) continue;
      try {
        return parser.parse(from: from, subject: subject, bodyHtml: bodyHtml);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static PaymentConfirmation? tryParsePayment({
    required String from,
    required String subject,
    required String bodyHtml,
  }) {
    for (final parser in _paymentParsers) {
      if (!parser.canParse(from: from, subject: subject)) continue;
      try {
        return parser.parse(from: from, subject: subject, bodyHtml: bodyHtml);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static bool _isChannelEnabled(SalesChannel ch, ImapSettings settings) => switch (ch) {
    SalesChannel.jew => settings.enableJew,
    SalesChannel.ebay => settings.enableEbay,
    SalesChannel.bol => settings.enableBol,
    SalesChannel.amazon => settings.enableAmazon,
  };
}

// ── Shared helpers ──

double parseEurAmount(String text) {
  var cleaned = text
      .replaceAll(RegExp(r'[€$£\s]'), '')
      .replaceAll('EUR', '')
      .trim();
  if (cleaned.contains(',') && cleaned.contains('.')) {
    if (cleaned.lastIndexOf(',') > cleaned.lastIndexOf('.')) {
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else {
      cleaned = cleaned.replaceAll(',', '');
    }
  } else if (cleaned.contains(',')) {
    cleaned = cleaned.replaceAll(',', '.');
  }
  return double.tryParse(cleaned) ?? 0;
}

String stripHtmlTags(String html) {
  return html
      .replaceAll(RegExp(r'<br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(RegExp(r'&nbsp;'), ' ')
      .replaceAll(RegExp(r'&amp;'), '&')
      .replaceAll(RegExp(r'&lt;'), '<')
      .replaceAll(RegExp(r'&gt;'), '>')
      .replaceAll(RegExp(r'&quot;'), '"')
      .replaceAll(RegExp(r'&#\d+;'), '')
      .replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n')
      .trim();
}

// ── Parser implementations (exported from separate files) ──

class JewOrderParser extends OrderEmailParser {
  @override
  SalesChannel get channel => SalesChannel.jew;

  static const _orderKeywords = [
    'bestelbevestiging', 'bestelling', 'nieuwe order', 'order bevestiging',
    'orderbevestiging', 'bestelling ontvangen',
  ];

  @override
  bool canParse({required String from, required String subject}) {
    if (!from.toLowerCase().contains('jeeigenweb') &&
        !from.toLowerCase().contains('ventoz')) {
      return false;
    }
    final subLower = subject.toLowerCase();
    return _orderKeywords.any((kw) => subLower.contains(kw));
  }

  @override
  ParsedOrder? parse({required String from, required String subject, required String bodyHtml}) {
    final text = stripHtmlTags(bodyHtml);
    final orderMatch = RegExp(r'Ordernummer[:\s]*(\d+)', caseSensitive: false).firstMatch(bodyHtml) ??
        RegExp(r'Ordernummer[:\s]*(\d+)', caseSensitive: false).firstMatch(text) ??
        RegExp(r'order\s*(?:nummer|nr|#)[:\s]*(\d+)', caseSensitive: false).firstMatch(text);
    if (orderMatch == null) return null;
    final orderId = orderMatch.group(1)!;

    final items = <ParsedOrderItem>[];
    final rowPattern = RegExp(
      r'class="winkelwagenoverzicht"[^>]*><div[^>]*>(\d+)</div></td>'
      r'<td[^>]*class="winkelwagenoverzicht"[^>]*><div[^>]*>(.*?)</div></td>'
      r'<td[^>]*class="winkelwagenoverzicht"[^>]*><div[^>]*>[€\s]*([\d.,]+)</div>',
      dotAll: true,
    );
    for (final m in rowPattern.allMatches(bodyHtml)) {
      final qty = int.tryParse(m.group(1)!) ?? 1;
      final rawName = stripHtmlTags(m.group(2)!).split('\n').first.trim();
      final price = parseEurAmount(m.group(3)!);
      if (rawName.isNotEmpty) {
        items.add(ParsedOrderItem(name: rawName, quantity: qty, unitPrice: price / qty));
      }
    }

    if (items.isEmpty) {
      final simpleRow = RegExp(
        r'padding10">\s*(\d+)\s*</div>.*?padding10">\s*(.*?)<(?:font|br)',
        dotAll: true,
      );
      for (final m in simpleRow.allMatches(bodyHtml)) {
        final qty = int.tryParse(m.group(1)!) ?? 1;
        final name = stripHtmlTags(m.group(2)!).trim();
        if (name.isNotEmpty && !name.startsWith('Aantal')) {
          items.add(ParsedOrderItem(name: name, quantity: qty));
        }
      }
    }

    final btwMatch = RegExp(r'BTW\s*</div>\s*</td>\s*<td[^>]*>\s*<div[^>]*>\s*<b>\s*[€\s]*([\d.,]+)', dotAll: true).firstMatch(bodyHtml);
    final totalMatch = RegExp(r'Totaal\s+Prijs\s*</div>\s*</td>\s*<td[^>]*>\s*<div[^>]*>\s*<b>\s*[€\s]*([\d.,]+)', dotAll: true).firstMatch(bodyHtml);
    final btw = btwMatch != null ? parseEurAmount(btwMatch.group(1)!) : 0.0;
    final total = totalMatch != null ? parseEurAmount(totalMatch.group(1)!) : 0.0;

    String? name, address, postcode, city, country, email, phone;
    final factuurBlock = RegExp(
      r'Factuurgegevens</b></div>(.*?)</td>',
      dotAll: true,
    ).firstMatch(bodyHtml);
    if (factuurBlock != null) {
      final lines = stripHtmlTags(factuurBlock.group(1)!)
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isNotEmpty) name = lines[0];
      if (lines.length > 1) address = lines[1];
      if (lines.length > 2) {
        final pcCity = lines[2];
        final pcMatch = RegExp(r'^(\d{4}\s*\w{2})\s*(.+)$').firstMatch(pcCity);
        if (pcMatch != null) {
          postcode = pcMatch.group(1);
          city = pcMatch.group(2);
        } else {
          city = pcCity;
        }
      }
      if (lines.length > 3) country = lines[3];
      for (final l in lines) {
        if (l.startsWith('E-mail:')) email = l.replaceFirst('E-mail:', '').trim();
        if (l.startsWith('Tel:') || l.startsWith('Telefoon:')) {
          phone = l.replaceFirst(RegExp(r'^Tel(?:efoon)?:\s*'), '').trim();
        }
      }
    }

    DateTime? orderDate;
    final dateMatch = RegExp(r'Datum:\s*(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})', caseSensitive: false).firstMatch(text);
    if (dateMatch != null) {
      final d = int.parse(dateMatch.group(1)!);
      final m = int.parse(dateMatch.group(2)!);
      var y = int.parse(dateMatch.group(3)!);
      if (y < 100) y += 2000;
      orderDate = DateTime(y, m, d);
    }

    final countryCode = _mapCountryToCode(country);

    return ParsedOrder(
      channel: SalesChannel.jew,
      externalOrderId: orderId,
      customerName: name,
      customerEmail: email,
      customerPhone: phone,
      address: address,
      postcode: postcode,
      city: city,
      countryCode: countryCode,
      orderDate: orderDate,
      subtotal: total - btw,
      taxAmount: btw,
      shippingCost: 0,
      total: total,
      items: items,
    );
  }
}

class EbayOrderParser extends OrderEmailParser {
  @override
  SalesChannel get channel => SalesChannel.ebay;

  static const _soldKeywords = [
    'verkocht', 'sold', 'verkauft', 'vendu', 'venduto', 'vendido',
    'item sold', 'artikel verkocht', 'artikel verkauft',
    'order confirmed', 'order received', 'bestelling ontvangen',
  ];

  @override
  bool canParse({required String from, required String subject}) {
    if (!from.toLowerCase().contains('ebay')) return false;
    final subLower = subject.toLowerCase();
    return _soldKeywords.any((kw) => subLower.contains(kw));
  }

  @override
  ParsedOrder? parse({required String from, required String subject, required String bodyHtml}) {
    final orderIdMatch = RegExp(r'orderid=([\d\-]+)').firstMatch(bodyHtml);
    if (orderIdMatch == null) return null;
    final orderId = orderIdMatch.group(1)!;

    String productName = subject;
    for (final prefix in ['U hebt ', 'You sold ', 'Sie haben ', 'Vous avez vendu ']) {
      if (productName.startsWith(prefix)) productName = productName.substring(prefix.length);
    }
    for (final suffix in [' verkocht', ' sold', ' verkauft', ' vendu', ' venduto', ' vendido']) {
      if (productName.toLowerCase().endsWith(suffix)) {
        productName = productName.substring(0, productName.length - suffix.length);
      }
    }

    final text = stripHtmlTags(bodyHtml);

    double soldPrice = 0;
    double shippingCost = 0;
    for (final label in ['Verkocht:', 'Sold:', 'Verkauft:', 'Vendu:', 'Venduto:', 'Vendido:']) {
      final m = RegExp('$label\\s*EUR\\s*([\\d.,]+)', caseSensitive: false).firstMatch(text);
      if (m != null) { soldPrice = parseEurAmount(m.group(1)!); break; }
    }
    for (final label in ['Verzending:', 'Shipping:', 'Versand:', 'Livraison:', 'Spedizione:', 'Envío:']) {
      final m = RegExp('$label\\s*EUR\\s*([\\d.,]+)', caseSensitive: false).firstMatch(text);
      if (m != null) { shippingCost = parseEurAmount(m.group(1)!); break; }
    }

    String? buyerName, street, cityPostal, country;
    final addressBlock = RegExp(
      r'(?:Verzendgegevens|Shipping details|Versanddetails|shipping address)[^:]*:?\s*\n+(.*?)(?:\n\s*\n|\n\s*Verzend|Ship by)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    if (addressBlock != null) {
      final lines = addressBlock.group(1)!.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.isNotEmpty) buyerName = lines[0];
      if (lines.length > 1) street = lines[1];
      if (lines.length > 2) cityPostal = lines[2];
      if (lines.length > 3) country = lines[3];
    }

    String? postcode, city;
    if (cityPostal != null) {
      final cpMatch = RegExp(r'^(.+?),?\s+(\d{4,6}\s*\w*)$').firstMatch(cityPostal);
      if (cpMatch != null) {
        city = cpMatch.group(1);
        postcode = cpMatch.group(2);
      } else {
        city = cityPostal;
      }
    }

    DateTime? orderDate;
    final eDateMatch = RegExp(r'(?:Datum|Date|Datum):\s*(\d{1,2})[.\-/](\d{1,2})[.\-/](\d{2,4})', caseSensitive: false).firstMatch(text) ??
        RegExp(r'(\d{1,2})\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+(\d{4})', caseSensitive: false).firstMatch(text);
    if (eDateMatch != null && eDateMatch.groupCount >= 3) {
      final d = int.parse(eDateMatch.group(1)!);
      final m = int.parse(eDateMatch.group(2)!);
      var y = int.parse(eDateMatch.group(3)!);
      if (y < 100) y += 2000;
      orderDate = DateTime(y, m, d);
    }

    return ParsedOrder(
      channel: SalesChannel.ebay,
      externalOrderId: orderId,
      customerName: buyerName,
      address: street,
      postcode: postcode,
      city: city,
      countryCode: _mapCountryToCode(country),
      subtotal: soldPrice,
      taxAmount: 0,
      shippingCost: shippingCost,
      total: soldPrice + shippingCost,
      items: [ParsedOrderItem(name: productName.trim(), quantity: 1, unitPrice: soldPrice)],
      orderDate: orderDate,
    );
  }
}

class BolOrderParser extends OrderEmailParser {
  @override
  SalesChannel get channel => SalesChannel.bol;

  static const _orderKeywords = [
    'nieuwe bestelling', 'bestelling', 'bestelnummer', 'order',
  ];

  @override
  bool canParse({required String from, required String subject}) {
    if (!from.toLowerCase().contains('bol.com') &&
        !from.toLowerCase().contains('bol ')) {
      return false;
    }
    final subLower = subject.toLowerCase();
    return _orderKeywords.any((kw) => subLower.contains(kw));
  }

  @override
  ParsedOrder? parse({required String from, required String subject, required String bodyHtml}) {
    final text = stripHtmlTags(bodyHtml);
    final orderMatch = RegExp(r'bestelnummer[:\s]*([A-Z0-9\-]+)', caseSensitive: false).firstMatch(subject) ??
        RegExp(r'bestelnummer[:\s]*([A-Z0-9\-]+)', caseSensitive: false).firstMatch(bodyHtml) ??
        RegExp(r'bestelnummer[:\s]*([A-Z0-9\-]+)', caseSensitive: false).firstMatch(text) ??
        RegExp(r'order[:\s]*#?\s*([A-Z0-9\-]{6,})', caseSensitive: false).firstMatch(text);
    if (orderMatch == null) return null;
    final orderId = orderMatch.group(1)!;

    final items = <ParsedOrderItem>[];
    final productMatch = RegExp(
      r'<strong>([^<]{3,})</strong>',
      caseSensitive: false,
    ).allMatches(bodyHtml);
    for (final m in productMatch) {
      final name = stripHtmlTags(m.group(1)!).trim();
      if (name.isNotEmpty && !name.startsWith('Artikel') && !name.startsWith('Conditie')
          && !name.startsWith('Levering') && !name.startsWith('Betaal')
          && name.length > 5 && !RegExp(r'^\d+$').hasMatch(name)) {
        items.add(ParsedOrderItem(name: name, quantity: 1));
      }
    }

    double totalPrice = 0;
    final priceMatches = RegExp(r'€\s*([\d.,]+)').allMatches(text);
    final prices = priceMatches.map((m) => parseEurAmount(m.group(1)!)).toList();
    if (prices.isNotEmpty) {
      totalPrice = prices.last;
      if (items.isNotEmpty && items.length == 1) {
        items[0] = ParsedOrderItem(
          name: items[0].name,
          quantity: items[0].quantity,
          unitPrice: totalPrice,
        );
      }
    }

    return ParsedOrder(
      channel: SalesChannel.bol,
      externalOrderId: orderId,
      subtotal: totalPrice,
      total: totalPrice,
      items: items,
    );
  }
}

class AmazonOrderParser extends OrderEmailParser {
  @override
  SalesChannel get channel => SalesChannel.amazon;

  static const _soldKeywords = [
    'sold', 'verkocht', 'verkauft', 'vendu', 'venduto', 'vendido',
    'order', 'bestelling', 'bestellung',
  ];

  @override
  bool canParse({required String from, required String subject}) {
    if (!from.toLowerCase().contains('amazon')) return false;
    final subLower = subject.toLowerCase();
    return _soldKeywords.any((kw) => subLower.contains(kw));
  }

  @override
  ParsedOrder? parse({required String from, required String subject, required String bodyHtml}) {
    final text = stripHtmlTags(bodyHtml);

    final orderMatch = RegExp(r'Order ID[:\s]*([\d\-]+)', caseSensitive: false).firstMatch(text) ??
        RegExp(r'Bestellnummer[:\s]*([\d\-]+)', caseSensitive: false).firstMatch(text) ??
        RegExp(r'Bestell-Nr[.:\s]*([\d\-]+)', caseSensitive: false).firstMatch(text) ??
        RegExp(r'<b>Order ID:</b>\s*([\d\-]+)', caseSensitive: false).firstMatch(bodyHtml) ??
        RegExp(r'order[:\s]*#?\s*([\d\-]{8,})', caseSensitive: false).firstMatch(text);
    if (orderMatch == null) return null;
    final orderId = orderMatch.group(1)!;

    final itemMatch = RegExp(r'Item:\s*(.+)', caseSensitive: false).firstMatch(text) ??
        RegExp(r'<b>Item:</b>\s*(.+?)(?:<br|$)', caseSensitive: false).firstMatch(bodyHtml);
    final itemName = itemMatch != null ? stripHtmlTags(itemMatch.group(1)!).trim() : 'Amazon product';

    final skuMatch = RegExp(r'SKU:\s*(\S+)', caseSensitive: false).firstMatch(text);
    final sku = skuMatch?.group(1);

    final qtyMatch = RegExp(r'(?:Quantity|Menge|Aantal|Quantit[eé])[:\s]*(\d+)', caseSensitive: false).firstMatch(text);
    final qty = int.tryParse(qtyMatch?.group(1) ?? '1') ?? 1;

    double price = 0, tax = 0, shipping = 0, shippingTax = 0;
    for (final label in ['Price:', 'Preis:', 'Prix:']) {
      final m = RegExp('$label\\s*EUR\\s*([\\d.,]+)', caseSensitive: false).firstMatch(text);
      if (m != null) { price = parseEurAmount(m.group(1)!); break; }
    }
    for (final label in ['Tax:', 'MwSt:', 'TVA:']) {
      final m = RegExp('$label\\s*EUR\\s*([\\d.,]+)', caseSensitive: false).firstMatch(text);
      if (m != null) { tax = parseEurAmount(m.group(1)!); break; }
    }
    final shipMatch = RegExp(r'Shipping:\s*EUR\s*([\d.,]+)', caseSensitive: false).firstMatch(text);
    if (shipMatch != null) shipping = parseEurAmount(shipMatch.group(1)!);
    final shipTaxMatch = RegExp(r'Shipping tax:\s*EUR\s*([\d.,]+)', caseSensitive: false).firstMatch(text);
    if (shipTaxMatch != null) shippingTax = parseEurAmount(shipTaxMatch.group(1)!);

    final senderDomain = RegExp(r'@amazon\.(\w+)').firstMatch(from.toLowerCase());
    final countryCode = switch (senderDomain?.group(1)) {
      'de' => 'DE',
      'fr' => 'FR',
      'it' => 'IT',
      'es' => 'ES',
      'co.uk' || 'uk' => 'GB',
      'nl' => 'NL',
      _ => null,
    };

    return ParsedOrder(
      channel: SalesChannel.amazon,
      externalOrderId: orderId,
      countryCode: countryCode,
      subtotal: price,
      taxAmount: tax + shippingTax,
      shippingCost: shipping,
      total: price + tax + shipping + shippingTax,
      currency: 'EUR',
      items: [ParsedOrderItem(name: itemName, quantity: qty, unitPrice: price / qty, sku: sku)],
    );
  }
}

// ── Payment confirmation parsers ──

class BuckarooPaymentParser extends PaymentEmailParser {
  @override
  String get providerName => 'Buckaroo';

  @override
  bool canParse({required String from, required String subject}) {
    if (!from.toLowerCase().contains('buckaroo')) return false;
    final subLower = subject.toLowerCase();
    return subLower.contains('betaalbevestiging') || subLower.contains('payment') || subLower.contains('betaling');
  }

  @override
  PaymentConfirmation? parse({required String from, required String subject, required String bodyHtml}) {
    final orderMatch = RegExp(r'factuur\s+(\d+)', caseSensitive: false).firstMatch(subject);
    if (orderMatch == null) return null;
    final orderId = orderMatch.group(1)!;

    final text = stripHtmlTags(bodyHtml);
    double amount = 0;
    final amountMatch = RegExp(r'EUR\s*([\d.,]+)', caseSensitive: false).firstMatch(text);
    if (amountMatch != null) amount = parseEurAmount(amountMatch.group(1)!);

    return PaymentConfirmation(
      orderId: orderId,
      amount: amount,
      provider: 'Buckaroo',
    );
  }
}

class PayPalPaymentParser extends PaymentEmailParser {
  @override
  String get providerName => 'PayPal';

  @override
  bool canParse({required String from, required String subject}) {
    if (!from.toLowerCase().contains('paypal')) return false;
    final subLower = subject.toLowerCase();
    return subLower.contains('betaling ontvangen') || subLower.contains('payment received') ||
        subLower.contains('zahlung erhalten') || subLower.contains('betaling');
  }

  @override
  PaymentConfirmation? parse({required String from, required String subject, required String bodyHtml}) {
    final text = stripHtmlTags(bodyHtml);

    final invoiceMatch = RegExp(r'Factuurreferentie\s*\n?\s*(\d+)', caseSensitive: false).firstMatch(text);
    if (invoiceMatch == null) return null;
    final orderId = invoiceMatch.group(1)!;

    double amount = 0;
    final amountMatch = RegExp(r'€\s*([\d.,]+)\s*EUR', caseSensitive: false).firstMatch(text);
    if (amountMatch != null) amount = parseEurAmount(amountMatch.group(1)!);

    final txnMatch = RegExp(r'Transactiereferentie\s*\n?\s*(\S+)', caseSensitive: false).firstMatch(text);
    final txnRef = txnMatch?.group(1);

    String? buyerName, buyerEmail;
    final buyerMatch = RegExp(r'betaling van .+? ontvangen van\s+(.+?)\s*\((\S+@\S+)\)', caseSensitive: false).firstMatch(text);
    if (buyerMatch != null) {
      buyerName = buyerMatch.group(1)?.trim();
      buyerEmail = buyerMatch.group(2)?.trim();
    }

    String? street, city, postcode, countryCode;
    final addressBlock = RegExp(
      r'Verzendadres[^]*?\n\n(.+?)(?:\n\s*\n|Verzendgegevens)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    if (addressBlock != null) {
      final lines = addressBlock.group(1)!
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isNotEmpty && buyerName == null) buyerName = lines[0];
      if (lines.length > 1) street = lines[1];
      if (lines.length >= 3) {
        final lastLine = lines.last;
        final countryName = lastLine;
        countryCode = _mapCountryToCode(countryName);
        if (countryCode == lastLine.toUpperCase() && lines.length > 3) {
          countryCode = _mapCountryToCode(lastLine);
        }
      }
      for (final l in lines) {
        final pcMatch = RegExp(r'^([A-Z]{1,2}\d[\dA-Z]?\s*\d[A-Z]{2})$|^(\d{4}\s*[A-Z]{2})$').firstMatch(l);
        if (pcMatch != null) {
          postcode = l;
        }
      }
      if (lines.length > 2) {
        for (int i = 1; i < lines.length - 1; i++) {
          if (lines[i] != street && lines[i] != postcode && !_isCountry(lines[i])) {
            city ??= lines[i];
          }
        }
      }
    }

    return PaymentConfirmation(
      orderId: orderId,
      amount: amount,
      provider: 'PayPal',
      transactionRef: txnRef,
      customerName: buyerName,
      customerEmail: buyerEmail,
      address: street,
      postcode: postcode,
      city: city,
      countryCode: countryCode,
    );
  }

  static bool _isCountry(String s) {
    return _mapCountryToCode(s) != s.toUpperCase() || s.length <= 3;
  }
}

// ── Country mapping helper ──

String _mapCountryToCode(String? country) {
  if (country == null || country.isEmpty) return 'NL';
  final lower = country.toLowerCase().trim();
  const map = {
    'nederland': 'NL', 'netherlands': 'NL', 'niederlande': 'NL', 'pays-bas': 'NL',
    'germany': 'DE', 'duitsland': 'DE', 'deutschland': 'DE', 'allemagne': 'DE', 'germania': 'DE', 'alemania': 'DE',
    'belgium': 'BE', 'belgië': 'BE', 'belgien': 'BE', 'belgique': 'BE', 'belgio': 'BE', 'bélgica': 'BE',
    'france': 'FR', 'frankrijk': 'FR', 'frankreich': 'FR',
    'united kingdom': 'GB', 'uk': 'GB', 'groot-brittannië': 'GB', 'vereinigtes königreich': 'GB', 'royaume-uni': 'GB',
    'italy': 'IT', 'italië': 'IT', 'italien': 'IT', 'italie': 'IT', 'italia': 'IT',
    'spain': 'ES', 'spanje': 'ES', 'spanien': 'ES', 'espagne': 'ES', 'españa': 'ES', 'spagna': 'ES',
    'austria': 'AT', 'oostenrijk': 'AT', 'österreich': 'AT', 'autriche': 'AT',
    'switzerland': 'CH', 'zwitserland': 'CH', 'schweiz': 'CH', 'suisse': 'CH', 'svizzera': 'CH',
    'luxembourg': 'LU', 'luxemburg': 'LU',
    'denmark': 'DK', 'denemarken': 'DK', 'dänemark': 'DK', 'danemark': 'DK',
    'sweden': 'SE', 'zweden': 'SE', 'schweden': 'SE', 'suède': 'SE',
    'norway': 'NO', 'noorwegen': 'NO', 'norwegen': 'NO', 'norvège': 'NO',
    'poland': 'PL', 'polen': 'PL', 'pologne': 'PL', 'polonia': 'PL',
    'portugal': 'PT',
    'ireland': 'IE', 'ierland': 'IE', 'irland': 'IE', 'irlande': 'IE', 'irlanda': 'IE',
  };
  return map[lower] ?? (lower.length == 2 ? lower.toUpperCase() : 'NL');
}
