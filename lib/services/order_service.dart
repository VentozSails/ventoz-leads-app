import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_service.dart';
import 'cart_service.dart';
import 'customer_service.dart';

class Order {
  final String? id;
  final String orderNummer;
  final String? userId;
  final String userEmail;
  final String status;
  final double subtotaal;
  final double btwBedrag;
  final double btwPercentage;
  final bool btwVerlegd;
  final double verzendkosten;
  final double totaal;
  final String valuta;
  final String? betaalMethode;
  final String? betaalReferentie;
  final String? factuurNummer;
  final String? naam;
  final String? adres;
  final String? postcode;
  final String? woonplaats;
  final String landCode;
  final String? factuurAdres;
  final String? factuurPostcode;
  final String? factuurWoonplaats;
  final String? btwNummer;
  final String? iban;
  final String? bedrijfsnaam;
  final String? opmerkingen;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? betaaldOp;
  final String? trackTraceCode;
  final String? trackTraceCarrier;
  final String? trackTraceUrl;
  final DateTime? verzondenOp;
  final int? myparcelShipmentId;
  final bool bevestigingVerzonden;
  final bool verzendEmailVerzonden;
  final String? klantId;
  final List<OrderRegel> regels;

  const Order({
    this.id,
    required this.orderNummer,
    this.userId,
    required this.userEmail,
    this.status = 'concept',
    this.subtotaal = 0,
    this.btwBedrag = 0,
    this.btwPercentage = 0,
    this.btwVerlegd = false,
    this.verzendkosten = 0,
    this.totaal = 0,
    this.valuta = 'EUR',
    this.betaalMethode,
    this.betaalReferentie,
    this.factuurNummer,
    this.naam,
    this.adres,
    this.postcode,
    this.woonplaats,
    this.landCode = 'NL',
    this.factuurAdres,
    this.factuurPostcode,
    this.factuurWoonplaats,
    this.btwNummer,
    this.iban,
    this.bedrijfsnaam,
    this.opmerkingen,
    this.createdAt,
    this.updatedAt,
    this.betaaldOp,
    this.trackTraceCode,
    this.trackTraceCarrier,
    this.trackTraceUrl,
    this.verzondenOp,
    this.myparcelShipmentId,
    this.bevestigingVerzonden = false,
    this.verzendEmailVerzonden = false,
    this.klantId,
    this.regels = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json, {List<OrderRegel>? regels}) {
    return Order(
      id: json['id'] as String?,
      orderNummer: json['order_nummer'] as String? ?? '',
      userId: json['user_id'] as String?,
      userEmail: json['user_email'] as String? ?? '',
      status: json['status'] as String? ?? 'concept',
      subtotaal: (json['subtotaal'] as num?)?.toDouble() ?? 0,
      btwBedrag: (json['btw_bedrag'] as num?)?.toDouble() ?? 0,
      btwPercentage: (json['btw_percentage'] as num?)?.toDouble() ?? 0,
      btwVerlegd: (json['btw_verlegd'] as bool?) ?? false,
      verzendkosten: (json['verzendkosten'] as num?)?.toDouble() ?? 0,
      totaal: (json['totaal'] as num?)?.toDouble() ?? 0,
      valuta: json['valuta'] as String? ?? 'EUR',
      betaalMethode: json['betaal_methode'] as String?,
      betaalReferentie: json['betaal_referentie'] as String?,
      factuurNummer: json['factuur_nummer'] as String?,
      naam: json['naam'] as String?,
      adres: json['adres'] as String?,
      postcode: json['postcode'] as String?,
      woonplaats: json['woonplaats'] as String?,
      landCode: json['land_code'] as String? ?? 'NL',
      factuurAdres: json['factuur_adres'] as String?,
      factuurPostcode: json['factuur_postcode'] as String?,
      factuurWoonplaats: json['factuur_woonplaats'] as String?,
      btwNummer: json['btw_nummer'] as String?,
      iban: json['iban'] as String?,
      bedrijfsnaam: json['bedrijfsnaam'] as String?,
      opmerkingen: json['opmerkingen'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
      betaaldOp: json['betaald_op'] != null ? DateTime.tryParse(json['betaald_op'] as String) : null,
      trackTraceCode: json['track_trace_code'] as String?,
      trackTraceCarrier: json['track_trace_carrier'] as String?,
      trackTraceUrl: json['track_trace_url'] as String?,
      verzondenOp: json['verzonden_op'] != null ? DateTime.tryParse(json['verzonden_op'] as String) : null,
      myparcelShipmentId: (json['myparcel_shipment_id'] as num?)?.toInt(),
      bevestigingVerzonden: (json['bevestiging_verzonden'] as bool?) ?? false,
      verzendEmailVerzonden: (json['verzend_email_verzonden'] as bool?) ?? false,
      klantId: json['klant_id'] as String?,
      regels: regels ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'order_nummer': orderNummer,
    'user_email': userEmail,
    'status': status,
    'subtotaal': subtotaal,
    'btw_bedrag': btwBedrag,
    'btw_percentage': btwPercentage,
    'btw_verlegd': btwVerlegd,
    'verzendkosten': verzendkosten,
    'totaal': totaal,
    'valuta': valuta,
    if (betaalMethode != null) 'betaal_methode': betaalMethode,
    if (betaalReferentie != null) 'betaal_referentie': betaalReferentie,
    if (factuurNummer != null) 'factuur_nummer': factuurNummer,
    if (naam != null) 'naam': naam,
    if (adres != null) 'adres': adres,
    if (postcode != null) 'postcode': postcode,
    if (woonplaats != null) 'woonplaats': woonplaats,
    'land_code': landCode,
    if (factuurAdres != null) 'factuur_adres': factuurAdres,
    if (factuurPostcode != null) 'factuur_postcode': factuurPostcode,
    if (factuurWoonplaats != null) 'factuur_woonplaats': factuurWoonplaats,
    if (btwNummer != null) 'btw_nummer': btwNummer,
    if (iban != null) 'iban': iban,
    if (bedrijfsnaam != null) 'bedrijfsnaam': bedrijfsnaam,
    if (opmerkingen != null) 'opmerkingen': opmerkingen,
    if (betaaldOp != null) 'betaald_op': betaaldOp!.toIso8601String(),
  };

  String get statusLabel {
    const labels = {
      'concept': 'Concept',
      'betaling_gestart': 'Betaling gestart',
      'betaald': 'Betaald',
      'verzonden': 'Verzonden',
      'afgeleverd': 'Afgeleverd',
      'geannuleerd': 'Geannuleerd',
    };
    return labels[status] ?? status;
  }

  bool get isBetaald => status == 'betaald' || status == 'verzonden' || status == 'afgeleverd';

  bool get hasFactuurAdres =>
      factuurAdres != null && factuurAdres!.isNotEmpty;

  String get effectiefFactuurAdres => factuurAdres ?? adres ?? '';
  String get effectiefFactuurPostcode => factuurPostcode ?? postcode ?? '';
  String get effectiefFactuurWoonplaats => factuurWoonplaats ?? woonplaats ?? '';
}

class OrderRegel {
  final String? id;
  final String? orderId;
  final String productId;
  final String productNaam;
  final String? productAfbeelding;
  final int aantal;
  final double stukprijs;
  final double kortingPercentage;
  final double regelTotaal;

  const OrderRegel({
    this.id,
    this.orderId,
    required this.productId,
    required this.productNaam,
    this.productAfbeelding,
    this.aantal = 1,
    this.stukprijs = 0,
    this.kortingPercentage = 0,
    this.regelTotaal = 0,
  });

  factory OrderRegel.fromJson(Map<String, dynamic> json) => OrderRegel(
    id: json['id'] as String?,
    orderId: json['order_id'] as String?,
    productId: json['product_id'] as String? ?? '',
    productNaam: json['product_naam'] as String? ?? '',
    productAfbeelding: json['product_afbeelding'] as String?,
    aantal: (json['aantal'] as num?)?.toInt() ?? 1,
    stukprijs: (json['stukprijs'] as num?)?.toDouble() ?? 0,
    kortingPercentage: (json['korting_percentage'] as num?)?.toDouble() ?? 0,
    regelTotaal: (json['regel_totaal'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'product_naam': productNaam,
    if (productAfbeelding != null) 'product_afbeelding': productAfbeelding,
    'aantal': aantal,
    'stukprijs': stukprijs,
    'korting_percentage': kortingPercentage,
    'regel_totaal': regelTotaal,
  };

  factory OrderRegel.fromCartItem(CartItem item) {
    final product = item.product;
    return OrderRegel(
      productId: product.artikelnummer ?? product.naam,
      productNaam: product.naam,
      productAfbeelding: product.afbeeldingUrl,
      aantal: item.quantity,
      stukprijs: item.unitPriceExclVat,
      kortingPercentage: 0,
      regelTotaal: item.lineTotalExclVat,
    );
  }
}

class OrderService {
  final _client = Supabase.instance.client;
  static const _ordersTable = 'orders';
  static const _regelsTable = 'order_regels';

  String generateOrderNummer() {
    final now = DateTime.now();
    final date = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final rand = (Random().nextInt(9000) + 1000).toString();
    return 'VTZ-$date-$rand';
  }

  String generateFactuurNummer() {
    final now = DateTime.now();
    final rand = (Random().nextInt(9000) + 1000).toString();
    return 'F-${now.year}-$rand';
  }

  Future<Order> createOrder({
    required List<CartItem> items,
    required AppUser user,
    required double subtotaal,
    required double btwBedrag,
    required double btwPercentage,
    required bool btwVerlegd,
    double verzendkosten = 0,
    required double totaal,
    String? opmerkingen,
    String? betaalMethode,
  }) async {
    final orderNummer = generateOrderNummer();

    String? klantId;
    try {
      final customerService = CustomerService();
      final nameParts = user.volledigeNaam.split(' ');
      final customer = await customerService.findOrCreateByEmail(
        email: user.email,
        voornaam: nameParts.isNotEmpty ? nameParts.first : null,
        achternaam: nameParts.length > 1 ? nameParts.sublist(1).join(' ') : null,
        bedrijfsnaam: user.bedrijfsnaam,
        adres: user.adres,
        postcode: user.postcode,
        woonplaats: user.woonplaats,
        landCode: user.landCode,
        btwNummer: user.btwNummer,
        authUserId: _client.auth.currentUser?.id,
      );
      klantId = customer?.id;
    } catch (e) {
      if (kDebugMode) debugPrint('Customer auto-link error: $e');
    }

    final orderData = <String, dynamic>{
      'order_nummer': orderNummer,
      'user_email': user.email,
      'status': 'concept',
      'subtotaal': subtotaal,
      'btw_bedrag': btwBedrag,
      'btw_percentage': btwPercentage,
      'btw_verlegd': btwVerlegd,
      'verzendkosten': verzendkosten,
      'totaal': totaal,
      'valuta': 'EUR',
      'naam': user.volledigeNaam,
      'adres': user.adres,
      'postcode': user.postcode,
      'woonplaats': user.woonplaats,
      'land_code': user.landCode,
      if (user.factuurAdres != null) 'factuur_adres': user.factuurAdres,
      if (user.factuurPostcode != null) 'factuur_postcode': user.factuurPostcode,
      if (user.factuurWoonplaats != null) 'factuur_woonplaats': user.factuurWoonplaats,
      'btw_nummer': user.btwNummer,
      'iban': user.iban,
      'bedrijfsnaam': user.bedrijfsnaam,
    };
    if (opmerkingen != null) orderData['opmerkingen'] = opmerkingen;
    if (betaalMethode != null) orderData['betaal_methode'] = betaalMethode;
    if (klantId != null) orderData['klant_id'] = klantId;

    final result = await _client.from(_ordersTable)
        .insert(orderData)
        .select()
        .single();

    final orderId = result['id'] as String;
    final regels = items.map((item) {
      final regel = OrderRegel.fromCartItem(item);
      final json = regel.toJson();
      json['order_id'] = orderId;
      return json;
    }).toList();

    if (regels.isNotEmpty) {
      await _client.from(_regelsTable).insert(regels);
    }

    final insertedRegels = await _client.from(_regelsTable)
        .select()
        .eq('order_id', orderId);

    return Order.fromJson(
      result,
      regels: (insertedRegels as List).map((r) => OrderRegel.fromJson(r as Map<String, dynamic>)).toList(),
    );
  }

  Future<List<Order>> fetchOrders({bool adminView = false}) async {
    List<dynamic> rows;
    if (adminView) {
      rows = await _client.from(_ordersTable)
          .select()
          .order('created_at', ascending: false);
    } else {
      rows = await _client.from(_ordersTable)
          .select()
          .order('created_at', ascending: false);
    }

    final orders = <Order>[];
    for (final row in rows) {
      final orderId = row['id'] as String;
      final List<dynamic> regelRows = await _client.from(_regelsTable)
          .select()
          .eq('order_id', orderId);
      final regels = regelRows.map((r) => OrderRegel.fromJson(r as Map<String, dynamic>)).toList();
      orders.add(Order.fromJson(row as Map<String, dynamic>, regels: regels));
    }
    return orders;
  }

  Future<Order?> fetchOrder(String orderId) async {
    try {
      final row = await _client.from(_ordersTable)
          .select()
          .eq('id', orderId)
          .single();
      final List<dynamic> regelRows = await _client.from(_regelsTable)
          .select()
          .eq('order_id', orderId);
      final regels = regelRows.map((r) => OrderRegel.fromJson(r as Map<String, dynamic>)).toList();
      return Order.fromJson(row, regels: regels);
    } catch (_) {
      return null;
    }
  }

  Future<Order?> updateStatus(String orderId, String newStatus) async {
    final updates = <String, dynamic>{
      'status': newStatus,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (newStatus == 'betaald') {
      updates['betaald_op'] = DateTime.now().toUtc().toIso8601String();
      updates['factuur_nummer'] = generateFactuurNummer();
    }
    await _client.from(_ordersTable).update(updates).eq('id', orderId);

    // Stock mutations are now triggered explicitly via the stock update popup
    // shown after label generation, instead of automatically at payment.

    return fetchOrder(orderId);
  }

  Future<void> updatePaymentReference(String orderId, String reference) async {
    await _client.from(_ordersTable).update({
      'betaal_referentie': reference,
      'status': 'betaling_gestart',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', orderId);
  }

  Future<void> updateTrackTrace({
    required String orderId,
    required String carrier,
    required String code,
    required String url,
  }) async {
    final safeUrl = url.trim();
    final lower = safeUrl.toLowerCase();
    if (safeUrl.isNotEmpty && !lower.startsWith('https://') && !lower.startsWith('http://')) {
      throw ArgumentError('Track & trace URL moet beginnen met https:// of http://');
    }
    await _client.from(_ordersTable).update({
      'status': 'verzonden',
      'track_trace_code': code,
      'track_trace_carrier': carrier,
      'track_trace_url': safeUrl,
      'verzonden_op': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', orderId);
  }

  Future<void> saveInvoicePdf(String orderId, Uint8List pdfBytes) async {
    await _client.from(_ordersTable).update({
      'factuur_pdf': pdfBytes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', orderId);
  }

  Future<void> markConfirmationSent(String orderId) async {
    await _client.from(_ordersTable).update({
      'bevestiging_verzonden': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', orderId);
  }

  Future<void> markShippingEmailSent(String orderId) async {
    await _client.from(_ordersTable).update({
      'verzend_email_verzonden': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', orderId);
  }

  static String buildTrackingUrl(String carrier, String code, {String? postcode}) {
    switch (carrier.toLowerCase()) {
      case 'postnl':
        final pc = postcode ?? '';
        return 'https://postnl.nl/tracktrace/?B=$code&P=$pc';
      case 'dhl':
        return 'https://www.dhl.com/nl-nl/home/tracking.html?tracking-id=$code';
      case 'dpd':
        return 'https://tracking.dpd.de/status/nl_NL/parcel/$code';
      case 'ups':
        return 'https://www.ups.com/track?tracknum=$code';
      case 'fedex':
        return 'https://www.fedex.com/fedextrack/?trknbr=$code';
      case 'gls':
        return 'https://gls-group.eu/NL/nl/pakketten-volgen?match=$code';
      default:
        return '';
    }
  }

  Future<void> deleteOrder(String orderId) async {
    await _client.from('order_regels').delete().eq('order_id', orderId);
    await _client.from(_ordersTable).delete().eq('id', orderId);
  }

  static const carriers = <String, String>{
    'postnl': 'PostNL',
    'dhl': 'DHL',
    'dpd': 'DPD',
    'ups': 'UPS',
    'fedex': 'FedEx',
    'gls': 'GLS',
  };
}
