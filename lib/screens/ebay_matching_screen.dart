import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/marketplace_listing.dart';
import '../services/marketplace_service.dart';

class EbayMatchingScreen extends StatefulWidget {
  const EbayMatchingScreen({super.key});

  @override
  State<EbayMatchingScreen> createState() => _EbayMatchingScreenState();
}

class _EbayMatchingScreenState extends State<EbayMatchingScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _accent = Color(0xFF1B4965);

  final _service = MarketplaceService();
  List<MarketplaceListing> _unmatched = [];
  List<MarketplaceListing> _suggested = [];
  List<MarketplaceListing> _confirmed = [];
  bool _loading = true;
  bool _importing = false;
  bool _autoMatching = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final all = await _service.getListings(platform: MarketplacePlatform.ebay);
      if (!mounted) return;
      setState(() {
        _unmatched = all.where((l) => l.matchStatus == 'unmatched').toList();
        _suggested = all.where((l) => l.matchStatus == 'suggested').toList();
        _confirmed = all.where((l) => l.matchStatus == 'confirmed' || l.matchStatus == 'manual').toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij laden: $e'), backgroundColor: const Color(0xFFE53935)),
      );
    }
  }

  Future<void> _importListings() async {
    setState(() => _importing = true);
    try {
      final accounts = await _service.getEbayAccounts();
      int totalImported = 0;
      int totalUpdated = 0;
      int totalTotal = 0;

      if (accounts.isEmpty) {
        final result = await _service.importEbayListings();
        totalImported = (result['imported'] as int?) ?? 0;
        totalUpdated = (result['updated'] as int?) ?? 0;
        totalTotal = (result['total'] as int?) ?? 0;
      } else {
        for (final account in accounts) {
          final label = account['account_label'] as String?;
          final result = await _service.importEbayListings(accountLabel: label);
          totalImported += (result['imported'] as int?) ?? 0;
          totalUpdated += (result['updated'] as int?) ?? 0;
          totalTotal += (result['total'] as int?) ?? 0;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$totalImported nieuw, $totalUpdated bijgewerkt van $totalTotal items'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import mislukt: $e'), backgroundColor: const Color(0xFFE53935)),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _autoMatch() async {
    setState(() => _autoMatching = true);
    try {
      final result = await _service.autoMatchListings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result['matched']} gematcht, ${result['not_found']} niet gevonden'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto-match mislukt: $e'), backgroundColor: const Color(0xFFE53935)),
      );
    } finally {
      if (mounted) setState(() => _autoMatching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('eBay Matching', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          if (_autoMatching)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else
            TextButton.icon(
              onPressed: _autoMatch,
              icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.white70),
              label: Text('Auto-match', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: _showPublishWizard,
            icon: const Icon(Icons.publish_rounded, size: 18, color: Colors.white70),
            label: Text('Publiceren', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(width: 4),
          if (_importing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else
            TextButton.icon(
              onPressed: _importListings,
              icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white70),
              label: Text('Importeren', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildSummaryRow(),
                  const SizedBox(height: 24),
                  if (_unmatched.isNotEmpty) ...[
                    _sectionHeader('Niet gekoppeld', _unmatched.length, const Color(0xFFE53935)),
                    const SizedBox(height: 12),
                    ..._unmatched.map(_buildListingCard),
                    const SizedBox(height: 24),
                  ],
                  if (_suggested.isNotEmpty) ...[
                    _sectionHeader('Voorgesteld', _suggested.length, const Color(0xFFF57F17)),
                    const SizedBox(height: 12),
                    ..._suggested.map(_buildListingCard),
                    const SizedBox(height: 24),
                  ],
                  if (_confirmed.isNotEmpty) ...[
                    _sectionHeader('Gekoppeld', _confirmed.length, const Color(0xFF2E7D32)),
                    const SizedBox(height: 12),
                    ..._confirmed.map(_buildListingCard),
                  ],
                  if (_unmatched.isEmpty && _suggested.isEmpty && _confirmed.isEmpty)
                    _emptyState(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryRow() {
    return Row(
      children: [
        _summaryCard('Niet gekoppeld', _unmatched.length, const Color(0xFFE53935)),
        const SizedBox(width: 12),
        _summaryCard('Voorgesteld', _suggested.length, const Color(0xFFF57F17)),
        const SizedBox(width: 12),
        _summaryCard('Gekoppeld', _confirmed.length, const Color(0xFF2E7D32)),
        const SizedBox(width: 12),
        _summaryCard('Totaal', _unmatched.length + _suggested.length + _confirmed.length, _accent),
      ],
    );
  }

  Widget _summaryCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(count.toString(), style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 20, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }

  Widget _buildListingCard(MarketplaceListing listing) {
    final matchColor = switch (listing.matchStatus) {
      'suggested' => const Color(0xFFF57F17),
      'confirmed' || 'manual' => const Color(0xFF2E7D32),
      _ => const Color(0xFFE53935),
    };
    final matchLabel = switch (listing.matchStatus) {
      'suggested' => 'Voorgesteld',
      'confirmed' => 'Bevestigd',
      'manual' => 'Handmatig',
      _ => 'Niet gekoppeld',
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: const Color(0xFFE8ECF1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // eBay image
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: listing.externImageUrl != null
                  ? Image.network(listing.externImageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported, size: 24, color: Color(0xFF94A3B8)))
                  : const Icon(Icons.gavel_rounded, size: 24, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(width: 14),
            // eBay info
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.externTitle ?? listing.ebaySku ?? 'Onbekend',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _navy),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: matchColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(matchLabel, style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: matchColor)),
                      ),
                      if (listing.ebaySku != null)
                        Text('SKU: ${listing.ebaySku}', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8))),
                      if (listing.prijs != null)
                        Text('€ ${listing.prijs!.toStringAsFixed(2)}', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                      if (listing.externQuantity != null)
                        Text('Voorraad: ${listing.externQuantity}', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8))),
                      if (listing.ebayMarketplaces.isNotEmpty)
                        Text(listing.ebayMarketplaces.map((m) => m.replaceAll('EBAY_', '')).join(', '),
                            style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                      if (listing.accountLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(4)),
                          child: Text(listing.accountLabel!, style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF2E7D32))),
                        ),
                    ],
                  ),
                  if (listing.productNaam != null && listing.productId != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.link, size: 14, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            listing.productNaam!,
                            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF2E7D32), fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Actions
            Column(
              children: [
                if (listing.matchStatus == 'unmatched' || listing.matchStatus == null)
                  _actionButton('Koppelen', Icons.link, _accent, () => _showMatchDialog(listing)),
                if (listing.matchStatus == 'suggested') ...[
                  _actionButton('Bevestigen', Icons.check, const Color(0xFF2E7D32), () async {
                    if (listing.id == null) return;
                    await _service.confirmMatch(listing.id!);
                    _loadAll();
                  }),
                  const SizedBox(height: 4),
                  _actionButton('Wijzigen', Icons.edit, _accent, () => _showMatchDialog(listing)),
                ],
                if (listing.matchStatus == 'confirmed' || listing.matchStatus == 'manual') ...[
                  _actionButton('Voorraad sync', Icons.inventory_2, const Color(0xFF1565C0), () => _showStockSyncDialog(listing)),
                  const SizedBox(height: 4),
                  _actionButton('Prijs sync', Icons.euro, const Color(0xFF6A1B9A), () => _showPriceSyncDialog(listing)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: listing.voorraadSync ? 'Auto-sync aan' : 'Auto-sync uit',
                        child: Switch(
                          value: listing.voorraadSync,
                          onChanged: (val) async {
                            if (listing.id == null) return;
                            await _service.updateListing(listing.id!, voorraadSync: val);
                            _loadAll();
                          },
                          activeColor: const Color(0xFF2E7D32),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      Text('Auto', style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF94A3B8))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _actionButton('Ontkoppelen', Icons.link_off, const Color(0xFFE53935), () async {
                    if (listing.id == null) return;
                    await _service.unmatchListing(listing.id!);
                    _loadAll();
                  }),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 110,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
      ),
    );
  }

  void _showMatchDialog(MarketplaceListing listing) {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool searching = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Koppel aan catalogusproduct', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                listing.externTitle ?? listing.ebaySku ?? '',
                style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Zoek op naam, artikelnummer of EAN...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    suffixIcon: searching
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                        : null,
                  ),
                  onChanged: (query) async {
                    if (query.length < 2) {
                      setDialogState(() => results = []);
                      return;
                    }
                    setDialogState(() => searching = true);
                    try {
                      final r = await _service.searchCatalogProducts(query);
                      if (ctx.mounted) setDialogState(() { results = r; searching = false; });
                    } catch (_) {
                      if (ctx.mounted) setDialogState(() => searching = false);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: results.isEmpty
                      ? Center(
                          child: Text(
                            searchCtrl.text.length < 2 ? 'Typ minstens 2 tekens om te zoeken' : 'Geen producten gevonden',
                            style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF94A3B8)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final p = results[i];
                            return ListTile(
                              dense: true,
                              leading: p['afbeelding_url'] != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(p['afbeelding_url'] as String, width: 40, height: 40, fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const SizedBox(width: 40, height: 40)),
                                    )
                                  : Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                      child: const Icon(Icons.inventory_2, size: 18, color: Color(0xFF94A3B8)),
                                    ),
                              title: Text(p['naam'] as String? ?? '', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500)),
                              subtitle: Wrap(
                                spacing: 8,
                                children: [
                                  if (p['artikelnummer'] != null)
                                    Text('Art: ${p['artikelnummer']}', style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF94A3B8))),
                                  if (p['ean_code'] != null)
                                    Text('EAN: ${p['ean_code']}', style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF94A3B8))),
                                  if (p['prijs'] != null)
                                    Text('€ ${(p['prijs'] as num).toStringAsFixed(2)}', style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF64748B))),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.link, color: Color(0xFF1565C0)),
                                onPressed: () async {
                                  if (listing.id == null) return;
                                  await _service.matchListing(listing.id!, p['id'] as int);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _loadAll();
                                },
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
          ],
        ),
      ),
    );
  }

  static const _ebayMarketplaces = <String, String>{
    'EBAY_NL': 'eBay Nederland',
    'EBAY_DE': 'eBay Duitsland',
    'EBAY_GB': 'eBay Verenigd Koninkrijk',
    'EBAY_FR': 'eBay Frankrijk',
    'EBAY_IT': 'eBay Italië',
    'EBAY_ES': 'eBay Spanje',
    'EBAY_BE': 'eBay België',
    'EBAY_AT': 'eBay Oostenrijk',
    'EBAY_PL': 'eBay Polen',
    'EBAY_IE': 'eBay Ierland',
    'EBAY_US': 'eBay Verenigde Staten',
  };

  static const _conditions = <String, String>{
    'NEW': 'Nieuw',
    'LIKE_NEW': 'Als nieuw',
    'NEW_OTHER': 'Nieuw (overig)',
    'NEW_WITH_DEFECTS': 'Nieuw met defecten',
    'USED_EXCELLENT': 'Gebruikt - Uitstekend',
    'USED_VERY_GOOD': 'Gebruikt - Zeer goed',
    'USED_GOOD': 'Gebruikt - Goed',
    'USED_ACCEPTABLE': 'Gebruikt - Acceptabel',
    'FOR_PARTS_OR_NOT_WORKING': 'Voor onderdelen / defect',
  };

  void _showPublishWizard() async {
    final products = await _service.getProductsForListing();
    if (!mounted) return;

    int? selectedProductId;
    String selectedMarketplace = 'EBAY_NL';
    String selectedCondition = 'NEW';
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final quantityCtrl = TextEditingController(text: '1');
    String? selectedAccountLabel;
    bool publishing = false;

    List<Map<String, dynamic>> accounts = [];
    try {
      accounts = await _service.getEbayAccounts();
      if (accounts.isNotEmpty) {
        selectedAccountLabel = accounts.first['account_label'] as String?;
      }
    } catch (_) {}

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedProduct = selectedProductId != null
              ? products.firstWhere((p) => p['id'] == selectedProductId, orElse: () => <String, dynamic>{})
              : null;

          if (selectedProduct != null && titleCtrl.text.isEmpty) {
            titleCtrl.text = selectedProduct['naam'] as String? ?? '';
            priceCtrl.text = (selectedProduct['prijs'] as num?)?.toStringAsFixed(2) ?? '';
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Publiceer op eBay', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 16)),
            content: SizedBox(
              width: 520,
              height: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFCC02).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFE65100)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Dit maakt een LIVE listing aan op eBay. Controleer alle gegevens zorgvuldig.',
                              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFE65100)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Product selectie
                    DropdownButtonFormField<int>(
                      value: selectedProductId,
                      decoration: InputDecoration(
                        labelText: 'Product uit catalogus',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      isExpanded: true,
                      items: products.map((p) => DropdownMenuItem(
                        value: p['id'] as int,
                        child: Text(p['naam'] as String? ?? 'Product ${p['id']}', overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (v) {
                        setDialogState(() {
                          selectedProductId = v;
                          final p = products.firstWhere((p) => p['id'] == v, orElse: () => <String, dynamic>{});
                          titleCtrl.text = p['naam'] as String? ?? '';
                          priceCtrl.text = (p['prijs'] as num?)?.toStringAsFixed(2) ?? '';
                          descCtrl.text = '';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    // Account selectie
                    if (accounts.length > 1)
                      DropdownButtonFormField<String?>(
                        value: selectedAccountLabel,
                        decoration: InputDecoration(
                          labelText: 'eBay Account',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: accounts.map((a) => DropdownMenuItem(
                          value: a['account_label'] as String?,
                          child: Text(a['display_name'] as String? ?? 'Standaard'),
                        )).toList(),
                        onChanged: (v) => setDialogState(() => selectedAccountLabel = v),
                      ),
                    if (accounts.length > 1) const SizedBox(height: 12),
                    // Marketplace
                    DropdownButtonFormField<String>(
                      value: selectedMarketplace,
                      decoration: InputDecoration(
                        labelText: 'eBay Marktplaats',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: _ebayMarketplaces.entries.map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      )).toList(),
                      onChanged: (v) => setDialogState(() => selectedMarketplace = v!),
                    ),
                    const SizedBox(height: 12),
                    // Titel
                    TextField(
                      controller: titleCtrl,
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText: 'Listing titel',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Beschrijving
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Beschrijving (optioneel)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Prijs
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Prijs (EUR)',
                              prefixText: '€ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Aantal
                        Expanded(
                          child: TextField(
                            controller: quantityCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Aantal',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Conditie
                    DropdownButtonFormField<String>(
                      value: selectedCondition,
                      decoration: InputDecoration(
                        labelText: 'Conditie',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: _conditions.entries.map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      )).toList(),
                      onChanged: (v) => setDialogState(() => selectedCondition = v!),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
              ElevatedButton.icon(
                onPressed: selectedProductId == null || publishing ? null : () async {
                  setDialogState(() => publishing = true);
                  try {
                    final result = await _service.publishToEbayNew(
                      productId: selectedProductId!,
                      marketplaceId: selectedMarketplace,
                      title: titleCtrl.text.trim().isEmpty ? null : titleCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                      price: double.tryParse(priceCtrl.text.replaceAll(',', '.')),
                      quantity: int.tryParse(quantityCtrl.text) ?? 1,
                      condition: selectedCondition,
                      accountLabel: selectedAccountLabel,
                    );

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result['message'] as String? ?? 'Gepubliceerd'),
                          backgroundColor: result['success'] == true ? const Color(0xFF2E7D32) : const Color(0xFFE53935),
                        ),
                      );
                      _loadAll();
                    }
                  } catch (e) {
                    setDialogState(() => publishing = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Publiceren mislukt: $e'), backgroundColor: const Color(0xFFE53935)),
                      );
                    }
                  }
                },
                icon: publishing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.publish, size: 18),
                label: Text('Publiceren', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showStockSyncDialog(MarketplaceListing listing) async {
    if (listing.id == null || listing.productId == null) return;

    int? catalogStock;
    try {
      final rows = await _service.getProductsForListing();
      final match = rows.where((p) => p['id'] == listing.productId).toList();
      if (match.isNotEmpty) {
        catalogStock = match.first['voorraad'] as int?;
      }
    } catch (_) {}

    final stockCtrl = TextEditingController(text: (catalogStock ?? listing.externQuantity ?? 0).toString());

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Voorraad synchroniseren', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFCC02).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFE65100)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dit wijzigt de voorraad op eBay!',
                        style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFE65100)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(listing.externTitle ?? '', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('HUIDIGE VOORRAAD EBAY', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
                        const SizedBox(height: 4),
                        Text('${listing.externQuantity ?? "Onbekend"}', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nieuwe voorraad',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              if (catalogStock != null) ...[
                const SizedBox(height: 8),
                Text('Catalogusvoorraad: $catalogStock', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B))),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.sync, size: 18),
            label: Text('Bijwerken op eBay', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final stock = int.tryParse(stockCtrl.text) ?? 0;
      try {
        final result = await _service.syncEbayStock(listing.id!, stock);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Voorraad bijgewerkt'),
            backgroundColor: result['success'] == true ? const Color(0xFF2E7D32) : const Color(0xFFE53935),
          ),
        );
        _loadAll();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync mislukt: $e'), backgroundColor: const Color(0xFFE53935)),
        );
      }
    }
    stockCtrl.dispose();
  }

  void _showPriceSyncDialog(MarketplaceListing listing) async {
    if (listing.id == null) return;

    final priceCtrl = TextEditingController(text: listing.prijs?.toStringAsFixed(2) ?? '');

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Prijs synchroniseren', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFCC02).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFE65100)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dit wijzigt de prijs op eBay!',
                        style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFE65100)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(listing.externTitle ?? '', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('HUIDIGE PRIJS EBAY', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
                        const SizedBox(height: 4),
                        Text(listing.prijs != null ? '€ ${listing.prijs!.toStringAsFixed(2)}' : 'Onbekend',
                            style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Nieuwe prijs (EUR)',
                        prefixText: '€ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.sync, size: 18),
            label: Text('Bijwerken op eBay', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
      try {
        final result = await _service.syncEbayPrice(listing.id!, price);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Prijs bijgewerkt'),
            backgroundColor: result['success'] == true ? const Color(0xFF2E7D32) : const Color(0xFFE53935),
          ),
        );
        _loadAll();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync mislukt: $e'), backgroundColor: const Color(0xFFE53935)),
        );
      }
    }
    priceCtrl.dispose();
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gavel_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Geen eBay-listings', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 4),
            Text('Klik op "Importeren" om je eBay-advertenties op te halen', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }
}
