import 'package:flutter/material.dart';
import '../services/pay_nl_service.dart';
import '../services/buckaroo_service.dart';
import '../services/payment_gateway_service.dart';
import '../services/user_service.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final PayNlService _payNlService = PayNlService();
  final BuckarooService _buckarooService = BuckarooService();
  final _userService = UserService();

  final _serviceIdCtrl = TextEditingController();
  final _serviceSecretCtrl = TextEditingController();
  final _atCodeCtrl = TextEditingController();
  final _apiTokenCtrl = TextEditingController();
  bool _payNlTestMode = true;

  final _bWebsiteKeyCtrl = TextEditingController();
  final _bSecretKeyCtrl = TextEditingController();
  bool _buckarooTestMode = true;

  Set<String> _activeGateways = {'pay_nl'};
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  Map<String, bool> _testResults = {};

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _serviceIdCtrl.dispose();
    _serviceSecretCtrl.dispose();
    _atCodeCtrl.dispose();
    _apiTokenCtrl.dispose();
    _bWebsiteKeyCtrl.dispose();
    _bSecretKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final perms = await _userService.getCurrentUserPermissions();
    if (!mounted) return;
    if (!perms.betaalgatewayInstellingen) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geen toegang tot dit scherm.'), backgroundColor: Color(0xFFE53935)),
        );
      }
      return;
    }
    final payConfig = await _payNlService.getConfig();
    final bConfig = await _buckarooService.getConfig();
    final gateways = await _buckarooService.getActiveGateways();
    if (!mounted) return;
    setState(() {
      if (payConfig != null) {
        _serviceIdCtrl.text = payConfig.serviceId;
        _serviceSecretCtrl.text = payConfig.serviceSecret;
        _atCodeCtrl.text = payConfig.atCode;
        _apiTokenCtrl.text = payConfig.apiToken;
        _payNlTestMode = payConfig.testMode;
      }
      if (bConfig != null) {
        _bWebsiteKeyCtrl.text = bConfig.websiteKey;
        _bSecretKeyCtrl.text = bConfig.secretKey;
        _buckarooTestMode = bConfig.testMode;
      }
      _activeGateways = gateways;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _payNlService.saveConfig(PaymentConfig(
        serviceId: _serviceIdCtrl.text.trim(),
        serviceSecret: _serviceSecretCtrl.text.trim(),
        atCode: _atCodeCtrl.text.trim(),
        apiToken: _apiTokenCtrl.text.trim(),
        testMode: _payNlTestMode,
      ));
      await _buckarooService.saveConfig(BuckarooConfig(
        websiteKey: _bWebsiteKeyCtrl.text.trim(),
        secretKey: _bSecretKeyCtrl.text.trim(),
        testMode: _buckarooTestMode,
      ));
      await _buckarooService.setActiveGateways(_activeGateways);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Betaalinstellingen opgeslagen'),
        backgroundColor: Color(0xFF43A047),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Opslaan mislukt: $e'),
        backgroundColor: const Color(0xFFE53935),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResults = {};
    });
    try {
      await _save();
      _payNlService.lastTestError = null;
      _buckarooService.lastTestError = null;
      final results = <String, bool>{};
      if (_activeGateways.contains('pay_nl')) {
        results['pay_nl'] = await _payNlService.testConnection();
      }
      if (_activeGateways.contains('buckaroo')) {
        results['buckaroo'] = await _buckarooService.testConnection();
      }
      if (mounted) setState(() { _testResults = results; _testing = false; });
    } catch (_) {
      if (mounted) setState(() { _testing = false; });
    }
  }

  String _getTestErrorDetail(String key) {
    final error = key == 'pay_nl'
        ? _payNlService.lastTestError
        : _buckarooService.lastTestError;
    if (error == null) return 'Controleer je gegevens.';
    if (error.contains('SocketException')) return 'Netwerk onbereikbaar. Controleer je internetverbinding.';
    if (error.contains('HandshakeException')) return 'SSL/TLS-fout. Mogelijk blokkeert een firewall of proxy de verbinding.';
    if (error.contains('TimeoutException') || error.contains('timed out')) return 'Verbinding verlopen. Server reageert niet.';
    if (error.contains('ClientException')) return 'HTTP-fout. Controleer je internetverbinding.';
    if (error.contains('CERTIFICATE_VERIFY_FAILED')) return 'SSL-certificaat ongeldig. Mogelijk zit je achter een proxy.';
    return error.length > 80 ? '${error.substring(0, 80)}...' : error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.asset('assets/ventoz_logo.png', width: 28, height: 28)),
          const SizedBox(width: 10),
          const Text('Betaalinstellingen'),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGatewaySelector(),
                      const SizedBox(height: 24),
                      _buildPayNlSection(),
                      const SizedBox(height: 24),
                      _buildBuckarooSection(),
                      const SizedBox(height: 24),
                      _buildActions(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildGatewaySelector() {
    final noneActive = _activeGateways.isEmpty;
    return Card(
      color: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.swap_horiz, size: 28, color: Color(0xFF455A64)),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Actieve betaalgateways', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Beide gateways kunnen tegelijk actief zijn. Pay.nl is primair bij overlap.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 14),
            CheckboxListTile(
              value: _activeGateways.contains('pay_nl'),
              onChanged: (v) => setState(() {
                if (v == true) { _activeGateways.add('pay_nl'); } else { _activeGateways.remove('pay_nl'); }
              }),
              title: const Text('Pay.nl', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              secondary: const Icon(Icons.payment, size: 22, color: Color(0xFF455A64)),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              value: _activeGateways.contains('buckaroo'),
              onChanged: (v) => setState(() {
                if (v == true) { _activeGateways.add('buckaroo'); } else { _activeGateways.remove('buckaroo'); }
              }),
              title: const Text('Buckaroo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              secondary: const Icon(Icons.account_balance, size: 22, color: Color(0xFF455A64)),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (noneActive) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFFE65100)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Geen gateway actief — bestellingen worden opgeslagen zonder online betaling.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFE65100)))),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPayNlSection() {
    final isActive = _activeGateways.contains('pay_nl');
    return Opacity(
      opacity: isActive ? 1.0 : 0.5,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.payment, size: 22, color: Color(0xFF455A64)),
              const SizedBox(width: 8),
              const Text('Pay.nl', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (isActive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF43A047), borderRadius: BorderRadius.circular(10)),
                  child: const Text('Actief', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Transactie-verwerking (TGU)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF455A64))),
                SizedBox(height: 2),
                Text('Instellingen > Verkooplocaties > klik op SL-code', style: TextStyle(fontSize: 11, color: Color(0xFF78909C))),
              ]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _serviceIdCtrl,
              decoration: const InputDecoration(labelText: 'Service ID (SL-code)', hintText: 'SL-xxxx-xxxx', prefixIcon: Icon(Icons.storefront, size: 20), isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _serviceSecretCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Service Secret (optioneel)', hintText: '40-karakter hash', prefixIcon: Icon(Icons.key, size: 20), isDense: true),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Merchant API', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF455A64))),
                SizedBox(height: 2),
                Text('Merchant > API tokens', style: TextStyle(fontSize: 11, color: Color(0xFF78909C))),
              ]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _atCodeCtrl,
              decoration: const InputDecoration(labelText: 'AT-code', hintText: 'AT-xxxx-xxxx', prefixIcon: Icon(Icons.vpn_key, size: 20), isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiTokenCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'API Token', hintText: '40-karakter hash', prefixIcon: Icon(Icons.lock, size: 20), isDense: true),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Testmodus', style: TextStyle(fontSize: 14)),
              subtitle: Text(
                _payNlTestMode ? 'Betalingen worden niet echt verwerkt' : 'Betalingen worden echt verwerkt',
                style: TextStyle(fontSize: 12, color: _payNlTestMode ? const Color(0xFFE65100) : const Color(0xFF43A047)),
              ),
              value: _payNlTestMode,
              onChanged: (v) => setState(() => _payNlTestMode = v),
              secondary: Icon(_payNlTestMode ? Icons.science : Icons.verified, color: _payNlTestMode ? const Color(0xFFE65100) : const Color(0xFF43A047)),
              contentPadding: EdgeInsets.zero,
            ),
            if (!_payNlTestMode) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [
                  Icon(Icons.warning_amber, size: 18, color: Color(0xFFE65100)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Live modus is actief!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE65100)))),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildBuckarooSection() {
    final isActive = _activeGateways.contains('buckaroo');
    return Opacity(
      opacity: isActive ? 1.0 : 0.5,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.account_balance, size: 22, color: Color(0xFF455A64)),
              const SizedBox(width: 8),
              const Text('Buckaroo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (isActive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF43A047), borderRadius: BorderRadius.circular(10)),
                  child: const Text('Actief', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Buckaroo Plaza', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF455A64))),
                SizedBox(height: 2),
                Text('Configuratie > Beveiligingsinstellingen > Webservices', style: TextStyle(fontSize: 11, color: Color(0xFF78909C))),
              ]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bWebsiteKeyCtrl,
              decoration: const InputDecoration(labelText: 'Website Key', hintText: 'Uw Buckaroo website key', prefixIcon: Icon(Icons.language, size: 20), isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bSecretKeyCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Secret Key', hintText: 'HMAC secret key', prefixIcon: Icon(Icons.lock, size: 20), isDense: true),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Testmodus', style: TextStyle(fontSize: 14)),
              subtitle: Text(
                _buckarooTestMode ? 'Test-omgeving actief' : 'Live-omgeving actief',
                style: TextStyle(fontSize: 12, color: _buckarooTestMode ? const Color(0xFFE65100) : const Color(0xFF43A047)),
              ),
              value: _buckarooTestMode,
              onChanged: (v) => setState(() => _buckarooTestMode = v),
              secondary: Icon(_buckarooTestMode ? Icons.science : Icons.verified, color: _buckarooTestMode ? const Color(0xFFE65100) : const Color(0xFF43A047)),
              contentPadding: EdgeInsets.zero,
            ),
            if (!_buckarooTestMode) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [
                  Icon(Icons.warning_amber, size: 18, color: Color(0xFFE65100)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Live modus is actief!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE65100)))),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Column(children: [
      for (final entry in _testResults.entries) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: entry.value ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(entry.value ? Icons.check_circle : Icons.error,
                size: 18, color: entry.value ? const Color(0xFF43A047) : const Color(0xFFE53935)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${entry.key == 'pay_nl' ? 'Pay.nl' : 'Buckaroo'}: ${entry.value ? 'Verbinding succesvol!' : 'Verbinding mislukt.'}',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: entry.value ? const Color(0xFF43A047) : const Color(0xFFE53935)),
              ),
              if (!entry.value) ...[
                const SizedBox(height: 2),
                Text(
                  _getTestErrorDetail(entry.key),
                  style: const TextStyle(fontSize: 10, color: Color(0xFF90A4AE)),
                ),
              ],
            ])),
          ]),
        ),
      ],
      if (_testResults.isNotEmpty) const SizedBox(height: 4),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: _testing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_tethering, size: 18),
            label: Text(_testing ? 'Testen...' : 'Verbinding testen'),
            onPressed: _testing ? null : _testConnection,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save, size: 18),
            label: Text(_saving ? 'Opslaan...' : 'Opslaan'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF455A64), foregroundColor: Colors.white),
            onPressed: _saving ? null : _save,
          ),
        ),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.payment, size: 18),
          label: const Text('Actieve betaalmethoden bekijken'),
          onPressed: _showPaymentMethods,
        ),
      ),
    ]);
  }

  Future<void> _showPaymentMethods() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final methods = await _collectActiveMethods();
    if (!mounted) return;
    Navigator.pop(context);

    final gatewayLabels = <String>{};
    for (final m in methods) {
      gatewayLabels.add(m.gateway == 'pay_nl' ? 'Pay.nl' : 'Buckaroo');
    }
    final subtitle = gatewayLabels.isEmpty
        ? 'Geen gateway actief'
        : 'Via ${gatewayLabels.join(' + ')}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.payment, color: Color(0xFF455A64)),
              const SizedBox(width: 8),
              Text('Actieve betaalmethoden (${methods.length})'),
            ]),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF78909C))),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: methods.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Geen actieve betaalmethoden gevonden.\nActiveer minstens één gateway.', textAlign: TextAlign.center)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: methods.length,
                  itemBuilder: (_, i) {
                    final m = methods[i];
                    final gwLabel = m.gateway == 'pay_nl' ? 'Pay.nl' : 'Buckaroo';
                    final gwColor = m.gateway == 'pay_nl' ? const Color(0xFF2E7D32) : const Color(0xFF1565C0);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.check_circle, color: gwColor, size: 20),
                        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(gwLabel, style: TextStyle(fontSize: 11, color: gwColor)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: gwColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            gwLabel.substring(0, 1),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: gwColor),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Sluiten')),
        ],
      ),
    );
  }

  Future<List<PaymentMethod>> _collectActiveMethods() async {
    final methods = <PaymentMethod>[];
    final seenNames = <String>{};

    if (_activeGateways.contains('pay_nl')) {
      final payNlConfig = await _payNlService.getConfig();
      if (payNlConfig != null && payNlConfig.isConfigured) {
        try {
          final svcConfig = await _payNlService.getServiceConfig();
          if (svcConfig != null) {
            final rawOptions = svcConfig['checkoutOptions'] as List? ?? [];
            for (final raw in rawOptions) {
              if (raw is! Map<String, dynamic>) continue;
              final name = raw['name'] as String? ?? '';
              if (name.isEmpty) continue;
              final norm = _normName(name);
              if (seenNames.contains(norm)) continue;
              seenNames.add(norm);
              methods.add(PaymentMethod(
                id: raw['tag'] as String? ?? '',
                name: name,
                gateway: 'pay_nl',
                payNlOptionId: raw['id'] as int? ?? 0,
              ));
            }
          }
        } catch (_) {}
      }
    }

    if (_activeGateways.contains('buckaroo')) {
      final bConfig = await _buckarooService.getConfig();
      if (bConfig != null && bConfig.isConfigured) {
        for (final entry in _buckarooMethods.entries) {
          final norm = _normName(entry.value);
          if (seenNames.contains(norm)) continue;
          seenNames.add(norm);
          methods.add(PaymentMethod(
            id: 'buckaroo_${entry.key}',
            name: entry.value,
            gateway: 'buckaroo',
            buckarooServiceName: entry.key,
          ));
        }
      }
    }

    return methods;
  }

  static String _normName(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static const _buckarooMethods = <String, String>{
    'ideal': 'iDEAL',
    'bancontactmrcash': 'Bancontact',
    'belfius': 'Belfius',
    'KBCPaymentButton': 'KBC/CBC-Betaalknop',
    'eps': 'EPS',
    'giropay': 'Giropay',
    'sofortueberweisung': 'SOFORT',
    'paypal': 'PayPal',
    'creditcard': 'Creditcard',
    'maestro': 'Maestro',
    'transfer': 'Overschrijving',
    'klarna': 'Klarna',
    'applepay': 'Apple Pay',
    'Riverty': 'Riverty',
    'visa': 'Visa',
    'vpay': 'V PAY',
  };
}
