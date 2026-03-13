import 'package:supabase_flutter/supabase_flutter.dart';

class CompanySettings {
  final String naam;
  final String tagline;
  final String adres;
  final String postcode;
  final String woonplaats;
  final String land;
  final String telefoon;
  final String email;
  final String kvk;
  final String btwNummer;
  final String iban;
  final String bic;
  final String accentKleur;

  const CompanySettings({
    this.naam = 'Ventoz',
    this.tagline = 'Sailmaker & Sailshop',
    this.adres = 'Dorpsstraat 111',
    this.postcode = '7948 BN',
    this.woonplaats = 'Nijeveen',
    this.land = 'The Netherlands',
    this.telefoon = '+31650282962',
    this.email = 'app@ventoz.nl',
    this.kvk = '64140814',
    this.btwNummer = 'NL855539203B01',
    this.iban = 'NL09ABNA0101868634',
    this.bic = 'ABNANL2A',
    this.accentKleur = '#455A64',
  });

  factory CompanySettings.fromJson(Map<String, dynamic> json) => CompanySettings(
    naam: json['naam'] as String? ?? 'Ventoz',
    tagline: json['tagline'] as String? ?? 'Sailmaker & Sailshop',
    adres: json['adres'] as String? ?? 'Dorpsstraat 111',
    postcode: json['postcode'] as String? ?? '7948 BN',
    woonplaats: json['woonplaats'] as String? ?? 'Nijeveen',
    land: json['land'] as String? ?? 'The Netherlands',
    telefoon: json['telefoon'] as String? ?? '+31650282962',
    email: json['email'] as String? ?? 'app@ventoz.nl',
    kvk: json['kvk'] as String? ?? '64140814',
    btwNummer: json['btw_nummer'] as String? ?? 'NL855539203B01',
    iban: json['iban'] as String? ?? 'NL09ABNA0101868634',
    bic: json['bic'] as String? ?? 'ABNANL2A',
    accentKleur: json['accent_kleur'] as String? ?? '#455A64',
  );

  Map<String, dynamic> toJson() => {
    'naam': naam,
    'tagline': tagline,
    'adres': adres,
    'postcode': postcode,
    'woonplaats': woonplaats,
    'land': land,
    'telefoon': telefoon,
    'email': email,
    'kvk': kvk,
    'btw_nummer': btwNummer,
    'iban': iban,
    'bic': bic,
    'accent_kleur': accentKleur,
  };

  String get fullAddress => '$adres · $postcode $woonplaats';
  String get footerLine => '$naam · $fullAddress';
  String get emailFooter => '$email · ${naam.toLowerCase()}.nl';
}

class CompanySettingsService {
  static final CompanySettingsService _instance = CompanySettingsService._();
  factory CompanySettingsService() => _instance;
  CompanySettingsService._();

  static const _key = 'bedrijfsgegevens';
  final _supabase = Supabase.instance.client;
  CompanySettings? _cached;

  Future<CompanySettings> getSettings() async {
    if (_cached != null) return _cached!;
    try {
      final rows = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', _key)
          .limit(1);
      if (rows.isNotEmpty && rows.first['value'] != null) {
        final val = rows.first['value'];
        if (val is Map<String, dynamic>) {
          _cached = CompanySettings.fromJson(val);
          return _cached!;
        }
      }
    } catch (_) {}
    _cached = const CompanySettings();
    return _cached!;
  }

  Future<void> saveSettings(CompanySettings settings) async {
    await _supabase.from('app_settings').upsert({
      'key': _key,
      'value': settings.toJson(),
    }, onConflict: 'key');
    _cached = settings;
  }

  void clearCache() => _cached = null;
}
