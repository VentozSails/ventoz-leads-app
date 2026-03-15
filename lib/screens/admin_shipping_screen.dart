import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/order_service.dart';
import '../services/order_email_service.dart';
import '../services/myparcel_service.dart';
import '../services/packaging_service.dart';
import '../services/web_scraper_service.dart';
import '../services/shipping_service.dart';
import '../services/user_service.dart';
import '../widgets/stock_update_after_shipment.dart';

class AdminShippingScreen extends StatefulWidget {
  const AdminShippingScreen({super.key});

  @override
  State<AdminShippingScreen> createState() => _AdminShippingScreenState();
}

class _AdminShippingScreenState extends State<AdminShippingScreen> {
  static const _navy = Color(0xFF1B2A4A);
  static const _teal = Color(0xFF00897B);

  final _orderService = OrderService();
  final _emailService = OrderEmailService();
  final _myparcel = MyParcelService();
  final _packagingService = PackagingService();
  final _scraper = WebScraperService();
  final _userService = UserService();
  final _fmt = NumberFormat.currency(locale: 'nl_NL', symbol: '€');

  List<Order> _pendingOrders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.bestellingenVerzenden) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
        );
      }
      return;
    }
    final pending = await _orderService.fetchOrdersByStatus('betaald');
    if (!mounted) return;
    setState(() {
      _pendingOrders = pending;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bestellingen verzenden', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Vernieuwen', onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pendingOrders.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF43A047)),
      const SizedBox(height: 16),
      Text('Alle bestellingen zijn verzonden!', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF43A047))),
      const SizedBox(height: 8),
      const Text('Er staan geen betaalde orders klaar voor verzending.', style: TextStyle(color: Color(0xFF64748B))),
    ]));
  }

  Widget _buildList() {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        color: const Color(0xFFF8FAFB),
        child: Row(children: [
          const Icon(Icons.local_shipping, size: 20, color: _navy),
          const SizedBox(width: 10),
          Text('${_pendingOrders.length} bestelling${_pendingOrders.length == 1 ? '' : 'en'} klaar voor verzending',
            style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: _navy)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _pendingOrders.length,
          itemBuilder: (_, i) => _buildOrderCard(_pendingOrders[i]),
        ),
      ),
    ]);
  }

  Widget _buildOrderCard(Order order) {
    final hasMyParcel = order.myparcelShipmentId != null;
    final step = hasMyParcel ? 2 : 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _stepBadge(step, hasMyParcel ? 'Concept klaar' : 'Wacht op concept'),
            const SizedBox(width: 10),
            Text(order.orderNummer, style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: _navy)),
            const Spacer(),
            Text(order.formatTotaal(), style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w800, color: _teal)),
          ]),
          const SizedBox(height: 8),

          Row(children: [
            const Icon(Icons.person, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 4),
            Expanded(child: Text(order.naam ?? order.userEmail,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 12),
            const Icon(Icons.location_on, size: 14, color: Color(0xFF64748B)),
            const SizedBox(width: 4),
            Expanded(child: Text('${order.postcode ?? ''} ${order.woonplaats ?? ''} (${order.landCode.toUpperCase()})'.trim(),
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 4),

          if (order.regels.isNotEmpty)
            Text(order.regels.map((r) => '${r.aantal}x ${r.productNaam}').join(', '),
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),

          if (order.betaaldOp != null)
            Text('Betaald op ${DateFormat('dd-MM-yyyy HH:mm').format(order.betaaldOp!)}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),

          const Divider(height: 18),

          _buildActions(order, hasMyParcel),
        ]),
      ),
    );
  }

  Widget _stepBadge(int step, String label) {
    final color = step == 1 ? const Color(0xFFE65100) : const Color(0xFF1565C0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(child: Text('$step', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget _buildActions(Order order, bool hasMyParcel) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      if (!hasMyParcel)
        ElevatedButton.icon(
          icon: const Icon(Icons.rocket_launch, size: 15),
          label: const Text('Stap 1: Concept klaarzetten', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(backgroundColor: _teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
          onPressed: () => _showConceptDialog(order),
        ),
      if (hasMyParcel) ...[
        ElevatedButton.icon(
          icon: const Icon(Icons.print, size: 15),
          label: const Text('Stap 2: Label genereren & verzenden', style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
          onPressed: () => _showLabelDialog(order),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFE65100)),
          label: const Text('Concept verwijderen', style: TextStyle(fontSize: 11, color: Color(0xFFE65100))),
          onPressed: () => _deleteConceptAndReload(order),
        ),
      ],
    ]);
  }

  // ── STEP 1: Concept klaarzetten ──

  void _showConceptDialog(Order order) {
    int selectedCarrier = 1;
    int selectedPackageType = 1;
    int selectedInsurance = 0;
    bool optOnlyRecipient = false;
    bool optSignature = false;
    bool optReturn = false;
    bool optLargeFormat = false;
    PackagingBox? selectedBox;
    List<PackagingBox> boxes = [];
    List<PackagingBox> suggestedBoxes = [];
    int productWeightGrams = 0;
    int maxGewichtGram = 31500;
    int maxOmtrekCm = 176;
    bool loadingWeights = true;
    bool processing = false;

    final adresParts = _splitStreetNumber(order.adres ?? '');
    final nameCtrl = TextEditingController(text: order.naam ?? order.userEmail);
    final streetCtrl = TextEditingController(text: adresParts.$1);
    final numberCtrl = TextEditingController(text: adresParts.$2);
    final suffixCtrl = TextEditingController(text: adresParts.$3);
    final postalCtrl = TextEditingController(text: order.postcode ?? '');
    final cityCtrl = TextEditingController(text: order.woonplaats ?? '');
    final ccCtrl = TextEditingController(text: order.landCode.toUpperCase());
    final weightCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          if (loadingWeights) {
            Future(() async {
              final config = await _myparcel.getConfig();
              final allBoxes = await _packagingService.getAll();
              final catalog = await _scraper.fetchCatalog(includeBlocked: true);

              int w = 0;
              final orderProductIds = <String>{};
              for (final r in order.regels) {
                final p = catalog.where((p) => p.artikelnummer == r.productId || p.displayNaam == r.productNaam).firstOrNull;
                if (p?.gewicht != null) w += (p!.gewicht! * r.aantal).toInt();
                if (p?.artikelnummer != null) orderProductIds.add(p!.artikelnummer!);
              }

              final suggested = await _packagingService.suggestBoxes(
                productIds: orderProductIds,
                totalWeightGrams: w,
              );

              if (!ctx.mounted) return;
              setSt(() {
                selectedCarrier = config?.defaultCarrierId ?? 1;
                maxGewichtGram = config?.maxGewichtGram ?? 31500;
                maxOmtrekCm = config?.maxOmtrekCm ?? 176;
                boxes = allBoxes;
                suggestedBoxes = suggested;

                if (suggested.isNotEmpty) {
                  selectedBox = suggested.first;
                } else if (config != null && config.defaultBoxId.isNotEmpty) {
                  selectedBox = allBoxes.where((b) => b.id == config.defaultBoxId).firstOrNull;
                }

                productWeightGrams = w;
                weightCtrl.text = '${w + (selectedBox?.gewicht ?? 0)}';
                loadingWeights = false;
              });
            });
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: const SizedBox(width: 500, height: 160, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Gegevens laden...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              ]))),
            );
          }

          final isStdPkg = selectedPackageType == 1 || selectedPackageType == 6;
          final cc = ccCtrl.text.trim().toUpperCase();
          final isNonEu = {'GB', 'UK', 'CH', 'NO', 'IS', 'LI'}.contains(cc);
          final shippingRate = ShippingService.getRate(cc);
          final totalWeight = productWeightGrams + (selectedBox?.gewicht ?? 0);

          final weightExceeded = maxGewichtGram > 0 && totalWeight > maxGewichtGram;
          final boxOmtrek = selectedBox?.omtrekCm ?? 0;
          final omtrekExceeded = maxOmtrekCm > 0 && boxOmtrek > 0 && boxOmtrek > maxOmtrekCm;
          final limitsExceeded = weightExceeded || omtrekExceeded;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620, maxHeight: 740),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // ── Header ──
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
                  decoration: const BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.rocket_launch, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Concept klaarzetten', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('${order.orderNummer}  \u00B7  ${order.formatTotaal()}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    ])),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ]),
                ),

                // ── Body ──
                Flexible(child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    _sectionHeader(Icons.shopping_bag, 'Artikelen'),
                    const SizedBox(height: 6),
                    ...order.regels.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(children: [
                        Text('${r.aantal}\u00D7', style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w600, color: _teal)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(r.productNaam, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                        Text(_fmt.format(r.regelTotaal), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ]),
                    )),

                    const Divider(height: 24),

                    _sectionHeader(Icons.person, 'Ontvanger \u2014 controleer en corrigeer'),
                    const SizedBox(height: 8),
                    _field(nameCtrl, 'Naam'),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(flex: 5, child: _field(streetCtrl, 'Straat')),
                      const SizedBox(width: 8),
                      SizedBox(width: 60, child: _field(numberCtrl, 'Nr.')),
                      const SizedBox(width: 8),
                      SizedBox(width: 60, child: _field(suffixCtrl, 'Toev.')),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      SizedBox(width: 100, child: _field(postalCtrl, 'Postcode')),
                      const SizedBox(width: 8),
                      Expanded(child: _field(cityCtrl, 'Plaats')),
                      const SizedBox(width: 8),
                      SizedBox(width: 60, child: TextField(
                        controller: ccCtrl,
                        decoration: _inputDeco('Land'),
                        onChanged: (_) => setSt(() {}),
                      )),
                    ]),
                    if (isNonEu) ...[
                      const SizedBox(height: 6),
                      _infoBanner(Icons.public, 'Non-EU bestemming \u2014 douaneverklaring wordt automatisch meegezonden.', const Color(0xFFE65100), const Color(0xFFFFF3E0)),
                    ],

                    const Divider(height: 24),

                    _sectionHeader(Icons.euro, 'Verzendkosten'),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFF0F7FF), Color(0xFFE8F5E9)]),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFB0BEC5), width: 0.5),
                      ),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${shippingRate.countryName} (${cc.isNotEmpty ? cc : "?"})',
                            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
                          Text('Levertijd: ${shippingRate.deliveryTime}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(shippingRate.cost == 0 ? 'Gratis' : _fmt.format(shippingRate.cost),
                            style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w800, color: shippingRate.cost == 0 ? const Color(0xFF2E7D32) : _navy)),
                          Text('excl. BTW', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                        ]),
                      ]),
                    ),

                    const Divider(height: 24),

                    _sectionHeader(Icons.settings, 'Zendinginstellingen'),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: DropdownButtonFormField<int>(
                        initialValue: selectedCarrier,
                        decoration: _inputDeco('Vervoerder'),
                        items: MyParcelService.carriers.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                        onChanged: (v) => setSt(() => selectedCarrier = v ?? 1),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: DropdownButtonFormField<int>(
                        initialValue: selectedPackageType,
                        decoration: _inputDeco('Pakkettype'),
                        items: MyParcelService.packageTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                        onChanged: (v) => setSt(() { selectedPackageType = v ?? 1; if (v != 1 && v != 6) { optOnlyRecipient = false; optSignature = false; optReturn = false; optLargeFormat = false; selectedInsurance = 0; } }),
                      )),
                    ]),
                    const SizedBox(height: 10),

                    // -- Verpakking met suggestie --
                    Row(children: [
                      Expanded(child: DropdownButtonFormField<String>(
                        initialValue: selectedBox?.id,
                        decoration: InputDecoration(
                          labelText: suggestedBoxes.isNotEmpty ? 'Verpakking (suggestie)' : 'Verpakking',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Geen (0g)')),
                          ...boxes.map((b) {
                            final isSuggested = suggestedBoxes.any((s) => s.id == b.id);
                            return DropdownMenuItem(
                              value: b.id,
                              child: Row(children: [
                                if (isSuggested)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 4),
                                    child: Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
                                  ),
                                Text(b.label, style: TextStyle(
                                  fontWeight: isSuggested ? FontWeight.w600 : FontWeight.normal,
                                )),
                                if (b.hasAfmetingen)
                                  Text('  ${b.afmetingenLabel}', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                              ]),
                            );
                          }),
                        ],
                        onChanged: (v) => setSt(() {
                          selectedBox = v != null ? boxes.firstWhere((b) => b.id == v) : null;
                          weightCtrl.text = '${productWeightGrams + (selectedBox?.gewicht ?? 0)}';
                        }),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: DropdownButtonFormField<int>(
                        initialValue: selectedInsurance,
                        decoration: _inputDeco('Verzekering'),
                        items: MyParcelService.insuranceAmounts.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                        onChanged: isStdPkg ? (v) => setSt(() => selectedInsurance = v ?? 0) : null,
                      )),
                    ]),

                    if (selectedBox != null && selectedBox!.hasAfmetingen) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.straighten, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text('Afmetingen: ${selectedBox!.afmetingenLabel}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        const SizedBox(width: 8),
                        Text('Omtrek: ${selectedBox!.omtrekCm} cm', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        if (selectedBox!.maxGewichtGram > 0) ...[
                          const SizedBox(width: 8),
                          Text('Max: ${selectedBox!.maxGewichtGram}g', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ]),
                    ],

                    if (isStdPkg) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        _optionChip('Alleen ontvanger', optOnlyRecipient, (v) => setSt(() => optOnlyRecipient = v)),
                        const SizedBox(width: 6),
                        _optionChip('Handtekening', optSignature, (v) => setSt(() => optSignature = v)),
                        const SizedBox(width: 6),
                        _optionChip('Retour bij niet thuis', optReturn, (v) => setSt(() => optReturn = v)),
                        const SizedBox(width: 6),
                        _optionChip('Groot formaat', optLargeFormat, (v) => setSt(() => optLargeFormat = v)),
                      ]),
                    ],

                    const SizedBox(height: 14),

                    // -- Gewicht --
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: limitsExceeded ? const Color(0xFFFFF3E0) : const Color(0xFFF1F8E9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: limitsExceeded ? const Color(0xFFFFCC80) : const Color(0xFFC5E1A5),
                          width: 0.5,
                        ),
                      ),
                      child: Row(children: [
                        Icon(Icons.scale, size: 16, color: limitsExceeded ? const Color(0xFFE65100) : const Color(0xFF558B2F)),
                        const SizedBox(width: 8),
                        Text('Producten ${productWeightGrams}g', style: TextStyle(fontSize: 12, color: limitsExceeded ? const Color(0xFFE65100) : const Color(0xFF558B2F))),
                        const Text('  +  ', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        Text('Verpakking ${selectedBox?.gewicht ?? 0}g', style: TextStyle(fontSize: 12, color: limitsExceeded ? const Color(0xFFE65100) : const Color(0xFF558B2F))),
                        const Text('  =  ', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        Text('${totalWeight}g', style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800,
                          color: limitsExceeded ? const Color(0xFFBF360C) : const Color(0xFF33691E),
                        )),
                        const Spacer(),
                        SizedBox(width: 90, child: TextField(
                          controller: weightCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            suffixText: 'g',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        )),
                      ]),
                    ),

                    if (productWeightGrams == 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _infoBanner(Icons.warning_amber, 'Geen productgewichten gevonden \u2014 controleer het gewicht handmatig.', const Color(0xFFE65100), const Color(0xFFFFF3E0)),
                      ),

                    // -- Limiet waarschuwing --
                    if (limitsExceeded) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFEF9A9A)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.warning, size: 18, color: Color(0xFFD32F2F)),
                            const SizedBox(width: 8),
                            Text('Verzendlimiet overschreden', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFFD32F2F))),
                          ]),
                          const SizedBox(height: 6),
                          if (weightExceeded)
                            Text(
                              '\u2022 Gewicht ${totalWeight}g overschrijdt max ${maxGewichtGram}g (${((totalWeight / maxGewichtGram) * 100).toStringAsFixed(0)}%)',
                              style: const TextStyle(fontSize: 11, color: Color(0xFFBF360C)),
                            ),
                          if (omtrekExceeded)
                            Text(
                              '\u2022 Omtrek $boxOmtrek cm overschrijdt max $maxOmtrekCm cm',
                              style: const TextStyle(fontSize: 11, color: Color(0xFFBF360C)),
                            ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(children: [
                              Icon(Icons.lightbulb_outline, size: 14, color: Color(0xFFF9A825)),
                              SizedBox(width: 6),
                              Expanded(child: Text(
                                'Overweeg de order te splitsen in meerdere verzendingen, '
                                'of kies een kleinere verpakking. '
                                'Je kunt het gewicht ook handmatig aanpassen.',
                                style: TextStyle(fontSize: 10, color: Color(0xFF6D4C00)),
                              )),
                            ]),
                          ),
                        ]),
                      ),
                    ],
                  ]),
                )),

                // ── Footer ──
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: processing ? null : () => Navigator.pop(ctx), child: const Text('Annuleren')),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      icon: processing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.rocket_launch, size: 16),
                      label: Text(processing ? 'Bezig...' : 'Concept klaarzetten', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: processing ? null : () async {
                        final weight = int.tryParse(weightCtrl.text) ?? 0;
                        if (weight <= 0) { _snack('Vul een geldig gewicht in', err: true); return; }
                        if (streetCtrl.text.trim().isEmpty || cityCtrl.text.trim().isEmpty) { _snack('Vul straat en plaats in', err: true); return; }
                        final isDomestic = {'NL', 'BE'}.contains(ccCtrl.text.trim().toUpperCase());
                        if (isDomestic && numberCtrl.text.trim().isEmpty) { _snack('Huisnummer is verplicht voor NL/BE', err: true); return; }

                        setSt(() => processing = true);
                        try {
                          final result = await _myparcel.createShipment(
                            recipientName: nameCtrl.text.trim(), recipientStreet: streetCtrl.text.trim(), recipientNumber: numberCtrl.text.trim(),
                            recipientNumberSuffix: suffixCtrl.text.trim().isEmpty ? null : suffixCtrl.text.trim(),
                            recipientPostalCode: postalCtrl.text.trim(), recipientCity: cityCtrl.text.trim(), recipientCc: ccCtrl.text.trim(),
                            recipientEmail: order.userEmail, carrierId: selectedCarrier, weightInGrams: weight, orderReference: order.orderNummer,
                            packageType: selectedPackageType, insuranceAmountCents: selectedInsurance,
                            onlyRecipient: optOnlyRecipient, signature: optSignature, returnIfNotHome: optReturn, largeFormat: optLargeFormat,
                          );
                          await Supabase.instance.client.from('orders').update({'myparcel_shipment_id': result.shipmentId}).eq('id', order.id!);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                          _snack('Concept klaargezet voor ${order.orderNummer}');
                        } catch (e) {
                          setSt(() => processing = false);
                          if (kDebugMode) debugPrint('Error creating MyParcel concept: $e');
                          _snack('Actie mislukt. Probeer het opnieuw.', err: true);
                        }
                      },
                    ),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(children: [
      Icon(icon, size: 16, color: _navy),
      const SizedBox(width: 6),
      Text(title, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: _navy)),
    ]);
  }

  Widget _field(TextEditingController ctrl, String label) {
    return TextField(controller: ctrl, decoration: _inputDeco(label));
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );

  Widget _infoBanner(IconData icon, String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: color, height: 1.3))),
      ]),
    );
  }

  Widget _optionChip(String label, bool selected, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: selected ? Colors.white : _navy)),
      selected: selected,
      onSelected: onChanged,
      selectedColor: _teal,
      checkmarkColor: Colors.white,
      backgroundColor: const Color(0xFFF0F4FF),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  // ── STEP 2: Label genereren & verzenden ──

  void _showLabelDialog(Order order) {
    bool sendEmail = true;
    bool processing = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.print, color: Color(0xFF1565C0)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Stap 2: Label genereren & verzenden', style: TextStyle(fontSize: 15)),
              Text(order.orderNummer, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w400)),
            ])),
          ]),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFFB74D))),
                child: const Row(children: [
                  Icon(Icons.warning_amber, size: 16, color: Color(0xFFE65100)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Na het genereren wordt de zending definitief aangemeld bij de vervoerder.', style: TextStyle(fontSize: 11, color: Color(0xFFE65100), height: 1.4))),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFB), borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(order.naam ?? order.userEmail, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('${order.adres ?? ''}\n${order.postcode ?? ''} ${order.woonplaats ?? ''} (${order.landCode.toUpperCase()})',
                    style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  Text('${order.regels.length} artikel${order.regels.length == 1 ? '' : 'en'} · ${order.formatTotaal()}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _teal)),
                ]),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                title: const Text('Verzendmail + factuur versturen', style: TextStyle(fontSize: 13)),
                subtitle: const Text('Automatisch na label genereren', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                value: sendEmail, onChanged: (v) => setSt(() => sendEmail = v),
                contentPadding: EdgeInsets.zero, dense: true,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: processing ? null : () => Navigator.pop(ctx), child: const Text('Annuleren')),
            ElevatedButton.icon(
              icon: processing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.print, size: 16),
              label: Text(processing ? 'Bezig...' : 'Label genereren', style: const TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
              onPressed: processing ? null : () async {
                setSt(() => processing = true);
                try {
                  final shipmentId = order.myparcelShipmentId!;
                  final shipmentData = await _myparcel.getShipment(shipmentId);
                  final barcode = shipmentData?['barcode'] as String? ?? '';
                  String trackUrl = '';
                  if (barcode.isNotEmpty) {
                    trackUrl = 'https://myparcel.me/track-trace/$barcode/${(order.postcode ?? '').replaceAll(' ', '')}/${order.landCode.toUpperCase()}';
                  }

                  final labelBytes = await _myparcel.getLabel(shipmentId);
                  if (labelBytes != null) {
                    try {
                      final dir = await getApplicationDocumentsDirectory();
                      final file = File('${dir.path}/myparcel_label_${order.orderNummer}.pdf');
                      await file.writeAsBytes(labelBytes);
                      await launchUrl(Uri.file(file.path));
                    } catch (_) {}
                  }

                  final carrierName = shipmentData?['carrier']?['name'] as String? ?? 'PostNL';
                  await _orderService.updateTrackTrace(orderId: order.id!, carrier: carrierName.toLowerCase().replaceAll(' ', ''), code: barcode, url: trackUrl);

                  if (sendEmail) {
                    final updated = await _orderService.fetchOrder(order.id!);
                    if (updated != null) {
                      try { await _emailService.sendShippingNotification(updated); } catch (_) {}
                    }
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                  _snack('Label gegenereerd${barcode.isNotEmpty ? " — $barcode" : ""}${sendEmail ? " + mail verstuurd" : ""}');

                  final freshOrder = await _orderService.fetchOrder(order.id!);
                  if (freshOrder != null && mounted) {
                    await showStockUpdateAfterShipment(context, freshOrder);
                  }
                } catch (e) {
                  setSt(() => processing = false);
                  if (kDebugMode) debugPrint('Error generating label: $e');
                  _snack('Label genereren mislukt. Probeer het opnieuw.', err: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──

  Future<void> _deleteConceptAndReload(Order order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Concept verwijderen?', style: TextStyle(fontSize: 16)),
        content: const Text('Het MyParcel concept wordt verwijderd. Je kunt daarna opnieuw een concept aanmaken.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white), child: const Text('Verwijderen')),
        ],
      ),
    );
    if (ok != true) return;

    final deleted = await _myparcel.deleteShipment(order.myparcelShipmentId!);
    if (deleted) {
      await Supabase.instance.client.from('orders').update({'myparcel_shipment_id': null}).eq('id', order.id!);
      _load();
      _snack('Concept verwijderd');
    } else {
      _snack('Verwijderen mislukt — label al gegenereerd?', err: true);
    }
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: err ? const Color(0xFFE53935) : const Color(0xFF43A047),
      duration: const Duration(seconds: 4),
    ));
  }

  static (String, String, String) _splitStreetNumber(String adres) {
    final match = RegExp(r'^(.+?)\s+(\d+)\s*(.*)$').firstMatch(adres.trim());
    if (match != null) return (match.group(1)!, match.group(2)!, match.group(3)?.trim() ?? '');
    return (adres, '', '');
  }
}
