class Lead {
  final int id;
  final String? nr;
  final String? ventozKlantnr;
  final String? region;
  final String? categorie;
  final String naam;
  final String? adres;
  final String? postcode;
  final String? plaats;
  final String? contactpersonen;
  final String? telefoon;
  final String? email;
  final String? website;
  final String? typeBoten;
  final String? geschatAantalBoten;
  final String? erkenningen;
  final String? opmerkingen;
  final String status;
  final DateTime? laatsteActie;

  // BE-specific fields
  final String? regio;
  final String? type;
  final String? relevantie;
  final String? hoofdtaal;
  final String? functie;
  final String? disciplines;
  final String? doelgroep;
  final String? typeWater;
  final String? jeugdwerking;
  final String? commercieelModel;

  const Lead({
    required this.id,
    this.nr,
    this.ventozKlantnr,
    this.region,
    this.categorie,
    required this.naam,
    this.adres,
    this.postcode,
    this.plaats,
    this.contactpersonen,
    this.telefoon,
    this.email,
    this.website,
    this.typeBoten,
    this.geschatAantalBoten,
    this.erkenningen,
    this.opmerkingen,
    this.status = 'Nieuw',
    this.laatsteActie,
    this.regio,
    this.type,
    this.relevantie,
    this.hoofdtaal,
    this.functie,
    this.disciplines,
    this.doelgroep,
    this.typeWater,
    this.jeugdwerking,
    this.commercieelModel,
  });

  bool get isKlant =>
      ventozKlantnr != null && ventozKlantnr!.trim().isNotEmpty;

  factory Lead.fromJson(Map<String, dynamic> json) {
    final klantnr = json['ventoz_klantnr'] as String?;
    final hasKlantnr = klantnr != null && klantnr.trim().isNotEmpty;

    final regionValue =
        (json['provincie'] as String?) ??
        (json['bundesland'] as String?);

    // NL uses 'contactpersonen', DE/BE use 'contactpersoon'
    final contact =
        (json['contactpersonen'] as String?) ??
        (json['contactpersoon'] as String?);

    // NL uses 'opmerkingen', BE uses 'opmerking'
    final remarks =
        (json['opmerkingen'] as String?) ??
        (json['opmerking'] as String?);

    return Lead(
      id: json['id'] as int,
      nr: json['nr'] as String?,
      ventozKlantnr: klantnr,
      region: regionValue,
      categorie: (json['categorie'] as String?) ?? (json['type'] as String?),
      naam: (json['naam'] as String?) ?? '',
      adres: json['adres'] as String?,
      postcode: json['postcode'] as String?,
      plaats: json['plaats'] as String?,
      contactpersonen: contact,
      telefoon: json['telefoon'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      typeBoten: json['boot_typen'] as String?,
      geschatAantalBoten: json['geschat_aantal_boten'] as String?,
      erkenningen: json['erkenningen'] as String?,
      opmerkingen: remarks,
      status: hasKlantnr ? 'Klant' : (json['status'] as String?) ?? 'Nieuw',
      laatsteActie: json['laatste_actie'] != null
          ? DateTime.tryParse(json['laatste_actie'] as String)
          : null,
      // BE-specific
      regio: json['regio'] as String?,
      type: json['type'] as String?,
      relevantie: json['relevantie'] as String?,
      hoofdtaal: json['hoofdtaal'] as String?,
      functie: json['functie'] as String?,
      disciplines: json['disciplines'] as String?,
      doelgroep: json['doelgroep'] as String?,
      typeWater: json['type_water'] as String?,
      jeugdwerking: json['jeugdwerking'] as String?,
      commercieelModel: json['commercieel_model'] as String?,
    );
  }

  Map<String, dynamic> toJsonNl() => {
        'nr': nr,
        'ventoz_klantnr': ventozKlantnr,
        'provincie': region,
        'categorie': categorie,
        'naam': naam,
        'adres': adres,
        'postcode': postcode,
        'plaats': plaats,
        'contactpersonen': contactpersonen,
        'telefoon': telefoon,
        'email': email,
        'website': website,
        'boot_typen': typeBoten,
        'geschat_aantal_boten': geschatAantalBoten,
        'erkenningen': erkenningen,
        'opmerkingen': opmerkingen,
        'status': status,
        'laatste_actie': laatsteActie?.toIso8601String(),
      };

  Map<String, dynamic> toJsonDe() => {
        'nr': nr,
        'ventoz_klantnr': ventozKlantnr,
        'bundesland': region,
        'categorie': categorie,
        'naam': naam,
        'adres': adres,
        'postcode': postcode,
        'plaats': plaats,
        'contactpersoon': contactpersonen,
        'telefoon': telefoon,
        'email': email,
        'website': website,
        'boot_typen': typeBoten,
        'status': status,
        'laatste_actie': laatsteActie?.toIso8601String(),
      };

  Map<String, dynamic> toJsonBe() => {
        'ventoz_klantnr': ventozKlantnr,
        'naam': naam,
        'type': type,
        'relevantie': relevantie,
        'regio': regio,
        'provincie': region,
        'plaats': plaats,
        'postcode': postcode,
        'adres': adres,
        'website': website,
        'hoofdtaal': hoofdtaal,
        'email': email,
        'telefoon': telefoon,
        'contactpersoon': contactpersonen,
        'functie': functie,
        'disciplines': disciplines,
        'doelgroep': doelgroep,
        'type_water': typeWater,
        'jeugdwerking': jeugdwerking,
        'commercieel_model': commercieelModel,
        'opmerking': opmerkingen,
        'boot_typen': typeBoten,
        'status': status,
        'laatste_actie': laatsteActie?.toIso8601String(),
      };

  Lead copyWith({
    String? nr,
    String? ventozKlantnr,
    String? region,
    String? categorie,
    String? naam,
    String? adres,
    String? postcode,
    String? plaats,
    String? contactpersonen,
    String? telefoon,
    String? email,
    String? website,
    String? typeBoten,
    String? geschatAantalBoten,
    String? erkenningen,
    String? opmerkingen,
    String? status,
    DateTime? laatsteActie,
    String? regio,
    String? type,
    String? relevantie,
    String? hoofdtaal,
    String? functie,
    String? disciplines,
    String? doelgroep,
    String? typeWater,
    String? jeugdwerking,
    String? commercieelModel,
  }) {
    return Lead(
      id: id,
      nr: nr ?? this.nr,
      ventozKlantnr: ventozKlantnr ?? this.ventozKlantnr,
      region: region ?? this.region,
      categorie: categorie ?? this.categorie,
      naam: naam ?? this.naam,
      adres: adres ?? this.adres,
      postcode: postcode ?? this.postcode,
      plaats: plaats ?? this.plaats,
      contactpersonen: contactpersonen ?? this.contactpersonen,
      telefoon: telefoon ?? this.telefoon,
      email: email ?? this.email,
      website: website ?? this.website,
      typeBoten: typeBoten ?? this.typeBoten,
      geschatAantalBoten: geschatAantalBoten ?? this.geschatAantalBoten,
      erkenningen: erkenningen ?? this.erkenningen,
      opmerkingen: opmerkingen ?? this.opmerkingen,
      status: status ?? this.status,
      laatsteActie: laatsteActie ?? this.laatsteActie,
      regio: regio ?? this.regio,
      type: type ?? this.type,
      relevantie: relevantie ?? this.relevantie,
      hoofdtaal: hoofdtaal ?? this.hoofdtaal,
      functie: functie ?? this.functie,
      disciplines: disciplines ?? this.disciplines,
      doelgroep: doelgroep ?? this.doelgroep,
      typeWater: typeWater ?? this.typeWater,
      jeugdwerking: jeugdwerking ?? this.jeugdwerking,
      commercieelModel: commercieelModel ?? this.commercieelModel,
    );
  }

  static const productCatalog = [
    ('Optimist Grootzeil', 'https://ventoz.nl/product/optimist'),
    ('Laser/ILCA Grootzeil', 'https://ventoz.nl/product/laser-ilca'),
    ('420 Grootzeil', 'https://ventoz.nl/product/420'),
    ('470 Grootzeil', 'https://ventoz.nl/product/470'),
    ('Polyvalk Grootzeil', 'https://ventoz.nl/product/polyvalk'),
  ];

  String applyToTemplate(
    String template, {
    String? gekozenZeil,
    String? productUrl,
    String? kortingscode,
    String? kortingscodeBlok,
    String? geldigTot,
    String? proefperiode,
    String? kortingspercentage,
    List<(String naam, String? url)>? selectedProducts,
    String? downloadBlok,
  }) {
    return template
        .replaceAll('{{naam}}', naam)
        .replaceAll('{{plaats}}', plaats ?? '')
        .replaceAll('{{email}}', email ?? '')
        .replaceAll('{{telefoon}}', telefoon ?? '')
        .replaceAll('{{contactpersoon}}', contactpersonen?.split(',').first.trim() ?? naam)
        .replaceAll('{{contactpersonen}}', contactpersonen ?? naam)
        .replaceAll('{{boot_typen}}', typeBoten ?? '')
        .replaceAll('{{geschat_aantal_boten}}', geschatAantalBoten ?? 'uw vloot')
        .replaceAll('{{categorie}}', categorie ?? '')
        .replaceAll('{{erkenningen}}', erkenningen ?? '')
        .replaceAll('{{product}}', gekozenZeil ?? suggestedProduct)
        .replaceAll('{{gekozen_zeil}}', gekozenZeil ?? suggestedProduct)
        .replaceAll('{{product_url}}', productUrl ?? bestellink)
        .replaceAll('{{bestellink}}', productUrl ?? bestellink)
        .replaceAll('{{productlinks}}', _productLinksBlock())
        .replaceAll('{{product_lijst}}', _selectedProductsBlock(selectedProducts))
        .replaceAll('{{kortingscode}}', kortingscode ?? '')
        .replaceAll('{{kortingscode_blok}}', kortingscodeBlok ?? '')
        .replaceAll('{{geldig_tot}}', geldigTot ?? '')
        .replaceAll('{{proefperiode}}', proefperiode ?? '1 maand')
        .replaceAll('{{kortingspercentage}}', kortingspercentage ?? '10')
        .replaceAll('{{download_blok}}', downloadBlok ?? '');
  }

  String _selectedProductsBlock(List<(String naam, String? url)>? products) {
    if (products == null || products.isEmpty) return _productLinksBlock();
    final buf = StringBuffer();
    buf.writeln('VENTOZ_PRODUCT_LIST_START');
    for (final (name, url) in products) {
      buf.writeln('VENTOZ_PRODUCT|$name|${url ?? ''}');
    }
    buf.write('VENTOZ_PRODUCT_LIST_END');
    return buf.toString();
  }

  String _productLinksBlock() {
    final buf = StringBuffer();
    buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buf.writeln('       VENTOZ ZEILEN – ASSORTIMENT');
    buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buf.writeln();
    for (final (name, url) in productCatalog) {
      final marker = name == suggestedProduct ? '★' : '▸';
      buf.writeln('  $marker $name');
      buf.writeln('    $url');
      buf.writeln();
    }
    buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buf.write('★ = Aanbevolen op basis van uw vloot');
    return buf.toString();
  }

  String get suggestedProduct {
    final type = typeBoten?.toLowerCase() ?? '';
    if (type.contains('optimist')) return 'Optimist Grootzeil';
    if (type.contains('laser') || type.contains('ilca')) return 'Laser/ILCA Grootzeil';
    if (type.contains('420') || type.contains('470')) return 'Polyvalk Grootzeil';
    if (type.contains('valk')) return 'Polyvalk Grootzeil';
    return 'Polyvalk Grootzeil';
  }

  String get bestellink {
    final type = typeBoten?.toLowerCase() ?? '';
    if (type.contains('optimist')) return 'https://ventoz.nl/product/optimist';
    if (type.contains('laser') || type.contains('ilca')) return 'https://ventoz.nl/product/laser-ilca';
    if (type.contains('420')) return 'https://ventoz.nl/product/420';
    if (type.contains('470')) return 'https://ventoz.nl/product/470';
    if (type.contains('valk')) return 'https://ventoz.nl/product/polyvalk';
    return 'https://ventoz.nl/product/polyvalk';
  }
}
