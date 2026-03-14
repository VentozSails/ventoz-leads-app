import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'translate_service.dart';

class CategoryDescription {
  final int? id;
  final String categorie;
  final String beschrijvingNl;
  final String? beschrijvingEn;
  final String? beschrijvingDe;
  final String? beschrijvingFr;
  final Map<String, String> beschrijvingen;
  final DateTime? laatstBijgewerkt;

  const CategoryDescription({
    this.id,
    required this.categorie,
    required this.beschrijvingNl,
    this.beschrijvingEn,
    this.beschrijvingDe,
    this.beschrijvingFr,
    this.beschrijvingen = const {},
    this.laatstBijgewerkt,
  });

  factory CategoryDescription.fromJson(Map<String, dynamic> json) {
    final jsonMap = json['beschrijvingen'];
    final Map<String, String> translations = {};
    if (jsonMap is Map) {
      for (final e in jsonMap.entries) {
        if (e.value is String && (e.value as String).isNotEmpty) {
          translations[e.key as String] = e.value as String;
        }
      }
    }
    return CategoryDescription(
      id: json['id'] as int?,
      categorie: json['categorie'] as String,
      beschrijvingNl: (json['beschrijving_nl'] as String?) ?? '',
      beschrijvingEn: json['beschrijving_en'] as String?,
      beschrijvingDe: json['beschrijving_de'] as String?,
      beschrijvingFr: json['beschrijving_fr'] as String?,
      beschrijvingen: translations,
      laatstBijgewerkt: json['laatst_bijgewerkt'] != null
          ? DateTime.tryParse(json['laatst_bijgewerkt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'categorie': categorie,
    'beschrijving_nl': beschrijvingNl,
    'beschrijving_en': beschrijvingEn,
    'beschrijving_de': beschrijvingDe,
    'beschrijving_fr': beschrijvingFr,
    'beschrijvingen': beschrijvingen,
    'laatst_bijgewerkt': DateTime.now().toUtc().toIso8601String(),
  };

  String getForLocale(String locale) {
    if (beschrijvingen.containsKey(locale) && beschrijvingen[locale]!.isNotEmpty) {
      return beschrijvingen[locale]!;
    }
    switch (locale) {
      case 'en': return beschrijvingEn ?? beschrijvingNl;
      case 'de': return beschrijvingDe ?? beschrijvingNl;
      case 'fr': return beschrijvingFr ?? beschrijvingNl;
      default: return beschrijvingNl;
    }
  }
}

class CategoryDescriptionService {
  static final CategoryDescriptionService _instance = CategoryDescriptionService._();
  factory CategoryDescriptionService() => _instance;
  CategoryDescriptionService._();

  final _client = Supabase.instance.client;
  static const _table = 'category_descriptions';

  Map<String, CategoryDescription>? _cache;

  Future<Map<String, CategoryDescription>> getAll({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;
    try {
      final rows = await _client.from(_table).select();
      final map = <String, CategoryDescription>{};
      for (final row in rows) {
        final desc = CategoryDescription.fromJson(row);
        map[desc.categorie] = desc;
      }
      _cache = map;
      return map;
    } catch (e) {
      if (kDebugMode) debugPrint('CategoryDescriptionService.getAll error: $e');
      return _cache ?? {};
    }
  }

  Future<CategoryDescription?> getByCategory(String categorie) async {
    final all = await getAll();
    return all[categorie];
  }

  Future<void> save(CategoryDescription desc) async {
    _cache = null;
    final json = desc.toJson();
    if (desc.id != null) {
      await _client.from(_table).update(json).eq('id', desc.id!);
    } else {
      final existing = await _client.from(_table)
          .select('id')
          .eq('categorie', desc.categorie)
          .limit(1);
      if (existing.isNotEmpty) {
        await _client.from(_table).update(json).eq('id', existing.first['id'] as int);
      } else {
        await _client.from(_table).insert(json);
      }
    }
  }

  Future<void> saveAndTranslate(
    String categorie,
    String nlText, {
    void Function(String lang)? onProgress,
  }) async {
    _cache = null;
    final translator = TranslateService();
    final translations = <String, String>{'nl': nlText};

    for (final lang in TranslateService.translationTargets) {
      onProgress?.call(lang);
      try {
        final translated = await translator.translate(nlText, targetLang: lang);
        if (translated.isNotEmpty) translations[lang] = translated;
      } catch (e) {
        if (kDebugMode) debugPrint('Translate $lang failed: $e');
      }
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final existing = await _client.from(_table)
        .select('id')
        .eq('categorie', categorie)
        .limit(1);

    final payload = {
      'categorie': categorie,
      'beschrijving_nl': nlText,
      'beschrijving_en': translations['en'],
      'beschrijving_de': translations['de'],
      'beschrijving_fr': translations['fr'],
      'beschrijvingen': translations,
      'laatst_bijgewerkt': now,
    };

    if (existing.isNotEmpty) {
      await _client.from(_table).update(payload).eq('id', existing.first['id'] as int);
    } else {
      await _client.from(_table).insert(payload);
    }
  }

  Future<void> seedDefaults() async {
    final existing = await getAll(forceRefresh: true);
    final now = DateTime.now().toUtc().toIso8601String();
    for (final entry in _defaults.entries) {
      final current = existing[entry.key];
      if (current == null) {
        try {
          await _client.from(_table).insert({
            'categorie': entry.key,
            'beschrijving_nl': entry.value,
            'laatst_bijgewerkt': now,
          });
        } catch (e) {
          if (kDebugMode) debugPrint('Seed default desc error: $e');
        }
      } else if (current.beschrijvingNl != entry.value) {
        try {
          await _client.from(_table).update({
            'beschrijving_nl': entry.value,
            'laatst_bijgewerkt': now,
          }).eq('id', current.id!);
        } catch (e) {
          if (kDebugMode) debugPrint('Update default desc error: $e');
        }
      }
    }
    _cache = null;
  }

  static const _defaults = <String, String>{
    'optimist': 'Ventoz Sails biedt mooie Optimist zeilen, die perfect passen op deze klassieke jeugdzeilboot. Deze zeilen zijn gemaakt van sterk zeildoek van het merk Challenge voor een lange levensduur. De verschillende types en zijn geschikt voor (club)wedstrijden, recreatief zeilen en zeillessen.',
    'ventoz-laserzeil': 'Bij Ventoz Sails bieden we een reeks hoogwaardige zeilen voor de Laser / ILCA-klasse, evenals andere populaire Laser-varianten zoals de Laser Pico en Laser Vago. Onze zeilen zijn direct uit voorraad leverbaar.',
    'ventoz-topaz': 'Ventoz Sails biedt een hoogwaardige set zeilen die perfect passen op uw Topper en Topaz zeilboot. Deze zeilen zijn gemaakt van sterk zeildoek van het merk Challenge voor een lange levensduur. De Topaz Uno zeilen (grootzeil en fok) zijn in verschillende kleurstellingen beschikbaar.',
    'ventoz-splash': 'Ventoz Sails biedt hoogwaardige zeilen die perfect passen op uw Splash zeilboot. Deze zeilen zijn gemaakt van sterk zeildoek van het merk Challenge voor een lange levensduur.\n\nVentoz Splash Zeil 5.4 (green)\nSpeciaal ontworpen voor jongere Splash-zeilers. Voorzien van een doorkijkvenster, teltales, zeillatten en een zeilzak.\n\nVentoz Splash Zeil 6.3 (blue)\nCompleet Splash-zeil voor optimaal zeilplezier.',
    'beachsailing': 'Ventoz Sails biedt een heel scala aan hoogwaardige strandzeilen in diverse afmetingen, speciaal ontworpen om mee te blokarten.\n\nVentoz strandzeilen zijn direct uit voorraad leverbaar en worden gratis verzonden binnen Nederland. Dankzij het gebruik van premium materialen en doordachte ontwerpen zijn deze zeilen ideaal voor zowel recreatief gebruik als professionele verhuur en evenementen.',
    'ventoz-centaur': 'Ventoz Sails biedt een hoogwaardige set zeilen die perfect passen op uw Centaur zeilboot. Deze zeilen zijn gemaakt van sterk zeildoek van het merk Challenge voor een lange levensduur.\n\nCentaur Grootzeil - Losse Broek\nHet voorlijk heeft een koord/pees, het onderlijk heeft een zogenaamde "losse broek" voor meer trimmogelijkheden.\n\nCentaur Grootzeil - Koord/Pees\nZowel het voorlijk als het onderlijk zijn voorzien van een koord/pees.\n\nCentaur Genua\nMet een oppervlakte van 7.0 m². Optioneel met een doorkijkvenster.\n\nCentaur Fok\nMet een oppervlakte van 5.5 m².',
    'rs-feva': 'Ventoz Sails biedt een hoogwaardige set zeilen die perfect passen op uw RS Feva zeilboot. Deze zeilen zijn gemaakt van sterk zeildoek van het merk Challenge voor een lange levensduur.\n\nRS Feva Grootzeil - Radial Cut\nRadiaal gesneden grootzeil voor een optimale snit en krachtverdeling.\n\nRS Feva Grootzeil - Cross-Cut\nCross-cut gesneden grootzeil met felle gele patches op de hoeken.\n\nRS Feva Fok\nStandaard fok met doorkijkvenster.',
    'valk': 'Ventoz Sails biedt een hoogwaardige set zeilen die perfect passen op uw Polyvalk zeilboot. Deze zeilen zijn gemaakt van sterk zeildoek van het merk Challenge voor een lange levensduur.\n\nPolyvalk Grootzeil\nStandaard grootzeil voor de Polyvalk (met metalen mast en gaffel).\n\nPolyvalk (Rol)Fok\nGeschikt voor de gangbare Polyvalk rolfoksystemen. Voorzien van een brede UV-strook voor extra bescherming.\n\nPolyvalk (Stag)Fok\nStandaard fok met (stag)leuvers.',
    'randmeer': 'Ventoz Sails biedt een hoogwaardige set zeilen die perfect passen op uw Randmeer zeilboot. Deze zeilen zijn gemaakt van sterk zeildoek van het merk Challenge voor een lange levensduur.\n\nRandmeer Grootzeil\nHet voorlijk is voorzien van glijleuvers, en het onderlijk heeft een koord/pees. Het zeil biedt de mogelijkheid voor het plaatsen van een rif.\n\nRandmeer (Rol)Genua\nUitgerust met een voorlijkhoes voor rolsystemen, een oppervlakte van 7.4 m² en een doorkijkvenster.\n\nRandmeer (Stag)Genua\nVoorzien van (stag)leuvers, een oppervlakte van 7.4 m² en een doorkijkvenster.',
    'hobie-cat': 'Ventoz Sails biedt een hoogwaardige set zeilen die perfect passen op uw Hobie Cat Catamaran. Deze zeilen zijn gemaakt van sterk zeildoek van het merk Challenge voor een lange levensduur.\n\nHobie Cat 14 Grootzeil\nEen volledig doorgelat grootzeil met doorkijkvensters. Het zeil is inclusief zeillatten en tube zeilzak.\n\nHobie Cat 14 Fok\nStandaardfok met een venster en zeilzak.\n\nHobie Cat 16 Grootzeil\nEen volledig doorgelat grootzeil met doorkijkvensters. Het zeil is inclusief zeillatten en tube zeilzak.\n\nHobie Cat 16 Fok\nEen doorgelatte fok met doorkijkvensters. Het zeil is inclusief zeillatten en tube zeilzak.\n\nHobie Cat 16 Gennaker (Asymmetrische Spinnaker)\nGemaakt van sterk en lichtgewicht Challenge spinnaker zeildoek.',
    'ventoz-420-470-sails': 'Ventoz Sails biedt een hoogwaardige set zeilen die perfect passen op uw 420 en/of 470 zeilboot. Deze zeilen zijn gemaakt van sterk zeildoek van het merk Challenge voor een lange levensduur.\n\n420 Grootzeil\nCrosscut gesneden met een oppervlakte van 7.45 m².\n\n420 Fok\nStandaard fok voor de 420 van 2.80 m² en met een kijkvenster.\n\n470 Grootzeil\nCrosscut gesneden met een oppervlakte van 9.12 m².\n\n470 Fok\nStandaard fok voor de 470 van 3.58 m² en met een kijkvenster.',
    'efsix': 'Ventoz Sails biedt een hoogwaardige set zeilen die perfect passen op uw Efsix zeilboot. Deze zeilen zijn gemaakt van sterk zeildoek van het merk Challenge voor een lange levensduur.\n\nEfsix Grootzeil - Losse Broek\nHet voorlijk heeft een koord, het onderlijk een zogenaamde "losse broek" voor meer trimmogelijkheden.\n\nEfsix Grootzeil - Koord/Pees\nZowel het voorlijk als het onderlijk zijn voorzien van een koord/pees.\n\nEfsix Fok\nMet een oppervlakte van 6.05 m².',
    'sunfish': 'Bij Ventoz Sails bieden we hoogwaardige zeilen aan voor zowel de Sunfish als ook de Minifish. Deze zeilen zijn gemaakt van sterk zeildoek van het merk Challenge voor een lange levensduur. Onze zeilen zijn verkrijgbaar in diverse ontwerpen en kleuren, zodat u een keuze kunt maken die bij uw stijl past.',
    'stormfok': 'Ventoz Sails heeft een aantal hoogwaardige en zeer sterke stormfokken in haar assortiment. Deze zeilen zijn gemaakt van dik zeildoek van het merk Challenge voor een lange levensduur.',
    'open-bic': "Ventoz Sails biedt een hoogwaardige set zeilen die perfect passen op uw O'pen BIC zeilboot. Deze zeilen zijn gemaakt van sterk zeildoek van het merk Challenge voor een lange levensduur.\n\nVentoz O'pen BIC Basis Zeil\nDit is het standaard zeil voor de O'pen BIC en is wit met een rode top. Het wordt gevouwen geleverd, inclusief zeilzak.\n\nVentoz O'pen BIC Race Zeil\nDit voor snelheid ontworpen zeil is wit met rode en zwarte accenten. Het is vervaardigd uit sterk dacon zeildoek gecombineerd met x-ply. Het wordt gerold geleverd, inclusief zeilzak en zeillatten.",
    'nacra-17': 'Bij Ventoz Sails bieden we hoogwaardige zeilen aan die speciaal zijn ontworpen voor de Nacra 17.\n\nVentoz Nacra 17 Grootzeil\nDit volledig doorgelatte, radiaal gesneden grootzeil met zeven zeillatten is vervaardigd van hoogwaardig Challenge zeildoek (Warp-Drive 6.11 oz). Het zeil heeft een groot venster voor goed zicht.\n\nVentoz Nacra 17 Fok\nDeze doorgelatte, radiaal gesneden fok met drie zeillatten is gemaakt van hoogwaardig Challenge zeildoek (Warp-Drive 4.11 oz). Het zeil heeft een groot venster.',
  };
}
