import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'marketplace_service.dart';
import '../models/marketplace_listing.dart';

class InventoryItem {
  final int? id;
  final int? productId;
  final String? eanCode;
  final String? artikelnummer;
  final String variantLabel;
  final String kleur;
  final String? leverancierCode;
  final String? categorie;
  final int voorraadActueel;
  final int voorraadMinimum;
  final int voorraadBesteld;
  final double? inkoopPrijs;
  final double? vliegtuigKosten;
  final double? invoertaxAdmin;
  final double? inkoopTotaal;
  final double? nettoInkoop;
  final double? nettoInkoopWaarde;
  final double? importKosten;
  final double? brutoInkoop;
  final double? verkoopprijsIncl;
  final double? verkoopprijsExcl;
  final double? verkoopWaardeExcl;
  final double? verkoopWaardeIncl;
  final double? marge;
  final String? vervoerMethode;
  final String? opmerking;
  final int? gewichtGram;
  final int? gewichtVerpakkingGram;
  final bool isArchived;
  final DateTime? laatstBijgewerkt;

  const InventoryItem({
    this.id,
    this.productId,
    this.eanCode,
    this.artikelnummer,
    this.variantLabel = '',
    this.kleur = '',
    this.leverancierCode,
    this.categorie,
    this.voorraadActueel = 0,
    this.voorraadMinimum = 0,
    this.voorraadBesteld = 0,
    this.inkoopPrijs,
    this.vliegtuigKosten,
    this.invoertaxAdmin,
    this.inkoopTotaal,
    this.nettoInkoop,
    this.nettoInkoopWaarde,
    this.importKosten,
    this.brutoInkoop,
    this.verkoopprijsIncl,
    this.verkoopprijsExcl,
    this.verkoopWaardeExcl,
    this.verkoopWaardeIncl,
    this.marge,
    this.vervoerMethode,
    this.opmerking,
    this.gewichtGram,
    this.gewichtVerpakkingGram,
    this.isArchived = false,
    this.laatstBijgewerkt,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    id: json['id'] as int?,
    productId: json['product_id'] as int?,
    eanCode: json['ean_code'] as String?,
    artikelnummer: json['artikelnummer'] as String?,
    variantLabel: (json['variant_label'] as String?) ?? '',
    kleur: (json['kleur'] as String?) ?? '',
    leverancierCode: json['leverancier_code'] as String?,
    categorie: json['categorie'] as String?,
    voorraadActueel: (json['voorraad_actueel'] as int?) ?? 0,
    voorraadMinimum: (json['voorraad_minimum'] as int?) ?? 0,
    voorraadBesteld: (json['voorraad_besteld'] as int?) ?? 0,
    inkoopPrijs: (json['inkoop_prijs'] as num?)?.toDouble(),
    vliegtuigKosten: (json['vliegtuig_kosten'] as num?)?.toDouble(),
    invoertaxAdmin: (json['invoertax_admin'] as num?)?.toDouble(),
    inkoopTotaal: (json['inkoop_totaal'] as num?)?.toDouble(),
    nettoInkoop: (json['netto_inkoop'] as num?)?.toDouble(),
    nettoInkoopWaarde: (json['netto_inkoop_waarde'] as num?)?.toDouble(),
    importKosten: (json['import_kosten'] as num?)?.toDouble(),
    brutoInkoop: (json['bruto_inkoop'] as num?)?.toDouble(),
    verkoopprijsIncl: (json['verkoopprijs_incl'] as num?)?.toDouble(),
    verkoopprijsExcl: (json['verkoopprijs_excl'] as num?)?.toDouble(),
    verkoopWaardeExcl: (json['verkoop_waarde_excl'] as num?)?.toDouble(),
    verkoopWaardeIncl: (json['verkoop_waarde_incl'] as num?)?.toDouble(),
    marge: (json['marge'] as num?)?.toDouble(),
    vervoerMethode: json['vervoer_methode'] as String?,
    opmerking: json['opmerking'] as String?,
    gewichtGram: json['gewicht_gram'] as int?,
    gewichtVerpakkingGram: json['gewicht_verpakking_gram'] as int?,
    isArchived: (json['is_archived'] as bool?) ?? false,
    laatstBijgewerkt: json['laatst_bijgewerkt'] != null
        ? DateTime.tryParse(json['laatst_bijgewerkt'] as String)
        : null,
  );

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'variant_label': variantLabel,
      'kleur': kleur,
      'voorraad_actueel': voorraadActueel,
      'voorraad_minimum': voorraadMinimum,
      'voorraad_besteld': voorraadBesteld,
      'laatst_bijgewerkt': DateTime.now().toUtc().toIso8601String(),
    };
    if (productId != null) m['product_id'] = productId;
    if (eanCode != null) m['ean_code'] = eanCode;
    if (artikelnummer != null) m['artikelnummer'] = artikelnummer;
    if (leverancierCode != null) m['leverancier_code'] = leverancierCode;
    if (categorie != null) m['categorie'] = categorie;
    if (inkoopPrijs != null) m['inkoop_prijs'] = inkoopPrijs;
    if (vliegtuigKosten != null) m['vliegtuig_kosten'] = vliegtuigKosten;
    if (invoertaxAdmin != null) m['invoertax_admin'] = invoertaxAdmin;
    if (inkoopTotaal != null) m['inkoop_totaal'] = inkoopTotaal;
    if (nettoInkoop != null) m['netto_inkoop'] = nettoInkoop;
    if (nettoInkoopWaarde != null) m['netto_inkoop_waarde'] = nettoInkoopWaarde;
    if (importKosten != null) m['import_kosten'] = importKosten;
    if (brutoInkoop != null) m['bruto_inkoop'] = brutoInkoop;
    if (verkoopprijsIncl != null) m['verkoopprijs_incl'] = verkoopprijsIncl;
    if (verkoopprijsExcl != null) m['verkoopprijs_excl'] = verkoopprijsExcl;
    if (verkoopWaardeExcl != null) m['verkoop_waarde_excl'] = verkoopWaardeExcl;
    if (verkoopWaardeIncl != null) m['verkoop_waarde_incl'] = verkoopWaardeIncl;
    if (marge != null) m['marge'] = marge;
    if (vervoerMethode != null) m['vervoer_methode'] = vervoerMethode;
    if (opmerking != null) m['opmerking'] = opmerking;
    if (gewichtGram != null) m['gewicht_gram'] = gewichtGram;
    if (gewichtVerpakkingGram != null) m['gewicht_verpakking_gram'] = gewichtVerpakkingGram;
    m['is_archived'] = isArchived;
    return m;
  }

  int get totaalGewicht => (gewichtGram ?? 0) + (gewichtVerpakkingGram ?? 0);

  InventoryItem copyWith({
    int? id,
    int? productId,
    String? eanCode,
    String? artikelnummer,
    String? variantLabel,
    String? kleur,
    String? leverancierCode,
    String? categorie,
    int? voorraadActueel,
    int? voorraadMinimum,
    int? voorraadBesteld,
    double? inkoopPrijs,
    double? vliegtuigKosten,
    double? invoertaxAdmin,
    double? inkoopTotaal,
    double? nettoInkoop,
    double? nettoInkoopWaarde,
    double? importKosten,
    double? brutoInkoop,
    double? verkoopprijsIncl,
    double? verkoopprijsExcl,
    double? verkoopWaardeExcl,
    double? verkoopWaardeIncl,
    double? marge,
    String? vervoerMethode,
    String? opmerking,
    int? gewichtGram,
    int? gewichtVerpakkingGram,
    bool? isArchived,
  }) => InventoryItem(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    eanCode: eanCode ?? this.eanCode,
    artikelnummer: artikelnummer ?? this.artikelnummer,
    variantLabel: variantLabel ?? this.variantLabel,
    kleur: kleur ?? this.kleur,
    leverancierCode: leverancierCode ?? this.leverancierCode,
    categorie: categorie ?? this.categorie,
    voorraadActueel: voorraadActueel ?? this.voorraadActueel,
    voorraadMinimum: voorraadMinimum ?? this.voorraadMinimum,
    voorraadBesteld: voorraadBesteld ?? this.voorraadBesteld,
    inkoopPrijs: inkoopPrijs ?? this.inkoopPrijs,
    vliegtuigKosten: vliegtuigKosten ?? this.vliegtuigKosten,
    invoertaxAdmin: invoertaxAdmin ?? this.invoertaxAdmin,
    inkoopTotaal: inkoopTotaal ?? this.inkoopTotaal,
    nettoInkoop: nettoInkoop ?? this.nettoInkoop,
    nettoInkoopWaarde: nettoInkoopWaarde ?? this.nettoInkoopWaarde,
    importKosten: importKosten ?? this.importKosten,
    brutoInkoop: brutoInkoop ?? this.brutoInkoop,
    verkoopprijsIncl: verkoopprijsIncl ?? this.verkoopprijsIncl,
    verkoopprijsExcl: verkoopprijsExcl ?? this.verkoopprijsExcl,
    verkoopWaardeExcl: verkoopWaardeExcl ?? this.verkoopWaardeExcl,
    verkoopWaardeIncl: verkoopWaardeIncl ?? this.verkoopWaardeIncl,
    marge: marge ?? this.marge,
    vervoerMethode: vervoerMethode ?? this.vervoerMethode,
    opmerking: opmerking ?? this.opmerking,
    gewichtGram: gewichtGram ?? this.gewichtGram,
    gewichtVerpakkingGram: gewichtVerpakkingGram ?? this.gewichtVerpakkingGram,
    isArchived: isArchived ?? this.isArchived,
  );
}

class InventoryMutation {
  final int? id;
  final int inventoryItemId;
  final int hoeveelheidDelta;
  final String reden;
  final String bron;
  final String? gebruikerId;
  final String? verkoopkanaalCode;
  final String? orderNummer;
  final String? klantId;
  final String? klantNaam;
  final String mutatieType;
  final String? externOrderNummer;
  final DateTime? createdAt;

  // Joined fields (not stored, populated via queries)
  final String? itemVariantLabel;
  final String? itemKleur;
  final String? itemArtikelNummer;

  const InventoryMutation({
    this.id,
    required this.inventoryItemId,
    required this.hoeveelheidDelta,
    this.reden = '',
    this.bron = 'handmatig',
    this.gebruikerId,
    this.verkoopkanaalCode,
    this.orderNummer,
    this.klantId,
    this.klantNaam,
    this.mutatieType = 'correctie',
    this.externOrderNummer,
    this.createdAt,
    this.itemVariantLabel,
    this.itemKleur,
    this.itemArtikelNummer,
  });

  factory InventoryMutation.fromJson(Map<String, dynamic> json) {
    final itemData = json['inventory_items'];
    return InventoryMutation(
      id: json['id'] as int?,
      inventoryItemId: json['inventory_item_id'] as int,
      hoeveelheidDelta: json['hoeveelheid_delta'] as int,
      reden: (json['reden'] as String?) ?? '',
      bron: (json['bron'] as String?) ?? 'handmatig',
      gebruikerId: json['gebruiker_id'] as String?,
      verkoopkanaalCode: json['verkoopkanaal_code'] as String?,
      orderNummer: json['order_nummer'] as String?,
      klantId: json['klant_id'] as String?,
      klantNaam: json['klant_naam'] as String?,
      mutatieType: (json['mutatie_type'] as String?) ?? 'correctie',
      externOrderNummer: json['extern_order_nummer'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      itemVariantLabel: itemData != null ? (itemData['variant_label'] as String?) : null,
      itemKleur: itemData != null ? (itemData['kleur'] as String?) : null,
      itemArtikelNummer: itemData != null ? (itemData['artikelnummer'] as String?) : null,
    );
  }

  static const mutatieTypes = <String, String>{
    'verkoop': 'Verkoop',
    'inkoop': 'Inkoop',
    'correctie': 'Correctie',
    'retour': 'Retour',
    'import': 'Import',
  };

  String get mutatieTypeLabel => mutatieTypes[mutatieType] ?? mutatieType;
}

class EanRegistryEntry {
  final int? id;
  final int artikelnummer;
  final String eanCode;
  final String? productNaam;
  final String? variant;
  final String? kleur;
  final String? opmerking;
  final bool actief;

  const EanRegistryEntry({
    this.id,
    required this.artikelnummer,
    required this.eanCode,
    this.productNaam,
    this.variant,
    this.kleur,
    this.opmerking,
    this.actief = true,
  });

  factory EanRegistryEntry.fromJson(Map<String, dynamic> json) => EanRegistryEntry(
    id: json['id'] as int?,
    artikelnummer: json['artikelnummer'] as int,
    eanCode: json['ean_code'] as String,
    productNaam: json['product_naam'] as String?,
    variant: json['variant'] as String?,
    kleur: json['kleur'] as String?,
    opmerking: json['opmerking'] as String?,
    actief: (json['actief'] as bool?) ?? true,
  );

  Map<String, dynamic> toJson() => {
    'artikelnummer': artikelnummer,
    'ean_code': eanCode,
    'product_naam': productNaam,
    'variant': variant,
    'kleur': kleur,
    'opmerking': opmerking,
    'actief': actief,
  };
}

class SailNumberLetter {
  final int? id;
  final String type; // 'nummer' or 'letter'
  final String waarde;
  final int maatMm; // 230 or 300
  final int voorraad;
  final String? opmerking;

  const SailNumberLetter({
    this.id,
    required this.type,
    required this.waarde,
    required this.maatMm,
    this.voorraad = 0,
    this.opmerking,
  });

  factory SailNumberLetter.fromJson(Map<String, dynamic> json) => SailNumberLetter(
    id: json['id'] as int?,
    type: json['type'] as String,
    waarde: json['waarde'] as String,
    maatMm: json['maat_mm'] as int,
    voorraad: (json['voorraad'] as int?) ?? 0,
    opmerking: json['opmerking'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'type': type,
    'waarde': waarde,
    'maat_mm': maatMm,
    'voorraad': voorraad,
    if (opmerking != null) 'opmerking': opmerking,
    'laatst_bijgewerkt': DateTime.now().toUtc().toIso8601String(),
  };
}

class CsvImportRow {
  final String? categorie;
  final String? productNaam;
  final String? kleur;
  final String? artikelnummer;
  final String? eanCode;
  final int? voorraad;
  final int? voorraadMinimum;
  final int? voorraadBesteld;
  final double? inkoopPrijs;
  final double? vliegtuigKosten;
  final double? invoertaxAdmin;
  final double? inkoopTotaal;
  final double? nettoInkoop;
  final double? nettoInkoopWaarde;
  final double? importKosten;
  final double? brutoInkoop;
  final double? verkoopprijsIncl;
  final double? verkoopprijsExcl;
  final double? verkoopWaardeExcl;
  final double? verkoopWaardeIncl;
  final double? marge;
  final int? gewichtGram;
  final int? gewichtVerpakkingGram;
  final String? vervoerMethode;
  final String? leverancierCode;
  final String? opmerking;

  String? matchedStatus;
  int? matchedProductId;
  String? matchedProductNaam;

  CsvImportRow({
    this.categorie,
    this.productNaam,
    this.kleur,
    this.artikelnummer,
    this.eanCode,
    this.voorraad,
    this.voorraadMinimum,
    this.voorraadBesteld,
    this.inkoopPrijs,
    this.vliegtuigKosten,
    this.invoertaxAdmin,
    this.inkoopTotaal,
    this.nettoInkoop,
    this.nettoInkoopWaarde,
    this.importKosten,
    this.brutoInkoop,
    this.verkoopprijsIncl,
    this.verkoopprijsExcl,
    this.verkoopWaardeExcl,
    this.verkoopWaardeIncl,
    this.marge,
    this.gewichtGram,
    this.gewichtVerpakkingGram,
    this.vervoerMethode,
    this.leverancierCode,
    this.opmerking,
  });
}

class InventoryService {
  final _client = Supabase.instance.client;

  // ── Inventory Items CRUD ──

  Future<List<InventoryItem>> getAll() async {
    try {
      final List<dynamic> rows = await _client
          .from('inventory_items')
          .select()
          .eq('is_archived', false)
          .order('artikelnummer', ascending: true)
          .order('kleur', ascending: true);
      return rows.cast<Map<String, dynamic>>().map(InventoryItem.fromJson).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('InventoryService.getAll error: $e');
      return [];
    }
  }

  Future<List<InventoryItem>> getAllArchived() async {
    try {
      final List<dynamic> rows = await _client
          .from('inventory_items')
          .select()
          .eq('is_archived', true)
          .order('artikelnummer', ascending: true)
          .order('kleur', ascending: true);
      return rows.cast<Map<String, dynamic>>().map(InventoryItem.fromJson).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('InventoryService.getAllArchived error: $e');
      return [];
    }
  }

  Future<void> archiveItems(List<int> ids) async {
    for (final id in ids) {
      await _client
          .from('inventory_items')
          .update({'is_archived': true, 'laatst_bijgewerkt': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
    }
  }

  Future<void> unarchiveItems(List<int> ids) async {
    for (final id in ids) {
      await _client
          .from('inventory_items')
          .update({'is_archived': false, 'laatst_bijgewerkt': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
    }
  }

  Future<InventoryItem?> getById(int id) async {
    try {
      final row = await _client
          .from('inventory_items')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return InventoryItem.fromJson(row);
    } catch (e) {
      if (kDebugMode) debugPrint('InventoryService.getById error: $e');
      return null;
    }
  }

  Future<List<InventoryItem>> getByProductId(int productId) async {
    try {
      final List<dynamic> rows = await _client
          .from('inventory_items')
          .select()
          .eq('product_id', productId)
          .order('leverancier_code', ascending: true);
      return rows.cast<Map<String, dynamic>>().map(InventoryItem.fromJson).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('InventoryService.getByProductId error: $e');
      return [];
    }
  }

  Future<int> getTotalStock(int productId) async {
    final items = await getByProductId(productId);
    return items.fold<int>(0, (sum, i) => sum + i.voorraadActueel);
  }

  Future<InventoryItem?> save(InventoryItem item) async {
    try {
      final json = item.toJson();
      if (item.id != null) {
        final rows = await _client
            .from('inventory_items')
            .update(json)
            .eq('id', item.id!)
            .select();
        if (rows.isNotEmpty) {
          return InventoryItem.fromJson(rows.first);
        }
      } else {
        final rows = await _client
            .from('inventory_items')
            .insert(json)
            .select();
        if (rows.isNotEmpty) {
          return InventoryItem.fromJson(rows.first);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('InventoryService.save error: $e');
      rethrow;
    }
    return null;
  }

  Future<void> delete(int id) async {
    await _client.from('inventory_items').delete().eq('id', id);
  }

  // ── Stock mutations ──

  Future<void> adjustStock(
    int itemId,
    int delta,
    String reden, {
    String bron = 'handmatig',
    String mutatieType = 'correctie',
    String? verkoopkanaalCode,
    String? orderNummer,
    String? klantId,
    String? klantNaam,
    String? externOrderNummer,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final mutData = <String, dynamic>{
      'inventory_item_id': itemId,
      'hoeveelheid_delta': delta,
      'reden': reden,
      'bron': bron,
      'mutatie_type': mutatieType,
    };
    if (userId != null) mutData['gebruiker_id'] = userId;
    if (verkoopkanaalCode != null) mutData['verkoopkanaal_code'] = verkoopkanaalCode;
    if (orderNummer != null) mutData['order_nummer'] = orderNummer;
    if (klantId != null) mutData['klant_id'] = klantId;
    if (klantNaam != null) mutData['klant_naam'] = klantNaam;
    if (externOrderNummer != null) mutData['extern_order_nummer'] = externOrderNummer;

    await _client.from('inventory_mutations').insert(mutData);

    final current = await _client
        .from('inventory_items')
        .select('voorraad_actueel')
        .eq('id', itemId)
        .single();
    final newStock = ((current['voorraad_actueel'] as int?) ?? 0) + delta;

    await _client.from('inventory_items').update({
      'voorraad_actueel': newStock < 0 ? 0 : newStock,
      'laatst_bijgewerkt': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', itemId);

    // Sync stock to connected marketplaces (fire-and-forget)
    final item = await getById(itemId);
    if (item?.productId != null) {
      MarketplaceService().syncStock(item!.productId!).catchError((e) {
        if (kDebugMode) debugPrint('Marketplace stock sync after adjustStock: $e');
        return StockCheckResult();
      });
    }
  }

  Future<List<InventoryMutation>> getMutations(int itemId, {int limit = 50}) async {
    try {
      final List<dynamic> rows = await _client
          .from('inventory_mutations')
          .select('*, inventory_items(variant_label, kleur, artikelnummer)')
          .eq('inventory_item_id', itemId)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.cast<Map<String, dynamic>>().map(InventoryMutation.fromJson).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('InventoryService.getMutations error: $e');
      return [];
    }
  }

  Future<List<InventoryMutation>> getAllMutations({
    int limit = 100,
    int offset = 0,
    String? search,
    String? mutatieType,
    String? verkoopkanaalCode,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      var query = _client
          .from('inventory_mutations')
          .select('*, inventory_items(variant_label, kleur, artikelnummer)');

      if (mutatieType != null && mutatieType.isNotEmpty) {
        query = query.eq('mutatie_type', mutatieType);
      }
      if (verkoopkanaalCode != null && verkoopkanaalCode.isNotEmpty) {
        query = query.eq('verkoopkanaal_code', verkoopkanaalCode);
      }
      if (from != null) {
        query = query.gte('created_at', from.toIso8601String());
      }
      if (to != null) {
        query = query.lte('created_at', to.toIso8601String());
      }
      if (search != null && search.trim().isNotEmpty) {
        final sanitized = search.trim().replaceAll(RegExp(r'[,\(\)\.\\\"]'), '');
        final s = '%$sanitized%';
        query = query.or('reden.ilike.$s,order_nummer.ilike.$s,klant_naam.ilike.$s');
      }

      final List<dynamic> rows = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return rows.cast<Map<String, dynamic>>().map(InventoryMutation.fromJson).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('InventoryService.getAllMutations error: $e');
      return [];
    }
  }

  // ── Sync product_catalogus.in_stock based on inventory ──

  Future<void> syncProductStock(int productId) async {
    final total = await getTotalStock(productId);
    await _client.from('product_catalogus').update({
      'in_stock': total > 0,
    }).eq('id', productId);

    // Sync stock to connected marketplaces (fire-and-forget)
    MarketplaceService().syncStock(productId).catchError((e) {
      if (kDebugMode) debugPrint('Marketplace stock sync after syncProductStock: $e');
      return StockCheckResult();
    });
  }

  // ── EAN Registry ──

  Future<List<EanRegistryEntry>> getAllEan() async {
    try {
      final List<dynamic> rows = await _client
          .from('ean_registry')
          .select()
          .order('artikelnummer', ascending: true);
      return rows.cast<Map<String, dynamic>>().map(EanRegistryEntry.fromJson).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('InventoryService.getAllEan error: $e');
      return [];
    }
  }

  Future<EanRegistryEntry?> saveEan(EanRegistryEntry entry) async {
    try {
      final json = entry.toJson();
      if (entry.id != null) {
        final rows = await _client.from('ean_registry').update(json).eq('id', entry.id!).select();
        if (rows.isNotEmpty) return EanRegistryEntry.fromJson(rows.first);
      } else {
        final rows = await _client.from('ean_registry').insert(json).select();
        if (rows.isNotEmpty) return EanRegistryEntry.fromJson(rows.first);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('InventoryService.saveEan error: $e');
      rethrow;
    }
    return null;
  }

  Future<EanRegistryEntry?> findNextAvailableEan() async {
    final all = await getAllEan();
    final inactive = all.where((e) => !e.actief).toList();
    if (inactive.isNotEmpty) return inactive.first;
    return null;
  }

  Future<void> reassignEan(int eanId, {required String productNaam, String? variant, String? kleur}) async {
    await _client.from('ean_registry').update({
      'product_naam': productNaam,
      'variant': variant,
      'kleur': kleur,
      'actief': true,
    }).eq('id', eanId);
  }

  // ── Sail Numbers / Letters ──

  Future<List<SailNumberLetter>> getAllSailItems() async {
    try {
      final List<dynamic> rows = await _client
          .from('sail_numbers_letters')
          .select()
          .order('maat_mm', ascending: true)
          .order('type', ascending: true)
          .order('waarde', ascending: true);
      return rows.cast<Map<String, dynamic>>().map(SailNumberLetter.fromJson).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('InventoryService.getAllSailItems error: $e');
      return [];
    }
  }

  Future<void> updateSailStock(int id, int newStock) async {
    await _client.from('sail_numbers_letters').update({
      'voorraad': newStock < 0 ? 0 : newStock,
      'laatst_bijgewerkt': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> saveSailItem(SailNumberLetter item) async {
    if (item.id != null) {
      await _client.from('sail_numbers_letters').update(item.toJson()).eq('id', item.id!);
    } else {
      await _client.from('sail_numbers_letters').upsert(item.toJson(), onConflict: 'type,waarde,maat_mm');
    }
  }

  // ── CSV Import ──

  List<CsvImportRow> parseCsv(String csvContent) {
    final lines = const LineSplitter().convert(csvContent);
    if (lines.isEmpty) return [];

    // Auto-detect delimiter: semicolon-separated CSVs have more semicolons than commas in the header
    final firstLine = lines.first;
    final delimiter = firstLine.split(';').length > firstLine.split(',').length ? ';' : ',';

    final header = _parseCsvLine(firstLine, delimiter: delimiter).map((h) => h.toLowerCase().trim()).toList();
    final rows = <CsvImportRow>[];

    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;
      final cells = _parseCsvLine(lines[i], delimiter: delimiter);
      if (cells.length < 2) continue;

      String? col(String name) {
        final idx = header.indexOf(name);
        if (idx < 0 || idx >= cells.length) return null;
        final v = cells[idx].trim();
        return v.isEmpty ? null : v;
      }
      int? intCol(String name) {
        final v = col(name);
        if (v == null) return null;
        final cleaned = v.replaceAll(RegExp(r'[^0-9-]'), '');
        final parsed = int.tryParse(cleaned);
        if (parsed == null) return null;
        // Sanity: stock/besteld values above 100000 are likely EAN codes or errors
        if (parsed > 100000 && (name == 'besteld' || name == 'voorraad' || name == 'minimaal')) return null;
        return parsed;
      }
      double? dblCol(String name) {
        final v = col(name);
        return v != null ? double.tryParse(v.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.-]'), '')) : null;
      }

      final productName = col('product') ?? col('productnaam') ?? col('naam');
      final pLower = (productName ?? '').toLowerCase().trim();
      final catLower = (col('categorie') ?? col('category') ?? '').toLowerCase().trim();

      // Skip totaal/summary rows
      if (pLower == 'totaal' || pLower == 'totalen' || pLower == 'subtotaal' || pLower == 'total') continue;

      // Skip packaging/box rows
      const boxNames = {'wit kleinste', 'wit middel', 'midden', 'groot', 'lang standaard', 'lang groot', 'splash', 'mk ii', 'valk', 'doos', 'karton', 'verpakking'};
      if (boxNames.contains(pLower) || catLower == 'dozen') continue;

      // Clean #REF! values
      var artNr = col('artikelnummer') ?? col('artikelnr') ?? col('article');
      var ean = col('ean') ?? col('ean_code') ?? col('ean code');
      if (artNr != null && artNr.contains('#REF')) artNr = null;
      if (ean != null && ean.contains('#REF')) ean = null;

      rows.add(CsvImportRow(
        categorie: col('categorie') ?? col('category'),
        productNaam: productName,
        kleur: col('kleur') ?? col('color'),
        artikelnummer: artNr,
        eanCode: ean,
        voorraad: intCol('voorraad') ?? intCol('stock') ?? intCol('huidige voorraad'),
        voorraadMinimum: intCol('minimaal') ?? intCol('minimum') ?? intCol('min'),
        voorraadBesteld: intCol('besteld') ?? intCol('aantal besteld'),
        inkoopPrijs: dblCol('inkoop') ?? dblCol('inkoop_prijs') ?? dblCol('cost'),
        vliegtuigKosten: dblCol('vliegtuig_kosten') ?? dblCol('extra vliegtuig kosten'),
        invoertaxAdmin: dblCol('invoertax_admin') ?? dblCol('invoertax') ?? dblCol('invoertax+ administratie'),
        inkoopTotaal: dblCol('inkoop_totaal') ?? dblCol('inkoop prijs totaal'),
        nettoInkoop: dblCol('netto_inkoop') ?? dblCol('netto inkoop'),
        nettoInkoopWaarde: dblCol('netto_inkoop_waarde') ?? dblCol('netto inkoop waarde'),
        importKosten: dblCol('import_kosten') ?? dblCol('import'),
        brutoInkoop: dblCol('bruto_inkoop') ?? dblCol('bruto inkoop waarde'),
        verkoopprijsIncl: dblCol('verkoopprijs_incl') ?? dblCol('verkoop prijs (incl.)') ?? dblCol('verkoopprijs incl'),
        verkoopprijsExcl: dblCol('verkoopprijs_excl') ?? dblCol('verkoop prijs (excl.)') ?? dblCol('verkoopprijs excl'),
        verkoopWaardeExcl: dblCol('verkoop_waarde_excl') ?? dblCol('verkoop waarde (excl.)'),
        verkoopWaardeIncl: dblCol('verkoop_waarde_incl') ?? dblCol('verkoop waarde (incl.)'),
        marge: dblCol('marge') ?? dblCol('verkoopprijs gedeeld door inkoopprijs'),
        gewichtGram: intCol('gewicht') ?? intCol('gewicht zeil (gram)') ?? intCol('weight'),
        gewichtVerpakkingGram: intCol('gewicht_verpakking') ?? intCol('gewicht verpakking') ?? intCol('gweicht verpakking (gram)'),
        vervoerMethode: col('vervoer') ?? col('transport'),
        leverancierCode: col('code') ?? col('leverancier_code') ?? col('ve_code'),
        opmerking: col('opmerking') ?? col('notes'),
      ));
    }
    return rows;
  }

  List<String> _parseCsvLine(String line, {String delimiter = ';'}) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == delimiter && !inQuotes) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(c);
      }
    }
    result.add(current.toString());
    return result;
  }

  Future<int> importCsvRows(List<CsvImportRow> rows, {bool updateWeights = true, bool updatePrices = true}) async {
    int imported = 0;
    final userId = _client.auth.currentUser?.id;

    for (final row in rows) {
      if (row.matchedStatus == 'error') continue;

      try {
        final json = <String, dynamic>{
          'variant_label': row.productNaam ?? '',
          'kleur': row.kleur ?? '',
          'voorraad_actueel': row.voorraad ?? 0,
          'voorraad_minimum': row.voorraadMinimum ?? 0,
          'voorraad_besteld': row.voorraadBesteld ?? 0,
          'laatst_bijgewerkt': DateTime.now().toUtc().toIso8601String(),
        };

        if (row.matchedProductId != null) json['product_id'] = row.matchedProductId;
        if (row.categorie != null) json['categorie'] = row.categorie;
        if (row.eanCode != null) json['ean_code'] = row.eanCode;
        if (row.artikelnummer != null) json['artikelnummer'] = row.artikelnummer;
        if (row.leverancierCode != null) json['leverancier_code'] = row.leverancierCode;
        if (row.opmerking != null) json['opmerking'] = row.opmerking;
        if (row.vervoerMethode != null) json['vervoer_methode'] = row.vervoerMethode;
        if (updatePrices) {
          if (row.inkoopPrijs != null) json['inkoop_prijs'] = row.inkoopPrijs;
          if (row.vliegtuigKosten != null) json['vliegtuig_kosten'] = row.vliegtuigKosten;
          if (row.invoertaxAdmin != null) json['invoertax_admin'] = row.invoertaxAdmin;
          if (row.inkoopTotaal != null) json['inkoop_totaal'] = row.inkoopTotaal;
          if (row.nettoInkoop != null) json['netto_inkoop'] = row.nettoInkoop;
          if (row.nettoInkoopWaarde != null) json['netto_inkoop_waarde'] = row.nettoInkoopWaarde;
          if (row.importKosten != null) json['import_kosten'] = row.importKosten;
          if (row.brutoInkoop != null) json['bruto_inkoop'] = row.brutoInkoop;
          if (row.verkoopprijsIncl != null) json['verkoopprijs_incl'] = row.verkoopprijsIncl;
          if (row.verkoopprijsExcl != null) json['verkoopprijs_excl'] = row.verkoopprijsExcl;
          if (row.verkoopWaardeExcl != null) json['verkoop_waarde_excl'] = row.verkoopWaardeExcl;
          if (row.verkoopWaardeIncl != null) json['verkoop_waarde_incl'] = row.verkoopWaardeIncl;
          if (row.marge != null) json['marge'] = row.marge;
        }
        if (updateWeights) {
          if (row.gewichtGram != null) json['gewicht_gram'] = row.gewichtGram;
          if (row.gewichtVerpakkingGram != null) json['gewicht_verpakking_gram'] = row.gewichtVerpakkingGram;
        }

        // Try to find existing item by leverancier_code+kleur (most specific), then EAN
        List<dynamic>? existing;
        if (row.leverancierCode != null && row.leverancierCode!.isNotEmpty) {
          var query = _client.from('inventory_items')
              .select('id,voorraad_actueel')
              .eq('leverancier_code', row.leverancierCode!);
          if (row.kleur != null && row.kleur!.isNotEmpty) {
            query = query.eq('kleur', row.kleur!);
          }
          existing = await query.limit(1);
        }
        if ((existing == null || existing.isEmpty) && row.eanCode != null && row.eanCode!.isNotEmpty) {
          existing = await _client.from('inventory_items')
              .select('id,voorraad_actueel')
              .eq('ean_code', row.eanCode!)
              .limit(1);
        }

        if (existing != null && existing.isNotEmpty) {
          final existingId = existing.first['id'] as int;
          final oldStock = (existing.first['voorraad_actueel'] as int?) ?? 0;
          await _client.from('inventory_items').update(json).eq('id', existingId);

          if (row.voorraad != null && row.voorraad != oldStock) {
            await _client.from('inventory_mutations').insert({
              'inventory_item_id': existingId,
              'hoeveelheid_delta': row.voorraad! - oldStock,
              'reden': 'CSV import update',
              'bron': 'csv_import',
              ...?userId != null ? {'gebruiker_id': userId} : null,
            });
          }
        } else {
          final inserted = await _client.from('inventory_items').insert(json).select();
          if (inserted.isNotEmpty && row.voorraad != null && row.voorraad! > 0) {
            await _client.from('inventory_mutations').insert({
              'inventory_item_id': inserted.first['id'] as int,
              'hoeveelheid_delta': row.voorraad!,
              'reden': 'Initiële CSV import',
              'bron': 'csv_import',
              ...?userId != null ? {'gebruiker_id': userId} : null,
            });
          }
        }
        imported++;
      } catch (e) {
        if (kDebugMode) debugPrint('Import row error: $e');
      }
    }
    return imported;
  }

  /// Replace mode: delete all existing inventory data and import fresh
  Future<int> replaceAllWithCsvRows(List<CsvImportRow> rows, {bool updateWeights = true, bool updatePrices = true}) async {
    await _client.from('inventory_mutations').delete().neq('id', 0);
    await _client.from('inventory_items').delete().neq('id', 0);

    final userId = _client.auth.currentUser?.id;
    int imported = 0;

    for (final row in rows) {
      if (row.matchedStatus == 'error') continue;

      try {
        final json = <String, dynamic>{
          'variant_label': row.productNaam ?? '',
          'kleur': row.kleur ?? '',
          'voorraad_actueel': row.voorraad ?? 0,
          'voorraad_minimum': row.voorraadMinimum ?? 0,
          'voorraad_besteld': row.voorraadBesteld ?? 0,
          'laatst_bijgewerkt': DateTime.now().toUtc().toIso8601String(),
        };

        if (row.matchedProductId != null) json['product_id'] = row.matchedProductId;
        if (row.categorie != null) json['categorie'] = row.categorie;
        if (row.eanCode != null) json['ean_code'] = row.eanCode;
        if (row.artikelnummer != null) json['artikelnummer'] = row.artikelnummer;
        if (row.leverancierCode != null) json['leverancier_code'] = row.leverancierCode;
        if (row.opmerking != null) json['opmerking'] = row.opmerking;
        if (row.vervoerMethode != null) json['vervoer_methode'] = row.vervoerMethode;
        if (updatePrices) {
          if (row.inkoopPrijs != null) json['inkoop_prijs'] = row.inkoopPrijs;
          if (row.vliegtuigKosten != null) json['vliegtuig_kosten'] = row.vliegtuigKosten;
          if (row.invoertaxAdmin != null) json['invoertax_admin'] = row.invoertaxAdmin;
          if (row.inkoopTotaal != null) json['inkoop_totaal'] = row.inkoopTotaal;
          if (row.nettoInkoop != null) json['netto_inkoop'] = row.nettoInkoop;
          if (row.nettoInkoopWaarde != null) json['netto_inkoop_waarde'] = row.nettoInkoopWaarde;
          if (row.importKosten != null) json['import_kosten'] = row.importKosten;
          if (row.brutoInkoop != null) json['bruto_inkoop'] = row.brutoInkoop;
          if (row.verkoopprijsIncl != null) json['verkoopprijs_incl'] = row.verkoopprijsIncl;
          if (row.verkoopprijsExcl != null) json['verkoopprijs_excl'] = row.verkoopprijsExcl;
          if (row.verkoopWaardeExcl != null) json['verkoop_waarde_excl'] = row.verkoopWaardeExcl;
          if (row.verkoopWaardeIncl != null) json['verkoop_waarde_incl'] = row.verkoopWaardeIncl;
          if (row.marge != null) json['marge'] = row.marge;
        }
        if (updateWeights) {
          if (row.gewichtGram != null) json['gewicht_gram'] = row.gewichtGram;
          if (row.gewichtVerpakkingGram != null) json['gewicht_verpakking_gram'] = row.gewichtVerpakkingGram;
        }

        final inserted = await _client.from('inventory_items').insert(json).select();
        if (inserted.isNotEmpty && row.voorraad != null && row.voorraad! != 0) {
          await _client.from('inventory_mutations').insert({
            'inventory_item_id': inserted.first['id'] as int,
            'hoeveelheid_delta': row.voorraad!,
            'reden': 'Volledige herimport',
            'bron': 'csv_replace',
            ...?userId != null ? {'gebruiker_id': userId} : null,
          });
        }
        imported++;
      } catch (e) {
        if (kDebugMode) debugPrint('Replace import row error: $e');
      }
    }
    return imported;
  }

  /// Verify import results: compare DB totals with CSV source totals.
  /// Returns a report with mismatches and overall stats.
  Future<ImportVerificationReport> verifyImport(List<CsvImportRow> csvRows) async {
    final dbItems = await getAll();
    final report = ImportVerificationReport();

    // CSV totals per product
    final csvByProduct = <String, _ProductTotals>{};
    for (final row in csvRows) {
      final key = (row.productNaam ?? '').trim().toLowerCase();
      if (key.isEmpty) continue;
      final t = csvByProduct.putIfAbsent(key, () => _ProductTotals(row.productNaam ?? ''));
      t.totalStock += row.voorraad ?? 0;
      t.totalCost += (row.inkoopPrijs ?? 0) * (row.voorraad ?? 0);
      t.rowCount++;
    }

    // DB totals per product
    final dbByProduct = <String, _ProductTotals>{};
    for (final item in dbItems) {
      final key = item.variantLabel.trim().toLowerCase();
      if (key.isEmpty) continue;
      final t = dbByProduct.putIfAbsent(key, () => _ProductTotals(item.variantLabel));
      t.totalStock += item.voorraadActueel;
      t.totalCost += (item.inkoopPrijs ?? 0) * item.voorraadActueel;
      t.rowCount++;
    }

    report.csvProductCount = csvByProduct.length;
    report.dbProductCount = dbByProduct.length;
    report.csvTotalRows = csvRows.length;
    report.dbTotalRows = dbItems.length;
    report.csvTotalStock = csvRows.fold(0, (s, r) => s + (r.voorraad ?? 0));
    report.dbTotalStock = dbItems.fold(0, (s, i) => s + i.voorraadActueel);

    // Check each CSV product against DB
    for (final entry in csvByProduct.entries) {
      final dbTotals = dbByProduct[entry.key];
      if (dbTotals == null) {
        report.mismatches.add(ImportMismatch(
          productName: entry.value.name,
          type: 'missing',
          csvValue: '${entry.value.totalStock} stk (${entry.value.rowCount} rijen)',
          dbValue: 'niet gevonden',
        ));
      } else if (dbTotals.totalStock != entry.value.totalStock) {
        report.mismatches.add(ImportMismatch(
          productName: entry.value.name,
          type: 'stock',
          csvValue: '${entry.value.totalStock}',
          dbValue: '${dbTotals.totalStock}',
        ));
      } else if (dbTotals.rowCount != entry.value.rowCount) {
        report.mismatches.add(ImportMismatch(
          productName: entry.value.name,
          type: 'rows',
          csvValue: '${entry.value.rowCount} rijen',
          dbValue: '${dbTotals.rowCount} rijen',
        ));
      }
    }

    return report;
  }

  /// Match import rows against existing catalog products
  Future<void> matchImportRows(List<CsvImportRow> rows) async {
    final List<dynamic> catalogRows = await _client
        .from('product_catalogus')
        .select('id,naam,artikelnummer,ean_code,categorie');
    final catalog = catalogRows.cast<Map<String, dynamic>>();

    for (final row in rows) {
      // 1. Match by EAN
      if (row.eanCode != null && row.eanCode!.isNotEmpty) {
        final match = catalog.where((p) => p['ean_code'] == row.eanCode).toList();
        if (match.isNotEmpty) {
          row.matchedStatus = 'matched';
          row.matchedProductId = match.first['id'] as int;
          row.matchedProductNaam = match.first['naam'] as String?;
          continue;
        }
      }
      // 2. Match by artikelnummer
      if (row.artikelnummer != null && row.artikelnummer!.isNotEmpty) {
        final match = catalog.where((p) => p['artikelnummer'] == row.artikelnummer).toList();
        if (match.isNotEmpty) {
          row.matchedStatus = 'matched';
          row.matchedProductId = match.first['id'] as int;
          row.matchedProductNaam = match.first['naam'] as String?;
          continue;
        }
      }
      // 3. Fuzzy match by product name
      if (row.productNaam != null && row.productNaam!.isNotEmpty) {
        final needle = row.productNaam!.toLowerCase();
        final match = catalog.where((p) {
          final name = ((p['naam'] as String?) ?? '').toLowerCase();
          return name.contains(needle) || needle.contains(name);
        }).toList();
        if (match.isNotEmpty) {
          row.matchedStatus = 'matched';
          row.matchedProductId = match.first['id'] as int;
          row.matchedProductNaam = match.first['naam'] as String?;
          continue;
        }
      }
      row.matchedStatus = 'new';
    }
  }

  // ── Weight-only CSV import → updates product_catalogus.gewicht + inventory_items ──

  Future<int> importWeightsCsv(List<CsvImportRow> rows) async {
    int updated = 0;

    final catalogRows = await _client.from('product_catalogus')
        .select('id,naam,artikelnummer,ean_code');
    final catalog = catalogRows.cast<Map<String, dynamic>>();

    final invRows = await _client.from('inventory_items')
        .select('id,variant_label,artikelnummer,ean_code');
    final inventory = invRows.cast<Map<String, dynamic>>();

    for (final row in rows) {
      final hasWeight = row.gewichtGram != null && row.gewichtGram! > 0;
      final hasPkgWeight = row.gewichtVerpakkingGram != null && row.gewichtVerpakkingGram! > 0;
      if (!hasWeight && !hasPkgWeight) continue;

      bool didUpdate = false;

      // ── 1. Update product_catalogus.gewicht ──
      final catMatches = _findCatalogMatches(catalog, row);
      for (final catId in catMatches) {
        if (hasWeight) {
          try {
            await _client.from('product_catalogus').update({
              'gewicht': row.gewichtGram!.toDouble(),
            }).eq('id', catId);
            didUpdate = true;
          } catch (e) {
            if (kDebugMode) debugPrint('importWeightsCsv catalogus error: $e');
          }
        }
      }

      // ── 2. Update inventory_items.gewicht_gram + gewicht_verpakking_gram ──
      final weightUpdate = <String, dynamic>{};
      if (hasWeight) weightUpdate['gewicht_gram'] = row.gewichtGram;
      if (hasPkgWeight) weightUpdate['gewicht_verpakking_gram'] = row.gewichtVerpakkingGram;

      if (weightUpdate.isNotEmpty) {
        final invMatches = _findInventoryMatches(inventory, row);
        for (final invId in invMatches) {
          try {
            await _client.from('inventory_items').update(weightUpdate).eq('id', invId);
            didUpdate = true;
          } catch (_) {}
        }
      }

      if (didUpdate) updated++;
    }
    return updated;
  }

  Set<int> _findCatalogMatches(List<Map<String, dynamic>> catalog, CsvImportRow row) {
    final matches = <int>{};
    final ean = row.eanCode?.trim() ?? '';
    final art = row.artikelnummer?.trim() ?? '';
    final artNumeric = art.replaceAll(RegExp(r'[^0-9]'), '');
    final name = (row.productNaam ?? '').toLowerCase().trim();

    for (final p in catalog) {
      final pId = p['id'] as int;
      final pEan = ((p['ean_code'] as String?) ?? '').trim();
      final pArt = ((p['artikelnummer'] as String?) ?? '').trim();
      final pArtNumeric = pArt.replaceAll(RegExp(r'[^0-9]'), '');
      final pName = ((p['naam'] as String?) ?? '').toLowerCase().trim();

      if (ean.isNotEmpty && pEan.isNotEmpty && ean == pEan) {
        matches.add(pId);
      } else if (art.isNotEmpty && pArt.isNotEmpty && (art == pArt || (artNumeric.isNotEmpty && artNumeric == pArtNumeric))) {
        matches.add(pId);
      } else if (name.isNotEmpty && pName.isNotEmpty && (pName.contains(name) || name.contains(pName))) {
        matches.add(pId);
      }
    }
    return matches;
  }

  Set<int> _findInventoryMatches(List<Map<String, dynamic>> inventory, CsvImportRow row) {
    final matches = <int>{};
    final ean = row.eanCode?.trim() ?? '';
    final art = row.artikelnummer?.trim() ?? '';
    final artNumeric = art.replaceAll(RegExp(r'[^0-9]'), '');
    final name = (row.productNaam ?? '').toLowerCase().trim();

    for (final inv in inventory) {
      final invId = inv['id'] as int;
      final invEan = ((inv['ean_code'] as String?) ?? '').trim();
      final invArt = ((inv['artikelnummer'] as String?) ?? '').trim();
      final invArtNumeric = invArt.replaceAll(RegExp(r'[^0-9]'), '');
      final invLabel = ((inv['variant_label'] as String?) ?? '').toLowerCase().trim();

      if (ean.isNotEmpty && invEan.isNotEmpty && ean == invEan) {
        matches.add(invId);
      } else if (art.isNotEmpty && invArt.isNotEmpty && (art == invArt || (artNumeric.isNotEmpty && artNumeric == invArtNumeric))) {
        matches.add(invId);
      } else if (name.isNotEmpty && invLabel.isNotEmpty && (invLabel.contains(name) || name.contains(invLabel))) {
        matches.add(invId);
      }
    }
    return matches;
  }

  /// Extract packaging/box rows from a stock CSV based on product name patterns.
  List<CsvImportRow> extractPackagingRows(List<CsvImportRow> rows) {
    final boxPatterns = [
      RegExp(r'doos', caseSensitive: false),
      RegExp(r'verpakking', caseSensitive: false),
      RegExp(r'karton', caseSensitive: false),
      RegExp(r'box', caseSensitive: false),
    ];

    return rows.where((row) {
      final name = (row.productNaam ?? '').toLowerCase();
      final cat = (row.categorie ?? '').toLowerCase();
      return boxPatterns.any((p) => p.hasMatch(name) || p.hasMatch(cat));
    }).toList();
  }

  // ── Auto-match unlinked inventory items to product_catalogus ──

  Future<List<InventoryMatchSuggestion>> autoMatchInventoryToProducts() async {
    final List<dynamic> unlinkedRows = await _client
        .from('inventory_items')
        .select()
        .isFilter('product_id', null)
        .eq('is_archived', false);
    final unlinked = unlinkedRows.cast<Map<String, dynamic>>().map(InventoryItem.fromJson).toList();
    if (unlinked.isEmpty) return [];

    final List<dynamic> catalogRows = await _client
        .from('product_catalogus')
        .select('id,naam,artikelnummer,ean_code');
    final catalog = catalogRows.cast<Map<String, dynamic>>();

    final suggestions = <InventoryMatchSuggestion>[];

    for (final item in unlinked) {
      InventoryMatchSuggestion? best;

      // Priority 1: exact EAN match
      if (item.eanCode != null && item.eanCode!.isNotEmpty) {
        final ean = item.eanCode!.trim();
        for (final p in catalog) {
          final pEan = ((p['ean_code'] as String?) ?? '').trim();
          if (pEan.isNotEmpty && pEan == ean) {
            best = InventoryMatchSuggestion(
              inventoryItem: item,
              productId: p['id'] as int,
              productNaam: (p['naam'] as String?) ?? '',
              matchMethod: 'EAN',
              matchScore: 100,
            );
            break;
          }
        }
      }

      // Priority 2: exact artikelnummer match
      if (best == null && item.artikelnummer != null && item.artikelnummer!.isNotEmpty) {
        final artClean = item.artikelnummer!.trim().toLowerCase();
        final artNumeric = artClean.replaceAll(RegExp(r'[^0-9]'), '');
        for (final p in catalog) {
          final pArt = ((p['artikelnummer'] as String?) ?? '').trim().toLowerCase();
          if (pArt.isNotEmpty && (pArt == artClean || (artNumeric.isNotEmpty && pArt.replaceAll(RegExp(r'[^0-9]'), '') == artNumeric))) {
            best = InventoryMatchSuggestion(
              inventoryItem: item,
              productId: p['id'] as int,
              productNaam: (p['naam'] as String?) ?? '',
              matchMethod: 'Artikelnr',
              matchScore: 95,
            );
            break;
          }
        }
      }

      // Priority 3: partial EAN (last 8+ digits)
      if (best == null && item.eanCode != null && item.eanCode!.trim().length >= 8) {
        final ean = item.eanCode!.trim();
        final tail = ean.length > 8 ? ean.substring(ean.length - 8) : ean;
        for (final p in catalog) {
          final pEan = ((p['ean_code'] as String?) ?? '').trim();
          if (pEan.length >= 8 && pEan.endsWith(tail)) {
            best = InventoryMatchSuggestion(
              inventoryItem: item,
              productId: p['id'] as int,
              productNaam: (p['naam'] as String?) ?? '',
              matchMethod: 'EAN deel',
              matchScore: 90,
            );
            break;
          }
        }
      }

      // Priority 4: fuzzy name match with improved scoring
      if (best == null && item.variantLabel.isNotEmpty) {
        final needle = _normalizeForMatch(item.variantLabel);
        int bestScore = 0;
        for (final p in catalog) {
          final pName = _normalizeForMatch((p['naam'] as String?) ?? '');
          if (pName.isEmpty) continue;
          final score = _fuzzyScore(needle, pName);
          if (score > bestScore && score >= 50) {
            bestScore = score;
            best = InventoryMatchSuggestion(
              inventoryItem: item,
              productId: p['id'] as int,
              productNaam: (p['naam'] as String?) ?? '',
              matchMethod: 'Naam',
              matchScore: score,
            );
          }
        }
      }

      // Priority 5: leverancier_code → artikelnummer match
      if (best == null && item.leverancierCode != null && item.leverancierCode!.isNotEmpty) {
        final lc = item.leverancierCode!.trim().toLowerCase();
        for (final p in catalog) {
          final pArt = ((p['artikelnummer'] as String?) ?? '').trim().toLowerCase();
          if (pArt.isNotEmpty && (pArt.contains(lc) || lc.contains(pArt))) {
            best = InventoryMatchSuggestion(
              inventoryItem: item,
              productId: p['id'] as int,
              productNaam: (p['naam'] as String?) ?? '',
              matchMethod: 'Lev.code',
              matchScore: 80,
            );
            break;
          }
        }
      }

      // Always add: matched items with approved=true if high score, unmatched with approved=false
      if (best != null) {
        best.approved = best.matchScore >= 90;
        suggestions.add(best);
      } else {
        suggestions.add(InventoryMatchSuggestion(
          inventoryItem: item,
          productId: catalog.isNotEmpty ? catalog.first['id'] as int : 0,
          productNaam: '',
          matchMethod: 'Geen',
          matchScore: 0,
          approved: false,
        ));
      }
    }

    // Sort: matched high-score first, then lower scores, unmatched last
    suggestions.sort((a, b) {
      if (a.matchScore == 0 && b.matchScore > 0) return 1;
      if (b.matchScore == 0 && a.matchScore > 0) return -1;
      return b.matchScore.compareTo(a.matchScore);
    });

    return suggestions;
  }

  static String _normalizeForMatch(String s) {
    return s.toLowerCase().trim()
        .replaceAll(RegExp(r'[/\-_.,;:()[\]{}]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int _fuzzyScore(String a, String b) {
    if (a == b) return 100;
    if (a.contains(b) || b.contains(a)) return 88;

    final wordsA = a.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    final wordsB = b.split(RegExp(r'\s+')).where((w) => w.length > 1).toSet();
    if (wordsA.isEmpty || wordsB.isEmpty) return 0;

    int matched = 0;
    for (final wa in wordsA) {
      for (final wb in wordsB) {
        if (wa == wb) { matched++; break; }
        if (wa.length >= 4 && wb.length >= 4 && (wa.contains(wb) || wb.contains(wa))) {
          matched++; break;
        }
      }
    }

    final total = wordsA.length > wordsB.length ? wordsA.length : wordsB.length;
    final score = ((matched / total) * 100).round();

    // Bonus for matching beginning (likely the product type)
    if (wordsA.isNotEmpty && wordsB.isNotEmpty && wordsA.first == wordsB.first) {
      return (score + 10).clamp(0, 100);
    }
    return score;
  }

  Future<void> linkInventoryToProduct(int inventoryItemId, int productId) async {
    await _client.from('inventory_items').update({
      'product_id': productId,
      'laatst_bijgewerkt': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', inventoryItemId);
  }

  // ── Aggregated inventory summary ──

  Future<Map<int, int>> getStockSummaryByProduct() async {
    final items = await getAll();
    final summary = <int, int>{};
    for (final item in items) {
      if (item.productId != null) {
        summary[item.productId!] = (summary[item.productId!] ?? 0) + item.voorraadActueel;
      }
    }
    return summary;
  }
}

class _ProductTotals {
  final String name;
  int totalStock = 0;
  double totalCost = 0;
  int rowCount = 0;
  _ProductTotals(this.name);
}

class InventoryMatchSuggestion {
  final InventoryItem inventoryItem;
  final int productId;
  final String productNaam;
  final String matchMethod; // 'EAN', 'Artikelnummer', 'Naam'
  final int matchScore; // 0-100

  bool approved;
  int? overrideProductId;

  InventoryMatchSuggestion({
    required this.inventoryItem,
    required this.productId,
    required this.productNaam,
    required this.matchMethod,
    required this.matchScore,
    this.approved = false,
    this.overrideProductId,
  });

  int get effectiveProductId => overrideProductId ?? productId;
}

class ImportMismatch {
  final String productName;
  final String type; // 'missing', 'stock', 'rows'
  final String csvValue;
  final String dbValue;

  ImportMismatch({
    required this.productName,
    required this.type,
    required this.csvValue,
    required this.dbValue,
  });

  String get description => switch (type) {
    'missing' => '$productName: ontbreekt in DB (CSV: $csvValue)',
    'stock' => '$productName: voorraad CSV=$csvValue, DB=$dbValue',
    'rows' => '$productName: rijen CSV=$csvValue, DB=$dbValue',
    _ => '$productName: $type verschil',
  };
}

class ImportVerificationReport {
  int csvProductCount = 0;
  int dbProductCount = 0;
  int csvTotalRows = 0;
  int dbTotalRows = 0;
  int csvTotalStock = 0;
  int dbTotalStock = 0;
  List<ImportMismatch> mismatches = [];

  bool get isOk => mismatches.isEmpty && csvTotalStock == dbTotalStock && csvTotalRows == dbTotalRows;

  String get summary {
    final buf = StringBuffer();
    buf.writeln('Verificatie: ${isOk ? "OK" : "${mismatches.length} afwijking(en)"}');
    buf.writeln('CSV: $csvTotalRows rijen, $csvProductCount producten, $csvTotalStock stk totaal');
    buf.writeln('DB:  $dbTotalRows rijen, $dbProductCount producten, $dbTotalStock stk totaal');
    if (mismatches.isNotEmpty) {
      buf.writeln('\nAfwijkingen:');
      for (final m in mismatches.take(20)) {
        buf.writeln('  • ${m.description}');
      }
      if (mismatches.length > 20) {
        buf.writeln('  ... en ${mismatches.length - 20} meer');
      }
    }
    return buf.toString();
  }
}
