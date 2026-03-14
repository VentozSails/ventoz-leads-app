import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/pay_nl_service.dart';
import '../services/buckaroo_service.dart';
import '../services/user_service.dart';
import '../services/payment_icon_service.dart';
import '../l10n/app_localizations.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  static const _payNlImageBase = 'https://static.pay.nl';
  static const _sidebarWidth = 200.0;
  static const _wideBreakpoint = 680.0;

  final PayNlService _payNlService = PayNlService();
  final BuckarooService _buckarooService = BuckarooService();
  final PaymentIconService _iconService = PaymentIconService();
  final _userService = UserService();
  bool _loading = true;
  String? _error;
  List<_CheckoutOption> _options = [];
  Map<String, Set<String>> _resolvedCountries = {};
  String _lang = 'nl';
  late AppLocalizations _l = AppLocalizations(_lang);
  String? _filterCountry;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final lang = await _userService.getUserLanguage();

      List<_CheckoutOption> parsed = [];
      Map<String, List<String>> seq = {};

      await _iconService.loadAll();

      // Try Pay.nl (primary)
      final payNlConfig = await _payNlService.getConfig();
      final payNlConfigured = payNlConfig != null && payNlConfig.isConfigured;
      List<Map<String, dynamic>> rawOptionsJson = [];
      if (payNlConfigured) {
        try {
          final svcConfig = await _payNlService.getServiceConfig();
          if (svcConfig != null) {
            rawOptionsJson = (svcConfig['checkoutOptions'] as List? ?? [])
                .cast<Map<String, dynamic>>();
            parsed = rawOptionsJson.map((e) => _CheckoutOption.fromJson(e)).toList();

            final rawSeq = svcConfig['checkoutSequence'] as Map<String, dynamic>? ?? {};
            for (final entry in rawSeq.entries) {
              final val = entry.value;
              if (val is! Map<String, dynamic>) continue;
              final primary = (val['primary'] as List?)?.cast<String>() ?? [];
              final secondary = (val['secondary'] as List?)?.cast<String>() ?? [];
              seq[entry.key] = [...primary, ...secondary];
            }
          }
        } catch (_) {}
      }

      // Merge Buckaroo methods (always, if configured — both can be active)
      final bConfig = await _buckarooService.getConfig();
      if (bConfig != null && bConfig.isConfigured) {
        final payNlNames = parsed.map((o) => _normName(o.name)).toSet();
        for (final entry in _buckarooMethodCountries.entries) {
          final displayName = _buckarooMethodNames[entry.key] ?? entry.key;
          if (payNlNames.contains(_normName(displayName))) continue;
          parsed.add(_CheckoutOption(
            tag: 'buckaroo_${entry.key}',
            id: 0,
            name: displayName,
            translations: {},
            image: null,
            paymentMethods: [],
            source: 'buckaroo',
          ));
          payNlNames.add(_normName(displayName));
        }
      }

      final resolved = _buildResolvedCountries(parsed, seq);

      if (!mounted) return;
      setState(() {
        _lang = lang;
        _l = AppLocalizations(lang);
        _options = parsed;
        _resolvedCountries = resolved;
        _loading = false;
      });

      if (parsed.isEmpty) {
        setState(() => _error = _t('pay_niet_geconfigureerd'));
      }

      if (rawOptionsJson.isNotEmpty) {
        _iconService.seedFromPayNl(rawOptionsJson).then((_) {
          _iconService.loadAll(force: true).then((_) {
            if (mounted) setState(() {});
          });
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading payment methods: $e');
      if (mounted) setState(() { _loading = false; _error = 'Er is een fout opgetreden bij het laden.'; });
    }
  }

  static String _normName(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static const _knownCountries = <String, List<String>>{
    'iDEAL':              ['NL'],
    'Bancontact':         ['BE'],
    'EPS':                ['AT'],
    'EPS uberweisung':    ['AT'],
    'Blik':               ['PL'],
    'BLIK':               ['PL'],
    'Swish':              ['SE'],
    'MobilePAY':          ['DK', 'FI'],
    'MobilePay':          ['DK', 'FI'],
    'Vipps':              ['NO'],
    'Vipps Payment':      ['NO'],
    'Bizum':              ['ES'],
    'MB Way':             ['PT'],
    'Satispay':           ['IT'],
    'Wero':               ['DE', 'FR', 'BE', 'NL'],
    'Wero Payment':       ['DE', 'FR', 'BE', 'NL'],
    'Riverty':            ['NL', 'DE', 'AT', 'BE', 'FI'],
    'Pay By Bank':        ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES'],
    'Overboeking':        ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'FI', 'SE', 'DK', 'PL'],
    'Overboeking (SCT)':  ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'FI', 'SE', 'DK', 'PL'],
    'Klarna':             ['NL', 'DE', 'AT', 'BE', 'FI', 'SE', 'DK'],
    'SOFORT':             ['DE', 'AT', 'BE', 'NL'],
    'Sofort':             ['DE', 'AT', 'BE', 'NL'],
    'Giropay':            ['DE'],
    'MyBank':             ['IT'],
    'Przelewy24':         ['PL'],
    'Trustly':            ['SE', 'FI', 'DK', 'NO', 'EE', 'LT', 'LV', 'DE', 'AT', 'NL', 'GB'],
    'PayPal':             ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'PL', 'SE', 'DK', 'FI', 'GB'],
    'Apple Pay':          ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'PL', 'SE', 'DK', 'FI', 'GB'],
    'Google Wallet':      ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'PL', 'SE', 'DK', 'FI', 'GB'],
    'Belfius':            ['BE'],
    'KBC/CBC-Betaalknop': ['BE'],
    'KBC/CBC':            ['BE'],
    'Maestro':            ['NL', 'DE', 'BE', 'AT'],
    'Visa':               ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'PL', 'SE', 'DK', 'FI', 'GB', 'NO'],
    'V PAY':              ['NL', 'DE', 'BE', 'AT'],
    'Creditcard':         ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'PL', 'SE', 'DK', 'FI', 'GB', 'NO'],
    'MasterCard':         ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'PL', 'SE', 'DK', 'FI', 'GB', 'NO'],
    'Overschrijving':     ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT'],
  };

  static const _buckarooMethodCountries = <String, List<String>>{
    'ideal': ['NL'],
    'bancontactmrcash': ['BE'],
    'belfius': ['BE'],
    'KBCPaymentButton': ['BE'],
    'eps': ['AT'],
    'giropay': ['DE'],
    'sofortueberweisung': ['DE', 'AT', 'BE', 'NL'],
    'paypal': ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'PL', 'SE', 'DK', 'FI', 'GB'],
    'creditcard': ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'PL', 'SE', 'DK', 'FI', 'GB', 'NO'],
    'maestro': ['NL', 'DE', 'BE', 'AT'],
    'transfer': ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT'],
    'klarna': ['NL', 'DE', 'AT', 'BE', 'FI', 'SE', 'DK'],
    'applepay': ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'PL', 'SE', 'DK', 'FI', 'GB'],
    'Riverty': ['NL', 'DE', 'AT', 'BE', 'FI'],
    'visa': ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'PL', 'SE', 'DK', 'FI', 'GB', 'NO'],
    'vpay': ['NL', 'DE', 'BE', 'AT'],
    'mastercard': ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'PL', 'SE', 'DK', 'FI', 'GB', 'NO'],
  };

  static const _buckarooMethodNames = <String, String>{
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
    'mastercard': 'MasterCard',
  };

  static Map<String, Set<String>> _buildResolvedCountries(
      List<_CheckoutOption> options, Map<String, List<String>> sequence) {
    final result = <String, Set<String>>{};

    for (final opt in options) {
      final countries = <String>{};
      for (final pm in opt.paymentMethods) {
        countries.addAll(pm.targetCountries.map((c) => c.toUpperCase()));
      }
      for (final pm in opt.paymentMethods) {
        final known = _knownCountries[pm.name];
        if (known != null) countries.addAll(known);
      }
      final optKnown = _knownCountries[opt.name];
      if (optKnown != null) countries.addAll(optKnown);

      result[opt.tag] = countries;
    }

    for (final entry in sequence.entries) {
      final countryCode = entry.key.toUpperCase();
      if (countryCode == 'DEFAULT') continue;
      for (final tag in entry.value) {
        result.putIfAbsent(tag, () => <String>{});
        result[tag]!.add(countryCode);
      }
    }

    return result;
  }

  String _t(String key) => _l.t(key);

  List<String> get _sortedCountries {
    final countries = <String>{};
    for (final c in _resolvedCountries.values) {
      countries.addAll(c);
    }
    final list = countries.toList();
    list.sort((a, b) => _t('country_$a').compareTo(_t('country_$b')));
    return list;
  }

  Set<String> _countriesForOption(_CheckoutOption opt) =>
      _resolvedCountries[opt.tag] ?? <String>{};

  int _methodCountForCountry(String? country) {
    if (country == null) return _options.length;
    return _options.where((opt) {
      final c = _countriesForOption(opt);
      return c.isEmpty || c.contains(country);
    }).length;
  }

  List<_CheckoutOption> get _filteredOptions {
    if (_filterCountry == null) return _options;
    return _options.where((opt) {
      final countries = _countriesForOption(opt);
      return countries.isEmpty || countries.contains(_filterCountry);
    }).toList();
  }

  String _localizedName(String defaultName, Map<String, String> translations) {
    final localeKey = _localeKey;
    if (translations.containsKey(localeKey)) return translations[localeKey]!;
    final langOnly = localeKey.split('_').first;
    for (final key in translations.keys) {
      if (key.startsWith(langOnly)) return translations[key]!;
    }
    if (translations.containsKey('nl_NL')) return translations['nl_NL']!;
    if (translations.containsKey('en_GB')) return translations['en_GB']!;
    return defaultName;
  }

  String get _localeKey {
    switch (_lang) {
      case 'nl': return 'nl_NL';
      case 'de': return 'de_DE';
      case 'fr': return 'fr_FR';
      case 'en': return 'en_GB';
      case 'es': return 'es_ES';
      case 'it': return 'it_IT';
      default: return 'en_GB';
    }
  }

  void _selectCountry(String? code) => setState(() => _filterCountry = code);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/ventoz_logo.png', width: 28, height: 28),
          ),
          const SizedBox(width: 10),
          Text(_t('betaalmethoden')),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: _t('vernieuwen'), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: _buildErrorState())
              : LayoutBuilder(builder: (ctx, constraints) {
                  final wide = constraints.maxWidth >= _wideBreakpoint;
                  return wide ? _buildWideLayout() : _buildNarrowLayout();
                }),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        _buildSidebar(),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: _buildRightPane()),
      ],
    );
  }

  Widget _buildSidebar() {
    final countries = _sortedCountries;
    return Container(
      width: _sidebarWidth,
      color: const Color(0xFFF8FAFB),
      child: Column(
        children: [
          _buildSidebarHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _buildSidebarItem(null, _t('alle_landen'), null, _options.length),
                ...countries.map((c) =>
                    _buildSidebarItem(c, _t('country_$c'), _countryFlag(c), _methodCountForCountry(c))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF37474F), Color(0xFF455A64)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.public, color: Colors.white70, size: 18),
            SizedBox(width: 6),
            Text('Landen', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          ]),
          const SizedBox(height: 2),
          Text(
            '${_sortedCountries.length} ${_t('landen_beschikbaar')}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(String? code, String label, String? flag, int count) {
    final selected = _filterCountry == code;
    return Material(
      color: selected ? const Color(0xFF00897B).withAlpha(25) : Colors.transparent,
      child: InkWell(
        onTap: () => _selectCountry(code),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? const Color(0xFF00897B) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              if (flag != null)
                Container(
                  width: 32, height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 3, offset: const Offset(0, 1))],
                  ),
                  child: Text(flag, style: const TextStyle(fontSize: 17)),
                )
              else
                Container(
                  width: 32, height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(colors: [Color(0xFF00897B), Color(0xFF4DB6AC)]),
                  ),
                  child: const Icon(Icons.language, color: Colors.white, size: 15),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? const Color(0xFF00695C) : const Color(0xFF455A64),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF00897B) : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? Colors.white : const Color(0xFF757575)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        _buildHorizontalCountryStrip(),
        Expanded(child: _buildRightPane()),
      ],
    );
  }

  Widget _buildHorizontalCountryStrip() {
    final countries = _sortedCountries;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF37474F), Color(0xFF546E7A)]),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildCountryChip(null),
            ...countries.map((c) => _buildCountryChip(c)),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryChip(String? code) {
    final selected = _filterCountry == code;
    final label = code != null ? _t('country_$code') : _t('alle');
    final flag = code != null ? _countryFlag(code) : null;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected ? const Color(0xFF00897B) : Colors.white12,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _selectCountry(code),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (flag != null) ...[
                  Text(flag, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                ] else ...[
                  Icon(Icons.language, size: 14, color: selected ? Colors.white : Colors.white70),
                  const SizedBox(width: 4),
                ],
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: selected ? Colors.white : Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightPane() {
    final opts = _filteredOptions;
    final countryLabel = _filterCountry != null
        ? '${_countryFlag(_filterCountry!)} ${_t('country_$_filterCountry')}'
        : _t('alle_landen');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildContentHeader(countryLabel, opts.length),
        Expanded(
          child: opts.isEmpty
              ? Center(child: Text(_t('geen_betaalmethoden'), style: const TextStyle(color: Color(0xFF9E9E9E))))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: opts.length,
                  itemBuilder: (_, i) => _buildMethodCard(opts[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildContentHeader(String countryLabel, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.verified_user, size: 16, color: Color(0xFF00897B)),
                  const SizedBox(width: 6),
                  Text(_t('betaalmethoden_subtitel'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF263238))),
                ]),
                const SizedBox(height: 2),
                Text(
                  _t('betaalmethoden_beschrijving'),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF78909C)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count ${_t('methoden')}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF455A64)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── METHOD CARDS ─────────────────────────────────────────────────

  Widget _buildMethodCard(_CheckoutOption opt) {
    final name = _localizedName(opt.name, opt.translations);
    final hasSubMethods = opt.paymentMethods.length > 1 ||
        (opt.paymentMethods.length == 1 && opt.paymentMethods.first.name != opt.name);
    final resolvedCountries = _countriesForOption(opt);
    final sortedCountries = resolvedCountries.toList()..sort();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE8E8E8)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: _buildMethodIcon(opt.image, methodName: opt.name),
        title: Row(children: [
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          if (opt.source == 'buckaroo')
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(4)),
              child: const Text('B', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF1565C0))),
            ),
        ]),
        subtitle: _buildFlagRow(sortedCountries),
        children: [
          if (hasSubMethods) ...opt.paymentMethods.map(_buildSubMethodRow),
          if (opt.paymentMethods.isNotEmpty) _buildAmountRange(opt.paymentMethods),
          if (sortedCountries.isNotEmpty) _buildCountryChips(sortedCountries),
        ],
      ),
    );
  }

  Widget _buildFlagRow(List<String> countries) {
    if (countries.isEmpty) {
      return Row(
        children: [
          const Icon(Icons.language, size: 12, color: Color(0xFF9E9E9E)),
          const SizedBox(width: 4),
          Text(_t('alle_landen'), style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E))),
        ],
      );
    }
    return Row(
      children: [
        ...countries.take(8).map((c) => Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Text(_countryFlag(c), style: const TextStyle(fontSize: 13)),
        )),
        if (countries.length > 8)
          Text(' +${countries.length - 8}', style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
      ],
    );
  }

  Widget _buildMethodIcon(String? imagePath, {double size = 38, String? methodName}) {
    final innerSize = size - 4;

    if (methodName != null) {
      final Uint8List? dbPng = _iconService.getPngSync(methodName);
      if (dbPng != null && dbPng.isNotEmpty) {
        return _iconContainer(size, child: Image.memory(
          dbPng, width: innerSize, height: innerSize, fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _fallbackIcon(methodName, size),
        ));
      }

      final String? dbSvg = _iconService.getSvgSync(methodName);
      if (dbSvg != null && dbSvg.isNotEmpty) {
        return _iconContainer(size, child: SvgPicture.string(
          dbSvg, width: innerSize, height: innerSize, fit: BoxFit.contain,
          placeholderBuilder: (_) => _fallbackIcon(methodName, size),
        ));
      }
    }

    if (imagePath != null && imagePath.isNotEmpty) {
      final url = imagePath.startsWith('http') ? imagePath : '$_payNlImageBase$imagePath';

      if (!url.toLowerCase().endsWith('.svg')) {
        return _iconContainer(size, child: Image.network(
          url, width: innerSize, height: innerSize, fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _fallbackIcon(methodName, size),
        ));
      }
    }

    return _iconContainer(size, child: _fallbackIcon(methodName, size));
  }

  Widget _fallbackIcon(String? methodName, double size) {
    if (methodName == null) return Icon(Icons.payment, color: const Color(0xFF78909C), size: size * 0.55);
    final lc = methodName.toLowerCase();
    IconData icon;
    Color color;
    Color? bgColor;

    if (lc.contains('ideal')) {
      icon = Icons.account_balance; color = Colors.white; bgColor = const Color(0xFFCC0066);
    } else if (lc.contains('bancontact')) {
      icon = Icons.account_balance_wallet; color = Colors.white; bgColor = const Color(0xFF005498);
    } else if (lc.contains('credit') || lc.contains('debit') || lc.contains('mastercard')) {
      icon = Icons.credit_card; color = Colors.white; bgColor = const Color(0xFFEB001B);
    } else if (lc.contains('visa') || lc.contains('vpay') || lc == 'v pay') {
      icon = Icons.credit_card; color = Colors.white; bgColor = const Color(0xFF1A1F71);
    } else if (lc.contains('paypal')) {
      icon = Icons.account_balance_wallet; color = Colors.white; bgColor = const Color(0xFF003087);
    } else if (lc.contains('apple')) {
      icon = Icons.phone_iphone; color = Colors.white; bgColor = const Color(0xFF333333);
    } else if (lc.contains('google')) {
      icon = Icons.phone_android; color = Colors.white; bgColor = const Color(0xFF4285F4);
    } else if (lc.contains('klarna')) {
      icon = Icons.schedule; color = Colors.white; bgColor = const Color(0xFFFFB3C7);
    } else if (lc.contains('riverty')) {
      icon = Icons.schedule; color = Colors.white; bgColor = const Color(0xFF2B7A4B);
    } else if (lc.contains('sofort')) {
      icon = Icons.swap_horiz; color = Colors.white; bgColor = const Color(0xFFEF6C00);
    } else if (lc.contains('giropay')) {
      icon = Icons.swap_horiz; color = Colors.white; bgColor = const Color(0xFF003A7D);
    } else if (lc.contains('belfius')) {
      icon = Icons.account_balance; color = Colors.white; bgColor = const Color(0xFF6C1D45);
    } else if (lc.contains('kbc') || lc.contains('cbc')) {
      icon = Icons.account_balance; color = Colors.white; bgColor = const Color(0xFF003D6D);
    } else if (lc.contains('maestro')) {
      icon = Icons.credit_card; color = Colors.white; bgColor = const Color(0xFF0099DF);
    } else if (lc.contains('wero')) {
      icon = Icons.euro; color = Colors.white; bgColor = const Color(0xFF003D2E);
    } else if (lc.contains('eps')) {
      icon = Icons.account_balance; color = Colors.white; bgColor = const Color(0xFFC8202F);
    } else if (lc.contains('blik')) {
      icon = Icons.phone_android; color = Colors.white; bgColor = const Color(0xFF000000);
    } else if (lc.contains('swish')) {
      icon = Icons.phone_android; color = Colors.white; bgColor = const Color(0xFF00A042);
    } else if (lc.contains('mobilepay')) {
      icon = Icons.phone_android; color = Colors.white; bgColor = const Color(0xFF5A78FF);
    } else if (lc.contains('vipps')) {
      icon = Icons.phone_android; color = Colors.white; bgColor = const Color(0xFFFF5B24);
    } else if (lc.contains('bizum')) {
      icon = Icons.phone_android; color = Colors.white; bgColor = const Color(0xFF05C3DD);
    } else if (lc.contains('mb way')) {
      icon = Icons.phone_android; color = Colors.white; bgColor = const Color(0xFFE40520);
    } else if (lc.contains('satispay')) {
      icon = Icons.phone_android; color = Colors.white; bgColor = const Color(0xFFE53935);
    } else if (lc.contains('trustly')) {
      icon = Icons.account_balance; color = Colors.white; bgColor = const Color(0xFF0EBB52);
    } else if (lc.contains('przelewy') || lc.contains('p24')) {
      icon = Icons.account_balance; color = Colors.white; bgColor = const Color(0xFFD42127);
    } else if (lc.contains('mybank')) {
      icon = Icons.account_balance; color = Colors.white; bgColor = const Color(0xFF1A3C6E);
    } else if (lc.contains('pay by bank')) {
      icon = Icons.account_balance; color = Colors.white; bgColor = const Color(0xFF00897B);
    } else if (lc.contains('overboek') || lc.contains('transfer') || lc.contains('overschrijving')) {
      icon = Icons.send; color = Colors.white; bgColor = const Color(0xFF455A64);
    } else {
      icon = Icons.payment; color = Colors.white; bgColor = const Color(0xFF78909C);
    }

    return Container(
      width: size * 0.75, height: size * 0.75,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: size * 0.45),
    );
  }

  Widget _iconContainer(double size, {required Widget child}) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
      ),
      padding: const EdgeInsets.all(2),
      child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Center(child: child)),
    );
  }


  Widget _buildSubMethodRow(_PaymentMethod pm) {
    final name = _localizedName(pm.name, pm.nameTranslations);
    final desc = _localizedName(pm.description, pm.descTranslations);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMethodIcon(pm.image, methodName: pm.name),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                if (desc.isNotEmpty && desc != name)
                  Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF78909C)), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (pm.targetCountries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(
                      spacing: 2,
                      children: pm.targetCountries.map((c) => c.toUpperCase()).toSet().map((c) =>
                        Text(_countryFlag(c), style: const TextStyle(fontSize: 11))).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRange(List<_PaymentMethod> methods) {
    int minVal = 0, maxVal = 0;
    for (final pm in methods) {
      if (pm.minAmount > 0 && (minVal == 0 || pm.minAmount < minVal)) minVal = pm.minAmount;
      if (pm.maxAmount > maxVal) maxVal = pm.maxAmount;
    }
    if (minVal == 0 && maxVal == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        const Icon(Icons.euro, size: 13, color: Color(0xFF90A4AE)),
        const SizedBox(width: 4),
        Text(
          '${_t('bedrag_bereik')}: €${(minVal / 100).toStringAsFixed(2)} – €${(maxVal / 100).toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF90A4AE)),
        ),
      ]),
    );
  }

  Widget _buildCountryChips(List<String> countries) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 5, runSpacing: 4,
        children: countries.map((c) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_countryFlag(c), style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(_t('country_$c'), style: const TextStyle(fontSize: 11, color: Color(0xFF546E7A))),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.payment, size: 64, color: Color(0xFFBDBDBD)),
        const SizedBox(height: 16),
        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF757575))),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(_t('opnieuw_proberen')),
          onPressed: _load,
        ),
      ],
    );
  }

  static String _countryFlag(String countryCode) {
    if (countryCode.length != 2) return countryCode;
    final cc = countryCode.toUpperCase();
    return String.fromCharCode(cc.codeUnitAt(0) + 0x1F1A5) +
           String.fromCharCode(cc.codeUnitAt(1) + 0x1F1A5);
  }
}

// ─── DATA MODELS ──────────────────────────────────────────────────

class _CheckoutOption {
  final String tag;
  final int id;
  final String name;
  final Map<String, String> translations;
  final String? image;
  final List<_PaymentMethod> paymentMethods;
  final String source; // 'pay_nl' or 'buckaroo'

  const _CheckoutOption({
    required this.tag, required this.id, required this.name,
    required this.translations, this.image, required this.paymentMethods,
    this.source = 'pay_nl',
  });

  factory _CheckoutOption.fromJson(Map<String, dynamic> json) {
    final transRaw = json['translations']?['name'] as Map<String, dynamic>? ?? {};
    final pms = (json['paymentMethods'] as List? ?? [])
        .map((e) => _PaymentMethod.fromJson(e as Map<String, dynamic>))
        .toList();
    return _CheckoutOption(
      tag: json['tag'] as String? ?? '',
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      translations: transRaw.map((k, v) => MapEntry(k, v.toString())),
      image: json['image'] as String?,
      paymentMethods: pms,
    );
  }
}

class _PaymentMethod {
  final int id;
  final String name;
  final String description;
  final Map<String, String> nameTranslations;
  final Map<String, String> descTranslations;
  final String? image;
  final List<String> targetCountries;
  final int minAmount;
  final int maxAmount;

  const _PaymentMethod({
    required this.id, required this.name, required this.description,
    required this.nameTranslations, required this.descTranslations,
    this.image, required this.targetCountries,
    required this.minAmount, required this.maxAmount,
  });

  factory _PaymentMethod.fromJson(Map<String, dynamic> json) {
    final nameT = json['translations']?['name'] as Map<String, dynamic>? ?? {};
    final descT = json['translations']?['description'] as Map<String, dynamic>? ?? {};
    final tc = json['targetCountries'] as List? ?? [];
    return _PaymentMethod(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      nameTranslations: nameT.map((k, v) => MapEntry(k, v.toString())),
      descTranslations: descT.map((k, v) => MapEntry(k, v.toString())),
      image: json['image'] as String?,
      targetCountries: tc.map((e) => e.toString()).toList(),
      minAmount: json['minAmount'] as int? ?? 0,
      maxAmount: json['maxAmount'] as int? ?? 0,
    );
  }
}
