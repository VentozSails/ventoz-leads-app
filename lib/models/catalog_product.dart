import '../utils/image_url_helper.dart';

class CatalogProduct {
  final int? id;
  final String naam;
  final String? artikelnummer;
  final String? categorie;
  final double? prijs;
  final Map<String, double>? staffelprijzen;
  final String? beschrijving;
  final String? afbeeldingUrl;
  final String? webshopUrl;
  final String? luff;
  final String? foot;
  final String? sailArea;

  /// Dynamic specs table parsed from the product page.
  /// Keys are the header names (e.g. "Voorlijk (cm)", "Achterlijk (cm)").
  final Map<String, String>? specsTabel;

  final String? materiaal;
  final String? inclusief;
  final bool inStock;
  final DateTime? laatstBijgewerkt;
  final bool geblokkeerd;
  final String? geblokkeerdDoor;
  final DateTime? geblokkeerdOp;
  final List<String> extraAfbeeldingen;

  final double? gewicht;
  final String? eanCode;

  // SEO fields scraped from ventoz.nl
  final String? seoTitle;
  final String? seoDescription;
  final String? seoKeywords;
  final String? canonicalUrl;
  final String? ogImage;

  final String? naamOverride;
  final String? beschrijvingOverride;
  final double? prijsOverride;
  final String? afbeeldingUrlOverride;

  /// Translated names/descriptions keyed by language code.
  /// e.g. {'de': 'Optimist Segel', 'en': 'Optimist Sail', ...}
  final Map<String, String> translatedNames;
  final Map<String, String> translatedDescriptions;

  /// Translated spec values keyed by language, then spec field.
  /// e.g. {'de': {'materiaal': 'starkes Dacron...', 'inclusief': '...'}, ...}
  final Map<String, Map<String, String>> translatedSpecs;

  static const _allLangs = [
    'ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi',
    'fr', 'ga', 'hr', 'hu', 'it', 'lt', 'lv', 'mt', 'pl', 'pt',
    'ro', 'sk', 'sl', 'sv', 'tr', 'zh',
  ];

  const CatalogProduct({
    this.id,
    required this.naam,
    this.artikelnummer,
    this.categorie,
    this.prijs,
    this.staffelprijzen,
    this.beschrijving,
    this.afbeeldingUrl,
    this.webshopUrl,
    this.luff,
    this.foot,
    this.sailArea,
    this.specsTabel,
    this.materiaal,
    this.inclusief,
    this.inStock = true,
    this.laatstBijgewerkt,
    this.geblokkeerd = false,
    this.geblokkeerdDoor,
    this.geblokkeerdOp,
    this.extraAfbeeldingen = const [],
    this.gewicht,
    this.eanCode,
    this.seoTitle,
    this.seoDescription,
    this.seoKeywords,
    this.canonicalUrl,
    this.ogImage,
    this.naamOverride,
    this.beschrijvingOverride,
    this.prijsOverride,
    this.afbeeldingUrlOverride,
    this.translatedNames = const {},
    this.translatedDescriptions = const {},
    this.translatedSpecs = const {},
  });

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    Map<String, double>? staffel;
    if (json['staffelprijzen'] != null) {
      final raw = json['staffelprijzen'] as Map<String, dynamic>;
      staffel = raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }

    final names = <String, String>{};
    final descs = <String, String>{};
    for (final lang in _allLangs) {
      final n = json['naam_$lang'] as String?;
      if (n != null && n.isNotEmpty) names[lang] = n;
      final d = json['beschrijving_$lang'] as String?;
      if (d != null && d.isNotEmpty) descs[lang] = d;
    }

    final specs = <String, Map<String, String>>{};
    final rawSpecs = json['translated_specs'];
    if (rawSpecs is Map) {
      for (final entry in rawSpecs.entries) {
        final lang = entry.key as String;
        if (entry.value is Map) {
          specs[lang] = (entry.value as Map).map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          );
        }
      }
    }

    return CatalogProduct(
      id: json['id'] as int?,
      naam: (json['naam'] as String?) ?? '',
      artikelnummer: json['artikelnummer'] as String?,
      categorie: json['categorie'] as String?,
      prijs: (json['prijs'] as num?)?.toDouble(),
      staffelprijzen: staffel,
      beschrijving: json['beschrijving'] as String?,
      afbeeldingUrl: json['afbeelding_url'] as String?,
      webshopUrl: json['webshop_url'] as String?,
      luff: json['luff'] as String?,
      foot: json['foot'] as String?,
      sailArea: json['sail_area'] as String?,
      specsTabel: json['specs_tabel'] != null
          ? (json['specs_tabel'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString()))
          : null,
      materiaal: json['materiaal'] as String?,
      inclusief: json['inclusief'] as String?,
      inStock: (json['in_stock'] as bool?) ?? true,
      laatstBijgewerkt: json['laatst_bijgewerkt'] != null
          ? DateTime.tryParse(json['laatst_bijgewerkt'] as String)
          : null,
      geblokkeerd: (json['geblokkeerd'] as bool?) ?? false,
      geblokkeerdDoor: json['geblokkeerd_door'] as String?,
      geblokkeerdOp: json['geblokkeerd_op'] != null
          ? DateTime.tryParse(json['geblokkeerd_op'] as String)
          : null,
      extraAfbeeldingen: json['extra_afbeeldingen'] != null
          ? (json['extra_afbeeldingen'] as List).cast<String>()
          : const [],
      gewicht: (json['gewicht'] as num?)?.toDouble(),
      eanCode: json['ean_code'] as String?,
      seoTitle: json['seo_title'] as String?,
      seoDescription: json['seo_description'] as String?,
      seoKeywords: json['seo_keywords'] as String?,
      canonicalUrl: json['canonical_url'] as String?,
      ogImage: json['og_image'] as String?,
      naamOverride: json['naam_override'] as String?,
      beschrijvingOverride: json['beschrijving_override'] as String?,
      prijsOverride: (json['prijs_override'] as num?)?.toDouble(),
      afbeeldingUrlOverride: json['afbeelding_url_override'] as String?,
      translatedNames: names,
      translatedDescriptions: descs,
      translatedSpecs: specs,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'naam': naam,
      'in_stock': inStock,
      'laatst_bijgewerkt': DateTime.now().toUtc().toIso8601String(),
    };
    if (artikelnummer != null) map['artikelnummer'] = artikelnummer;
    if (categorie != null) map['categorie'] = categorie;
    if (prijs != null) map['prijs'] = prijs;
    if (staffelprijzen != null) map['staffelprijzen'] = staffelprijzen;
    if (beschrijving != null) map['beschrijving'] = beschrijving;
    if (afbeeldingUrl != null) map['afbeelding_url'] = afbeeldingUrl;
    if (webshopUrl != null) map['webshop_url'] = webshopUrl;
    if (luff != null) map['luff'] = luff;
    if (foot != null) map['foot'] = foot;
    if (sailArea != null) map['sail_area'] = sailArea;
    if (specsTabel != null) map['specs_tabel'] = specsTabel;
    if (materiaal != null) map['materiaal'] = materiaal;
    if (inclusief != null) map['inclusief'] = inclusief;
    if (extraAfbeeldingen.isNotEmpty) map['extra_afbeeldingen'] = extraAfbeeldingen;
    if (gewicht != null) map['gewicht'] = gewicht;
    if (eanCode != null) map['ean_code'] = eanCode;
    if (seoTitle != null) map['seo_title'] = seoTitle;
    if (seoDescription != null) map['seo_description'] = seoDescription;
    if (seoKeywords != null) map['seo_keywords'] = seoKeywords;
    if (canonicalUrl != null) map['canonical_url'] = canonicalUrl;
    if (ogImage != null) map['og_image'] = ogImage;

    for (final entry in translatedNames.entries) {
      map['naam_${entry.key}'] = entry.value;
    }
    for (final entry in translatedDescriptions.entries) {
      map['beschrijving_${entry.key}'] = entry.value;
    }
    if (translatedSpecs.isNotEmpty) {
      map['translated_specs'] = translatedSpecs;
    }
    return map;
  }

  /// Fallback serialization with only core columns that are guaranteed to exist.
  Map<String, dynamic> toJsonMinimal() {
    final map = <String, dynamic>{
      'naam': naam,
      'in_stock': inStock,
      'laatst_bijgewerkt': DateTime.now().toUtc().toIso8601String(),
    };
    if (artikelnummer != null) map['artikelnummer'] = artikelnummer;
    if (categorie != null) map['categorie'] = categorie;
    if (prijs != null) map['prijs'] = prijs;
    if (staffelprijzen != null) map['staffelprijzen'] = staffelprijzen;
    if (beschrijving != null) map['beschrijving'] = beschrijving;
    if (afbeeldingUrl != null) map['afbeelding_url'] = afbeeldingUrl;
    if (webshopUrl != null) map['webshop_url'] = webshopUrl;
    if (luff != null) map['luff'] = luff;
    if (foot != null) map['foot'] = foot;
    if (sailArea != null) map['sail_area'] = sailArea;
    return map;
  }

  String get displayNaam => naamOverride ?? naam;
  String? get displayBeschrijving => beschrijvingOverride ?? beschrijving;
  double? get displayPrijs => prijsOverride ?? prijs;
  String? get displayAfbeeldingUrl {
    final url = afbeeldingUrlOverride ?? afbeeldingUrl;
    return url != null ? resolveImageUrl(url) : null;
  }

  bool get hasOverrides =>
      naamOverride != null || beschrijvingOverride != null ||
      prijsOverride != null || afbeeldingUrlOverride != null;

  String naamForLang(String lang) => translatedNames[lang] ?? displayNaam;

  /// Returns the spec value for the given field in the requested language,
  /// falling back to the Dutch source value.
  String? specForLang(String field, String lang) {
    if (lang == 'nl') return _nlSpecValue(field);
    final translated = translatedSpecs[lang]?[field];
    if (translated != null && translated.isNotEmpty) return translated;
    return _nlSpecValue(field);
  }

  String? _nlSpecValue(String field) {
    switch (field) {
      case 'materiaal': return materiaal;
      case 'inclusief': return inclusief;
      default: return null;
    }
  }

  String? beschrijvingForLang(String lang) {
    if (lang == 'nl') return displayBeschrijving;
    final translated = translatedDescriptions[lang];
    if (translated != null && translated.isNotEmpty) return translated;
    return null;
  }

  bool get hasTranslations => translatedNames.isNotEmpty;

  /// Returns true if this product has translations for all target languages.
  bool get hasAllTranslations => _allLangs.every((l) => translatedNames.containsKey(l));

  List<String> get alleAfbeeldingen {
    final all = <String>[];
    if (displayAfbeeldingUrl != null) all.add(displayAfbeeldingUrl!);
    for (final url in extraAfbeeldingen) {
      final resolved = resolveImageUrl(url);
      if (resolved != displayAfbeeldingUrl) all.add(resolved);
    }
    return all;
  }

  String get prijsFormatted {
    final p = displayPrijs;
    if (p == null) return '';
    return '€ ${p.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String get categorieLabel => categorieLabelForLang('nl');

  String categorieLabelForLang(String lang) {
    if (categorie == null) {
      const other = {
        'nl': 'Overig', 'en': 'Other', 'de': 'Sonstiges', 'fr': 'Autres',
        'es': 'Otros', 'it': 'Altro', 'bg': 'Други', 'cs': 'Ostatní',
        'da': 'Andet', 'el': 'Άλλα', 'et': 'Muud', 'fi': 'Muut',
        'ga': 'Eile', 'hr': 'Ostalo', 'hu': 'Egyéb', 'lt': 'Kita',
        'lv': 'Citi', 'mt': 'Oħrajn', 'pl': 'Inne', 'pt': 'Outros',
        'ro': 'Altele', 'sk': 'Ostatné', 'sl': 'Drugo', 'sv': 'Övrigt',
      };
      return other[lang] ?? 'Other';
    }
    const map = {
      'optimist': 'Optimist',
      'ventoz-laserzeil': 'Laser / ILCA',
      'ventoz-topaz': 'Topaz',
      'ventoz-splash': 'Splash',
      'ventoz-centaur': 'Centaur',
      'rs-feva': 'RS Feva',
      'randmeer': 'Randmeer',
      'hobie-cat': 'Hobie Cat',
      'ventoz-420-470-sails': '420 / 470',
      'efsix': 'EFSix',
      'sunfish': 'Sunfish',
      'open-bic': 'Open Bic',
      'nacra-17': 'Nacra 17',
      'yamaha-seahopper': 'Yamaha Seahopper',
      'mirror': 'Mirror',
      'fox-22': 'Fox 22',
    };
    final fixed = map[categorie];
    if (fixed != null) return fixed;

    const translated = {
      'beachsailing': {
        'nl': 'Strandzeil', 'en': 'Beach Sail', 'de': 'Strandsegel', 'fr': 'Voile de plage',
        'es': 'Vela de playa', 'it': 'Vela da spiaggia', 'bg': 'Плажно платно', 'cs': 'Plážová plachta',
        'da': 'Strandsejl', 'el': 'Πανί παραλίας', 'et': 'Rannapuri', 'fi': 'Rantapurje',
        'ga': 'Seol trá', 'hr': 'Jedro za plažu', 'hu': 'Strandvitorla', 'lt': 'Paplūdimio burė',
        'lv': 'Pludmales bura', 'mt': 'Qala tal-bajja', 'pl': 'Żagiel plażowy', 'pt': 'Vela de praia',
        'ro': 'Velă de plajă', 'sk': 'Plážová plachta', 'sl': 'Plažno jadro', 'sv': 'Strandsegel',
      },
      'diversen': {
        'nl': 'Diversen', 'en': 'Accessories', 'de': 'Zubehör', 'fr': 'Accessoires',
        'es': 'Accesorios', 'it': 'Accessori', 'bg': 'Аксесоари', 'cs': 'Příslušenství',
        'da': 'Tilbehør', 'el': 'Αξεσουάρ', 'et': 'Tarvikud', 'fi': 'Tarvikkeet',
        'ga': 'Gabhálais', 'hr': 'Pribor', 'hu': 'Kiegészítők', 'lt': 'Priedai',
        'lv': 'Piederumi', 'mt': 'Aċċessorji', 'pl': 'Akcesoria', 'pt': 'Acessórios',
        'ro': 'Accesorii', 'sk': 'Príslušenstvo', 'sl': 'Dodatki', 'sv': 'Tillbehör',
      },
      'stormfok': {
        'nl': 'Stormfok', 'en': 'Storm Jib', 'de': 'Sturmfock', 'fr': 'Foc de tempête',
        'es': 'Foque de tormenta', 'it': 'Fiocco da tempesta', 'bg': 'Щормов кливер', 'cs': 'Bouřkový kosatec',
        'da': 'Stormfok', 'el': 'Θυελλώδες πανί', 'et': 'Tormipuri', 'fi': 'Myrskyföökki',
        'ga': 'Seol stoirme', 'hr': 'Olujni flok', 'hu': 'Viharvitorla', 'lt': 'Audros burė',
        'lv': 'Vētras bura', 'mt': 'Flokk ta\' maltempata', 'pl': 'Sztormowy fok', 'pt': 'Vela de tempestade',
        'ro': 'Foc de furtună', 'sk': 'Búrková plachta', 'sl': 'Viharno jadro', 'sv': 'Stormfock',
      },
      'valk': {
        'nl': 'Polyvalk', 'en': 'Polyvalk', 'de': 'Polyvalk', 'fr': 'Polyvalk',
        'es': 'Polyvalk', 'it': 'Polyvalk', 'bg': 'Polyvalk', 'cs': 'Polyvalk',
        'da': 'Polyvalk', 'el': 'Polyvalk', 'et': 'Polyvalk', 'fi': 'Polyvalk',
        'ga': 'Polyvalk', 'hr': 'Polyvalk', 'hu': 'Polyvalk', 'lt': 'Polyvalk',
        'lv': 'Polyvalk', 'mt': 'Polyvalk', 'pl': 'Polyvalk', 'pt': 'Polyvalk',
        'ro': 'Polyvalk', 'sk': 'Polyvalk', 'sl': 'Polyvalk', 'sv': 'Polyvalk',
      },
    };
    final catTranslated = translated[categorie];
    if (catTranslated != null) {
      return catTranslated[lang] ?? catTranslated['en'] ?? categorie!;
    }
    return categorie!;
  }
}
