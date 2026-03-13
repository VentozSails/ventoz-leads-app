import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';

class ShippingRate {
  final String countryCode;
  final String countryName;
  final double cost;
  final String deliveryTime;

  const ShippingRate({
    required this.countryCode,
    required this.countryName,
    required this.cost,
    required this.deliveryTime,
  });

  factory ShippingRate.fromJson(Map<String, dynamic> json) => ShippingRate(
    countryCode: json['country_code'] as String? ?? '',
    countryName: json['country_name'] as String? ?? '',
    cost: (json['cost'] as num?)?.toDouble() ?? 0,
    deliveryTime: json['delivery_time'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'country_code': countryCode,
    'country_name': countryName,
    'cost': cost,
    'delivery_time': deliveryTime,
  };

  String get costFormatted => cost == 0 ? 'Gratis' : '€ ${cost.toStringAsFixed(2).replaceAll('.', ',')}';

  String localizedName(String lang) {
    final loc = AppLocalizations(lang);
    final key = 'country_$countryCode';
    final translated = loc.t(key);
    return translated == key ? countryName : translated;
  }

  String costFormattedLocalized(String lang) {
    if (cost == 0) return AppLocalizations(lang).t('gratis');
    return '€ ${cost.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}

class ShippingService {
  static const _settingsKey = 'shipping_rates';

  /// Scraped from ventoz.nl/shipment-and-delivery/ (March 2026).
  /// Country codes mapped to the rates on the website.
  static const defaultRates = <String, ShippingRate>{
    'NL': ShippingRate(countryCode: 'NL', countryName: 'Nederland', cost: 0, deliveryTime: '1-2 dagen'),
    'BE': ShippingRate(countryCode: 'BE', countryName: 'België', cost: 11.00, deliveryTime: '2-3 dagen'),
    'BG': ShippingRate(countryCode: 'BG', countryName: 'Bulgarije', cost: 32.00, deliveryTime: '5-8 dagen'),
    'CZ': ShippingRate(countryCode: 'CZ', countryName: 'Tsjechië', cost: 20.50, deliveryTime: '5-8 dagen'),
    'DK': ShippingRate(countryCode: 'DK', countryName: 'Denemarken', cost: 18.15, deliveryTime: '3-6 dagen'),
    'DE': ShippingRate(countryCode: 'DE', countryName: 'Duitsland', cost: 12.50, deliveryTime: '3-5 dagen'),
    'EE': ShippingRate(countryCode: 'EE', countryName: 'Estland', cost: 32.50, deliveryTime: '4-6 dagen'),
    'ES': ShippingRate(countryCode: 'ES', countryName: 'Spanje', cost: 19.50, deliveryTime: '4-7 dagen'),
    'GR': ShippingRate(countryCode: 'GR', countryName: 'Griekenland', cost: 32.00, deliveryTime: '5-8 dagen'),
    'CY': ShippingRate(countryCode: 'CY', countryName: 'Cyprus', cost: 32.00, deliveryTime: '5-8 dagen'),
    'FR': ShippingRate(countryCode: 'FR', countryName: 'Frankrijk', cost: 17.75, deliveryTime: '3-5 dagen'),
    'AT': ShippingRate(countryCode: 'AT', countryName: 'Oostenrijk', cost: 17.75, deliveryTime: '4-6 dagen'),
    'IE': ShippingRate(countryCode: 'IE', countryName: 'Ierland', cost: 23.50, deliveryTime: '3-5 dagen'),
    'IT': ShippingRate(countryCode: 'IT', countryName: 'Italië', cost: 19.50, deliveryTime: '4-7 dagen'),
    'LV': ShippingRate(countryCode: 'LV', countryName: 'Letland', cost: 32.00, deliveryTime: '4-7 dagen'),
    'LT': ShippingRate(countryCode: 'LT', countryName: 'Litouwen', cost: 32.00, deliveryTime: '4-7 dagen'),
    'LU': ShippingRate(countryCode: 'LU', countryName: 'Luxemburg', cost: 15.00, deliveryTime: '3-5 dagen'),
    'HU': ShippingRate(countryCode: 'HU', countryName: 'Hongarije', cost: 25.00, deliveryTime: '5-8 dagen'),
    'PL': ShippingRate(countryCode: 'PL', countryName: 'Polen', cost: 25.00, deliveryTime: '5-8 dagen'),
    'PT': ShippingRate(countryCode: 'PT', countryName: 'Portugal', cost: 21.50, deliveryTime: '5-8 dagen'),
    'RO': ShippingRate(countryCode: 'RO', countryName: 'Roemenië', cost: 32.00, deliveryTime: '5-8 dagen'),
    'SI': ShippingRate(countryCode: 'SI', countryName: 'Slovenië', cost: 25.00, deliveryTime: '5-8 dagen'),
    'SK': ShippingRate(countryCode: 'SK', countryName: 'Slowakije', cost: 20.50, deliveryTime: '5-8 dagen'),
    'FI': ShippingRate(countryCode: 'FI', countryName: 'Finland', cost: 25.00, deliveryTime: '5-8 dagen'),
    'SE': ShippingRate(countryCode: 'SE', countryName: 'Zweden', cost: 25.00, deliveryTime: '4-6 dagen'),
    'MT': ShippingRate(countryCode: 'MT', countryName: 'Malta', cost: 32.00, deliveryTime: '5-8 dagen'),
    'CH': ShippingRate(countryCode: 'CH', countryName: 'Zwitserland', cost: 32.00, deliveryTime: '5-8 dagen'),
    'GB': ShippingRate(countryCode: 'GB', countryName: 'Verenigd Koninkrijk', cost: 25.00, deliveryTime: '8-12 dagen'),
    'HR': ShippingRate(countryCode: 'HR', countryName: 'Kroatië', cost: 25.00, deliveryTime: '5-8 dagen'),
  };

  static ShippingRate getRate(String countryCode) {
    return defaultRates[countryCode.toUpperCase()] ??
        const ShippingRate(countryCode: '??', countryName: 'Overig', cost: 32.00, deliveryTime: '5-10 dagen');
  }

  static List<ShippingRate> get allRates {
    final list = defaultRates.values.toList();
    list.sort((a, b) => a.countryName.compareTo(b.countryName));
    return list;
  }

  static List<ShippingRate> allRatesLocalized(String lang) {
    final list = defaultRates.values.toList();
    list.sort((a, b) => a.localizedName(lang).compareTo(b.localizedName(lang)));
    return list;
  }

  /// Persist rates to Supabase (for admin overrides or scraper updates).
  static Future<void> saveRates(Map<String, ShippingRate> rates) async {
    final data = rates.map((k, v) => MapEntry(k, v.toJson()));
    await Supabase.instance.client.from('app_settings').upsert({
      'key': _settingsKey,
      'value': data,
    }, onConflict: 'key');
  }

  /// Fetch custom rates from Supabase. Falls back to defaults.
  static Future<Map<String, ShippingRate>> fetchRates() async {
    try {
      final List<dynamic> rows = await Supabase.instance.client
          .from('app_settings').select('value').eq('key', _settingsKey);
      if (rows.isNotEmpty) {
        final raw = rows.first['value'] as Map<String, dynamic>?;
        if (raw != null && raw.isNotEmpty) {
          return raw.map((k, v) => MapEntry(k, ShippingRate.fromJson(v as Map<String, dynamic>)));
        }
      }
    } catch (_) {}
    return defaultRates;
  }
}
