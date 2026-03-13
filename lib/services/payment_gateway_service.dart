import 'package:flutter/foundation.dart';
import 'pay_nl_service.dart';
import 'buckaroo_service.dart';
import 'order_service.dart';

class PaymentMethod {
  final String id;
  final String name;
  final String? imageUrl;
  final String gateway; // 'pay_nl' or 'buckaroo'
  final int? payNlOptionId;
  final String? buckarooServiceName;

  const PaymentMethod({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.gateway,
    this.payNlOptionId,
    this.buckarooServiceName,
  });
}

class PaymentResult {
  final String transactionId;
  final String paymentUrl;

  const PaymentResult({
    required this.transactionId,
    required this.paymentUrl,
  });
}

class PaymentGatewayService {
  final PayNlService _payNlService = PayNlService();
  final BuckarooService _buckarooService = BuckarooService();

  static const _knownCountries = <String, List<String>>{
    'iDEAL': ['NL'],
    'Bancontact': ['BE'],
    'EPS': ['AT'],
    'Blik': ['PL'],
    'BLIK': ['PL'],
    'Swish': ['SE'],
    'MobilePay': ['DK', 'FI'],
    'MobilePAY': ['DK', 'FI'],
    'Vipps': ['NO'],
    'Bizum': ['ES'],
    'MB Way': ['PT'],
    'Satispay': ['IT'],
    'Wero': ['DE', 'FR', 'BE', 'NL'],
    'Giropay': ['DE'],
    'SOFORT': ['DE', 'AT', 'BE', 'NL'],
    'Sofort': ['DE', 'AT', 'BE', 'NL'],
    'MyBank': ['IT'],
    'Przelewy24': ['PL'],
    'Trustly': ['SE', 'FI', 'DK', 'NO', 'EE', 'LT', 'LV', 'DE', 'AT', 'NL', 'GB'],
    'PayPal': ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'PL', 'SE', 'DK', 'FI', 'GB'],
    'Apple Pay': ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'PL', 'SE', 'DK', 'FI', 'GB'],
    'Google Wallet': ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'PL', 'SE', 'DK', 'FI', 'GB'],
    'Klarna': ['NL', 'DE', 'AT', 'BE', 'FI', 'SE', 'DK'],
    'Riverty': ['NL', 'DE', 'AT', 'BE', 'FI'],
    'Creditcard': ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'PL', 'SE', 'DK', 'FI', 'GB', 'NO'],
    'Credit- / Debitcard': ['NL', 'DE', 'BE', 'AT', 'FR', 'IT', 'ES', 'PT', 'PL', 'SE', 'DK', 'FI', 'GB', 'NO'],
    'Belfius': ['BE'],
    'KBC/CBC': ['BE'],
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
  };

  /// Normalized name for deduplication: lowercase, stripped of spaces/punctuation.
  static String _normName(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Returns available payment methods for the customer's country.
  ///
  /// Only gateways in the active set are queried. Both can be active
  /// simultaneously. Pay.nl is primary when both are active: Buckaroo
  /// only adds methods not already covered by Pay.nl.
  Future<List<PaymentMethod>> getMethodsForCountry(String countryCode) async {
    final cc = countryCode.toUpperCase();
    final active = await _buckarooService.getActiveGateways();

    final methods = <PaymentMethod>[];
    final seenNames = <String>{};

    if (active.contains('pay_nl')) {
      final payNlConfig = await _payNlService.getConfig();
      if (payNlConfig != null && payNlConfig.isConfigured) {
        final payNlMethods = await _getPayNlMethods(cc);
        for (final m in payNlMethods) {
          seenNames.add(_normName(m.name));
          methods.add(m);
        }
      }
    }

    if (active.contains('buckaroo')) {
      final buckarooConfig = await _buckarooService.getConfig();
      if (buckarooConfig != null && buckarooConfig.isConfigured) {
        final buckarooMethods = _getBuckarooMethods(cc);
        for (final bm in buckarooMethods) {
          if (!seenNames.contains(_normName(bm.name))) {
            methods.add(bm);
            seenNames.add(_normName(bm.name));
          }
        }
      }
    }

    return methods;
  }

  Future<List<PaymentMethod>> _getPayNlMethods(String countryCode) async {
    try {
      final svcConfig = await _payNlService.getServiceConfig();
      if (svcConfig == null) return [];

      final rawOptions = svcConfig['checkoutOptions'] as List? ?? [];
      final rawSeq = svcConfig['checkoutSequence'] as Map<String, dynamic>? ?? {};

      final countrySeqTags = <String>{};
      final ccLower = countryCode.toLowerCase();
      for (final entry in rawSeq.entries) {
        if (entry.key.toUpperCase() == countryCode || entry.key.toLowerCase() == ccLower) {
          final val = entry.value;
          if (val is Map<String, dynamic>) {
            final primary = (val['primary'] as List?)?.cast<String>() ?? [];
            final secondary = (val['secondary'] as List?)?.cast<String>() ?? [];
            countrySeqTags.addAll([...primary, ...secondary]);
          }
        }
      }

      final methods = <PaymentMethod>[];
      final seenNames = <String>{};

      for (final raw in rawOptions) {
        if (raw is! Map<String, dynamic>) continue;
        final tag = raw['tag'] as String? ?? '';
        final name = raw['name'] as String? ?? '';
        final id = raw['id'] as int? ?? 0;
        final image = raw['image'] as String?;
        final pms = raw['paymentMethods'] as List? ?? [];

        final countries = <String>{};
        for (final pm in pms) {
          if (pm is Map<String, dynamic>) {
            final tc = pm['targetCountries'] as List? ?? [];
            countries.addAll(tc.map((c) => c.toString().toUpperCase()));
          }
        }
        final known = _knownCountries[name];
        if (known != null) countries.addAll(known);
        for (final pm in pms) {
          if (pm is Map<String, dynamic>) {
            final pmName = pm['name'] as String? ?? '';
            final pmKnown = _knownCountries[pmName];
            if (pmKnown != null) countries.addAll(pmKnown);
          }
        }
        if (countrySeqTags.contains(tag)) countries.add(countryCode);

        final matchesCountry = countries.isEmpty || countries.contains(countryCode);
        if (!matchesCountry) continue;

        final norm = _normName(name);
        if (seenNames.contains(norm)) continue;
        seenNames.add(norm);

        String? imageUrl;
        if (image != null && image.isNotEmpty) {
          imageUrl = image.startsWith('http') ? image : 'https://static.pay.nl$image';
        }

        methods.add(PaymentMethod(
          id: 'paynl_${tag}_$id',
          name: name,
          imageUrl: imageUrl,
          gateway: 'pay_nl',
          payNlOptionId: id,
        ));
      }

      return methods;
    } catch (e) {
      if (kDebugMode) debugPrint('PaymentGatewayService._getPayNlMethods error: $e');
      return [];
    }
  }

  List<PaymentMethod> _getBuckarooMethods(String countryCode) {
    final methods = <PaymentMethod>[];
    for (final entry in _buckarooMethodCountries.entries) {
      if (entry.value.contains(countryCode)) {
        methods.add(PaymentMethod(
          id: 'buckaroo_${entry.key}',
          name: _buckarooMethodNames[entry.key] ?? entry.key,
          gateway: 'buckaroo',
          buckarooServiceName: entry.key,
        ));
      }
    }
    return methods;
  }

  Future<PaymentResult> pay({
    required Order order,
    required PaymentMethod method,
    required String returnUrl,
  }) async {
    if (method.gateway == 'pay_nl') {
      final transaction = await _payNlService.createTransaction(
        order: order,
        returnUrl: returnUrl,
        paymentOptionId: method.payNlOptionId,
      );
      return PaymentResult(
        transactionId: transaction.transactionId,
        paymentUrl: transaction.paymentUrl,
      );
    } else if (method.gateway == 'buckaroo') {
      final transaction = await _buckarooService.createTransaction(
        order: order,
        returnUrl: returnUrl,
        serviceName: method.buckarooServiceName,
      );
      return PaymentResult(
        transactionId: transaction.transactionKey,
        paymentUrl: transaction.paymentUrl,
      );
    }
    throw Exception('Onbekende betaalgateway: ${method.gateway}');
  }
}
