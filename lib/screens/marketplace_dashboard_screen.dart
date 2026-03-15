import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/marketplace_listing.dart';
import '../services/marketplace_service.dart';
import 'channel_matrix_screen.dart';
import 'ebay_matching_screen.dart';

class MarketplaceDashboardScreen extends StatefulWidget {
  final int initialTabIndex;
  const MarketplaceDashboardScreen({super.key, this.initialTabIndex = 0});

  @override
  State<MarketplaceDashboardScreen> createState() => _MarketplaceDashboardScreenState();
}

class _MarketplaceDashboardScreenState extends State<MarketplaceDashboardScreen> with SingleTickerProviderStateMixin {
  static const _navy = Color(0xFF0D1B2A);
  static const _accent = Color(0xFF1B4965);

  final _service = MarketplaceService();
  late final TabController _tabController;

  List<MarketplaceCredentialStatus> _credentials = [];
  List<MarketplaceListing> _listings = [];
  List<MarketplaceOrder> _orders = [];
  List<MarketplaceSyncLog> _syncLog = [];
  Map<MarketplacePlatform, int> _listingCounts = {};
  bool _loading = true;
  bool _syncing = false;
  MarketplacePlatform? _filterPlatform;
  String? _feedUrl;
  String? _feedUrlTsv;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this, initialIndex: widget.initialTabIndex);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _service.getCredentialStatuses(),
      _service.getListings(platform: _filterPlatform),
      _service.getMarketplaceOrders(),
      _service.getSyncLog(),
      _service.getListingCounts(),
    ]);
    if (!mounted) return;
    setState(() {
      _credentials = results[0] as List<MarketplaceCredentialStatus>;
      _listings = results[1] as List<MarketplaceListing>;
      _orders = results[2] as List<MarketplaceOrder>;
      _syncLog = results[3] as List<MarketplaceSyncLog>;
      _listingCounts = results[4] as Map<MarketplacePlatform, int>;
      _loading = false;
    });
  }

  Future<void> _syncAllStock() async {
    setState(() => _syncing = true);
    final count = await _service.syncAllStock();
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voorraad gesynchroniseerd voor $count product(en)'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Marktplaatsen', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD4A843),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13),
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overzicht'),
            Tab(text: 'Kanaaloverzicht'),
            Tab(text: 'Listings'),
            Tab(text: 'eBay Matching'),
            Tab(text: 'Orders'),
            Tab(text: 'Feed'),
            Tab(text: 'Sync Log'),
          ],
        ),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              tooltip: 'Voorraad synchroniseren',
              onPressed: _syncAllStock,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                const ChannelMatrixScreen(),
                _buildListingsTab(),
                const EbayMatchingScreen(),
                _buildOrdersTab(),
                _buildFeedTab(),
                _buildSyncLogTab(),
              ],
            ),
    );
  }

  // ── Tab 1: Overzicht ──

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Platformkoppelingen', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: _navy)),
          const SizedBox(height: 16),
          ...MarketplacePlatform.values.map(_buildPlatformCard),
        ],
      ),
    );
  }

  Widget _buildPlatformCard(MarketplacePlatform platform) {
    final cred = _credentials.firstWhere(
      (c) => c.platform == platform,
      orElse: () => MarketplaceCredentialStatus(platform: platform),
    );
    final count = _listingCounts[platform] ?? 0;
    final icon = _platformIcon(platform);
    final color = _platformColor(platform);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cred.isConfigured ? color.withValues(alpha: 0.3) : const Color(0xFFE8ECF1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(platform.label, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
                      const SizedBox(width: 10),
                      _statusChip(cred.isConfigured, cred.isActive),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cred.isConfigured
                        ? '$count listing(s) actief${cred.lastUpdated != null ? ' · Laatst bijgewerkt ${_formatDate(cred.lastUpdated!)}' : ''}'
                        : 'Niet geconfigureerd — voer API-credentials in',
                    style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _showCredentialsDialog(platform),
              icon: Icon(cred.isConfigured ? Icons.edit_outlined : Icons.vpn_key_outlined, size: 16),
              label: Text(cred.isConfigured ? 'Bewerken' : 'Koppelen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(bool configured, bool active) {
    if (!configured) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('Niet verbonden', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFE65100))),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        active ? 'Verbonden' : 'Inactief',
        style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: active ? const Color(0xFF2E7D32) : const Color(0xFFF57F17)),
      ),
    );
  }

  // ── Tab 2: Listings ──

  Widget _buildListingsTab() {
    return Column(
      children: [
        _buildListingsToolbar(),
        Expanded(
          child: _listings.isEmpty
              ? _emptyState('Geen listings', 'Maak een listing aan om producten op marktplaatsen te plaatsen', Icons.storefront_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: _listings.length,
                  itemBuilder: (ctx, i) => _buildListingTile(_listings[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildListingsToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<MarketplacePlatform?>(
              value: _filterPlatform,
              hint: Text('Alle platforms', style: GoogleFonts.dmSans(fontSize: 13, color: _navy)),
              style: GoogleFonts.dmSans(fontSize: 13, color: _navy),
              borderRadius: BorderRadius.circular(12),
              items: [
                const DropdownMenuItem(value: null, child: Text('Alle platforms')),
                ...MarketplacePlatform.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))),
              ],
              onChanged: (v) {
                setState(() => _filterPlatform = v);
                _loadAll();
              },
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _showCreateListingDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nieuwe listing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingTile(MarketplaceListing listing) {
    final color = _platformColor(listing.platform);
    final statusColor = _statusColor(listing.status);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFFE8ECF1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: listing.productAfbeelding != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(listing.productAfbeelding!, fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(_platformIcon(listing.platform), color: color, size: 22)),
                )
              : Icon(_platformIcon(listing.platform), color: color, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                listing.productNaam ?? 'Product #${listing.productId}',
                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _navy),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(listing.status.label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Icon(_platformIcon(listing.platform), size: 12, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(listing.platform.label, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
              child: Text(listing.taal.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF455A64), letterSpacing: 0.5)),
            ),
            if (listing.prijs != null) ...[
              const SizedBox(width: 12),
              Text('€ ${listing.prijs!.toStringAsFixed(2)}', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
            ],
            if (listing.productVoorraad != null) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: listing.productVoorraad! > 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${listing.productVoorraad} op voorraad',
                  style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: listing.productVoorraad! > 0 ? const Color(0xFF2E7D32) : const Color(0xFFE53935)),
                ),
              ),
            ],
            if (listing.laatsteSync != null) ...[
              const SizedBox(width: 12),
              Icon(Icons.sync, size: 10, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 2),
              Text(_formatDate(listing.laatsteSync!), style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF94A3B8))),
            ],
            if (listing.syncFout != null) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: listing.syncFout!,
                child: const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFE53935)),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'edit', child: Text('Bewerken')),
            if (listing.status == ListingStatus.concept)
              const PopupMenuItem(value: 'publish', child: Text('Publiceren')),
            if (listing.status == ListingStatus.actief)
              const PopupMenuItem(value: 'pause', child: Text('Pauzeren')),
            if (listing.status == ListingStatus.gepauzeerd)
              const PopupMenuItem(value: 'activate', child: Text('Heractiveren')),
            if (listing.externUrl != null)
              const PopupMenuItem(value: 'open', child: Text('Openen op platform')),
            if (listing.platform == MarketplacePlatform.bolCom && listing.externId == null && listing.status == ListingStatus.actief)
              const PopupMenuItem(value: 'check_status', child: Text('Status controleren')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'delete', child: Text('Verwijderen', style: TextStyle(color: Color(0xFFE53935)))),
          ],
          onSelected: (action) => _handleListingAction(listing, action),
        ),
      ),
    );
  }

  // ── Tab 3: Orders ──

  Widget _buildOrdersTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            children: [
              Text('${_orders.length} marketplace order(s)', style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B))),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _fetchAllOrders,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Orders ophalen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _orders.isEmpty
              ? _emptyState('Geen marketplace orders', 'Orders van externe platforms verschijnen hier', Icons.receipt_long_outlined)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: _orders.length,
                  itemBuilder: (ctx, i) => _buildOrderTile(_orders[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildOrderTile(MarketplaceOrder order) {
    final color = _platformColor(order.platform);
    final statusColor = _orderStatusColor(order.status);
    final muted = const Color(0xFF94A3B8);
    final body = const Color(0xFF64748B);
    final labelStyle = GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: muted);
    final valueStyle = GoogleFonts.dmSans(fontSize: 12, color: body);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE8ECF1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
          child: Icon(_platformIcon(order.platform), color: color, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.productTitel ?? order.externOrderId,
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _navy),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  if (order.productTitel != null)
                    Text(order.externOrderId, style: GoogleFonts.dmSans(fontSize: 11, color: muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(order.status.label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 12,
            children: [
              Text(order.platform.label, style: GoogleFonts.dmSans(fontSize: 11, color: muted)),
              if (order.klantNaam != null && order.klantNaam!.isNotEmpty)
                Text(order.klantNaam!, style: GoogleFonts.dmSans(fontSize: 11, color: body)),
              if (order.totaal != null)
                Text('€ ${order.totaal!.toStringAsFixed(2)}', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: body)),
              if (order.besteldOp != null)
                Text(_formatDate(order.besteldOp!), style: GoogleFonts.dmSans(fontSize: 10, color: muted))
              else if (order.createdAt != null)
                Text(_formatDate(order.createdAt!), style: GoogleFonts.dmSans(fontSize: 10, color: muted)),
              if (order.aantalItems > 1)
                Text('${order.aantalItems} items', style: GoogleFonts.dmSans(fontSize: 10, color: muted)),
            ],
          ),
        ),
        trailing: order.status == MarketplaceOrderStatus.nieuw && order.orderId == null
            ? IconButton(
                icon: const Icon(Icons.input_rounded, size: 20, color: Color(0xFF1565C0)),
                tooltip: 'Importeer naar interne orders',
                onPressed: () async {
                  try {
                    final internalId = await _service.importOrderToInternal(order.id!);
                    _loadAll();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Order geïmporteerd (ID: ${internalId ?? "onbekend"})'), backgroundColor: const Color(0xFF2E7D32)),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Import mislukt: $e'), backgroundColor: const Color(0xFFE53935)),
                      );
                    }
                  }
                },
              )
            : order.orderId != null
                ? const Icon(Icons.check_circle, size: 20, color: Color(0xFF2E7D32))
                : null,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          // ── Product details ──
          if (order.orderItems.isNotEmpty) ...[
            Text('PRODUCTEN', style: labelStyle),
            const SizedBox(height: 6),
            ...order.orderItems.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['title'] as String? ?? 'Onbekend product', style: valueStyle.copyWith(fontWeight: FontWeight.w500)),
                        if (item['ean'] != null)
                          Text('EAN: ${item['ean']}', style: GoogleFonts.dmSans(fontSize: 10, color: muted)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('${item['quantity'] ?? 1}x', style: valueStyle, textAlign: TextAlign.center),
                  ),
                  SizedBox(
                    width: 75,
                    child: Text('€ ${((item['unitPrice'] as num?) ?? 0).toStringAsFixed(2)}', style: valueStyle, textAlign: TextAlign.right),
                  ),
                  SizedBox(
                    width: 85,
                    child: Text('€ ${((item['totalPrice'] as num?) ?? 0).toStringAsFixed(2)}',
                      style: valueStyle.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.right),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 8),
          ] else if (order.productTitel != null) ...[
            Text('PRODUCT', style: labelStyle),
            const SizedBox(height: 4),
            Text('${order.productHoeveelheid}x ${order.productTitel}', style: valueStyle),
            if (order.productEan != null)
              Text('EAN: ${order.productEan}', style: GoogleFonts.dmSans(fontSize: 10, color: muted)),
            const SizedBox(height: 8),
          ],
          // ── Financial summary ──
          Row(
            children: [
              Expanded(child: _orderDetailRow('Totaal', '€ ${(order.totaal ?? 0).toStringAsFixed(2)}', labelStyle, valueStyle.copyWith(fontWeight: FontWeight.w700))),
              if (order.commissie != null)
                Expanded(child: _orderDetailRow('Commissie', '€ ${order.commissie!.toStringAsFixed(2)}', labelStyle, valueStyle)),
              if (order.stukprijs != null && order.aantalItems == 1)
                Expanded(child: _orderDetailRow('Stukprijs', '€ ${order.stukprijs!.toStringAsFixed(2)}', labelStyle, valueStyle)),
            ],
          ),
          const SizedBox(height: 12),
          // ── Customer + addresses ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (order.klantNaam != null && order.klantNaam!.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('KLANT', style: labelStyle),
                      const SizedBox(height: 4),
                      if (order.klantAanhef != null) Text(_formatSalutation(order.klantAanhef!), style: GoogleFonts.dmSans(fontSize: 10, color: muted)),
                      Text(order.klantNaam!, style: valueStyle.copyWith(fontWeight: FontWeight.w500)),
                      if (order.klantEmail != null) Text(order.klantEmail!, style: GoogleFonts.dmSans(fontSize: 11, color: body)),
                      if (order.klantTelefoon != null) Text(order.klantTelefoon!, style: GoogleFonts.dmSans(fontSize: 11, color: body)),
                    ],
                  ),
                ),
              if (order.verzendStraat != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('VERZENDADRES', style: labelStyle),
                      const SizedBox(height: 4),
                      Text('${order.verzendStraat} ${order.verzendHuisnummer ?? ""}${order.verzendHuisnummerExt != null ? " ${order.verzendHuisnummerExt}" : ""}', style: valueStyle),
                      Text('${order.verzendPostcode ?? ""} ${order.verzendStad ?? ""}', style: valueStyle),
                      if (order.verzendLand != null && order.verzendLand != 'NL')
                        Text(order.verzendLand!, style: valueStyle),
                    ],
                  ),
                ),
              if (order.factuurStraat != null && order.factuurStraat != order.verzendStraat)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FACTUURADRES', style: labelStyle),
                      const SizedBox(height: 4),
                      if (order.factuurNaam != null) Text(order.factuurNaam!, style: valueStyle.copyWith(fontWeight: FontWeight.w500)),
                      Text('${order.factuurStraat} ${order.factuurHuisnummer ?? ""}${order.factuurHuisnummerExt != null ? " ${order.factuurHuisnummerExt}" : ""}', style: valueStyle),
                      Text('${order.factuurPostcode ?? ""} ${order.factuurStad ?? ""}', style: valueStyle),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Fulfillment / transport ──
          Row(
            children: [
              if (order.fulfillmentMethode != null)
                Expanded(child: _orderDetailRow('Fulfillment', order.fulfillmentMethode == 'FBR' ? 'Eigen verzending' : 'Bol.com (FBB)', labelStyle, valueStyle)),
              if (order.besteldOp != null)
                Expanded(child: _orderDetailRow('Besteld op', _formatDate(order.besteldOp!), labelStyle, valueStyle)),
              if (order.uitersteLeverdatum != null)
                Expanded(child: _orderDetailRow('Leveren voor', _formatDate(order.uitersteLeverdatum!), labelStyle, valueStyle)),
            ],
          ),
          if (order.transportId != null || order.trackTrace != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (order.transportId != null)
                  Expanded(child: _orderDetailRow('Transport ID', order.transportId!, labelStyle, valueStyle)),
                if (order.trackTrace != null)
                  Expanded(child: _orderDetailRow('Track & Trace', order.trackTrace!, labelStyle, valueStyle)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _orderDetailRow(String label, String value, TextStyle labelStyle, TextStyle valueStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: labelStyle),
        const SizedBox(height: 2),
        Text(value, style: valueStyle),
      ],
    );
  }

  String _formatSalutation(String salutation) {
    return switch (salutation) {
      'MALE' => 'Dhr.',
      'FEMALE' => 'Mevr.',
      _ => salutation,
    };
  }

  // ── Tab 4: Marktplaats Feed ──

  Widget _buildFeedTab() {
    final feedListings = _listings.where((l) => l.platform == MarketplacePlatform.marktplaats && l.status != ListingStatus.verwijderd).toList();
    final muted = const Color(0xFF94A3B8);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Feed URL card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFE8ECF1))),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rss_feed_rounded, color: Color(0xFFE65100), size: 24),
                      const SizedBox(width: 12),
                      Text('Marktplaats XML Feed', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: _navy)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Deze feed genereert automatisch een XML-bestand met al je actieve Marktplaats-producten. '
                    'Upload de feed-URL op marktplaatszakelijk.nl via TSV/XML, of deel de URL met Marktplaats.',
                    style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B), height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  if (_feedUrl != null) ...[
                    _feedUrlRow('XML Feed', _feedUrl!),
                    const SizedBox(height: 8),
                    _feedUrlRow('TSV Feed', _feedUrlTsv ?? _feedUrl!),
                  ] else
                    ElevatedButton.icon(
                      onPressed: _loadFeedUrl,
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: Text('Feed-URL ophalen', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_feedUrl != null)
                        TextButton.icon(
                          onPressed: () => launchUrl(Uri.parse(_feedUrl!)),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: Text('Preview XML', style: GoogleFonts.dmSans(fontSize: 12)),
                        ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => launchUrl(Uri.parse('https://www.marktplaatszakelijk.nl')),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text('Marktplaats Zakelijk', style: GoogleFonts.dmSans(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Products in feed
          Row(
            children: [
              Text('Producten in feed', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFE65100).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('${feedListings.length}', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFE65100))),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showAddToFeedDialog,
                icon: const Icon(Icons.add, size: 18),
                label: Text('Producten toevoegen', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (feedListings.isEmpty)
            _emptyState('Geen producten in de feed', 'Voeg producten toe om ze op Marktplaats te adverteren', Icons.storefront_outlined)
          else
            ...feedListings.map((listing) {
              final statusColor = listing.status == ListingStatus.actief ? const Color(0xFF2E7D32) : muted;
              final pd = listing.platformData;
              final cpc = (pd['cpc'] as num?)?.toDouble() ?? 2;
              final totalBudget = (pd['total_budget'] as num?)?.toDouble() ?? 5000;
              final dailyBudget = (pd['daily_budget'] as num?)?.toDouble() ?? 1000;
              final autobid = pd['autobid'] as bool? ?? false;
              final labelSt = GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: muted);
              final valueSt = GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B));

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE8ECF1))),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: const Color(0xFFE65100).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.storefront_outlined, color: Color(0xFFE65100), size: 20),
                  ),
                  title: Text(
                    listing.productNaam ?? 'Product #${listing.productId}',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _navy),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Wrap(
                    spacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(listing.status.label, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                      ),
                      if (listing.prijs != null)
                        Text('€ ${listing.prijs!.toStringAsFixed(2)}', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B))),
                      Text('CPC: € ${(cpc / 100).toStringAsFixed(2)}', style: GoogleFonts.dmSans(fontSize: 11, color: muted)),
                      Text('Budget: € ${(totalBudget / 100).toStringAsFixed(0)}', style: GoogleFonts.dmSans(fontSize: 11, color: muted)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (listing.status == ListingStatus.actief)
                        IconButton(
                          icon: const Icon(Icons.pause_circle_outline, size: 20, color: Color(0xFFF57F17)),
                          tooltip: 'Pauzeren',
                          onPressed: () async {
                            await _service.updateListing(listing.id!, status: ListingStatus.gepauzeerd);
                            _loadAll();
                          },
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.play_circle_outline, size: 20, color: Color(0xFF2E7D32)),
                          tooltip: 'Activeren',
                          onPressed: () async {
                            await _service.updateListing(listing.id!, status: ListingStatus.actief);
                            _loadAll();
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFE53935)),
                        tooltip: 'Verwijderen uit feed',
                        onPressed: listing.productId != null ? () async {
                          await _service.removeProductFromMarktplaatsFeed(listing.productId!);
                          _loadAll();
                        } : null,
                      ),
                    ],
                  ),
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('CPC', style: labelSt),
                          const SizedBox(height: 2),
                          Text('€ ${(cpc / 100).toStringAsFixed(2)}', style: valueSt.copyWith(fontWeight: FontWeight.w600)),
                        ])),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('TOTAALBUDGET', style: labelSt),
                          const SizedBox(height: 2),
                          Text('€ ${(totalBudget / 100).toStringAsFixed(2)}', style: valueSt.copyWith(fontWeight: FontWeight.w600)),
                        ])),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('DAGBUDGET', style: labelSt),
                          const SizedBox(height: 2),
                          Text('€ ${(dailyBudget / 100).toStringAsFixed(2)}', style: valueSt.copyWith(fontWeight: FontWeight.w600)),
                        ])),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('AUTOBID', style: labelSt),
                          const SizedBox(height: 2),
                          Text(autobid ? 'Aan' : 'Uit', style: valueSt),
                        ])),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: () => _showBudgetDialog(listing),
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text('Budget aanpassen', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showBudgetDialog(MarketplaceListing listing) async {
    final pd = Map<String, dynamic>.from(listing.platformData);
    final cpcCtrl = TextEditingController(text: ((pd['cpc'] as num?)?.toDouble() ?? 2).toString());
    final totalCtrl = TextEditingController(text: ((pd['total_budget'] as num?)?.toDouble() ?? 5000).toString());
    final dailyCtrl = TextEditingController(text: ((pd['daily_budget'] as num?)?.toDouble() ?? 1000).toString());
    var autobid = pd['autobid'] as bool? ?? false;

    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Budget: ${listing.productNaam ?? "Product"}', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 16)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Bedragen in eurocenten. 2 = € 0,02 | 5000 = € 50,00',
                    style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8))),
                const SizedBox(height: 16),
                TextFormField(
                  controller: cpcCtrl,
                  decoration: InputDecoration(
                    labelText: 'CPC (eurocent)',
                    helperText: 'Bijv. 2 = € 0,02 per klik',
                    helperStyle: GoogleFonts.dmSans(fontSize: 11),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: totalCtrl,
                  decoration: InputDecoration(
                    labelText: 'Totaalbudget (eurocent)',
                    helperText: 'Bijv. 5000 = € 50,00',
                    helperStyle: GoogleFonts.dmSans(fontSize: 11),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: dailyCtrl,
                  decoration: InputDecoration(
                    labelText: 'Dagbudget (eurocent)',
                    helperText: 'Bijv. 1000 = € 10,00',
                    helperStyle: GoogleFonts.dmSans(fontSize: 11),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text('Autobid', style: GoogleFonts.dmSans(fontSize: 14)),
                  subtitle: Text(autobid ? 'Marktplaats bepaalt je CPC' : 'Jij bepaalt je CPC', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8))),
                  value: autobid,
                  onChanged: (v) => setDialogState(() => autobid = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
              child: Text('Opslaan', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      pd['cpc'] = int.tryParse(cpcCtrl.text) ?? 2;
      pd['total_budget'] = int.tryParse(totalCtrl.text) ?? 5000;
      pd['daily_budget'] = int.tryParse(dailyCtrl.text) ?? 1000;
      pd['autobid'] = autobid;
      await _service.updateListing(listing.id!, platformData: pd);
      _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Budget-instellingen opgeslagen'), backgroundColor: Color(0xFF2E7D32)),
        );
      }
    }

    cpcCtrl.dispose();
    totalCtrl.dispose();
    dailyCtrl.dispose();
  }

  Widget _feedUrlRow(String label, String url) {
    return Row(
      children: [
        Text('$label: ', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _navy)),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
            child: SelectableText(url, style: GoogleFonts.dmMono(fontSize: 11, color: const Color(0xFF64748B))),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          tooltip: 'Kopiëren',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label URL gekopieerd'), duration: const Duration(seconds: 2)),
              );
            }
          },
        ),
      ],
    );
  }

  Future<void> _loadFeedUrl() async {
    try {
      final result = await _service.getMarktplaatsFeedUrl();
      setState(() {
        _feedUrl = result['feed_url'] as String?;
        _feedUrlTsv = result['feed_url_tsv'] as String?;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij ophalen feed-URL: $e'), backgroundColor: const Color(0xFFE53935)),
        );
      }
    }
  }

  Future<void> _showAddToFeedDialog() async {
    final products = await _service.getProductsForListing();
    final existingIds = _listings
        .where((l) => l.platform == MarketplacePlatform.marktplaats && l.status != ListingStatus.verwijderd)
        .map((l) => l.productId)
        .toSet();
    final available = products.where((p) => !existingIds.contains(p['id'] as int)).toList();

    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alle producten staan al in de feed')),
        );
      }
      return;
    }

    final selected = <int>{};
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Producten toevoegen aan feed', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 500,
            height: 400,
            child: Column(
              children: [
                Row(
                  children: [
                    Text('${available.length} beschikbare producten', style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF94A3B8))),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setDialogState(() {
                          if (selected.length == available.length) {
                            selected.clear();
                          } else {
                            selected.addAll(available.map((p) => p['id'] as int));
                          }
                        });
                      },
                      child: Text(
                        selected.length == available.length ? 'Niets selecteren' : 'Alles selecteren',
                        style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: available.length,
                    itemBuilder: (_, i) {
                      final p = available[i];
                      final id = p['id'] as int;
                      return CheckboxListTile(
                        dense: true,
                        value: selected.contains(id),
                        title: Text(p['naam'] as String? ?? 'Product #$id', style: GoogleFonts.dmSans(fontSize: 13)),
                        onChanged: (v) {
                          setDialogState(() {
                            if (v == true) { selected.add(id); } else { selected.remove(id); }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
            ElevatedButton(
              onPressed: selected.isEmpty ? null : () async {
                Navigator.pop(ctx);
                await _service.addProductsToMarktplaatsFeed(selected.toList());
                _loadAll();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${selected.length} product(en) toegevoegd aan Marktplaats feed'), backgroundColor: const Color(0xFF2E7D32)),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
              child: Text('${selected.length} toevoegen', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 5: Sync Log ──

  Widget _buildSyncLogTab() {
    if (_syncLog.isEmpty) {
      return _emptyState('Geen sync-activiteit', 'Synchronisatie-acties worden hier gelogd', Icons.history_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _syncLog.length,
      itemBuilder: (ctx, i) {
        final log = _syncLog[i];
        final isError = log.status == 'fout';
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isError ? const Color(0xFFFFF5F5) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isError ? const Color(0xFFFFCDD2) : const Color(0xFFE8ECF1)),
          ),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                size: 18,
                color: isError ? const Color(0xFFE53935) : const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${log.platform.toUpperCase()} · ${_formatActie(log.actie)}',
                      style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _navy),
                    ),
                    if (log.details.isNotEmpty)
                      Text(
                        log.details.entries.take(3).map((e) => '${e.key}: ${e.value}').join(' · '),
                        style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF94A3B8)),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (log.createdAt != null)
                Text(_formatDateTime(log.createdAt!), style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF94A3B8))),
            ],
          ),
        );
      },
    );
  }

  // ── Dialogs ──

  void _showCredentialsDialog(MarketplacePlatform platform) async {
    if (platform == MarketplacePlatform.ebay) {
      _showEbayCredentialsDialog();
      return;
    }

    final fields = _credentialFields(platform);
    final controllers = <String, TextEditingController>{};

    final existingValues = await _service.getCredentialValues(platform);
    for (final field in fields) {
      final key = field['key']!;
      final isSecret = field['secret'] == 'true';
      controllers[key] = TextEditingController(
        text: isSecret ? '' : (existingValues[key] ?? ''),
      );
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(_platformIcon(platform), color: _platformColor(platform), size: 24),
            const SizedBox(width: 10),
            Text('${platform.label} — API Credentials'),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _platformHelpText(platform),
                style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              ...fields.map((field) {
                final key = field['key']!;
                final isSecret = field['secret'] == 'true';
                final hasExisting = existingValues.containsKey(key);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: controllers[key],
                    obscureText: isSecret,
                    decoration: InputDecoration(
                      labelText: field['label'],
                      border: const OutlineInputBorder(),
                      hintText: isSecret && hasExisting
                          ? '••••••••  (al ingesteld, laat leeg om te behouden)'
                          : field['hint'],
                      suffixIcon: hasExisting
                          ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20)
                          : null,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.deleteCredentials(platform);
              _loadAll();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${platform.label} credentials verwijderd'), backgroundColor: const Color(0xFFE53935)),
                );
              }
            },
            child: const Text('Ontkoppelen', style: TextStyle(color: Color(0xFFE53935))),
          ),
          ElevatedButton(
            onPressed: () async {
              for (final field in fields) {
                final value = controllers[field['key']]!.text.trim();
                if (value.isNotEmpty) {
                  await _service.saveCredential(
                    platform: platform,
                    type: field['key']!,
                    value: value,
                  );
                }
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadAll();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${platform.label} credentials opgeslagen'), backgroundColor: const Color(0xFF2E7D32)),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );
  }

  void _showEbayCredentialsDialog() async {
    final accounts = await _service.getEbayAccounts();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.gavel_rounded, color: Color(0xFFE53935), size: 24),
              const SizedBox(width: 10),
              Text('eBay Accounts', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Beheer meerdere eBay-accounts. Elk account heeft eigen API-credentials.',
                  style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                if (accounts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 18, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Nog geen eBay-accounts geconfigureerd',
                              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF94A3B8))),
                        ),
                      ],
                    ),
                  )
                else
                  ...accounts.map((acct) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE8ECF1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.gavel_rounded, size: 18, color: Color(0xFFE53935)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            acct['display_name'] as String? ?? 'eBay Account',
                            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          tooltip: 'Bewerken',
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showSingleEbayAccountDialog(acct['account_label'] as String?);
                          },
                        ),
                      ],
                    ),
                  )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Sluiten')),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showSingleEbayAccountDialog(null, isNew: true);
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text('Account toevoegen', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showSingleEbayAccountDialog(String? existingLabel, {bool isNew = false}) async {
    final labelCtrl = TextEditingController(text: existingLabel ?? '');
    final clientIdCtrl = TextEditingController();
    final clientSecretCtrl = TextEditingController();

    final existingValues = existingLabel != null
        ? await _service.getCredentialValues(MarketplacePlatform.ebay)
        : <String, String>{};

    clientIdCtrl.text = existingValues['client_id'] ?? '';
    final hasClientId = existingValues.containsKey('client_id');
    final hasClientSecret = existingValues.containsKey('client_secret');
    final hasRefreshToken = existingValues.containsKey('refresh_token');

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isNew ? 'Nieuw eBay Account' : 'eBay Account: ${existingLabel ?? "Standaard"}',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: InputDecoration(
                    labelText: 'Account label',
                    hintText: 'Bijv. "eBay Hoofdaccount" of "eBay UK"',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: clientIdCtrl,
                  decoration: InputDecoration(
                    labelText: 'App ID (Client ID)',
                    hintText: 'Van developer.ebay.com',
                    border: const OutlineInputBorder(),
                    suffixIcon: hasClientId
                        ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: clientSecretCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Cert ID (Client Secret)',
                    border: const OutlineInputBorder(),
                    hintText: hasClientSecret
                        ? '••••••••  (al ingesteld, laat leeg om te behouden)'
                        : 'Geheim, bewaar veilig',
                    suffixIcon: hasClientSecret
                        ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20)
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: hasRefreshToken ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasRefreshToken ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasRefreshToken ? Icons.link : Icons.link_off,
                        color: hasRefreshToken ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hasRefreshToken
                              ? 'eBay-account is gekoppeld (refresh token actief)'
                              : 'Nog niet gekoppeld — sla eerst Client ID en Secret op, klik dan op "Koppel met eBay"',
                          style: GoogleFonts.dmSans(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
          if (hasClientId && hasClientSecret)
            OutlinedButton.icon(
              onPressed: () async {
                final label = labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim();
                final cId = clientIdCtrl.text.trim().isNotEmpty
                    ? clientIdCtrl.text.trim()
                    : existingValues['client_id'] ?? '';
                if (cId.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Vul eerst een Client ID in'), backgroundColor: Colors.red),
                  );
                  return;
                }
                final scopes = Uri.encodeComponent(
                  'https://api.ebay.com/oauth/api_scope/sell.inventory '
                  'https://api.ebay.com/oauth/api_scope/sell.fulfillment '
                  'https://api.ebay.com/oauth/api_scope/sell.account',
                );
                final callbackUrl = Uri.encodeComponent(
                  'Igor_Hulst-IgorHuls-Ventoz-fdmyguttc',
                );
                final state = Uri.encodeComponent(label ?? '');
                final authUrl = 'https://auth.ebay.com/oauth2/authorize'
                    '?client_id=$cId'
                    '&response_type=code'
                    '&redirect_uri=$callbackUrl'
                    '&scope=$scopes'
                    '&state=$state';
                final uri = Uri.parse(authUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Koppel met eBay'),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE53238)),
            ),
          ElevatedButton(
            onPressed: () async {
              try {
                final label = labelCtrl.text.trim().isEmpty ? null : labelCtrl.text.trim();
                final cId = clientIdCtrl.text.trim();
                final cSecret = clientSecretCtrl.text.trim();
                if (cId.isNotEmpty) {
                  await _service.saveCredentialWithAccount(
                    platform: MarketplacePlatform.ebay,
                    type: 'client_id',
                    value: cId,
                    accountLabel: label,
                  );
                }
                if (cSecret.isNotEmpty) {
                  await _service.saveCredentialWithAccount(
                    platform: MarketplacePlatform.ebay,
                    type: 'client_secret',
                    value: cSecret,
                    accountLabel: label,
                  );
                }
                if (cId.isEmpty && cSecret.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Vul minimaal een veld in'), backgroundColor: Colors.orange),
                  );
                  return;
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadAll();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('eBay account "${label ?? "Standaard"}" opgeslagen'),
                      backgroundColor: const Color(0xFF2E7D32),
                    ),
                  );
                }
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Fout bij opslaan: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );
  }

  static const _platformLangs = <String, List<String>>{
    'bol_com': ['nl', 'fr'],
    'ebay': ['nl', 'en', 'de', 'fr'],
    'amazon': ['nl', 'en', 'de', 'fr', 'it', 'es'],
    'marktplaats': ['nl'],
  };

  static const _langLabels = <String, String>{
    'nl': 'Nederlands', 'en': 'English', 'de': 'Deutsch', 'fr': 'Français',
    'es': 'Español', 'it': 'Italiano',
  };

  void _showCreateListingDialog() {
    int? selectedProductId;
    MarketplacePlatform selectedPlatform = MarketplacePlatform.bolCom;
    String selectedTaal = 'nl';
    final prijsCtrl = TextEditingController();
    List<Map<String, dynamic>> products = [];
    bool loadingProducts = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (loadingProducts) {
            _loadProducts().then((p) {
              if (ctx.mounted) {
                setDialogState(() {
                  products = p;
                  loadingProducts = false;
                });
              }
            });
          }

          final availableLangs = _platformLangs[selectedPlatform.code] ?? ['nl'];
          if (!availableLangs.contains(selectedTaal)) selectedTaal = availableLangs.first;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Nieuwe Listing'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<MarketplacePlatform>(
                    initialValue: selectedPlatform,
                    decoration: const InputDecoration(labelText: 'Platform', border: OutlineInputBorder()),
                    items: MarketplacePlatform.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
                    onChanged: (v) => setDialogState(() => selectedPlatform = v!),
                  ),
                  const SizedBox(height: 12),
                  if (loadingProducts)
                    const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())
                  else
                    DropdownButtonFormField<int>(
                      initialValue: selectedProductId,
                      decoration: const InputDecoration(labelText: 'Product', border: OutlineInputBorder()),
                      items: products.map((p) => DropdownMenuItem(
                        value: p['id'] as int,
                        child: Text(p['naam'] as String? ?? 'Product ${p['id']}', overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (v) => setDialogState(() => selectedProductId = v),
                      isExpanded: true,
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: prijsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Prijs (EUR)',
                      border: OutlineInputBorder(),
                      prefixText: '€ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTaal,
                    decoration: const InputDecoration(labelText: 'Taal advertentie', border: OutlineInputBorder()),
                    items: availableLangs.map((lang) => DropdownMenuItem(
                      value: lang,
                      child: Text(_langLabels[lang] ?? lang.toUpperCase()),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => selectedTaal = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
              ElevatedButton(
                onPressed: selectedProductId == null ? null : () async {
                  try {
                    await _service.createListing(MarketplaceListing(
                      productId: selectedProductId!,
                      platform: selectedPlatform,
                      prijs: double.tryParse(prijsCtrl.text.replaceAll(',', '.')),
                      taal: selectedTaal,
                    ));
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _loadAll();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Listing aangemaakt'), backgroundColor: Color(0xFF2E7D32)),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Fout: $e'), backgroundColor: const Color(0xFFE53935)),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
                child: const Text('Aanmaken'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadProducts() async {
    return _service.getProductsForListing();
  }

  // ── Actions ──

  Future<void> _handleListingAction(MarketplaceListing listing, String action) async {
    switch (action) {
      case 'edit':
        _showEditListingDialog(listing);
      case 'publish':
        try {
          await _service.publishListing(listing.id!);
          await _service.updateListing(listing.id!, status: ListingStatus.actief);
          _loadAll();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Publiceren mislukt: $e'), backgroundColor: const Color(0xFFE53935)));
          }
        }
      case 'pause':
        await _service.updateListing(listing.id!, status: ListingStatus.gepauzeerd);
        _loadAll();
      case 'activate':
        await _service.updateListing(listing.id!, status: ListingStatus.actief);
        _loadAll();
      case 'check_status':
        try {
          final result = await _service.checkProcessStatus(listing.id!);
          _loadAll();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message'] ?? 'Status gecontroleerd'), backgroundColor: result['extern_id'] != null ? const Color(0xFF2E7D32) : _accent),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status check mislukt: $e'), backgroundColor: const Color(0xFFE53935)));
          }
        }
      case 'open':
        if (listing.externUrl != null) {
          final uri = Uri.tryParse(listing.externUrl!);
          if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Listing verwijderen'),
            content: Text('Weet je zeker dat je deze ${listing.platform.label} listing wilt verwijderen?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
                child: const Text('Verwijderen'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _service.deleteListing(listing.id!);
          _loadAll();
        }
    }
  }

  void _showEditListingDialog(MarketplaceListing listing) {
    final prijsCtrl = TextEditingController(text: listing.prijs?.toStringAsFixed(2) ?? '');
    bool voorraadSync = listing.voorraadSync;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Listing bewerken — ${listing.platform.label}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(listing.productNaam ?? 'Product #${listing.productId}',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
                const SizedBox(height: 16),
                TextField(
                  controller: prijsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Prijs (EUR)', border: OutlineInputBorder(), prefixText: '€ '),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Voorraad automatisch synchroniseren'),
                  value: voorraadSync,
                  onChanged: (v) => setDialogState(() => voorraadSync = v),
                  activeTrackColor: Colors.green.withValues(alpha: 0.4),
                  activeThumbColor: Colors.green,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
            ElevatedButton(
              onPressed: () async {
                await _service.updateListing(
                  listing.id!,
                  prijs: double.tryParse(prijsCtrl.text.replaceAll(',', '.')),
                  voorraadSync: voorraadSync,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadAll();
              },
              style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
              child: const Text('Opslaan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchAllOrders() async {
    for (final platform in MarketplacePlatform.values) {
      final cred = _credentials.firstWhere(
        (c) => c.platform == platform,
        orElse: () => MarketplaceCredentialStatus(platform: platform),
      );
      if (!cred.isConfigured) continue;
      try {
        await _service.fetchOrdersFromPlatform(platform);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${platform.label} orders ophalen mislukt: $e'), backgroundColor: const Color(0xFFE53935)),
          );
        }
      }
    }
    _loadAll();
  }

  // ── Helpers ──

  Widget _emptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) => DateFormat('d MMM yyyy').format(dt);
  String _formatDateTime(DateTime dt) => DateFormat('d MMM HH:mm').format(dt);

  String _formatActie(String actie) => switch (actie) {
    'listing_create' => 'Listing aangemaakt',
    'listing_update' => 'Listing bijgewerkt',
    'listing_delete' => 'Listing verwijderd',
    'stock_sync' => 'Voorraad gesynchroniseerd',
    'price_sync' => 'Prijs gesynchroniseerd',
    'order_import' => 'Order geïmporteerd',
    'import_listings' => 'Listings geïmporteerd',
    'publish_listing' => 'Listing gepubliceerd',
    'auto_pause' => 'Automatisch gepauzeerd',
    'auto_close' => 'Automatisch gesloten',
    'auto_reactivate' => 'Automatisch geheractiveerd',
    'low_stock_warning' => 'Lage voorraad waarschuwing',
    'batch_add_to_feed' => 'Aan feed toegevoegd',
    _ => actie,
  };

  IconData _platformIcon(MarketplacePlatform platform) => switch (platform) {
    MarketplacePlatform.bolCom => Icons.store_rounded,
    MarketplacePlatform.ebay => Icons.gavel_rounded,
    MarketplacePlatform.amazon => Icons.shopping_cart_rounded,
    MarketplacePlatform.marktplaats => Icons.sell_rounded,
    MarketplacePlatform.admark => Icons.ads_click_rounded,
  };

  Color _platformColor(MarketplacePlatform platform) => switch (platform) {
    MarketplacePlatform.bolCom => const Color(0xFF0070E0),
    MarketplacePlatform.ebay => const Color(0xFFE53935),
    MarketplacePlatform.amazon => const Color(0xFFFF9900),
    MarketplacePlatform.marktplaats => const Color(0xFF009E3D),
    MarketplacePlatform.admark => const Color(0xFF6A1B9A),
  };

  Color _statusColor(ListingStatus status) => switch (status) {
    ListingStatus.concept => const Color(0xFF64748B),
    ListingStatus.actief => const Color(0xFF2E7D32),
    ListingStatus.gepauzeerd => const Color(0xFFF57F17),
    ListingStatus.verwijderd => const Color(0xFF94A3B8),
    ListingStatus.fout => const Color(0xFFE53935),
  };

  Color _orderStatusColor(MarketplaceOrderStatus status) => switch (status) {
    MarketplaceOrderStatus.nieuw => const Color(0xFF1565C0),
    MarketplaceOrderStatus.verwerkt => const Color(0xFFF57F17),
    MarketplaceOrderStatus.verzonden => const Color(0xFF2E7D32),
    MarketplaceOrderStatus.geannuleerd => const Color(0xFFE53935),
  };

  List<Map<String, String>> _credentialFields(MarketplacePlatform platform) => switch (platform) {
    MarketplacePlatform.bolCom => [
      {'key': 'client_id', 'label': 'Client ID', 'hint': 'Uit het Bol.com Partner Platform', 'secret': 'false'},
      {'key': 'client_secret', 'label': 'Client Secret', 'hint': 'Geheim, bewaar veilig', 'secret': 'true'},
    ],
    MarketplacePlatform.ebay => [
      {'key': 'client_id', 'label': 'App ID (Client ID)', 'hint': 'Van developer.ebay.com', 'secret': 'false'},
      {'key': 'client_secret', 'label': 'Cert ID (Client Secret)', 'hint': 'Geheim, bewaar veilig', 'secret': 'true'},
    ],
    MarketplacePlatform.amazon => [
      {'key': 'client_id', 'label': 'Client ID', 'hint': 'SP-API App Client ID', 'secret': 'false'},
      {'key': 'client_secret', 'label': 'Client Secret', 'hint': 'SP-API App Secret', 'secret': 'true'},
      {'key': 'refresh_token', 'label': 'Refresh Token', 'hint': 'LWA Refresh Token', 'secret': 'true'},
      {'key': 'seller_id', 'label': 'Seller ID', 'hint': 'Amazon Seller/Merchant ID', 'secret': 'false'},
    ],
    MarketplacePlatform.marktplaats => [
      {'key': 'client_id', 'label': 'Client ID', 'hint': 'Van Marktplaats API-registratie', 'secret': 'false'},
      {'key': 'client_secret', 'label': 'Client Secret', 'hint': 'Geheim, bewaar veilig', 'secret': 'true'},
    ],
    MarketplacePlatform.admark => [
      {'key': 'client_id', 'label': 'Client ID', 'hint': 'Van Admark API-registratie', 'secret': 'false'},
      {'key': 'client_secret', 'label': 'Client Secret', 'hint': 'Geheim, bewaar veilig', 'secret': 'true'},
    ],
  };

  String _platformHelpText(MarketplacePlatform platform) => switch (platform) {
    MarketplacePlatform.bolCom => 'Credentials aanvragen via het Bol.com Partner Platform → Instellingen → API-instellingen.',
    MarketplacePlatform.ebay => 'Registreer een app op developer.ebay.com en maak OAuth tokens aan.',
    MarketplacePlatform.amazon => 'Registreer via Seller Central → Apps → Develop Apps. Jaarabonnement \$1.400 vereist.',
    MarketplacePlatform.marktplaats => 'Neem contact op met Marktplaats om API-credentials aan te vragen.',
    MarketplacePlatform.admark => 'Neem contact op met Admark om API-credentials aan te vragen.',
  };
}
