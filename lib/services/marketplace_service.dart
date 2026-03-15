import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/catalog_product.dart';
import '../models/marketplace_listing.dart';

class MarketplaceService {
  final _client = Supabase.instance.client;

  static const _listingsTable = 'marketplace_listings';
  static const _ordersTable = 'marketplace_orders';
  static const _credentialsTable = 'marketplace_credentials';

  static String _sanitizeFilter(String input) {
    return input.replaceAll(RegExp(r'[,\(\)\.\\\"]'), '');
  }
  static const _syncLogTable = 'marketplace_sync_log';

  // ── Listings CRUD ──

  Future<List<MarketplaceListing>> getListings({
    MarketplacePlatform? platform,
    int? productId,
    ListingStatus? status,
  }) async {
    try {
      var query = _client
          .from(_listingsTable)
          .select('*, product_catalogus(naam, afbeelding_url)');
      if (platform != null) query = query.eq('platform', platform.code);
      if (productId != null) query = query.eq('product_id', productId);
      if (status != null) query = query.eq('status', status.code);

      final List<dynamic> rows = await query.order('created_at', ascending: false);
      final listings = rows
          .cast<Map<String, dynamic>>()
          .map(MarketplaceListing.fromJson)
          .toList();

      // Enrich with stock data
      final productIds = listings.map((l) => l.productId).whereType<int>().toSet();
      final stockMap = <int, int>{};
      for (final pid in productIds) {
        try {
          final stockRows = await _client
              .from('inventory_items')
              .select('voorraad_actueel')
              .eq('product_id', pid)
              .eq('is_archived', false);
          stockMap[pid] = (stockRows as List).fold<int>(
            0, (sum, row) => sum + ((row['voorraad_actueel'] as int?) ?? 0),
          );
        } catch (_) {
          stockMap[pid] = 0;
        }
      }

      return listings.map((l) => MarketplaceListing(
        id: l.id,
        productId: l.productId,
        platform: l.platform,
        externId: l.externId,
        externUrl: l.externUrl,
        status: l.status,
        prijs: l.prijs,
        voorraadSync: l.voorraadSync,
        laatsteSync: l.laatsteSync,
        syncFout: l.syncFout,
        platformData: l.platformData,
        createdAt: l.createdAt,
        updatedAt: l.updatedAt,
        ebayItemId: l.ebayItemId,
        ebayOfferId: l.ebayOfferId,
        ebaySku: l.ebaySku,
        ebayMarketplaces: l.ebayMarketplaces,
        matchStatus: l.matchStatus,
        externTitle: l.externTitle,
        externDescription: l.externDescription,
        externImageUrl: l.externImageUrl,
        externQuantity: l.externQuantity,
        accountLabel: l.accountLabel,
        productNaam: l.productNaam ?? l.externTitle,
        productAfbeelding: l.productAfbeelding ?? l.externImageUrl,
        productVoorraad: l.productId != null ? (stockMap[l.productId!] ?? 0) : null,
      )).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.getListings error: $e');
      return [];
    }
  }

  Future<MarketplaceListing?> getListing(String id) async {
    try {
      final row = await _client
          .from(_listingsTable)
          .select('*, product_catalogus(naam, afbeelding_url)')
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return MarketplaceListing.fromJson(row);
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.getListing error: $e');
      return null;
    }
  }

  Future<MarketplaceListing?> createListing(MarketplaceListing listing) async {
    try {
      final rows = await _client
          .from(_listingsTable)
          .insert(listing.toJson())
          .select('*, product_catalogus(naam, afbeelding_url)');
      if (rows.isNotEmpty) {
        final created = MarketplaceListing.fromJson(rows.first);
        await _logSync(
          platform: listing.platform.code,
          actie: 'listing_create',
          listingId: created.id,
          details: {'product_id': listing.productId, 'platform': listing.platform.code},
        );
        return created;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.createListing error: $e');
      rethrow;
    }
    return null;
  }

  Future<MarketplaceListing?> updateListing(
    String id, {
    double? prijs,
    String? taal,
    ListingStatus? status,
    bool? voorraadSync,
    String? externId,
    String? externUrl,
    Map<String, dynamic>? platformData,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (prijs != null) updates['prijs'] = prijs;
      if (taal != null) updates['taal'] = taal;
      if (status != null) updates['status'] = status.code;
      if (voorraadSync != null) updates['voorraad_sync'] = voorraadSync;
      if (externId != null) updates['extern_id'] = externId;
      if (externUrl != null) updates['extern_url'] = externUrl;
      if (platformData != null) updates['platform_data'] = platformData;
      if (updates.isEmpty) return getListing(id);

      final rows = await _client
          .from(_listingsTable)
          .update(updates)
          .eq('id', id)
          .select('*, product_catalogus(naam, afbeelding_url)');
      if (rows.isNotEmpty) {
        final updated = MarketplaceListing.fromJson(rows.first);
        await _logSync(
          platform: updated.platform.code,
          actie: 'listing_update',
          listingId: id,
          details: updates,
        );
        return updated;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.updateListing error: $e');
      rethrow;
    }
    return null;
  }

  Future<void> deleteListing(String id) async {
    try {
      final listing = await getListing(id);
      await _client.from(_listingsTable).delete().eq('id', id);
      if (listing != null) {
        await _logSync(
          platform: listing.platform.code,
          actie: 'listing_delete',
          details: {'product_id': listing.productId, 'extern_id': listing.externId},
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.deleteListing error: $e');
      rethrow;
    }
  }

  // ── Publish to marketplace via Edge Function ──

  Future<Map<String, dynamic>> publishListing(String listingId) async {
    return _callEdgeFunction('marketplace', {
      'action': 'publish_listing',
      'listing_id': listingId,
    });
  }

  Future<Map<String, dynamic>> unpublishListing(String listingId) async {
    return _callEdgeFunction('marketplace', {
      'action': 'unpublish_listing',
      'listing_id': listingId,
    });
  }

  Future<Map<String, dynamic>> syncPrice(String listingId, double price) async {
    return _callEdgeFunction('marketplace', {
      'action': 'sync_price',
      'listing_id': listingId,
      'price': price,
    });
  }

  Future<Map<String, dynamic>> checkProcessStatus(String listingId) async {
    return _callEdgeFunction('marketplace', {
      'action': 'check_process_status',
      'listing_id': listingId,
    });
  }

  // ── Stock Sync with Auto-Management Rules ──
  //
  // Stock thresholds:
  //  < 5 → "low stock" warning logged
  //  < 2 → auto-pause all marketplace listings (not the internal catalog)
  //  = 0 → auto-close (set to 'verwijderd') all marketplace listings (sold out)
  //  last item ordered but not yet shipped → also close all listings
  //
  // When stock returns above threshold, paused listings are automatically reactivated.

  static const int stockWarningThreshold = 5;
  static const int stockPauseThreshold = 2;

  Future<StockCheckResult> syncStock(int productId) async {
    final result = StockCheckResult();
    try {
      final listings = await getListings(productId: productId);
      final managedListings = listings.where((l) => l.voorraadSync && (l.status == ListingStatus.actief || l.status == ListingStatus.gepauzeerd)).toList();
      if (managedListings.isEmpty) return result;

      final stockRows = await _client
          .from('inventory_items')
          .select('voorraad_actueel')
          .eq('product_id', productId)
          .eq('is_archived', false);
      final totalStock = (stockRows as List).fold<int>(
        0, (sum, row) => sum + ((row['voorraad_actueel'] as int?) ?? 0),
      );

      result.totalStock = totalStock;

      // Check if last item was ordered (reserved) but not shipped
      final pendingOrders = await _client
          .from('orders')
          .select('id')
          .eq('status', 'betaald')
          .limit(1);
      final hasUnshippedOrders = (pendingOrders as List).isNotEmpty;

      for (final listing in managedListings) {
        try {
          if (totalStock <= 0 || (totalStock <= 1 && hasUnshippedOrders)) {
            // SOLD OUT: close all marketplace listings
            if (listing.status != ListingStatus.verwijderd) {
              final reden = totalStock <= 0 ? 'uitverkocht' : 'laatste_besteld';
              final pd = Map<String, dynamic>.from(listing.platformData);
              pd['auto_actie'] = 'auto_close';
              pd['auto_reden'] = reden;
              pd['auto_datum'] = DateTime.now().toUtc().toIso8601String();
              pd['auto_voorraad'] = totalStock;
              await updateListing(listing.id!, status: ListingStatus.verwijderd, platformData: pd);
              try { await unpublishListing(listing.id!); } catch (_) {}
              result.closed++;
              await _logSync(
                platform: listing.platform.code, actie: 'auto_close',
                listingId: listing.id,
                details: {'product_id': productId, 'stock': totalStock, 'reden': reden},
              );
            }
          } else if (totalStock < stockPauseThreshold) {
            // LOW: auto-pause
            if (listing.status == ListingStatus.actief) {
              final pd = Map<String, dynamic>.from(listing.platformData);
              pd['auto_actie'] = 'auto_pause';
              pd['auto_reden'] = 'voorraad_laag';
              pd['auto_datum'] = DateTime.now().toUtc().toIso8601String();
              pd['auto_voorraad'] = totalStock;
              await updateListing(listing.id!, status: ListingStatus.gepauzeerd, platformData: pd);
              result.paused++;
              await _logSync(
                platform: listing.platform.code, actie: 'auto_pause',
                listingId: listing.id,
                details: {'product_id': productId, 'stock': totalStock},
              );
            }
          } else {
            // Stock OK: reactivate if paused, sync stock to platform
            if (listing.status == ListingStatus.gepauzeerd) {
              final pd = Map<String, dynamic>.from(listing.platformData);
              final wasAuto = pd.containsKey('auto_actie');
              pd.remove('auto_actie');
              pd.remove('auto_reden');
              pd.remove('auto_datum');
              pd.remove('auto_voorraad');
              await updateListing(listing.id!, status: ListingStatus.actief, platformData: pd);
              result.reactivated++;
              await _logSync(
                platform: listing.platform.code, actie: 'auto_reactivate',
                listingId: listing.id,
                details: {'product_id': productId, 'stock': totalStock, 'was_auto': wasAuto},
              );
            }

            if (listing.platform == MarketplacePlatform.ebay && listing.ebaySku != null) {
              await _callEdgeFunction('marketplace', {
                'action': 'sync_ebay_stock',
                'listing_id': listing.id,
                'stock': totalStock,
              });
            } else {
              await _callEdgeFunction('marketplace', {
                'action': 'sync_stock',
                'listing_id': listing.id,
                'stock': totalStock,
              });
            }
            await _client.from(_listingsTable).update({
              'laatste_sync': DateTime.now().toUtc().toIso8601String(),
              'sync_fout': null,
            }).eq('id', listing.id!);
            result.synced++;
          }

          if (totalStock < stockWarningThreshold && totalStock > 0) {
            result.warnings.add('${listing.platform.label}: voorraad laag ($totalStock)');
            await _logSync(
              platform: listing.platform.code, actie: 'low_stock_warning',
              listingId: listing.id,
              details: {'product_id': productId, 'stock': totalStock},
            );
          }
        } catch (e) {
          await _client.from(_listingsTable).update({'sync_fout': e.toString()}).eq('id', listing.id!);
          await _logSync(
            platform: listing.platform.code, actie: 'stock_sync',
            listingId: listing.id, status: 'fout',
            details: {'product_id': productId, 'error': e.toString()},
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.syncStock error: $e');
    }
    return result;
  }

  Future<int> syncAllStock() async {
    try {
      final listings = await getListings(status: ListingStatus.actief);
      final productIds = listings
          .where((l) => l.voorraadSync && l.productId != null)
          .map((l) => l.productId!)
          .toSet();
      for (final pid in productIds) {
        await syncStock(pid);
      }
      return productIds.length;
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.syncAllStock error: $e');
      return 0;
    }
  }

  // ── Marketplace Orders ──

  Future<List<MarketplaceOrder>> getMarketplaceOrders({
    MarketplacePlatform? platform,
    MarketplaceOrderStatus? status,
  }) async {
    try {
      var query = _client.from(_ordersTable).select();
      if (platform != null) query = query.eq('platform', platform.code);
      if (status != null) query = query.eq('status', status.code);

      final List<dynamic> rows = await query.order('created_at', ascending: false);
      return rows
          .cast<Map<String, dynamic>>()
          .map(MarketplaceOrder.fromJson)
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.getMarketplaceOrders error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchOrdersFromPlatform(MarketplacePlatform platform) async {
    return _callEdgeFunction('marketplace', {
      'action': 'fetch_orders',
      'platform': platform.code,
    });
  }

  Future<void> updateMarketplaceOrderStatus(String id, MarketplaceOrderStatus status) async {
    await _client.from(_ordersTable).update({
      'status': status.code,
    }).eq('id', id);
  }

  /// Import a marketplace order into the internal orders system.
  /// Creates an Order + OrderRegels and links them back.
  Future<String?> importOrderToInternal(String marketplaceOrderId) async {
    try {
      final row = await _client.from(_ordersTable)
          .select()
          .eq('id', marketplaceOrderId)
          .single();
      final mpOrder = MarketplaceOrder.fromJson(row);
      if (mpOrder.orderId != null) return mpOrder.orderId;

      final orderData = mpOrder.orderData;
      final now = DateTime.now();
      final rand = (now.millisecondsSinceEpoch % 9000 + 1000).toString();
      final orderNummer = 'MP-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$rand';

      final internalOrder = <String, dynamic>{
        'order_nummer': orderNummer,
        'user_email': mpOrder.klantEmail ?? '',
        'status': 'betaald',
        'subtotaal': mpOrder.totaal ?? 0,
        'btw_bedrag': 0,
        'btw_percentage': 0,
        'btw_verlegd': false,
        'verzendkosten': 0,
        'totaal': mpOrder.totaal ?? 0,
        'valuta': 'EUR',
        'naam': mpOrder.klantNaam,
        'betaal_methode': mpOrder.platform.label,
        'betaal_referentie': mpOrder.externOrderId,
        'opmerkingen': '${mpOrder.platform.label} order ${mpOrder.externOrderId}',
        'betaald_op': now.toUtc().toIso8601String(),
      };

      // Extract address from order_data if available
      if (orderData.containsKey('shipmentDetails')) {
        final sd = orderData['shipmentDetails'] as Map<String, dynamic>? ?? {};
        internalOrder['adres'] = '${sd['streetName'] ?? ''} ${sd['houseNumber'] ?? ''}'.trim();
        internalOrder['postcode'] = sd['zipCode'] ?? '';
        internalOrder['woonplaats'] = sd['city'] ?? '';
        internalOrder['land_code'] = sd['countryCode'] ?? 'NL';
      }

      final insertedOrder = await _client.from('orders').insert(internalOrder).select().single();
      final internalOrderId = insertedOrder['id'] as String;

      // Create order lines from order_data items
      final items = (orderData['orderItems'] as List?)
          ?? (orderData['lineItems'] as List?)
          ?? [];
      for (final item in items) {
        final itemMap = item as Map<String, dynamic>;
        await _client.from('order_regels').insert({
          'order_id': internalOrderId,
          'product_id': itemMap['ean'] ?? itemMap['sku'] ?? itemMap['offerReference'] ?? '',
          'product_naam': itemMap['title'] ?? itemMap['product']?['title'] ?? 'Marketplace item',
          'aantal': itemMap['quantity'] ?? 1,
          'stukprijs': (itemMap['unitPrice'] as num?)?.toDouble()
              ?? (itemMap['price']?['value'] != null ? double.tryParse(itemMap['price']['value'].toString()) : null)
              ?? 0,
          'korting_percentage': 0,
          'regel_totaal': ((itemMap['unitPrice'] as num?)?.toDouble() ?? 0) * ((itemMap['quantity'] as num?)?.toInt() ?? 1),
        });
      }

      // Link marketplace order to internal order
      await _client.from(_ordersTable).update({
        'order_id': internalOrderId,
        'status': 'verwerkt',
      }).eq('id', marketplaceOrderId);

      await _logSync(
        platform: mpOrder.platform.code,
        actie: 'order_import',
        details: {
          'marketplace_order_id': marketplaceOrderId,
          'internal_order_id': internalOrderId,
          'order_nummer': orderNummer,
        },
      );

      return internalOrderId;
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.importOrderToInternal error: $e');
      rethrow;
    }
  }

  // ── Credentials ──

  Future<List<MarketplaceCredentialStatus>> getCredentialStatuses() async {
    final statuses = <MarketplaceCredentialStatus>[];
    for (final platform in MarketplacePlatform.values) {
      try {
        final rows = await _client
            .from(_credentialsTable)
            .select('credential_type, actief, updated_at')
            .eq('platform', platform.code);
        final hasCredentials = (rows as List).isNotEmpty;
        final allActive = hasCredentials && rows.every((r) => r['actief'] == true);
        DateTime? lastUpdated;
        if (hasCredentials) {
          final dates = rows
              .map((r) => DateTime.tryParse(r['updated_at'] as String? ?? ''))
              .whereType<DateTime>()
              .toList();
          if (dates.isNotEmpty) {
            dates.sort((a, b) => b.compareTo(a));
            lastUpdated = dates.first;
          }
        }
        statuses.add(MarketplaceCredentialStatus(
          platform: platform,
          isConfigured: hasCredentials,
          isActive: allActive,
          lastUpdated: lastUpdated,
        ));
      } catch (e) {
        statuses.add(MarketplaceCredentialStatus(platform: platform));
      }
    }
    return statuses;
  }

  Future<void> saveCredential({
    required MarketplacePlatform platform,
    required String type,
    required String value,
  }) async {
    // Check for existing credential (with or without account_label)
    final existing = await _client
        .from(_credentialsTable)
        .select('id')
        .eq('platform', platform.code)
        .eq('credential_type', type)
        .isFilter('account_label', null)
        .limit(1);

    if ((existing as List).isNotEmpty) {
      await _client.from(_credentialsTable).update({
        'encrypted_value': value,
        'actief': true,
      }).eq('id', existing[0]['id']);
    } else {
      await _client.from(_credentialsTable).insert({
        'platform': platform.code,
        'credential_type': type,
        'encrypted_value': value,
        'actief': true,
        'account_label': null,
      });
    }
  }

  Future<Map<String, String>> getCredentialValues(MarketplacePlatform platform) async {
    try {
      final rows = await _client
          .from(_credentialsTable)
          .select('credential_type, encrypted_value')
          .eq('platform', platform.code)
          .eq('actief', true);
      final map = <String, String>{};
      for (final row in (rows as List)) {
        map[row['credential_type'] as String] = row['encrypted_value'] as String;
      }
      return map;
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.getCredentialValues error: $e');
      return {};
    }
  }

  Future<void> deleteCredentials(MarketplacePlatform platform) async {
    await _client.from(_credentialsTable).delete().eq('platform', platform.code);
  }

  // ── Sync Log ──

  Future<List<MarketplaceSyncLog>> getSyncLog({
    String? platform,
    int limit = 50,
  }) async {
    try {
      var query = _client.from(_syncLogTable).select();
      if (platform != null) query = query.eq('platform', platform);
      final List<dynamic> rows = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .cast<Map<String, dynamic>>()
          .map(MarketplaceSyncLog.fromJson)
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.getSyncLog error: $e');
      return [];
    }
  }

  // ── Statistics ──

  Future<Map<MarketplacePlatform, int>> getListingCounts() async {
    final counts = <MarketplacePlatform, int>{};
    for (final platform in MarketplacePlatform.values) {
      try {
        final rows = await _client
            .from(_listingsTable)
            .select('id')
            .eq('platform', platform.code)
            .neq('status', 'verwijderd');
        counts[platform] = (rows as List).length;
      } catch (_) {
        counts[platform] = 0;
      }
    }
    return counts;
  }

  // ── Kanaalvaluta & Wisselkoersen (voor batch-omrekening) ──

  /// Haalt valuta en wisselkoers per kanaal op. wisselkoers_eur = hoeveel EUR per 1 eenheid lokale valuta (bijv. 1 GBP = 0.85 EUR).
  Future<Map<String, Map<String, dynamic>>> getKanaalValuta() async {
    try {
      final rows = await _client.from('kanaal_valuta').select('kanaal_code, valuta, wisselkoers_eur');
      final map = <String, Map<String, dynamic>>{};
      for (final r in (rows as List)) {
        final row = r as Map<String, dynamic>;
        final code = row['kanaal_code'] as String?;
        if (code != null) {
          map[code] = {
            'valuta': row['valuta'] ?? 'EUR',
            'wisselkoers_eur': (row['wisselkoers_eur'] as num?)?.toDouble(),
          };
        }
      }
      return map;
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.getKanaalValuta error: $e');
      return {};
    }
  }

  // ── Channel Matrix ──

  Future<List<ChannelMatrixRow>> getChannelMatrix() async {
    try {
      final results = await Future.wait([
        _client
            .from('product_catalogus')
            .select()
            .or('geblokkeerd.is.null,geblokkeerd.eq.false')
            .order('categorie', ascending: true)
            .order('naam', ascending: true),
        _client
            .from(_listingsTable)
            .select('*, product_catalogus(naam, afbeelding_url)')
            .neq('status', 'verwijderd'),
        _client
            .from('inventory_items')
            .select('product_id, voorraad_actueel')
            .eq('is_archived', false),
      ]);

      final products = (results[0] as List)
          .cast<Map<String, dynamic>>()
          .map((j) => CatalogProduct.fromJson(j))
          .toList();

      final allListings = (results[1] as List)
          .cast<Map<String, dynamic>>()
          .map(MarketplaceListing.fromJson)
          .toList();

      final stockMap = <int, int>{};
      for (final row in (results[2] as List)) {
        final rawPid = row['product_id'];
        final pid = rawPid is int ? rawPid : int.tryParse(rawPid?.toString() ?? '');
        if (pid == null) continue;
        final rawQty = row['voorraad_actueel'];
        final qty = rawQty is int ? rawQty : (int.tryParse(rawQty?.toString() ?? '') ?? 0);
        stockMap[pid] = (stockMap[pid] ?? 0) + qty;
      }

      final listingsByProduct = <int, Map<MarketplacePlatform, List<MarketplaceListing>>>{};
      for (final l in allListings) {
        if (l.productId == null) continue;
        listingsByProduct
            .putIfAbsent(l.productId!, () => {})
            .putIfAbsent(l.platform, () => [])
            .add(l);
      }

      return products.map((p) => ChannelMatrixRow(
        product: p,
        voorraad: stockMap[p.id] ?? 0,
        listings: listingsByProduct[p.id] ?? {},
      )).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.getChannelMatrix error: $e');
      rethrow;
    }
  }

  // ── Marktplaats XML Feed ──

  Future<Map<String, dynamic>> getMarktplaatsFeedUrl() async {
    return _callEdgeFunction('marketplace', {'action': 'get_feed_url'});
  }

  Future<Map<String, dynamic>> addProductsToMarktplaatsFeed(List<int> productIds) async {
    return _callEdgeFunction('marketplace', {
      'action': 'add_to_feed',
      'product_ids': productIds,
    });
  }

  Future<void> removeProductFromMarktplaatsFeed(int productId) async {
    await _client
        .from(_listingsTable)
        .update({'status': 'verwijderd'})
        .eq('product_id', productId)
        .eq('platform', 'marktplaats');
  }

  // ── Products (for listing creation) ──

  Future<List<Map<String, dynamic>>> getProductsForListing() async {
    try {
      final rows = await _client.from('product_catalogus').select('id, naam').order('naam');
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.getProductsForListing error: $e');
      return [];
    }
  }

  // ── CSV Import ──

  /// Column index -> SalesChannel mapping for the advertenties.csv format.
  static const _csvColumnMap = <int, SalesChannel>{
    // col 2 = eigen site prijs (handled separately)
    3:  SalesChannel.ebayUk,
    4:  SalesChannel.ebayDe,
    5:  SalesChannel.ebayIt,
    6:  SalesChannel.ebayFr,
    7:  SalesChannel.ebayNl,
    8:  SalesChannel.ebayEs,
    9:  SalesChannel.ebayBe,
    10: SalesChannel.ebayIe,
    11: SalesChannel.ebayPl,
    // col 12 = eBay UK price in GBP (handled separately)
    14: SalesChannel.bolNl,
    15: SalesChannel.bolBe,
    16: SalesChannel.amazonDe,
    17: SalesChannel.amazonFr,
    18: SalesChannel.amazonIt,
    19: SalesChannel.amazonNl,
    20: SalesChannel.amazonSe,
    21: SalesChannel.amazonUk,
    22: SalesChannel.admarkNl,
  };

  /// Import the advertenties.csv content into marketplace_listings.
  /// Returns a summary with counts of imported/skipped/matched products.
  Future<Map<String, int>> importAdvertentiesCsv(String csvContent) async {
    final lines = csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 4) return {'error': 1};

    final products = await getProductsForListing();
    final productsByName = <String, int>{};
    for (final p in products) {
      final naam = (p['naam'] as String? ?? '').toLowerCase().trim();
      if (naam.isNotEmpty) productsByName[naam] = p['id'] as int;
    }

    int matched = 0, created = 0, skipped = 0;

    for (int i = 3; i < lines.length; i++) {
      final cols = lines[i].split(';');
      final productName = (cols.isNotEmpty ? cols[0] : '').trim();
      if (productName.isEmpty) continue;

      final productId = _matchProduct(productName, productsByName);
      if (productId == null) {
        skipped++;
        continue;
      }
      matched++;

      final eigenPrijs = cols.length > 2 ? _parsePrice(cols[2]) : null;

      for (final entry in _csvColumnMap.entries) {
        final colIdx = entry.key;
        final channel = entry.value;
        if (colIdx >= cols.length) continue;

        final raw = cols[colIdx].trim().toLowerCase();
        double? prijs;

        if (raw.isEmpty || raw == 'nvt' || raw == '-') continue;

        if (raw == 'x' || raw == 'q') {
          prijs = eigenPrijs;
        } else if (raw == 'error') {
          continue;
        } else {
          prijs = _parsePrice(cols[colIdx]);
        }

        if (prijs == null) continue;

        try {
          await _client.from(_listingsTable).upsert({
            'product_id': productId,
            'platform': channel.platformCode,
            'taal': channel.country,
            'prijs': prijs,
            'status': 'actief',
            'voorraad_sync': true,
            'platform_data': <String, dynamic>{},
          }, onConflict: 'product_id,platform,taal');
          created++;
        } catch (e) {
          if (kDebugMode) debugPrint('CSV import upsert error for $productName on ${channel.code}: $e');
        }
      }

      // Handle eBay UK GBP price separately (col 12)
      if (cols.length > 12) {
        final gbpRaw = cols[12].trim().toLowerCase();
        if (gbpRaw.isNotEmpty && gbpRaw != 'nvt' && gbpRaw != '-' && gbpRaw != 'x') {
          final gbpPrijs = _parsePrice(cols[12]);
          if (gbpPrijs != null) {
            try {
              await _client.from(_listingsTable).upsert({
                'product_id': productId,
                'platform': 'ebay',
                'taal': 'en',
                'prijs': gbpPrijs,
                'status': 'actief',
                'voorraad_sync': true,
                'platform_data': {'currency': 'GBP'},
              }, onConflict: 'product_id,platform,taal');
            } catch (_) {}
          }
        }
      }
    }

    return {'matched': matched, 'created': created, 'skipped': skipped};
  }

  int? _matchProduct(String csvName, Map<String, int> productsByName) {
    final normalized = csvName.toLowerCase().trim();
    if (productsByName.containsKey(normalized)) return productsByName[normalized];

    // Fuzzy: try to find the best substring match
    int bestScore = 0;
    int? bestId;
    for (final entry in productsByName.entries) {
      final dbName = entry.key;
      int score = 0;
      final csvWords = normalized.split(RegExp(r'\s+'));
      for (final w in csvWords) {
        if (w.length >= 2 && dbName.contains(w)) score += w.length;
      }
      if (score > bestScore && score >= (normalized.length * 0.5).floor()) {
        bestScore = score;
        bestId = entry.value;
      }
    }
    return bestId;
  }

  static double? _parsePrice(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  // ── Private helpers ──

  Future<void> _logSync({
    required String platform,
    required String actie,
    String? listingId,
    String status = 'succes',
    Map<String, dynamic> details = const {},
  }) async {
    try {
      final data = <String, dynamic>{
        'platform': platform,
        'actie': actie,
        'status': status,
        'details': details,
      };
      if (listingId != null) data['listing_id'] = listingId;
      await _client.from(_syncLogTable).insert(data);
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService._logSync error: $e');
    }
  }

  // ── eBay Multi-Account ──

  Future<List<Map<String, dynamic>>> getEbayAccounts() async {
    final result = await _callEdgeFunction('marketplace', {
      'action': 'get_ebay_accounts',
    });
    final accounts = result['accounts'] as List?;
    return accounts?.cast<Map<String, dynamic>>() ?? [];
  }

  Future<Map<String, dynamic>> importEbayListings({String? accountLabel}) async {
    return _callEdgeFunction('marketplace', {
      'action': 'import_ebay_listings',
      if (accountLabel != null) 'account_label': accountLabel,
    });
  }

  Future<List<MarketplaceListing>> getUnmatchedListings({String? platform}) async {
    var query = _client
        .from(_listingsTable)
        .select('*, product_catalogus(naam, afbeelding_url)')
        .eq('match_status', 'unmatched');
    if (platform != null) query = query.eq('platform', platform);

    final List<dynamic> rows = await query.order('extern_title');
    return rows.cast<Map<String, dynamic>>().map(MarketplaceListing.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> searchCatalogProducts(String query) async {
    final rows = await _client
        .from('product_catalogus')
        .select('id, naam, artikelnummer, ean_code, afbeelding_url, prijs')
        .or('naam.ilike.%${_sanitizeFilter(query)}%,artikelnummer.ilike.%${_sanitizeFilter(query)}%,ean_code.ilike.%${_sanitizeFilter(query)}%')
        .limit(20);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> matchListing(String listingId, int productId) async {
    await _client.from(_listingsTable).update({
      'product_id': productId,
      'match_status': 'manual',
    }).eq('id', listingId);
  }

  Future<void> confirmMatch(String listingId) async {
    await _client.from(_listingsTable).update({
      'match_status': 'confirmed',
    }).eq('id', listingId);
  }

  Future<void> unmatchListing(String listingId) async {
    await _client.from(_listingsTable).update({
      'product_id': null,
      'match_status': 'unmatched',
    }).eq('id', listingId);
  }

  Future<Map<String, int>> autoMatchListings() async {
    final unmatched = await getUnmatchedListings(platform: 'ebay');
    int matched = 0;
    int notFound = 0;

    // Pre-fetch all catalog products for title matching
    List<Map<String, dynamic>>? allProducts;

    for (final listing in unmatched) {
      final pd = listing.platformData;
      final ean = pd['ean'] as String?;
      final sku = pd['sku'] as String?;
      final title = listing.externTitle?.toLowerCase().trim();

      Map<String, dynamic>? product;

      // 1. Match by EAN (highest confidence)
      if (ean != null && ean.isNotEmpty) {
        final rows = await _client
            .from('product_catalogus')
            .select('id')
            .eq('ean_code', ean)
            .limit(1);
        if ((rows as List).isNotEmpty) {
          product = (rows as List).first as Map<String, dynamic>;
        }
      }

      // 2. Match by artikelnummer / SKU
      if (product == null && sku != null && sku.isNotEmpty) {
        final rows = await _client
            .from('product_catalogus')
            .select('id')
            .eq('artikelnummer', sku)
            .limit(1);
        if ((rows as List).isNotEmpty) {
          product = (rows as List).first as Map<String, dynamic>;
        }
      }

      // 3. Match by title (fuzzy): look for catalog product name inside eBay title
      if (product == null && title != null && title.length > 3) {
        allProducts ??= await _client
            .from('product_catalogus')
            .select('id, naam')
            .then((rows) => (rows as List).cast<Map<String, dynamic>>());

        int bestScore = 0;
        Map<String, dynamic>? bestMatch;

        for (final p in allProducts!) {
          final naam = (p['naam'] as String?)?.toLowerCase().trim();
          if (naam == null || naam.isEmpty) continue;

          final score = _titleMatchScore(title, naam);
          if (score > bestScore) {
            bestScore = score;
            bestMatch = p;
          }
        }

        // Require at least 60% word overlap
        if (bestMatch != null && bestScore >= 60) {
          product = bestMatch;
        }
      }

      if (product != null && listing.id != null) {
        await _client.from(_listingsTable).update({
          'product_id': product['id'] as int,
          'match_status': 'suggested',
        }).eq('id', listing.id!);
        matched++;
      } else {
        notFound++;
      }
    }

    return {'matched': matched, 'not_found': notFound};
  }

  /// Scores how well an eBay title matches a catalog product name.
  /// Returns 0-100: percentage of catalog name words found in eBay title.
  /// Language-agnostic — works for NL, FR, EN, DE titles.
  int _titleMatchScore(String ebayTitle, String catalogName) {
    final stopWords = {
      'de', 'het', 'een', 'van', 'voor', 'met', 'en', 'la', 'le', 'les',
      'du', 'des', 'un', 'une', 'pour', 'the', 'a', 'an', 'of', 'for',
      'and', 'with', 'die', 'der', 'das', 'und', 'fur', '-', '–',
    };

    List<String> toWords(String s) => s
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1 && !stopWords.contains(w))
        .toList();

    final catalogWords = toWords(catalogName);
    if (catalogWords.isEmpty) return 0;

    final titleWords = toWords(ebayTitle).toSet();
    int hits = 0;
    for (final w in catalogWords) {
      if (titleWords.contains(w)) {
        hits++;
      } else {
        // Partial match: check if any title word starts with this catalog word or vice versa
        final hasPartial = titleWords.any((tw) =>
            (tw.length >= 4 && w.length >= 4) &&
            (tw.startsWith(w) || w.startsWith(tw)));
        if (hasPartial) hits++;
      }
    }

    return ((hits / catalogWords.length) * 100).round();
  }

  Future<void> saveCredentialWithAccount({
    required MarketplacePlatform platform,
    required String type,
    required String value,
    String? accountLabel,
  }) async {
    var query = _client
        .from(_credentialsTable)
        .select('id, account_label')
        .eq('platform', platform.code)
        .eq('credential_type', type);

    if (accountLabel != null) {
      query = query.eq('account_label', accountLabel);
    }

    final existing = await query;
    final List rows = existing as List;

    // For null label, filter client-side since .is() for null varies
    final filtered = accountLabel == null
        ? rows.where((r) => r['account_label'] == null).toList()
        : rows;

    if (filtered.isNotEmpty) {
      await _client.from(_credentialsTable).update({
        'encrypted_value': value,
        'actief': true,
      }).eq('id', filtered.first['id']);
    } else {
      final data = <String, dynamic>{
        'platform': platform.code,
        'credential_type': type,
        'encrypted_value': value,
        'actief': true,
      };
      if (accountLabel != null) data['account_label'] = accountLabel;
      await _client.from(_credentialsTable).insert(data);
    }
  }

  // ── eBay Controlled Write (Fase 2) ──

  Future<Map<String, dynamic>> syncEbayStock(String listingId, int stock) async {
    return _callEdgeFunction('marketplace', {
      'action': 'sync_ebay_stock',
      'listing_id': listingId,
      'stock': stock,
    });
  }

  Future<Map<String, dynamic>> syncEbayPrice(String listingId, double price) async {
    return _callEdgeFunction('marketplace', {
      'action': 'sync_ebay_price',
      'listing_id': listingId,
      'price': price,
    });
  }

  Future<Map<String, dynamic>> publishToEbayNew({
    required int productId,
    String marketplaceId = 'EBAY_NL',
    String? title,
    String? description,
    double? price,
    int quantity = 1,
    String condition = 'NEW',
    String? categoryId,
    String? accountLabel,
  }) async {
    return _callEdgeFunction('marketplace', {
      'action': 'publish_to_ebay',
      'product_id': productId,
      'marketplace_id': marketplaceId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (price != null) 'price': price,
      'quantity': quantity,
      'condition': condition,
      if (categoryId != null) 'category_id': categoryId,
      if (accountLabel != null) 'account_label': accountLabel,
    });
  }

  // ── Amazon SP-API ──

  Future<Map<String, dynamic>> testAmazonConnection() async {
    return _callEdgeFunction('marketplace', {
      'action': 'amazon_test_connection',
    });
  }

  Future<Map<String, dynamic>> importAmazonListings({String channel = 'amazon_de'}) async {
    return _callEdgeFunction('marketplace', {
      'action': 'amazon_import_listings',
      'account_label': channel,
    });
  }

  Future<Map<String, dynamic>> fetchAmazonOrders() async {
    return _callEdgeFunction('marketplace', {
      'action': 'fetch_orders',
      'platform': 'amazon',
    });
  }

  Future<Map<String, dynamic>> _callEdgeFunction(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.functions.invoke(
        functionName,
        body: body,
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data;
        if (data == null) return {'success': true};
        if (data is Map<String, dynamic>) return data;
        if (data is String) {
          return data.isEmpty ? {'success': true} : jsonDecode(data) as Map<String, dynamic>;
        }
        return {'success': true, 'data': data};
      } else {
        throw Exception('Edge Function error ${response.status}: ${response.data}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Edge Function call error: $e');
      rethrow;
    }
  }
}
