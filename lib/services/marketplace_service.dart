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
      final productIds = listings.map((l) => l.productId).toSet();
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
        productNaam: l.productNaam,
        productAfbeelding: l.productAfbeelding,
        productVoorraad: stockMap[l.productId] ?? 0,
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

            await _callEdgeFunction('marketplace', {
              'action': 'sync_stock',
              'listing_id': listing.id,
              'stock': totalStock,
            });
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
          .where((l) => l.voorraadSync)
          .map((l) => l.productId)
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
    await _client.from(_credentialsTable).upsert({
      'platform': platform.code,
      'credential_type': type,
      'encrypted_value': value,
      'actief': true,
    }, onConflict: 'platform,credential_type');
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
        final pid = row['product_id'] as int;
        final qty = (row['voorraad_actueel'] as int?) ?? 0;
        stockMap[pid] = (stockMap[pid] ?? 0) + qty;
      }

      final listingsByProduct = <int, Map<MarketplacePlatform, List<MarketplaceListing>>>{};
      for (final l in allListings) {
        listingsByProduct
            .putIfAbsent(l.productId, () => {})
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
      return [];
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
