import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslateService {
  static const _baseUrl = 'https://translate.googleapis.com/translate_a/single';

  /// All 24 official EU languages.
  static const supportedLanguages = [
    'nl', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi',
    'fr', 'ga', 'hr', 'hu', 'it', 'lt', 'lv', 'mt', 'pl', 'pt',
    'ro', 'sk', 'sl', 'sv',
  ];

  /// All target languages (everything except NL source).
  static const translationTargets = [
    'ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi',
    'fr', 'ga', 'hr', 'hu', 'it', 'lt', 'lv', 'mt', 'pl', 'pt',
    'ro', 'sk', 'sl', 'sv', 'tr', 'zh',
  ];

  static const languageLabels = <String, String>{
    'nl': 'Nederlands', 'bg': 'Български', 'cs': 'Čeština',
    'da': 'Dansk', 'de': 'Deutsch', 'el': 'Ελληνικά',
    'en': 'English', 'es': 'Español', 'et': 'Eesti',
    'fi': 'Suomi', 'fr': 'Français', 'ga': 'Gaeilge',
    'hr': 'Hrvatski', 'hu': 'Magyar', 'it': 'Italiano',
    'lt': 'Lietuvių', 'lv': 'Latviešu', 'mt': 'Malti',
    'pl': 'Polski', 'pt': 'Português', 'ro': 'Română',
    'sk': 'Slovenčina', 'sl': 'Slovenščina', 'sv': 'Svenska',
  };

  static const languageFlags = <String, String>{
    'nl': '🇳🇱', 'bg': '🇧🇬', 'cs': '🇨🇿', 'da': '🇩🇰',
    'de': '🇩🇪', 'el': '🇬🇷', 'en': '🇬🇧', 'es': '🇪🇸',
    'et': '🇪🇪', 'fi': '🇫🇮', 'fr': '🇫🇷', 'ga': '🇮🇪',
    'hr': '🇭🇷', 'hu': '🇭🇺', 'it': '🇮🇹', 'lt': '🇱🇹',
    'lv': '🇱🇻', 'mt': '🇲🇹', 'pl': '🇵🇱', 'pt': '🇵🇹',
    'ro': '🇷🇴', 'sk': '🇸🇰', 'sl': '🇸🇮', 'sv': '🇸🇪',
  };

  // ── Sailing terminology glossary ──
  // Google Translate often mistranslates nautical/sailing terms.
  // This glossary maps NL sailing terms to their correct translation per language.
  // Format: { targetLang: { wrongTranslation: correctTranslation } }
  // Applied as post-processing after each translation call.

  static const _sailingGlossary = <String, Map<String, String>>{
    'de': {
      // Sails & sail types
      'Zucht': 'Segel', 'zucht': 'Segel',
      'Tuch': 'Segel', 'tuch': 'Segel',
      'Hauptsegel': 'Großsegel', 'hauptsegel': 'Großsegel',
      'Vorsegel': 'Fock', 'vorsegel': 'Fock',
      // Sail parts & rigging
      'Ausleger': 'Baum', 'ausleger': 'Baum',
      'Latte': 'Segellatte', 'latte': 'Segellatte',
      'Bolzen': 'Schäkel', 'bolzen': 'Schäkel',
      'Schote': 'Schot', 'schote': 'Schot',
      'Vorliek': 'Vorliek',
      'Unterliek': 'Unterliek',
      'Achterliek': 'Achterliek',
      // Boat parts
      'Schwert': 'Schwert',
      'Ruder': 'Ruder',
      'Pinne': 'Pinne',
      // Materials
      'Laminat': 'Laminat',
      'Dacron': 'Dacron',
      'Mylar': 'Mylar',
    },
    'en': {
      // Sails & sail types
      'sail': 'sail',
      'Focus': 'Jib', 'focus': 'jib', 'fasses': 'jib',
      'mainsail': 'mainsail', 'main sail': 'mainsail',
      'genoa': 'genoa', 'Genoa': 'Genoa',
      'spinnaker': 'spinnaker', 'Spinnaker': 'Spinnaker',
      'gennaker': 'gennaker', 'Gennaker': 'Gennaker',
      // Sail parts & rigging
      'boom': 'boom',
      'batten': 'batten', 'battens': 'battens',
      'shackle': 'shackle',
      'sheet': 'sheet', 'sheets': 'sheets',
      'luff': 'luff',
      'leech': 'leech',
      'foot': 'foot',
      'clew': 'clew',
      'tack': 'tack',
      'head': 'head',
      // Common mistranslations
      'draft': 'draft',
      'camber': 'camber',
      'tell-tale': 'tell-tale', 'telltale': 'telltale',
    },
    'fr': {
      // Sails
      'Voile': 'Voile', 'voile': 'voile',
      'foc': 'foc', 'Foc': 'Foc',
      'grand-voile': 'grand-voile', 'Grand-voile': 'Grand-voile',
      'spi': 'spi', 'Spi': 'Spi',
      // Rigging
      'bôme': 'bôme', 'Bôme': 'Bôme',
      'drisse': 'drisse', 'Drisse': 'Drisse',
      'écoute': 'écoute', 'Écoute': 'Écoute',
      'étai': 'étai', 'Étai': 'Étai',
      'hauban': 'hauban', 'Hauban': 'Hauban',
    },
    'it': {
      'vela': 'vela', 'Vela': 'Vela',
      'fiocco': 'fiocco', 'Fiocco': 'Fiocco',
      'randa': 'randa', 'Randa': 'Randa',
      'boma': 'boma', 'Boma': 'Boma',
      'scotta': 'scotta', 'Scotta': 'Scotta',
      'drizza': 'drizza', 'Drizza': 'Drizza',
      'stecca': 'stecca', 'Stecca': 'Stecca',
    },
    'es': {
      'vela': 'vela', 'Vela': 'Vela',
      'foque': 'foque', 'Foque': 'Foque',
      'mayor': 'vela mayor', 'Mayor': 'Vela mayor',
      'botavara': 'botavara', 'Botavara': 'Botavara',
      'escota': 'escota', 'Escota': 'Escota',
      'driza': 'driza', 'Driza': 'Driza',
      'sable': 'sable', 'Sable': 'Sable',
    },
    'sv': {
      'segel': 'segel', 'Segel': 'Segel',
      'fock': 'fock', 'Fock': 'Fock',
      'storsegel': 'storsegel', 'Storsegel': 'Storsegel',
      'bom': 'bom', 'Bom': 'Bom',
      'skot': 'skot', 'Skot': 'Skot',
      'fall': 'fall', 'Fall': 'Fall',
    },
    'da': {
      'sejl': 'sejl', 'Sejl': 'Sejl',
      'fok': 'fok', 'Fok': 'Fok',
      'storsejl': 'storsejl', 'Storsejl': 'Storsejl',
      'bom': 'bom', 'Bom': 'Bom',
    },
    'pl': {
      'żagiel': 'żagiel', 'Żagiel': 'Żagiel',
      'fok': 'fok', 'Fok': 'Fok',
      'grot': 'grot', 'Grot': 'Grot',
      'bom': 'bom', 'Bom': 'Bom',
      'szot': 'szot', 'Szot': 'Szot',
    },
  };

  /// Known wrong translations from Google Translate for NL sailing terms.
  /// Key: wrong output, Value: correct term. Applied per language.
  static const _wrongToCorrect = <String, Map<String, String>>{
    'de': {
      'Zucht': 'Segel',
      'Hauch': 'Segel',
      'Seufzer': 'Segel',
      'Anblick': 'Segel',
      'Tuch': 'Segeltuch',
      'Fokus': 'Fock',
      'Schwerpunkt': 'Fock',
      'Brennpunkt': 'Fock',
      'Genua': 'Genua',
      'Gennaker': 'Gennaker',
      'Hauptblatt': 'Großsegel',
    },
    'en': {
      'Focus': 'Jib',
      'focus': 'jib',
      'fasses': 'jib',
      'Sight': 'Sail',
      'sight': 'sail',
      'Sigh': 'Sail',
      'sigh': 'sail',
    },
    'fr': {
      'Mise au point': 'Foc',
      'mise au point': 'foc',
      'Concentration': 'Foc',
      'concentration': 'foc',
    },
    'it': {
      'Messa a fuoco': 'Fiocco',
      'messa a fuoco': 'fiocco',
      'Fuoco': 'Fiocco',
      'fuoco': 'fiocco',
    },
    'es': {
      'Enfoque': 'Foque',
      'enfoque': 'foque',
    },
    'pt': {
      'Foco': 'Vela de proa',
      'foco': 'vela de proa',
    },
    'sv': {
      'Fokus': 'Fock',
      'fokus': 'fock',
    },
    'da': {
      'Fokus': 'Fok',
      'fokus': 'fok',
    },
    'pl': {
      'Skupienie': 'Fok',
      'skupienie': 'fok',
      'Ogniskowa': 'Fok',
      'ogniskowa': 'fok',
    },
  };

  /// Applies sailing-domain corrections to a translated string.
  String _applySailingGlossary(String translated, String targetLang) {
    final corrections = _wrongToCorrect[targetLang];
    if (corrections == null || corrections.isEmpty) return translated;

    var result = translated;
    for (final entry in corrections.entries) {
      if (!result.contains(entry.key)) continue;
      result = result.replaceAll(
        RegExp('\\b${RegExp.escape(entry.key)}\\b'),
        entry.value,
      );
    }
    return result;
  }

  Future<String> translate(String text, {String sourceLang = 'nl', required String targetLang}) async {
    if (text.trim().isEmpty || sourceLang == targetLang) return text;

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'client': 'gtx',
        'sl': sourceLang,
        'tl': targetLang,
        'dt': 't',
        'q': text,
      });

      final response = await http.get(uri);
      if (response.statusCode != 200) return text;

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty || decoded[0] is! List) return text;

      final buf = StringBuffer();
      for (final segment in decoded[0]) {
        if (segment is List && segment.isNotEmpty && segment[0] is String) {
          buf.write(segment[0]);
        }
      }

      final result = buf.toString().trim();
      if (result.isEmpty) return text;

      return _applySailingGlossary(result, targetLang);
    } catch (_) {
      return text;
    }
  }

  Future<Map<String, String>> translateToAll(String text, {String sourceLang = 'nl'}) async {
    final results = <String, String>{};
    final targets = translationTargets.where((l) => l != sourceLang).toList();

    for (final lang in targets) {
      results[lang] = await translate(text, sourceLang: sourceLang, targetLang: lang);
      await Future.delayed(const Duration(milliseconds: 80));
    }
    return results;
  }
}
