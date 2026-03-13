import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import '../services/order_email_service.dart';
import '../services/company_settings_service.dart';
import '../services/invoice_service.dart';
import '../services/order_service.dart';
import '../services/user_service.dart';

class OrderTemplateEditorScreen extends StatefulWidget {
  const OrderTemplateEditorScreen({super.key});

  @override
  State<OrderTemplateEditorScreen> createState() => _OrderTemplateEditorScreenState();
}

class _OrderTemplateEditorScreenState extends State<OrderTemplateEditorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailService = OrderEmailService();
  final _userService = UserService();
  bool _loading = true;
  bool _saving = false;

  final _confirmCtrl = TextEditingController();
  final _shippingCtrl = TextEditingController();
  String _previewHtml = '';
  String _activeTab = 'bevestiging';
  bool _showEditor = true;

  String _invoiceAccent = '#455A64';
  bool _invoiceShowLogo = true;
  bool _invoiceShowIban = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _activeTab = ['bevestiging', 'verzending', 'factuur'][_tabController.index];
        });
        _updatePreview();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _confirmCtrl.dispose();
    _shippingCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.orderTemplatesBewerken) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
        );
      }
      return;
    }
    final templates = await OrderEmailService.loadTemplates();
    final defaultConfirm = _emailService.getDefaultConfirmationHtml();
    final defaultShipping = _emailService.getDefaultShippingHtml();

    _confirmCtrl.text = templates['bevestiging'] ?? defaultConfirm;
    _shippingCtrl.text = templates['verzending'] ?? defaultShipping;

    final company = await CompanySettingsService().getSettings();
    _invoiceAccent = company.accentKleur;

    if (mounted) {
      setState(() => _loading = false);
      _updatePreview();
    }
  }

  void _updatePreview() {
    setState(() {
      if (_activeTab == 'bevestiging') {
        _previewHtml = _fillDummyPlaceholders(_confirmCtrl.text);
      } else if (_activeTab == 'verzending') {
        _previewHtml = _fillDummyPlaceholders(_shippingCtrl.text);
      }
    });
  }

  String _fillDummyPlaceholders(String html) {
    return html
        .replaceAll('{{ordernummer}}', 'V-2026-00001')
        .replaceAll('{{datum}}', '11-03-2026')
        .replaceAll('{{klantnaam}}', 'Jan de Vries')
        .replaceAll('{{bedrijfsnaam}}', 'Ventoz')
        .replaceAll('{{betaalmethode}}', 'iDEAL')
        .replaceAll('{{subtotaal}}', '€ 347,11')
        .replaceAll('{{btw}}', '€ 72,89')
        .replaceAll('{{totaal}}', '€ 420,00')
        .replaceAll('{{verzendkosten}}', '€ 0,00')
        .replaceAll('{{carrier}}', 'PostNL')
        .replaceAll('{{trackcode}}', '3SABCD1234567890')
        .replaceAll('{{trackurl}}', 'https://postnl.nl/tracktrace')
        .replaceAll('{{verzendland}}', 'Nederland')
        .replaceAll('{{bedrijfs_adres}}', 'Dorpsstraat 111 · 7948 BN Nijeveen')
        .replaceAll('{{bedrijfs_email}}', 'app@ventoz.nl')
        .replaceAll('{{product_tabel}}', '''<tr>
  <td style="padding:10px 16px;border-bottom:1px solid #e2e8f0;font-size:14px;color:#334155;">Optimist Zeil Competition</td>
  <td style="padding:10px 8px;border-bottom:1px solid #e2e8f0;text-align:center;font-size:14px;color:#64748B;">1</td>
  <td style="padding:10px 16px;border-bottom:1px solid #e2e8f0;text-align:right;font-size:14px;color:#334155;">€ 395,00</td>
</tr>
<tr>
  <td style="padding:10px 16px;border-bottom:1px solid #e2e8f0;font-size:14px;color:#334155;">Fokkenlijn 6mm x 8m</td>
  <td style="padding:10px 8px;border-bottom:1px solid #e2e8f0;text-align:center;font-size:14px;color:#64748B;">2</td>
  <td style="padding:10px 16px;border-bottom:1px solid #e2e8f0;text-align:right;font-size:14px;color:#334155;">€ 25,00</td>
</tr>''');
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_activeTab == 'bevestiging') {
        await OrderEmailService.saveTemplate('bevestiging', _confirmCtrl.text);
      } else if (_activeTab == 'verzending') {
        await OrderEmailService.saveTemplate('verzending', _shippingCtrl.text);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Template opgeslagen'),
          backgroundColor: Color(0xFF43A047),
        ));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving order template: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Opslaan mislukt. Probeer het opnieuw.'),
          backgroundColor: Color(0xFFE53935),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetToDefault() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Standaard herstellen?'),
        content: const Text('De huidige template wordt overschreven met de standaard HTML.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuleren')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Herstellen', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      if (_activeTab == 'bevestiging') {
        _confirmCtrl.text = _emailService.getDefaultConfirmationHtml();
      } else if (_activeTab == 'verzending') {
        _shippingCtrl.text = _emailService.getDefaultShippingHtml();
      }
    });
    _updatePreview();
  }

  Future<void> _previewInvoicePdf() async {
    try {
      final dummyOrder = Order(
        orderNummer: 'V-2026-00001',
        factuurNummer: 'VF-2026-00001',
        userEmail: 'klant@voorbeeld.nl',
        naam: 'Jan de Vries',
        adres: 'Keizersgracht 100',
        postcode: '1015 AA',
        woonplaats: 'Amsterdam',
        landCode: 'NL',
        regels: [
          OrderRegel(productId: 'demo-1', productNaam: 'Optimist Zeil Competition', aantal: 1, stukprijs: 395.00, regelTotaal: 395.00),
          OrderRegel(productId: 'demo-2', productNaam: 'Fokkenlijn 6mm x 8m', aantal: 2, stukprijs: 12.50, regelTotaal: 25.00),
        ],
        subtotaal: 347.11,
        btwBedrag: 72.89,
        totaal: 420.00,
        verzendkosten: 0,
        btwPercentage: 21,
        status: 'betaald',
        betaalMethode: 'iDEAL',
        createdAt: DateTime.now(),
        betaaldOp: DateTime.now(),
      );

      if (!mounted) return;
      await InvoiceService.generateAndSave(dummyOrder, context);
    } catch (e) {
      if (kDebugMode) debugPrint('Error generating PDF preview: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('PDF voorbeeld mislukt. Probeer het opnieuw.'),
          backgroundColor: Color(0xFFE53935),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/ventoz_logo.png', width: 28, height: 28)),
          const SizedBox(width: 10),
          const Text('Template-editor'),
        ]),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.check_circle_outline, size: 16), text: 'Orderbevestiging'),
            Tab(icon: Icon(Icons.local_shipping, size: 16), text: 'Verzendnotificatie'),
            Tab(icon: Icon(Icons.picture_as_pdf, size: 16), text: 'Factuur-PDF'),
          ],
        ),
        actions: [
          if (_activeTab != 'factuur')
            IconButton(
              icon: Icon(_showEditor ? Icons.visibility : Icons.code),
              tooltip: _showEditor ? 'Alleen preview' : 'Editor tonen',
              onPressed: () => setState(() => _showEditor = !_showEditor),
            ),
          if (_activeTab != 'factuur')
            IconButton(icon: const Icon(Icons.restore), tooltip: 'Standaard herstellen', onPressed: _resetToDefault),
          if (_activeTab != 'factuur')
            _saving
                ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                : IconButton(icon: const Icon(Icons.save), tooltip: 'Opslaan', onPressed: _save),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildEmailEditorTab(_confirmCtrl),
                _buildEmailEditorTab(_shippingCtrl),
                _buildInvoiceConfigTab(),
              ],
            ),
    );
  }

  Widget _buildEmailEditorTab(TextEditingController ctrl) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (!_showEditor) {
      return _buildPreviewPane();
    }

    if (isWide) {
      return Row(children: [
        Expanded(flex: 5, child: _buildEditorPane(ctrl)),
        const VerticalDivider(width: 1),
        Expanded(flex: 5, child: _buildPreviewPane()),
      ]);
    }

    return Column(children: [
      _buildPlaceholderBar(),
      Expanded(flex: 5, child: _buildEditorPane(ctrl)),
      Container(
        height: 36,
        color: const Color(0xFF37474F),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          const Icon(Icons.visibility, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          const Text('Preview', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _showEditor = false),
            child: const Text('Volledig scherm', style: TextStyle(fontSize: 11, color: Colors.white)),
          ),
        ]),
      ),
      Expanded(flex: 4, child: _buildPreviewPane()),
    ]);
  }

  Widget _buildEditorPane(TextEditingController ctrl) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Column(children: [
      if (isWide) _buildPlaceholderBar(),
      Container(
        height: 32,
        color: const Color(0xFF263238),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          const Icon(Icons.code, size: 14, color: Colors.white54),
          const SizedBox(width: 6),
          Text(
            _activeTab == 'bevestiging' ? 'orderbevestiging.html' : 'verzendnotificatie.html',
            style: const TextStyle(fontSize: 11, color: Colors.white54, fontFamily: 'Courier New'),
          ),
          const Spacer(),
          Text(
            '${ctrl.text.length} tekens',
            style: const TextStyle(fontSize: 10, color: Colors.white38),
          ),
        ]),
      ),
      Expanded(
        child: Container(
          color: const Color(0xFF1E1E1E),
          child: TextField(
            controller: ctrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontFamily: 'Courier New', fontSize: 12, height: 1.6, color: Color(0xFFD4D4D4)),
            cursorColor: const Color(0xFF569CD6),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
              hintText: 'HTML template...',
              hintStyle: TextStyle(color: Color(0xFF555555)),
            ),
            onChanged: (_) => _updatePreview(),
          ),
        ),
      ),
    ]);
  }

  Widget _buildPlaceholderBar() {
    const placeholders = <(String, String, IconData)>[
      ('{{ordernummer}}', 'Ordernummer', Icons.tag),
      ('{{datum}}', 'Datum', Icons.calendar_today),
      ('{{klantnaam}}', 'Klantnaam', Icons.person),
      ('{{bedrijfsnaam}}', 'Bedrijfsnaam', Icons.business),
      ('{{product_tabel}}', 'Producttabel', Icons.table_chart),
      ('{{subtotaal}}', 'Subtotaal', Icons.calculate),
      ('{{btw}}', 'BTW', Icons.percent),
      ('{{totaal}}', 'Totaal', Icons.euro),
      ('{{verzendkosten}}', 'Verzendkosten', Icons.local_shipping),
      ('{{betaalmethode}}', 'Betaalmethode', Icons.payment),
      ('{{carrier}}', 'Vervoerder', Icons.local_shipping),
      ('{{trackcode}}', 'Trackcode', Icons.qr_code),
      ('{{trackurl}}', 'Track URL', Icons.link),
      ('{{verzendland}}', 'Verzendland', Icons.public),
      ('{{bedrijfs_adres}}', 'Adres', Icons.location_on),
      ('{{bedrijfs_email}}', 'E-mail', Icons.email),
    ];

    return Container(
      height: 38,
      color: const Color(0xFFECEFF1),
      child: Row(children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Placeholders:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF546E7A))),
        ),
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: placeholders.map((p) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Tooltip(
                message: 'Invoegen: ${p.$1}',
                child: ActionChip(
                  avatar: Icon(p.$3, size: 12, color: const Color(0xFF3949AB)),
                  label: Text(p.$2, style: const TextStyle(fontSize: 10)),
                  labelPadding: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: const Color(0xFFE8EAF6),
                  side: BorderSide.none,
                  onPressed: () {
                    final ctrl = _activeTab == 'bevestiging' ? _confirmCtrl : _shippingCtrl;
                    final sel = ctrl.selection;
                    final text = ctrl.text;
                    if (sel.isValid) {
                      ctrl.text = text.substring(0, sel.start) + p.$1 + text.substring(sel.end);
                      ctrl.selection = TextSelection.collapsed(offset: sel.start + p.$1.length);
                    }
                    _updatePreview();
                  },
                ),
              ),
            )).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _buildPreviewPane() {
    if (_activeTab == 'factuur') return const SizedBox.shrink();

    return Column(children: [
      if (_showEditor)
        Container(
          height: 32,
          color: const Color(0xFF37474F),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: const Row(children: [
            Icon(Icons.visibility, size: 14, color: Colors.white70),
            SizedBox(width: 6),
            Text('Live Preview', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
          ]),
        ),
      Expanded(
        child: Container(
          color: const Color(0xFFF1F5F9),
          child: _previewHtml.isEmpty
              ? const Center(child: Text('Typ HTML om een voorbeeld te zien', style: TextStyle(color: Color(0xFF94A3B8))))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: HtmlWidget(
                        _previewHtml,
                        textStyle: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    ]);
  }

  Widget _buildInvoiceConfigTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Factuur-PDF Configuratie', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            const Text(
              'De factuur-PDF wordt gegenereerd vanuit code. Hieronder kun je enkele elementen aanpassen. '
              'De bedrijfsgegevens worden automatisch uit het bedrijfsgegevens-scherm overgenomen.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Instellingen', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF455A64))),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Text('Accentkleur: ', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: _parseColor(_invoiceAccent),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_invoiceAccent, style: const TextStyle(fontSize: 12, fontFamily: 'Courier New', color: Color(0xFF64748B))),
                    const SizedBox(width: 8),
                    const Text('(Wijzig via Bedrijfsgegevens)', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic)),
                  ]),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Logo tonen', style: TextStyle(fontSize: 13)),
                    value: _invoiceShowLogo,
                    onChanged: (v) => setState(() => _invoiceShowLogo = v),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('IBAN tonen in footer', style: TextStyle(fontSize: 13)),
                    value: _invoiceShowIban,
                    onChanged: (v) => setState(() => _invoiceShowIban = v),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Voorbeeld PDF bekijken'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
                onPressed: _previewInvoicePdf,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      try { return Color(int.parse('FF$clean', radix: 16)); } catch (_) {}
    }
    return const Color(0xFF455A64);
  }
}
