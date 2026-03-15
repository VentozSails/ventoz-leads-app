import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/order_service.dart';
import '../services/pricing_service.dart';
import '../services/invoice_service.dart';
import '../services/order_email_service.dart';
import '../services/user_service.dart';
import '../services/myparcel_service.dart';
import '../services/packaging_service.dart';
import '../services/web_scraper_service.dart';
import '../services/vat_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/stock_update_after_shipment.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersScreen extends StatefulWidget {
  final bool adminView;
  const OrdersScreen({super.key, this.adminView = false});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final OrderService _orderService = OrderService();
  final OrderEmailService _emailService = OrderEmailService();
  List<Order> _orders = [];
  bool _loading = true;
  String? _statusFilter;
  String _lang = 'nl';
  late AppLocalizations _l = AppLocalizations(_lang);

  @override
  void initState() {
    super.initState();
    _loadOrders();
    UserService().getUserLanguage().then((lang) {
      if (mounted) setState(() { _lang = lang; _l = AppLocalizations(lang); });
    });
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    final perms = await UserService().getCurrentUserPermissions();
    if (!mounted) return;
    final requiredPerm = widget.adminView ? perms.alleBestellingenBeheren : perms.eigenBestelhistorie;
    if (!requiredPerm) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
      );
      return;
    }
    try {
      _orders = await _orderService.fetchOrders(adminView: widget.adminView);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Order> get _filtered {
    if (_statusFilter == null) return _orders;
    return _orders.where((o) => o.status == _statusFilter).toList();
  }

  String _statusLabel(String s) {
    const keyMap = {
      'concept': 'status_concept',
      'betaling_gestart': 'status_betaling',
      'betaald': 'status_betaald',
      'verzonden': 'status_verzonden',
      'afgeleverd': 'status_afgeleverd',
      'geannuleerd': 'status_geannuleerd',
    };
    final key = keyMap[s];
    return key != null ? _l.t(key) : s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/ventoz_logo.png', width: 28, height: 28)),
          const SizedBox(width: 10),
          Text(widget.adminView ? _l.t('orderbeheer') : _l.t('mijn_bestellingen')),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final statusOptions = ['concept', 'betaling_gestart', 'betaald', 'verzonden', 'afgeleverd', 'geannuleerd'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          FilterChip(
            label: Text('${_l.t('alle')} (${_orders.length})', style: const TextStyle(fontSize: 12)),
            selected: _statusFilter == null,
            onSelected: (_) => setState(() => _statusFilter = null),
          ),
          const SizedBox(width: 6),
          ...statusOptions.map((s) {
            final count = _orders.where((o) => o.status == s).length;
            if (count == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text('${_statusLabel(s)} ($count)', style: const TextStyle(fontSize: 12)),
                selected: _statusFilter == s,
                onSelected: (_) => setState(() => _statusFilter = _statusFilter == s ? null : s),
                avatar: Icon(_statusIcon(s), size: 16, color: _statusColor(s)),
              ),
            );
          }),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final orders = _filtered;
    if (orders.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.receipt_long, size: 64, color: Color(0xFFB0BEC5)),
          const SizedBox(height: 16),
          Text(_l.t('geen_bestellingen'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, i) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildOrderCard(orders[i]),
    );
  }

  Widget _buildOrderCard(Order order) {
    final dateStr = order.createdAt != null ? DateFormat('dd-MM-yyyy HH:mm').format(order.createdAt!.toLocal()) : '';
    return Card(
      child: InkWell(
        onTap: () => _showOrderDetail(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(order.orderNummer, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const Spacer(),
                _buildStatusChip(order.status),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.calendar_today, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(width: 16),
                const Icon(Icons.shopping_bag, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text('${order.regels.length} ${_l.t('items')}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                if (widget.adminView && order.naam != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.person, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(order.naam!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis)),
                ],
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Text(order.formatTotaal(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF455A64))),
                if (order.btwVerlegd) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(4)),
                    child: const Text('ICP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF1565C0))),
                  ),
                ],
                if (order.trackTraceCode != null && order.trackTraceCode!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.local_shipping, size: 14, color: Color(0xFF2E7D32)),
                ],
                const Spacer(),
                if (order.factuurNummer != null)
                  Text('${_l.t('factuur')}: ${order.factuurNummer}', style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_statusIcon(status), size: 12, color: _statusColor(status)),
        const SizedBox(width: 4),
        Text(_statusLabel(status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(status))),
      ]),
    );
  }

  void _showOrderDetail(Order order) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(order.orderNummer, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    if (order.createdAt != null)
                      Text(DateFormat('dd-MM-yyyy HH:mm').format(order.createdAt!.toLocal()), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ]),
                  const Spacer(),
                  _buildStatusChip(order.status),
                ]),
              ),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order.naam != null || order.adres != null) ...[
                        Text(_l.t('klantgegevens'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        if (order.bedrijfsnaam != null) Text(order.bedrijfsnaam!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        if (order.naam != null) Text(order.naam!, style: const TextStyle(fontSize: 13)),
                        if (order.adres != null) Text(order.adres!, style: const TextStyle(fontSize: 13)),
                        if (order.postcode != null || order.woonplaats != null)
                          Text('${order.postcode ?? ''} ${order.woonplaats ?? ''}'.trim(), style: const TextStyle(fontSize: 13)),
                        Text(order.landCode.toUpperCase(), style: const TextStyle(fontSize: 13)),
                        if (order.btwNummer != null) Text('${_l.t('btw')}: ${order.btwNummer}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        const SizedBox(height: 12),
                      ],
                      Text(_l.t('producten'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      ...order.regels.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          if (r.productAfbeelding != null)
                            ClipRRect(borderRadius: BorderRadius.circular(4),
                              child: Image.network(r.productAfbeelding!, width: 32, height: 32, fit: BoxFit.contain,
                                errorBuilder: (_, e, s) => const SizedBox(width: 32)))
                          else
                            const SizedBox(width: 32, height: 32, child: Icon(Icons.sailing, size: 16, color: Color(0xFFB0BEC5))),
                          const SizedBox(width: 8),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r.productNaam, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('${r.aantal}x ${PricingService.formatEuro(r.stukprijs)}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ])),
                          Text(PricingService.formatEuro(r.regelTotaal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ]),
                      )),
                      const Divider(),
                      _detailRow(_l.t('subtotaal_excl_btw'), PricingService.formatEuro(order.subtotaal)),
                      if (order.btwVerlegd)
                        _detailRow(_l.t('btw'), _l.t('verlegd_icp'), subtle: true)
                      else
                        _detailRow('${_l.t('btw')} ${order.btwPercentage.toStringAsFixed(order.btwPercentage == order.btwPercentage.roundToDouble() ? 0 : 1)}%',
                          PricingService.formatEuro(order.btwBedrag), subtle: true),
                      _detailRow(_l.t('verzendkosten'),
                        order.verzendkosten > 0 ? PricingService.formatEuro(order.verzendkosten) : _l.t('gratis'), subtle: true),
                      _detailRow(_l.t('totaal'), order.formatTotaal(), bold: true),
                      if (order.opmerkingen != null && order.opmerkingen!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('${_l.t('opmerkingen')}: ${order.opmerkingen}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
                      ],

                      if (order.trackTraceCode != null && order.trackTraceCode!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildTrackingInfoCard(order),
                      ],

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _buildDetailActions(ctx, order),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingInfoCard(Order order) {
    final carrierName = OrderService.carriers[order.trackTraceCarrier?.toLowerCase()] ?? order.trackTraceCarrier ?? '';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.local_shipping, size: 16, color: Color(0xFF2E7D32)),
            const SizedBox(width: 6),
            Text(_l.t('tracking_info'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32))),
          ]),
          const SizedBox(height: 8),
          Text('$carrierName — ${order.trackTraceCode}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          if (order.verzondenOp != null)
            Text(DateFormat('dd-MM-yyyy HH:mm').format(order.verzondenOp!.toLocal()), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          if (order.trackTraceUrl != null && order.trackTraceUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 14),
                label: Text(_l.t('volg_pakket'), style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2E7D32)),
                onPressed: () { if (VatService.isSafeUrl(order.trackTraceUrl!)) launchUrl(Uri.parse(order.trackTraceUrl!), mode: LaunchMode.externalApplication); },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailActions(BuildContext ctx, Order order) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (order.isBetaald)
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: Text(_l.t('factuur'), style: const TextStyle(fontSize: 12)),
            onPressed: () => _generateInvoice(order),
          ),
        if (widget.adminView && order.status == 'betaald') ...[
          ElevatedButton.icon(
            icon: const Icon(Icons.rocket_launch, size: 16),
            label: const Text('MyParcel', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _showMyParcelDialog(order);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.local_shipping, size: 16),
            label: Text(_l.t('markeer_verzonden'), style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _showShipDialog(order);
            },
          ),
          if (!order.bevestigingVerzonden)
            OutlinedButton.icon(
              icon: const Icon(Icons.email, size: 16),
              label: Text(_l.t('orderbevestiging_verzonden'), style: const TextStyle(fontSize: 11)),
              onPressed: () => _sendConfirmationManually(order),
            ),
        ],
        if (widget.adminView && order.status == 'betaald' && order.bevestigingVerzonden)
          OutlinedButton.icon(
            icon: const Icon(Icons.replay, size: 14),
            label: Text(_l.t('bevestiging_email_opnieuw'), style: const TextStyle(fontSize: 11)),
            onPressed: () => _sendConfirmationManually(order),
          ),
        if (widget.adminView && order.status == 'betaald' && order.myparcelShipmentId != null) ...[
          ElevatedButton.icon(
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Label genereren & verzenden', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _showGenerateLabelDialog(order);
            },
          ),
        ],
        if (widget.adminView && order.status == 'verzonden') ...[
          ElevatedButton.icon(
            icon: const Icon(Icons.done_all, size: 16),
            label: Text(_statusLabel('afgeleverd'), style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
            onPressed: () => _updateStatus(order, 'afgeleverd'),
          ),
          if (order.myparcelShipmentId != null)
            OutlinedButton.icon(
              icon: const Icon(Icons.print, size: 16),
              label: const Text('Label', style: TextStyle(fontSize: 12)),
              onPressed: () => _downloadLabel(order.myparcelShipmentId!),
            ),
        ],
        if (widget.adminView && order.status == 'verzonden' && order.myparcelShipmentId != null)
          OutlinedButton.icon(
            icon: const Icon(Icons.assignment_return, size: 16, color: Color(0xFF6A1B9A)),
            label: const Text('Retourzending', style: TextStyle(fontSize: 12, color: Color(0xFF6A1B9A))),
            onPressed: () {
              Navigator.pop(ctx);
              _showReturnShipmentDialog(order);
            },
          ),
        if (widget.adminView && order.status == 'betaald' && order.myparcelShipmentId != null)
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFE65100)),
            label: const Text('MyParcel concept verwijderen', style: TextStyle(fontSize: 11, color: Color(0xFFE65100))),
            onPressed: () => _deleteMyParcelConcept(order, ctx),
          ),
        if (widget.adminView && order.status == 'concept')
          ElevatedButton.icon(
            icon: const Icon(Icons.cancel, size: 16),
            label: Text(_l.t('annuleren'), style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
            onPressed: () => _updateStatus(order, 'geannuleerd'),
          ),
        if (widget.adminView)
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_forever, size: 16, color: Color(0xFFB71C1C)),
            label: const Text('Order verwijderen', style: TextStyle(fontSize: 11, color: Color(0xFFB71C1C))),
            onPressed: () => _confirmDeleteOrder(order, ctx),
          ),
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(_l.t('sluiten'), style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  void _showShipDialog(Order order) {
    String selectedCarrier = 'postnl';
    final codeCtrl = TextEditingController();
    bool sendEmail = true;
    bool processing = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final trackUrl = codeCtrl.text.isNotEmpty
              ? OrderService.buildTrackingUrl(selectedCarrier, codeCtrl.text, postcode: order.postcode)
              : '';

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              const Icon(Icons.local_shipping, color: Color(0xFF455A64)),
              const SizedBox(width: 8),
              Text(_l.t('markeer_verzonden'), style: const TextStyle(fontSize: 16)),
            ]),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.orderNummer, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(order.naam ?? order.userEmail, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: selectedCarrier,
                    decoration: InputDecoration(
                      labelText: _l.t('vervoerder'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: OrderService.carriers.entries.map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ).toList(),
                    onChanged: (v) => setDialogState(() => selectedCarrier = v!),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: codeCtrl,
                    decoration: InputDecoration(
                      labelText: _l.t('track_trace_code'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.qr_code),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),

                  if (trackUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.link, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(trackUrl, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text(_l.t('verzend_email_sturen'), style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${_l.t('factuur')} PDF', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    value: sendEmail,
                    onChanged: (v) => setDialogState(() => sendEmail = v),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: processing ? null : () => Navigator.pop(ctx),
                child: Text(_l.t('annuleren')),
              ),
              ElevatedButton.icon(
                icon: processing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, size: 16),
                label: Text(_l.t('bevestigen_verzending'), style: const TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
                onPressed: (processing || codeCtrl.text.isEmpty) ? null : () async {
                  setDialogState(() => processing = true);
                  try {
                    final url = OrderService.buildTrackingUrl(selectedCarrier, codeCtrl.text, postcode: order.postcode);
                    await _orderService.updateTrackTrace(
                      orderId: order.id!,
                      carrier: selectedCarrier,
                      code: codeCtrl.text,
                      url: url,
                    );

                    if (sendEmail) {
                      final updated = await _orderService.fetchOrder(order.id!);
                      if (updated != null) {
                        try {
                          await _emailService.sendShippingNotification(updated);
                        } catch (e) {
                          if (kDebugMode) debugPrint('Error sending shipping notification: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(_l.t('email_verzenden_mislukt')),
                              backgroundColor: const Color(0xFFE65100),
                            ));
                          }
                        }
                      }
                    }

                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadOrders();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(_l.t('verzending_geregistreerd')),
                        backgroundColor: const Color(0xFF43A047),
                      ));
                    }
                  } catch (e) {
                    if (kDebugMode) debugPrint('Error registering shipment: $e');
                    setDialogState(() => processing = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_l.t('fout')), backgroundColor: const Color(0xFFE53935)));
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMyParcelDialog(Order order) {
    final myparcel = MyParcelService();
    final packagingService = PackagingService();
    final scraper = WebScraperService();

    int selectedCarrier = 1;
    int selectedPackageType = 1;
    int selectedInsurance = 0;
    bool optOnlyRecipient = false;
    bool optSignature = false;
    bool optReturn = false;
    bool optLargeFormat = false;
    PackagingBox? selectedBox;
    List<PackagingBox> boxes = [];
    int productWeightGrams = 0;
    bool loadingWeights = true;
    bool processing = false;

    final nameCtrl = TextEditingController(text: order.naam ?? order.userEmail);
    final streetCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    final suffixCtrl = TextEditingController();
    final postalCtrl = TextEditingController(text: order.postcode ?? '');
    final cityCtrl = TextEditingController(text: order.woonplaats ?? '');
    final ccCtrl = TextEditingController(text: order.landCode.toUpperCase());
    final weightOverrideCtrl = TextEditingController();

    final adresParts = _splitStreetNumber(order.adres ?? '');
    streetCtrl.text = adresParts.$1;
    numberCtrl.text = adresParts.$2;
    suffixCtrl.text = adresParts.$3;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (loadingWeights) {
            Future(() async {
              final config = await myparcel.getConfig();
              final allBoxes = await packagingService.getAll();
              final catalog = await scraper.fetchCatalog(includeBlocked: true);

              int calcWeight = 0;
              for (final regel in order.regels) {
                final product = catalog.where((p) =>
                  p.artikelnummer == regel.productId ||
                  p.displayNaam == regel.productNaam).firstOrNull;
                if (product?.gewicht != null) {
                  calcWeight += (product!.gewicht! * regel.aantal).toInt();
                }
              }

              if (!ctx.mounted) return;
              setDialogState(() {
                selectedCarrier = config?.defaultCarrierId ?? 1;
                boxes = allBoxes;
                if (config != null && config.defaultBoxId.isNotEmpty) {
                  selectedBox = allBoxes.where((b) => b.id == config.defaultBoxId).firstOrNull;
                }
                productWeightGrams = calcWeight;
                final total = calcWeight + (selectedBox?.gewicht ?? 0);
                weightOverrideCtrl.text = total.toString();
                loadingWeights = false;
              });
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(children: [
                Icon(Icons.rocket_launch, color: Color(0xFF00897B)),
                SizedBox(width: 8),
                Text('MyParcel — Zending klaarzetten', style: TextStyle(fontSize: 16)),
              ]),
              content: const SizedBox(
                width: 440, height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          final isStandardPackage = selectedPackageType == 1 || selectedPackageType == 6;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              const Icon(Icons.rocket_launch, color: Color(0xFF00897B)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('MyParcel — Zending klaarzetten', style: TextStyle(fontSize: 15)),
                Text(order.orderNummer, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w400)),
              ])),
            ]),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCE93D8)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFF7B1FA2)),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'De zending wordt als concept klaargezet in MyParcel. '
                        'Het label wordt pas gegenereerd wanneer je dat apart bevestigt.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF7B1FA2), height: 1.4),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 14),

                  const Text('Ontvanger (controleer / corrigeer)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF455A64))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Naam', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(flex: 4, child: TextField(
                      controller: streetCtrl,
                      decoration: const InputDecoration(labelText: 'Straat', border: OutlineInputBorder(), isDense: true),
                    )),
                    const SizedBox(width: 8),
                    SizedBox(width: 60, child: TextField(
                      controller: numberCtrl,
                      decoration: const InputDecoration(labelText: 'Nr.', border: OutlineInputBorder(), isDense: true),
                    )),
                    const SizedBox(width: 8),
                    SizedBox(width: 60, child: TextField(
                      controller: suffixCtrl,
                      decoration: const InputDecoration(labelText: 'Toev.', border: OutlineInputBorder(), isDense: true),
                    )),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: postalCtrl,
                      decoration: const InputDecoration(labelText: 'Postcode', border: OutlineInputBorder(), isDense: true),
                    )),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: TextField(
                      controller: cityCtrl,
                      decoration: const InputDecoration(labelText: 'Plaats', border: OutlineInputBorder(), isDense: true),
                    )),
                    const SizedBox(width: 8),
                    SizedBox(width: 60, child: TextField(
                      controller: ccCtrl,
                      decoration: const InputDecoration(labelText: 'Land', border: OutlineInputBorder(), isDense: true),
                      onChanged: (_) => setDialogState(() {}),
                    )),
                  ]),
                  if ({'GB', 'UK', 'CH', 'NO', 'IS', 'LI'}.contains(ccCtrl.text.trim().toUpperCase()))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(6)),
                        child: const Row(children: [
                          Icon(Icons.info_outline, size: 14, color: Color(0xFFE65100)),
                          SizedBox(width: 6),
                          Expanded(child: Text(
                            'Non-EU bestemming: douaneverklaring wordt automatisch toegevoegd.',
                            style: TextStyle(fontSize: 10, color: Color(0xFFE65100)),
                          )),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 16),

                  const Text('Zending instellingen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF455A64))),
                  const SizedBox(height: 8),

                  Row(children: [
                    Expanded(child: DropdownButtonFormField<int>(
                      initialValue: selectedCarrier,
                      decoration: const InputDecoration(labelText: 'Vervoerder', border: OutlineInputBorder(), isDense: true),
                      items: MyParcelService.carriers.entries.map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ).toList(),
                      onChanged: (v) => setDialogState(() => selectedCarrier = v ?? 1),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: DropdownButtonFormField<int>(
                      initialValue: selectedPackageType,
                      decoration: const InputDecoration(labelText: 'Pakkettype', border: OutlineInputBorder(), isDense: true),
                      items: MyParcelService.packageTypes.entries.map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ).toList(),
                      onChanged: (v) => setDialogState(() {
                        selectedPackageType = v ?? 1;
                        if (v != 1 && v != 6) {
                          optOnlyRecipient = false;
                          optSignature = false;
                          optReturn = false;
                          optLargeFormat = false;
                          selectedInsurance = 0;
                        }
                      }),
                    )),
                  ]),
                  const SizedBox(height: 12),

                  Row(children: [
                    Expanded(child: DropdownButtonFormField<String>(
                      initialValue: selectedBox?.id,
                      decoration: const InputDecoration(labelText: 'Verpakking', border: OutlineInputBorder(), isDense: true),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Geen (0g)')),
                        ...boxes.map((b) => DropdownMenuItem(value: b.id, child: Text(b.label))),
                      ],
                      onChanged: (v) {
                        setDialogState(() {
                          selectedBox = v != null ? boxes.firstWhere((b) => b.id == v) : null;
                          final total = productWeightGrams + (selectedBox?.gewicht ?? 0);
                          weightOverrideCtrl.text = total.toString();
                        });
                      },
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: DropdownButtonFormField<int>(
                      initialValue: selectedInsurance,
                      decoration: InputDecoration(
                        labelText: 'Verzekering',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        enabled: isStandardPackage,
                      ),
                      items: MyParcelService.insuranceAmounts.entries.map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ).toList(),
                      onChanged: isStandardPackage ? (v) => setDialogState(() => selectedInsurance = v ?? 0) : null,
                    )),
                  ]),
                  const SizedBox(height: 12),

                  if (isStandardPackage) ...[
                    const Text('Verzendopties', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF455A64))),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 0,
                      runSpacing: 0,
                      children: [
                        SizedBox(width: 230, child: CheckboxListTile(
                          title: const Text('Alleen ontvanger', style: TextStyle(fontSize: 12)),
                          subtitle: const Text('Niet bij buren afleveren', style: TextStyle(fontSize: 10)),
                          value: optOnlyRecipient,
                          onChanged: (v) => setDialogState(() => optOnlyRecipient = v ?? false),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        )),
                        SizedBox(width: 230, child: CheckboxListTile(
                          title: const Text('Handtekening', style: TextStyle(fontSize: 12)),
                          subtitle: const Text('Ontvanger moet tekenen', style: TextStyle(fontSize: 10)),
                          value: optSignature,
                          onChanged: (v) => setDialogState(() => optSignature = v ?? false),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        )),
                        SizedBox(width: 230, child: CheckboxListTile(
                          title: const Text('Retour bij niet thuis', style: TextStyle(fontSize: 12)),
                          subtitle: const Text('Terugsturen als niet bezorgd', style: TextStyle(fontSize: 10)),
                          value: optReturn,
                          onChanged: (v) => setDialogState(() => optReturn = v ?? false),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        )),
                        SizedBox(width: 230, child: CheckboxListTile(
                          title: const Text('Groot formaat', style: TextStyle(fontSize: 12)),
                          subtitle: const Text('Groter dan standaard pakket', style: TextStyle(fontSize: 10)),
                          value: optLargeFormat,
                          onChanged: (v) => setDialogState(() => optLargeFormat = v ?? false),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                        )),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(8)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [
                        Icon(Icons.scale, size: 14, color: Color(0xFF558B2F)),
                        SizedBox(width: 6),
                        Text('Gewichtberekening', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF558B2F))),
                      ]),
                      const SizedBox(height: 6),
                      Text('Producten: ${productWeightGrams}g', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      Text('Verpakking: ${selectedBox?.gewicht ?? 0}g', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      if (productWeightGrams == 0)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('Let op: geen productgewichten gevonden. Vul het totaalgewicht handmatig in.',
                            style: TextStyle(fontSize: 11, color: Color(0xFFE65100))),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: weightOverrideCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Totaal gewicht (gram)',
                      suffixText: 'g',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ],
              )),
            ),
            actions: [
              TextButton(
                onPressed: processing ? null : () => Navigator.pop(ctx),
                child: const Text('Annuleren'),
              ),
              ElevatedButton.icon(
                icon: processing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.inventory_2, size: 16),
                label: Text(processing ? 'Bezig...' : 'Concept klaarzetten', style: const TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B), foregroundColor: Colors.white),
                onPressed: processing ? null : () async {
                  final weight = int.tryParse(weightOverrideCtrl.text) ?? 0;
                  if (weight <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vul een geldig gewicht in'), backgroundColor: Color(0xFFE65100)),
                    );
                    return;
                  }
                  final cc = ccCtrl.text.trim().toUpperCase();
                  final isDomestic = {'NL', 'BE'}.contains(cc);
                  if (streetCtrl.text.trim().isEmpty || cityCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vul straat en plaats in'), backgroundColor: Color(0xFFE65100)),
                    );
                    return;
                  }
                  if (isDomestic && numberCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Huisnummer is verplicht voor NL/BE'), backgroundColor: Color(0xFFE65100)),
                    );
                    return;
                  }
                  if (cc != 'IE' && postalCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vul de postcode in'), backgroundColor: Color(0xFFE65100)),
                    );
                    return;
                  }

                  setDialogState(() => processing = true);
                  try {
                    final result = await myparcel.createShipment(
                      recipientName: nameCtrl.text.trim(),
                      recipientStreet: streetCtrl.text.trim(),
                      recipientNumber: numberCtrl.text.trim(),
                      recipientNumberSuffix: suffixCtrl.text.trim().isEmpty ? null : suffixCtrl.text.trim(),
                      recipientPostalCode: postalCtrl.text.trim(),
                      recipientCity: cityCtrl.text.trim(),
                      recipientCc: ccCtrl.text.trim(),
                      recipientEmail: order.userEmail,
                      carrierId: selectedCarrier,
                      weightInGrams: weight,
                      orderReference: order.orderNummer,
                      packageType: selectedPackageType,
                      insuranceAmountCents: selectedInsurance,
                      onlyRecipient: optOnlyRecipient,
                      signature: optSignature,
                      returnIfNotHome: optReturn,
                      largeFormat: optLargeFormat,
                    );

                    await Supabase.instance.client.from('orders').update({
                      'myparcel_shipment_id': result.shipmentId,
                    }).eq('id', order.id!);

                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadOrders();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('MyParcel concept aangemaakt. Genereer het label wanneer je klaar bent.'),
                        backgroundColor: Color(0xFF00897B),
                        duration: Duration(seconds: 5),
                      ));
                    }
                  } catch (e) {
                    if (kDebugMode) debugPrint('MyParcel error: $e');
                    setDialogState(() => processing = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('MyParcel actie mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFE53935)),
                      );
                    }
                  }
                },
            ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteOrder(Order order, BuildContext ctx) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning, color: Color(0xFFB71C1C)),
          SizedBox(width: 8),
          Text('Order verwijderen', style: TextStyle(fontSize: 16, color: Color(0xFFB71C1C))),
        ]),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Weet je zeker dat je deze order wilt verwijderen? Dit kan niet worden teruggedraaid.',
              style: TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.orderNummer, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(order.naam ?? order.userEmail, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                Text('Status: ${_statusLabel(order.status)}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ]),
            ),
            if (order.myparcelShipmentId != null) ...[
              const SizedBox(height: 8),
              const Text('Het bijbehorende MyParcel concept wordt ook verwijderd (indien nog mogelijk).',
                style: TextStyle(fontSize: 11, color: Color(0xFFE65100))),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Annuleren')),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('Definitief verwijderen', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dlgCtx);
              if (ctx.mounted) Navigator.pop(ctx);
              try {
                if (order.myparcelShipmentId != null) {
                  await MyParcelService().deleteShipment(order.myparcelShipmentId!);
                }
                await _orderService.deleteOrder(order.id!);
                _loadOrders();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Order ${order.orderNummer} verwijderd'),
                    backgroundColor: const Color(0xFF43A047),
                  ));
                }
              } catch (e) {
                if (kDebugMode) debugPrint('Error deleting order: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Verwijderen mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFE53935)),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMyParcelConcept(Order order, BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.delete_outline, color: Color(0xFFE65100)),
          SizedBox(width: 8),
          Text('MyParcel concept verwijderen', style: TextStyle(fontSize: 15)),
        ]),
        content: const Text(
          'Het concept wordt verwijderd uit MyParcel. De order blijft bestaan in de app.\n\n'
          'Dit kan alleen als het label nog niet is gegenereerd.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx, false), child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
            child: const Text('Verwijderen', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final ok = await MyParcelService().deleteShipment(order.myparcelShipmentId!);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Kan concept niet verwijderen — mogelijk is het label al gegenereerd.'),
            backgroundColor: Color(0xFFE65100),
          ));
        }
        return;
      }

      await Supabase.instance.client.from('orders').update({
        'myparcel_shipment_id': null,
      }).eq('id', order.id!);

      if (ctx.mounted) Navigator.pop(ctx);
      _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('MyParcel concept verwijderd'),
          backgroundColor: Color(0xFF43A047),
        ));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error deleting MyParcel concept: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verwijderen mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFE53935)),
        );
      }
    }
  }

  void _showReturnShipmentDialog(Order order) {
    int selectedCarrier = 1;
    bool processing = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.assignment_return, color: Color(0xFF6A1B9A)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Retourzending aanmaken', style: TextStyle(fontSize: 15)),
              Text(order.orderNummer, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w400)),
            ])),
          ]),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCE93D8)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF6A1B9A)),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Er wordt een retourlabel aangemaakt gekoppeld aan de oorspronkelijke zending. '
                    'De klant ontvangt een email met het retourlabel.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6A1B9A), height: 1.4),
                  )),
                ]),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFB), borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(order.naam ?? order.userEmail, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(order.userEmail, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ]),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: selectedCarrier,
                decoration: const InputDecoration(labelText: 'Vervoerder', border: OutlineInputBorder(), isDense: true),
                items: MyParcelService.carriers.entries.map((e) =>
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
                ).toList(),
                onChanged: (v) => setDialogState(() => selectedCarrier = v ?? 1),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: processing ? null : () => Navigator.pop(ctx),
              child: const Text('Annuleren'),
            ),
            ElevatedButton.icon(
              icon: processing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.assignment_return, size: 16),
              label: Text(processing ? 'Bezig...' : 'Retourlabel aanmaken', style: const TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
              onPressed: processing ? null : () async {
                setDialogState(() => processing = true);
                try {
                  final result = await MyParcelService().createReturnShipment(
                    parentShipmentId: order.myparcelShipmentId!,
                    recipientEmail: order.userEmail,
                    recipientName: order.naam ?? order.userEmail,
                    carrierId: selectedCarrier,
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Retourzending aangemaakt (ID: ${result.shipmentId})'),
                      backgroundColor: const Color(0xFF6A1B9A),
                      duration: const Duration(seconds: 5),
                    ));
                  }
                } catch (e) {
                  if (kDebugMode) debugPrint('Error creating return shipment: $e');
                  setDialogState(() => processing = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Retourzending mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFE53935)),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  static (String, String, String) _splitStreetNumber(String adres) {
    final match = RegExp(r'^(.+?)\s+(\d+)\s*(.*)$').firstMatch(adres.trim());
    if (match != null) {
      return (match.group(1)!, match.group(2)!, match.group(3)?.trim() ?? '');
    }
    return (adres, '', '');
  }

  void _showGenerateLabelDialog(Order order) {
    bool sendEmail = true;
    bool processing = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.print, color: Color(0xFF1565C0)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Label genereren & verzenden', style: TextStyle(fontSize: 15)),
              Text(order.orderNummer, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w400)),
            ])),
          ]),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFB74D)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.warning_amber, size: 16, color: Color(0xFFE65100)),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'Let op: na het genereren van het label wordt de zending definitief bij de vervoerder aangemeld. '
                      'Dit kan niet worden teruggedraaid.',
                      style: TextStyle(fontSize: 11, color: Color(0xFFE65100), height: 1.4),
                    )),
                  ]),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFB), borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(order.naam ?? order.userEmail, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('${order.adres ?? ''}\n${order.postcode ?? ''} ${order.woonplaats ?? ''}\n${order.landCode.toUpperCase()}',
                      style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF64748B))),
                  ]),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  title: const Text('Verzendmail + factuur versturen', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('Automatisch na label genereren', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  value: sendEmail,
                  onChanged: (v) => setDialogState(() => sendEmail = v),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: processing ? null : () => Navigator.pop(ctx),
              child: const Text('Annuleren'),
            ),
            ElevatedButton.icon(
              icon: processing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.print, size: 16),
              label: Text(processing ? 'Bezig...' : 'Label genereren', style: const TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
              onPressed: processing ? null : () async {
                setDialogState(() => processing = true);
                try {
                  final myparcel = MyParcelService();
                  final shipmentId = order.myparcelShipmentId!;

                  final shipmentData = await myparcel.getShipment(shipmentId);
                  final barcode = shipmentData?['barcode'] as String? ?? '';
                  String trackUrl = '';
                  if (barcode.isNotEmpty) {
                    final cc = order.landCode.toUpperCase();
                    final pc = order.postcode?.replaceAll(' ', '') ?? '';
                    trackUrl = 'https://myparcel.me/track-trace/$barcode/$pc/$cc';
                  }

                  final labelBytes = await myparcel.getLabel(shipmentId);
                  if (labelBytes != null) {
                    try {
                      final dir = await getApplicationDocumentsDirectory();
                      final file = File('${dir.path}/myparcel_label_${order.orderNummer}.pdf');
                      await file.writeAsBytes(labelBytes);
                      await launchUrl(Uri.file(file.path));
                    } catch (_) {}
                  }

                  final carrierName = shipmentData?['carrier']?['name'] as String? ?? 'PostNL';
                  await _orderService.updateTrackTrace(
                    orderId: order.id!,
                    carrier: carrierName.toLowerCase().replaceAll(' ', ''),
                    code: barcode,
                    url: trackUrl,
                  );

                  if (sendEmail) {
                    final updated = await _orderService.fetchOrder(order.id!);
                    if (updated != null) {
                      try {
                        await _emailService.sendShippingNotification(updated);
                      } catch (_) {}
                    }
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadOrders();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Label gegenereerd${barcode.isNotEmpty ? " — $barcode" : ""}${sendEmail ? " + verzendmail verstuurd" : ""}'),
                      backgroundColor: const Color(0xFF1565C0),
                      duration: const Duration(seconds: 5),
                    ));

                    final freshOrder = await _orderService.fetchOrder(order.id!);
                    if (freshOrder != null && mounted) {
                      await showStockUpdateAfterShipment(context, freshOrder);
                    }
                  }
                } catch (e) {
                  if (kDebugMode) debugPrint('Error generating label: $e');
                  setDialogState(() => processing = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Label genereren mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFE53935)),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadLabel(int shipmentId) async {
    final myparcel = MyParcelService();
    try {
      final bytes = await myparcel.getLabel(shipmentId);
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Label nog niet beschikbaar'), backgroundColor: Color(0xFFE65100)),
          );
        }
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/myparcel_label_$shipmentId.pdf');
      await file.writeAsBytes(bytes);
      await launchUrl(Uri.file(file.path));
    } catch (e) {
      if (kDebugMode) debugPrint('Error downloading label: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Label downloaden mislukt. Probeer het opnieuw.'), backgroundColor: Color(0xFFE53935)),
        );
      }
    }
  }

  Widget _detailRow(String label, String value, {bool bold = false, bool subtle = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: bold ? 14 : 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: subtle ? const Color(0xFF64748B) : null)),
        Text(value, style: TextStyle(fontSize: bold ? 16 : 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: subtle ? const Color(0xFF64748B) : null)),
      ]),
    );
  }

  Future<void> _updateStatus(Order order, String newStatus) async {
    Navigator.pop(context);
    try {
      final updated = await _orderService.updateStatus(order.id!, newStatus);

      if (newStatus == 'betaald' && updated != null && !updated.bevestigingVerzonden) {
        try {
          await _emailService.sendOrderConfirmation(updated);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(_l.t('orderbevestiging_verzonden')),
              backgroundColor: const Color(0xFF1565C0),
              duration: const Duration(seconds: 3),
            ));
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Error sending order confirmation: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(_l.t('email_verzenden_mislukt')),
              backgroundColor: const Color(0xFFE65100),
            ));
          }
        }
      }

      _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_l.t('status_bijgewerkt')}: ${_statusLabel(newStatus)}'),
          backgroundColor: const Color(0xFF43A047),
        ));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_l.t('fout')), backgroundColor: const Color(0xFFE53935)));
      }
    }
  }

  Future<void> _sendConfirmationManually(Order order) async {
    try {
      await _emailService.sendOrderConfirmation(order);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_l.t('orderbevestiging_verzonden')),
          backgroundColor: const Color(0xFF43A047),
        ));
      }
      _loadOrders();
    } catch (e) {
      if (kDebugMode) debugPrint('Error sending confirmation manually: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_l.t('email_verzenden_mislukt')),
          backgroundColor: const Color(0xFFE53935),
        ));
      }
    }
  }

  Future<void> _generateInvoice(Order order) async {
    try {
      await InvoiceService.generateAndSave(order, context);
    } catch (e) {
      if (kDebugMode) debugPrint('Error generating invoice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_l.t('fout')), backgroundColor: const Color(0xFFE53935)));
      }
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'betaald': return const Color(0xFF43A047);
      case 'verzonden': return const Color(0xFF1565C0);
      case 'afgeleverd': return const Color(0xFF2E7D32);
      case 'geannuleerd': return const Color(0xFFE53935);
      case 'betaling_gestart': return const Color(0xFFE65100);
      default: return const Color(0xFF78909C);
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'betaald': return Icons.check_circle;
      case 'verzonden': return Icons.local_shipping;
      case 'afgeleverd': return Icons.done_all;
      case 'geannuleerd': return Icons.cancel;
      case 'betaling_gestart': return Icons.hourglass_top;
      default: return Icons.edit_note;
    }
  }
}
