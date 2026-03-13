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
    'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi',
    'fr', 'ga', 'hr', 'hu', 'it', 'lt', 'lv', 'mt', 'pl', 'pt',
    'ro', 'sk', 'sl', 'sv',
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
      return result.isNotEmpty ? result : text;
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
