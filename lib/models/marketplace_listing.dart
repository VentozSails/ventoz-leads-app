import 'catalog_product.dart';
import '../utils/image_url_helper.dart';

enum MarketplacePlatform {
  bolCom('bol_com', 'Bol.com'),
  ebay('ebay', 'eBay'),
  amazon('amazon', 'Amazon'),
  marktplaats('marktplaats', 'Marktplaats');

  final String code;
  final String label;
  const MarketplacePlatform(this.code, this.label);

  static MarketplacePlatform fromCode(String code) =>
      MarketplacePlatform.values.firstWhere(
        (p) => p.code == code,
        orElse: () => MarketplacePlatform.bolCom,
      );
}

enum ListingStatus {
  concept('concept', 'Concept'),
  actief('actief', 'Actief'),
  gepauzeerd('gepauzeerd', 'Gepauzeerd'),
  verwijderd('verwijderd', 'Verwijderd'),
  fout('fout', 'Fout');

  final String code;
  final String label;
  const ListingStatus(this.code, this.label);

  static ListingStatus fromCode(String code) =>
      ListingStatus.values.firstWhere(
        (s) => s.code == code,
        orElse: () => ListingStatus.concept,
      );
}

enum MarketplaceOrderStatus {
  nieuw('nieuw', 'Nieuw'),
  verwerkt('verwerkt', 'Verwerkt'),
  verzonden('verzonden', 'Verzonden'),
  geannuleerd('geannuleerd', 'Geannuleerd');

  final String code;
  final String label;
  const MarketplaceOrderStatus(this.code, this.label);

  static MarketplaceOrderStatus fromCode(String code) =>
      MarketplaceOrderStatus.values.firstWhere(
        (s) => s.code == code,
        orElse: () => MarketplaceOrderStatus.nieuw,
      );
}

class MarketplaceListing {
  final String? id;
  final int productId;
  final MarketplacePlatform platform;
  final String? externId;
  final String? externUrl;
  final ListingStatus status;
  final double? prijs;
  final String taal;
  final bool voorraadSync;
  final DateTime? laatsteSync;
  final String? syncFout;
  final Map<String, dynamic> platformData;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined fields (not stored, populated via queries)
  final String? productNaam;
  final String? productAfbeelding;
  final int? productVoorraad;

  const MarketplaceListing({
    this.id,
    required this.productId,
    required this.platform,
    this.externId,
    this.externUrl,
    this.status = ListingStatus.concept,
    this.prijs,
    this.taal = 'nl',
    this.voorraadSync = true,
    this.laatsteSync,
    this.syncFout,
    this.platformData = const {},
    this.createdAt,
    this.updatedAt,
    this.productNaam,
    this.productAfbeelding,
    this.productVoorraad,
  });

  factory MarketplaceListing.fromJson(Map<String, dynamic> json) {
    final product = json['product_catalogus'];
    return MarketplaceListing(
      id: json['id'] as String?,
      productId: json['product_id'] as int,
      platform: MarketplacePlatform.fromCode(json['platform'] as String? ?? 'bol_com'),
      externId: json['extern_id'] as String?,
      externUrl: json['extern_url'] as String?,
      status: ListingStatus.fromCode(json['status'] as String? ?? 'concept'),
      prijs: (json['prijs'] as num?)?.toDouble(),
      taal: (json['taal'] as String?) ?? 'nl',
      voorraadSync: (json['voorraad_sync'] as bool?) ?? true,
      laatsteSync: json['laatste_sync'] != null
          ? DateTime.tryParse(json['laatste_sync'] as String)
          : null,
      syncFout: json['sync_fout'] as String?,
      platformData: json['platform_data'] != null
          ? Map<String, dynamic>.from(json['platform_data'] as Map)
          : const {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      productNaam: product != null ? (product['naam'] as String?) : null,
      productAfbeelding: product != null && product['afbeelding_url'] != null
          ? resolveImageUrl(product['afbeelding_url'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'platform': platform.code,
    if (externId != null) 'extern_id': externId,
    if (externUrl != null) 'extern_url': externUrl,
    'status': status.code,
    if (prijs != null) 'prijs': prijs,
    'taal': taal,
    'voorraad_sync': voorraadSync,
    if (laatsteSync != null) 'laatste_sync': laatsteSync!.toIso8601String(),
    if (syncFout != null) 'sync_fout': syncFout,
    'platform_data': platformData,
  };

  MarketplaceListing copyWith({
    String? id,
    int? productId,
    MarketplacePlatform? platform,
    String? externId,
    String? externUrl,
    ListingStatus? status,
    double? prijs,
    String? taal,
    bool? voorraadSync,
    DateTime? laatsteSync,
    String? syncFout,
    Map<String, dynamic>? platformData,
  }) => MarketplaceListing(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    platform: platform ?? this.platform,
    externId: externId ?? this.externId,
    externUrl: externUrl ?? this.externUrl,
    status: status ?? this.status,
    prijs: prijs ?? this.prijs,
    taal: taal ?? this.taal,
    voorraadSync: voorraadSync ?? this.voorraadSync,
    laatsteSync: laatsteSync ?? this.laatsteSync,
    syncFout: syncFout ?? this.syncFout,
    platformData: platformData ?? this.platformData,
    createdAt: createdAt,
    updatedAt: updatedAt,
    productNaam: productNaam,
    productAfbeelding: productAfbeelding,
    productVoorraad: productVoorraad,
  );
}

class MarketplaceOrder {
  final String? id;
  final MarketplacePlatform platform;
  final String externOrderId;
  final String? orderId;
  final MarketplaceOrderStatus status;
  final String? klantNaam;
  final String? klantEmail;
  final String? klantTelefoon;
  final String? klantAanhef;
  final double? totaal;

  // Shipping address
  final String? verzendStraat;
  final String? verzendHuisnummer;
  final String? verzendHuisnummerExt;
  final String? verzendPostcode;
  final String? verzendStad;
  final String? verzendLand;

  // Billing address
  final String? factuurNaam;
  final String? factuurStraat;
  final String? factuurHuisnummer;
  final String? factuurHuisnummerExt;
  final String? factuurPostcode;
  final String? factuurStad;
  final String? factuurLand;
  final String? factuurEmail;

  // Order dates
  final DateTime? besteldOp;
  final DateTime? uitersteLeverdatum;

  // Fulfillment / transport
  final String? fulfillmentMethode;
  final String? transportId;
  final String? trackTrace;

  // Financial
  final double? commissie;
  final int aantalItems;

  // Product summary
  final String? productEan;
  final String? productTitel;
  final int productHoeveelheid;
  final double? stukprijs;

  // Multi-item detail
  final List<Map<String, dynamic>> orderItems;

  final Map<String, dynamic> orderData;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MarketplaceOrder({
    this.id,
    required this.platform,
    required this.externOrderId,
    this.orderId,
    this.status = MarketplaceOrderStatus.nieuw,
    this.klantNaam,
    this.klantEmail,
    this.klantTelefoon,
    this.klantAanhef,
    this.totaal,
    this.verzendStraat,
    this.verzendHuisnummer,
    this.verzendHuisnummerExt,
    this.verzendPostcode,
    this.verzendStad,
    this.verzendLand,
    this.factuurNaam,
    this.factuurStraat,
    this.factuurHuisnummer,
    this.factuurHuisnummerExt,
    this.factuurPostcode,
    this.factuurStad,
    this.factuurLand,
    this.factuurEmail,
    this.besteldOp,
    this.uitersteLeverdatum,
    this.fulfillmentMethode,
    this.transportId,
    this.trackTrace,
    this.commissie,
    this.aantalItems = 1,
    this.productEan,
    this.productTitel,
    this.productHoeveelheid = 1,
    this.stukprijs,
    this.orderItems = const [],
    this.orderData = const {},
    this.createdAt,
    this.updatedAt,
  });

  String get verzendAdresOneliner {
    final parts = [
      if (verzendStraat != null) verzendStraat,
      if (verzendHuisnummer != null) verzendHuisnummer,
      if (verzendHuisnummerExt != null) verzendHuisnummerExt,
    ];
    final line1 = parts.join(' ');
    final line2 = [
      if (verzendPostcode != null) verzendPostcode,
      if (verzendStad != null) verzendStad,
    ].join(' ');
    return [line1, line2].where((s) => s.isNotEmpty).join(', ');
  }

  String get factuurAdresOneliner {
    final parts = [
      if (factuurStraat != null) factuurStraat,
      if (factuurHuisnummer != null) factuurHuisnummer,
      if (factuurHuisnummerExt != null) factuurHuisnummerExt,
    ];
    final line1 = parts.join(' ');
    final line2 = [
      if (factuurPostcode != null) factuurPostcode,
      if (factuurStad != null) factuurStad,
    ].join(' ');
    return [line1, line2].where((s) => s.isNotEmpty).join(', ');
  }

  factory MarketplaceOrder.fromJson(Map<String, dynamic> json) => MarketplaceOrder(
    id: json['id'] as String?,
    platform: MarketplacePlatform.fromCode(json['platform'] as String? ?? 'bol_com'),
    externOrderId: json['extern_order_id'] as String? ?? '',
    orderId: json['order_id'] as String?,
    status: MarketplaceOrderStatus.fromCode(json['status'] as String? ?? 'nieuw'),
    klantNaam: json['klant_naam'] as String?,
    klantEmail: json['klant_email'] as String?,
    klantTelefoon: json['klant_telefoon'] as String?,
    klantAanhef: json['klant_aanhef'] as String?,
    totaal: (json['totaal'] as num?)?.toDouble(),
    verzendStraat: json['verzend_straat'] as String?,
    verzendHuisnummer: json['verzend_huisnummer'] as String?,
    verzendHuisnummerExt: json['verzend_huisnummer_ext'] as String?,
    verzendPostcode: json['verzend_postcode'] as String?,
    verzendStad: json['verzend_stad'] as String?,
    verzendLand: json['verzend_land'] as String?,
    factuurNaam: json['factuur_naam'] as String?,
    factuurStraat: json['factuur_straat'] as String?,
    factuurHuisnummer: json['factuur_huisnummer'] as String?,
    factuurHuisnummerExt: json['factuur_huisnummer_ext'] as String?,
    factuurPostcode: json['factuur_postcode'] as String?,
    factuurStad: json['factuur_stad'] as String?,
    factuurLand: json['factuur_land'] as String?,
    factuurEmail: json['factuur_email'] as String?,
    besteldOp: json['besteld_op'] != null
        ? DateTime.tryParse(json['besteld_op'] as String)
        : null,
    uitersteLeverdatum: json['uiterste_leverdatum'] != null
        ? DateTime.tryParse(json['uiterste_leverdatum'] as String)
        : null,
    fulfillmentMethode: json['fulfillment_methode'] as String?,
    transportId: json['transport_id'] as String?,
    trackTrace: json['track_trace'] as String?,
    commissie: (json['commissie'] as num?)?.toDouble(),
    aantalItems: (json['aantal_items'] as int?) ?? 1,
    productEan: json['product_ean'] as String?,
    productTitel: json['product_titel'] as String?,
    productHoeveelheid: (json['product_hoeveelheid'] as int?) ?? 1,
    stukprijs: (json['stukprijs'] as num?)?.toDouble(),
    orderItems: json['order_items'] != null
        ? List<Map<String, dynamic>>.from(
            (json['order_items'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
        : const [],
    orderData: json['order_data'] != null
        ? Map<String, dynamic>.from(json['order_data'] as Map)
        : const {},
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.tryParse(json['updated_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'platform': platform.code,
    'extern_order_id': externOrderId,
    if (orderId != null) 'order_id': orderId,
    'status': status.code,
    if (klantNaam != null) 'klant_naam': klantNaam,
    if (klantEmail != null) 'klant_email': klantEmail,
    if (klantTelefoon != null) 'klant_telefoon': klantTelefoon,
    if (klantAanhef != null) 'klant_aanhef': klantAanhef,
    if (totaal != null) 'totaal': totaal,
    if (verzendStraat != null) 'verzend_straat': verzendStraat,
    if (verzendHuisnummer != null) 'verzend_huisnummer': verzendHuisnummer,
    if (verzendHuisnummerExt != null) 'verzend_huisnummer_ext': verzendHuisnummerExt,
    if (verzendPostcode != null) 'verzend_postcode': verzendPostcode,
    if (verzendStad != null) 'verzend_stad': verzendStad,
    if (verzendLand != null) 'verzend_land': verzendLand,
    if (factuurNaam != null) 'factuur_naam': factuurNaam,
    if (factuurStraat != null) 'factuur_straat': factuurStraat,
    if (factuurHuisnummer != null) 'factuur_huisnummer': factuurHuisnummer,
    if (factuurHuisnummerExt != null) 'factuur_huisnummer_ext': factuurHuisnummerExt,
    if (factuurPostcode != null) 'factuur_postcode': factuurPostcode,
    if (factuurStad != null) 'factuur_stad': factuurStad,
    if (factuurLand != null) 'factuur_land': factuurLand,
    if (factuurEmail != null) 'factuur_email': factuurEmail,
    if (besteldOp != null) 'besteld_op': besteldOp!.toIso8601String(),
    if (uitersteLeverdatum != null) 'uiterste_leverdatum': uitersteLeverdatum!.toIso8601String().substring(0, 10),
    if (fulfillmentMethode != null) 'fulfillment_methode': fulfillmentMethode,
    if (transportId != null) 'transport_id': transportId,
    if (trackTrace != null) 'track_trace': trackTrace,
    if (commissie != null) 'commissie': commissie,
    'aantal_items': aantalItems,
    if (productEan != null) 'product_ean': productEan,
    if (productTitel != null) 'product_titel': productTitel,
    'product_hoeveelheid': productHoeveelheid,
    if (stukprijs != null) 'stukprijs': stukprijs,
    'order_items': orderItems,
    'order_data': orderData,
  };
}

class MarketplaceSyncLog {
  final int? id;
  final String platform;
  final String actie;
  final String status;
  final String? listingId;
  final Map<String, dynamic> details;
  final DateTime? createdAt;

  const MarketplaceSyncLog({
    this.id,
    required this.platform,
    required this.actie,
    this.status = 'succes',
    this.listingId,
    this.details = const {},
    this.createdAt,
  });

  factory MarketplaceSyncLog.fromJson(Map<String, dynamic> json) => MarketplaceSyncLog(
    id: json['id'] as int?,
    platform: json['platform'] as String? ?? '',
    actie: json['actie'] as String? ?? '',
    status: json['status'] as String? ?? 'succes',
    listingId: json['listing_id'] as String?,
    details: json['details'] != null
        ? Map<String, dynamic>.from(json['details'] as Map)
        : const {},
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'] as String)
        : null,
  );
}

class MarketplaceCredentialStatus {
  final MarketplacePlatform platform;
  final bool isConfigured;
  final bool isActive;
  final DateTime? lastUpdated;

  const MarketplaceCredentialStatus({
    required this.platform,
    this.isConfigured = false,
    this.isActive = false,
    this.lastUpdated,
  });
}

class ChannelMatrixRow {
  final CatalogProduct product;
  final int voorraad;
  final Map<MarketplacePlatform, List<MarketplaceListing>> listings;

  const ChannelMatrixRow({
    required this.product,
    this.voorraad = 0,
    this.listings = const {},
  });

  bool isActiveOn(MarketplacePlatform platform) {
    final list = listings[platform];
    if (list == null || list.isEmpty) return false;
    return list.any((l) => l.status == ListingStatus.actief);
  }

  ListingStatus? statusOn(MarketplacePlatform platform) {
    final list = listings[platform];
    if (list == null || list.isEmpty) return null;
    if (list.any((l) => l.status == ListingStatus.actief)) return ListingStatus.actief;
    if (list.any((l) => l.status == ListingStatus.gepauzeerd)) return ListingStatus.gepauzeerd;
    if (list.any((l) => l.status == ListingStatus.fout)) return ListingStatus.fout;
    if (list.any((l) => l.status == ListingStatus.concept)) return ListingStatus.concept;
    return list.first.status;
  }

  double? prijsOp(MarketplacePlatform platform) {
    final list = listings[platform];
    if (list == null || list.isEmpty) return null;
    final active = list.where((l) => l.status == ListingStatus.actief);
    if (active.isNotEmpty) return active.first.prijs;
    return list.first.prijs;
  }

  String? taalOp(MarketplacePlatform platform) {
    final list = listings[platform];
    if (list == null || list.isEmpty) return null;
    return list.map((l) => l.taal.toUpperCase()).join(', ');
  }

  MarketplaceListing? primaryListing(MarketplacePlatform platform) {
    final list = listings[platform];
    if (list == null || list.isEmpty) return null;
    final active = list.where((l) => l.status == ListingStatus.actief);
    if (active.isNotEmpty) return active.first;
    return list.first;
  }

  int get activeCount => MarketplacePlatform.values.where(isActiveOn).length;

  bool get isUitverkocht => voorraad <= 0;
  bool get isLaagOpVoorraad => voorraad > 0 && voorraad < 5;
}

class StockCheckResult {
  int totalStock = 0;
  int synced = 0;
  int paused = 0;
  int closed = 0;
  int reactivated = 0;
  List<String> warnings = [];

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hadActions => paused > 0 || closed > 0 || reactivated > 0;
}
