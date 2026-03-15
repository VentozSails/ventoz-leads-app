import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/customer_service.dart';
import '../services/order_service.dart';

class CustomerDetailScreen extends StatefulWidget {
  final String? customerId;
  const CustomerDetailScreen({super.key, this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  static const _navy = Color(0xFF0D1B2A);
  static const _accent = Color(0xFF1B4965);
  static const _green = Color(0xFF2E7D32);
  static const _border = Color(0xFFE8ECF1);

  final _service = CustomerService();
  final _orderService = OrderService();

  Customer? _customer;
  List<ExternalCustomerNumber> _externals = [];
  List<Order> _orders = [];
  bool _loading = true;
  bool _saving = false;
  bool _isNew = false;

  final _emailCtrl = TextEditingController();
  final _naamCtrl = TextEditingController();
  final _voornaamCtrl = TextEditingController();
  final _achternaamCtrl = TextEditingController();
  final _bedrijfCtrl = TextEditingController();
  final _adresCtrl = TextEditingController();
  final _postcodeCtrl = TextEditingController();
  final _woonplaatsCtrl = TextEditingController();
  final _telefoonCtrl = TextEditingController();
  final _mobielCtrl = TextEditingController();
  final _btwCtrl = TextEditingController();
  final _kvkCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _opmCtrl = TextEditingController();
  String _landCode = 'NL';
  bool _isZakelijk = false;

  @override
  void initState() {
    super.initState();
    _isNew = widget.customerId == null;
    _load();
  }

  @override
  void dispose() {
    for (final c in [_emailCtrl, _naamCtrl, _voornaamCtrl, _achternaamCtrl, _bedrijfCtrl, _adresCtrl, _postcodeCtrl, _woonplaatsCtrl, _telefoonCtrl, _mobielCtrl, _btwCtrl, _kvkCtrl, _contactCtrl, _opmCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (_isNew) {
      setState(() => _loading = false);
      return;
    }
    final customer = await _service.getById(widget.customerId!);
    if (customer == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final externals = await _service.getExternalNumbers(customer.id!);
    List<Order> orders = [];
    try {
      orders = await _orderService.fetchOrdersForCustomer(
        klantId: customer.id,
        email: customer.email,
      );
    } catch (_) {}

    if (!mounted) return;
    _emailCtrl.text = customer.email.startsWith('noemail_') ? '' : customer.email;
    _naamCtrl.text = customer.naam ?? '';
    _voornaamCtrl.text = customer.voornaam ?? '';
    _achternaamCtrl.text = customer.achternaam ?? '';
    _bedrijfCtrl.text = customer.bedrijfsnaam ?? '';
    _adresCtrl.text = customer.adres ?? '';
    _postcodeCtrl.text = customer.postcode ?? '';
    _woonplaatsCtrl.text = customer.woonplaats ?? '';
    _telefoonCtrl.text = customer.telefoon ?? '';
    _mobielCtrl.text = customer.mobiel ?? '';
    _btwCtrl.text = customer.btwNummer ?? '';
    _kvkCtrl.text = customer.kvkNummer ?? '';
    _contactCtrl.text = customer.contactpersoon ?? '';
    _opmCtrl.text = customer.opmerkingen ?? '';
    _landCode = customer.landCode;
    _isZakelijk = customer.isZakelijk;

    setState(() {
      _customer = customer;
      _externals = externals;
      _orders = orders;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty && _isNew) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mailadres is verplicht voor nieuwe klanten'), backgroundColor: Color(0xFFE53935)),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final customer = Customer(
        id: _customer?.id,
        klantnummer: _customer?.klantnummer ?? '',
        authUserId: _customer?.authUserId,
        email: email.isNotEmpty ? email.toLowerCase() : _customer?.email ?? '',
        naam: _naamCtrl.text.trim().isEmpty ? null : _naamCtrl.text.trim(),
        voornaam: _voornaamCtrl.text.trim().isEmpty ? null : _voornaamCtrl.text.trim(),
        achternaam: _achternaamCtrl.text.trim().isEmpty ? null : _achternaamCtrl.text.trim(),
        bedrijfsnaam: _bedrijfCtrl.text.trim().isEmpty ? null : _bedrijfCtrl.text.trim(),
        adres: _adresCtrl.text.trim().isEmpty ? null : _adresCtrl.text.trim(),
        postcode: _postcodeCtrl.text.trim().isEmpty ? null : _postcodeCtrl.text.trim(),
        woonplaats: _woonplaatsCtrl.text.trim().isEmpty ? null : _woonplaatsCtrl.text.trim(),
        landCode: _landCode,
        telefoon: _telefoonCtrl.text.trim().isEmpty ? null : _telefoonCtrl.text.trim(),
        mobiel: _mobielCtrl.text.trim().isEmpty ? null : _mobielCtrl.text.trim(),
        btwNummer: _btwCtrl.text.trim().isEmpty ? null : _btwCtrl.text.trim(),
        kvkNummer: _kvkCtrl.text.trim().isEmpty ? null : _kvkCtrl.text.trim(),
        contactpersoon: _contactCtrl.text.trim().isEmpty ? null : _contactCtrl.text.trim(),
        opmerkingen: _opmCtrl.text.trim().isEmpty ? null : _opmCtrl.text.trim(),
        snelstartId: _customer?.snelstartId,
        snelstartKlantcode: _customer?.snelstartKlantcode,
        klantcodeAliases: _customer?.klantcodeAliases ?? [],
        isZakelijk: _isZakelijk,
        totaleOmzet: _customer?.totaleOmzet ?? 0,
        eersteFactuurDatum: _customer?.eersteFactuurDatum,
        laatsteFactuurDatum: _customer?.laatsteFactuurDatum,
        aantalFacturen: _customer?.aantalFacturen ?? 0,
        bronProspectId: _customer?.bronProspectId,
        bronProspectLand: _customer?.bronProspectLand,
      );
      await _service.save(customer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Klant opgeslagen'), backgroundColor: Color(0xFF2E7D32)),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout: $e'), backgroundColor: const Color(0xFFE53935)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDeleteCustomer() async {
    final naam = _customer!.displayNaam;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, size: 22, color: Color(0xFFE53935)),
          const SizedBox(width: 8),
          const Text('Klant wissen'),
        ]),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Weet je zeker dat je "$naam" wilt verwijderen?',
              style: GoogleFonts.dmSans(fontSize: 14, color: _navy),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFFE53935)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Alle klantgegevens, externe nummers en koppelingen worden permanent verwijderd. Orders blijven bewaard.',
                  style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFE53935)),
                )),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
            child: const Text('Definitief wissen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _service.delete(_customer!.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$naam" is verwijderd'), backgroundColor: const Color(0xFF2E7D32)),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij verwijderen: $e'), backgroundColor: const Color(0xFFE53935)),
        );
      }
    }
  }

  void _addExternalNumber() {
    if (_customer?.id == null) return;
    final numCtrl = TextEditingController();
    String platform = 'ebay';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Extern klantnummer toevoegen'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: platform,
                  decoration: const InputDecoration(labelText: 'Platform', border: OutlineInputBorder()),
                  items: ExternalCustomerNumber.platformLabels.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => platform = v ?? platform),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: numCtrl,
                  decoration: const InputDecoration(labelText: 'Extern klantnummer', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
            ElevatedButton(
              onPressed: () async {
                if (numCtrl.text.trim().isEmpty) return;
                await _service.saveExternalNumber(ExternalCustomerNumber(
                  klantId: _customer!.id!,
                  platform: platform,
                  externNummer: numCtrl.text.trim(),
                ));
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _load();
              },
              style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white),
              child: const Text('Toevoegen'),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtOmzet(double v) {
    if (v == 0) return '-';
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final whole = parts[0];
    final dec = parts[1];
    final buf = StringBuffer();
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buf.write('.');
      buf.write(whole[i]);
    }
    return '€ ${buf.toString()},$dec';
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          _isNew ? 'Nieuwe klant' : (_customer?.displayNaam ?? 'Klantdetail'),
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [
          if (!_isNew && _customer != null) ...[
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Chip(
                label: Text(_customer!.klantnummer, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                backgroundColor: _accent,
                side: BorderSide.none,
              ),
            ),
            if (_customer!.snelstartKlantcode != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text('SNL ${_customer!.snelstartKlantcode!}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  backgroundColor: _accent.withValues(alpha: 0.6),
                  side: BorderSide.none,
                ),
              ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isNew) _buildStatsRow(),
                  if (!_isNew) const SizedBox(height: 16),
                  _buildInfoCard(),
                  if (!_isNew) ...[
                    const SizedBox(height: 16),
                    _buildActionsRow(),
                    const SizedBox(height: 16),
                    _buildFacturenCard(),
                    const SizedBox(height: 16),
                    _buildExternalsCard(),
                    const SizedBox(height: 16),
                    _buildOrderHistoryCard(),
                    if (_customer!.klantcodeAliases.isNotEmpty || _customer!.snelstartKlantcode != null) ...[
                      const SizedBox(height: 16),
                      _buildAliasesCard(),
                    ],
                    if (_customer!.bronProspectId != null) ...[
                      const SizedBox(height: 16),
                      _buildProspectCard(),
                    ],
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isNew ? 'Klant aanmaken' : 'Opslaan', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  if (!_isNew && _customer != null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _confirmDeleteCustomer,
                        icon: const Icon(Icons.delete_forever_outlined, size: 18),
                        label: const Text('Klant wissen'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE53935),
                          side: const BorderSide(color: Color(0xFFE53935)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatsRow() {
    final c = _customer!;
    final invoiceCount = _orders.where((o) => o.factuurNummer != null && o.factuurNummer!.isNotEmpty).length;
    final displayCount = invoiceCount > 0 ? invoiceCount : c.aantalFacturen;
    return Row(
      children: [
        _statCard(Icons.euro_rounded, _fmtOmzet(c.totaleOmzet), 'Totale omzet', _green),
        const SizedBox(width: 10),
        _statCard(Icons.receipt_long_rounded, '$displayCount', 'Facturen', _accent),
        const SizedBox(width: 10),
        _statCard(Icons.calendar_today_rounded, _fmtDate(c.eersteFactuurDatum), 'Eerste', const Color(0xFF64748B)),
        const SizedBox(width: 10),
        _statCard(Icons.event_rounded, _fmtDate(c.laatsteFactuurDatum), 'Laatste', const Color(0xFF64748B)),
      ],
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF94A3B8))),
            ]),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: _border)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Klantgegevens', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
                const Spacer(),
                _buildZakelijkToggle(),
              ],
            ),
            if (_customer?.authUserId != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  const Icon(Icons.verified_user, size: 14, color: _green),
                  const SizedBox(width: 6),
                  Text('Geregistreerd account', style: GoogleFonts.dmSans(fontSize: 12, color: _green)),
                ]),
              ),
            const SizedBox(height: 16),
            _field('Volledige naam', _naamCtrl),
            const SizedBox(height: 12),
            _field('E-mailadres', _emailCtrl),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field('Voornaam', _voornaamCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _field('Achternaam', _achternaamCtrl)),
            ]),
            const SizedBox(height: 12),
            _field('Bedrijfsnaam', _bedrijfCtrl),
            const SizedBox(height: 12),
            _field('Contactpersoon', _contactCtrl),
            const SizedBox(height: 12),
            _field('Adres', _adresCtrl),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field('Postcode', _postcodeCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _field('Woonplaats', _woonplaatsCtrl)),
            ]),
            const SizedBox(height: 12),
            _buildLandDropdown(),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field('Telefoon', _telefoonCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _field('Mobiel', _mobielCtrl)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field('BTW-nummer', _btwCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _field('KvK-nummer', _kvkCtrl)),
            ]),
            const SizedBox(height: 12),
            _field('Opmerkingen', _opmCtrl, maxLines: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildZakelijkToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isZakelijk = !_isZakelijk),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _isZakelijk ? const Color(0xFF6366F1).withValues(alpha: 0.08) : const Color(0xFF0EA5E9).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _isZakelijk ? const Color(0xFF6366F1).withValues(alpha: 0.3) : const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isZakelijk ? Icons.business_rounded : Icons.person_rounded,
              size: 14,
              color: _isZakelijk ? const Color(0xFF6366F1) : const Color(0xFF0EA5E9),
            ),
            const SizedBox(width: 5),
            Text(
              _isZakelijk ? 'Zakelijk' : 'Particulier',
              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _isZakelijk ? const Color(0xFF6366F1) : const Color(0xFF0EA5E9)),
            ),
            const SizedBox(width: 3),
            Icon(Icons.swap_horiz, size: 14, color: _isZakelijk ? const Color(0xFF6366F1) : const Color(0xFF0EA5E9)),
          ],
        ),
      ),
    );
  }

  Widget _buildLandDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _landCode,
      decoration: const InputDecoration(labelText: 'Land', border: OutlineInputBorder(), isDense: true),
      items: Customer.landLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text('${e.value} (${e.key})'))).toList(),
      onChanged: (v) => setState(() => _landCode = v ?? 'NL'),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildActionsRow() {
    return Row(children: [
      Expanded(
        child: _actionButton(
          icon: Icons.email_outlined,
          label: 'E-mail sturen',
          color: const Color(0xFF0EA5E9),
          onTap: _showSendEmailDialog,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _actionButton(
          icon: Icons.local_offer_outlined,
          label: 'Aanbieding doen',
          color: const Color(0xFF8B5CF6),
          onTap: _showOfferDialog,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _actionButton(
          icon: Icons.phone_outlined,
          label: 'Bellen',
          color: _green,
          onTap: () {
            final tel = _customer!.telefoon ?? _customer!.mobiel;
            if (tel != null && tel.isNotEmpty) {
              launchUrl(Uri.parse('tel:$tel'));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geen telefoonnummer beschikbaar')));
            }
          },
        ),
      ),
    ]);
  }

  Widget _actionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  Widget _buildFacturenCard() {
    final invoiceOrders = _orders.where((o) => o.factuurNummer != null && o.factuurNummer!.isNotEmpty).toList();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: _border)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.receipt_long, size: 18, color: _accent),
              const SizedBox(width: 8),
              Text('Facturen', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                child: Text('${invoiceOrders.length}', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: _accent)),
              ),
            ]),
            const SizedBox(height: 10),
            if (invoiceOrders.isEmpty)
              Text('Nog geen facturen beschikbaar.', style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF94A3B8)))
            else
              ...(invoiceOrders.map((o) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: _accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.description_outlined, size: 16, color: _accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o.factuurNummer!, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: _navy)),
                    Text('Order: ${o.orderNummer} — €${o.totaal.toStringAsFixed(2)}',
                        style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B))),
                  ])),
                  Text(
                    o.createdAt != null ? '${o.createdAt!.day}-${o.createdAt!.month}-${o.createdAt!.year}' : '',
                    style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                  ),
                ]),
              ))),
          ],
        ),
      ),
    );
  }

  void _showSendEmailDialog() {
    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final email = _customer!.email;

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.email_outlined, size: 20, color: Color(0xFF0EA5E9)),
        const SizedBox(width: 10),
        Text('E-mail sturen', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700)),
      ]),
      content: SizedBox(
        width: 500,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Text('Aan: ', style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B))),
              Text(email, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: subjectCtrl,
            decoration: const InputDecoration(labelText: 'Onderwerp', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bodyCtrl,
            decoration: const InputDecoration(labelText: 'Bericht', border: OutlineInputBorder(), isDense: true, alignLabelWithHint: true),
            maxLines: 8,
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuleren')),
        TextButton(
          onPressed: () {
            final uri = Uri(scheme: 'mailto', path: email, queryParameters: {
              if (subjectCtrl.text.isNotEmpty) 'subject': subjectCtrl.text,
              if (bodyCtrl.text.isNotEmpty) 'body': bodyCtrl.text,
            });
            launchUrl(uri);
            Navigator.pop(ctx);
          },
          child: const Text('Open in e-mailclient'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (subjectCtrl.text.isEmpty) return;
            Navigator.pop(ctx);
            try {
              await Supabase.instance.client.functions.invoke('send-order-email', body: {
                'to': email,
                'subject': subjectCtrl.text,
                'body': bodyCtrl.text,
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('E-mail verzonden'), backgroundColor: Color(0xFF43A047)),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Fout bij verzenden: $e'), backgroundColor: const Color(0xFFE53935)),
                );
              }
            }
          },
          child: const Text('Verzenden via Ventoz'),
        ),
      ],
    ));
  }

  void _showOfferDialog() {
    final naam = _customer!.displayNaam;
    final email = _customer!.email;

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.local_offer_outlined, size: 20, color: Color(0xFF8B5CF6)),
        const SizedBox(width: 10),
        Text('Aanbieding aan $naam', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700)),
      ]),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Kies een standaard e-mailsjabloon of stel zelf een aanbieding samen.',
              style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B))),
          const SizedBox(height: 16),
          _offerOption(
            icon: Icons.sailing,
            title: 'Productaanbieding',
            subtitle: 'Stuur een aanbieding op basis van ons assortiment',
            onTap: () { Navigator.pop(ctx); _showSendEmailDialog(); },
          ),
          const SizedBox(height: 8),
          _offerOption(
            icon: Icons.percent,
            title: 'Korting / Staffelprijs',
            subtitle: 'Bied een speciale korting aan',
            onTap: () { Navigator.pop(ctx); _showSendEmailDialog(); },
          ),
          const SizedBox(height: 8),
          _offerOption(
            icon: Icons.campaign_outlined,
            title: 'Seizoensactie',
            subtitle: 'Stuur een seizoensgebonden aanbieding',
            onTap: () { Navigator.pop(ctx); _showSendEmailDialog(); },
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Sluiten')),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            final uri = Uri(scheme: 'mailto', path: email, queryParameters: {'subject': 'Aanbieding Ventoz Sails'});
            launchUrl(uri);
          },
          child: const Text('Open in e-mailclient'),
        ),
      ],
    ));
  }

  Widget _offerOption({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: const Color(0xFF8B5CF6)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: _navy)),
            Text(subtitle, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
          ])),
          const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
        ]),
      ),
    );
  }

  Widget _buildExternalsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: _border)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Externe klantnummers', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: _accent),
                onPressed: _addExternalNumber,
                tooltip: 'Extern nummer toevoegen',
              ),
            ]),
            const SizedBox(height: 8),
            if (_externals.isEmpty)
              Text('Nog geen externe nummers gekoppeld.', style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF94A3B8)))
            else
              ...(_externals.map((ext) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: _accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.link, size: 16, color: _accent),
                ),
                title: Text(ext.platformLabel, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(ext.externNummer, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFE53935)),
                  onPressed: () async {
                    await _service.deleteExternalNumber(ext.id!);
                    _load();
                  },
                ),
              ))),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHistoryCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: _border)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bestelhistorie', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
            const SizedBox(height: 8),
            if (_orders.isEmpty)
              Text('Geen bestellingen gevonden.', style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF94A3B8)))
            else
              ...(_orders.take(20).map((o) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: o.isBetaald ? _green.withValues(alpha: 0.08) : const Color(0xFFE65100).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    o.isBetaald ? Icons.check_circle_outline : Icons.pending_outlined,
                    size: 16,
                    color: o.isBetaald ? _green : const Color(0xFFE65100),
                  ),
                ),
                title: Text(o.orderNummer, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${o.statusLabel} — €${o.totaal.toStringAsFixed(2)}',
                  style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                trailing: Text(
                  o.createdAt != null ? '${o.createdAt!.day}-${o.createdAt!.month}-${o.createdAt!.year}' : '',
                  style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                ),
              ))),
            if (_orders.length > 20)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('+ ${_orders.length - 20} meer...', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAliasesCard() {
    final allCodes = <String>[];
    if (_customer!.snelstartKlantcode != null && _customer!.snelstartKlantcode!.isNotEmpty) {
      allCodes.add(_customer!.snelstartKlantcode!);
    }
    for (final alias in _customer!.klantcodeAliases) {
      if (alias.isNotEmpty && !allCodes.contains(alias)) allCodes.add(alias);
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: _border)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Snelstart klantnummers', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
            const SizedBox(height: 8),
            Text(
              'Alle Snelstart-klantcodes gekoppeld aan deze klant (primair + samengevoegd):',
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: allCodes.asMap().entries.map((entry) {
                final isPrimary = entry.key == 0;
                return Chip(
                  avatar: isPrimary ? const Icon(Icons.star, size: 14, color: Color(0xFF92400E)) : null,
                  label: Text(
                    entry.value,
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500),
                  ),
                  backgroundColor: isPrimary ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Text(
              'Deze nummers worden door Snelstart beheerd en zijn niet aanpasbaar via de app.',
              style: GoogleFonts.dmSans(fontSize: 11, fontStyle: FontStyle.italic, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProspectCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: _border)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Prospect-koppeling', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.link, size: 16, color: _accent),
              const SizedBox(width: 8),
              Text(
                'Gekoppeld aan prospect #${_customer!.bronProspectId} (${_customer!.bronProspectLand ?? '?'})',
                style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
