import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'translate_service.dart';

class AboutTextService {
  static final AboutTextService _instance = AboutTextService._();
  factory AboutTextService() => _instance;
  AboutTextService._();

  static const _key = 'about_text';
  final _supabase = Supabase.instance.client;
  final _translator = TranslateService();

  Map<String, String>? _cache;

  Future<Map<String, String>> getTexts() async {
    if (_cache != null) return _cache!;
    try {
      final rows = await _supabase
          .from('app_settings')
          .select('value')
          .eq('key', _key)
          .limit(1);
      if (rows.isNotEmpty && rows.first['value'] != null) {
        final raw = rows.first['value'];
        if (raw is Map) {
          _cache = raw.map((k, v) => MapEntry(k.toString(), v.toString()));
          return _cache!;
        }
        if (raw is String) {
          final decoded = jsonDecode(raw) as Map;
          _cache = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
          return _cache!;
        }
      }
    } catch (_) {}
    return {};
  }

  Future<String> getTextForLang(String lang) async {
    final texts = await getTexts();
    return texts[lang] ?? texts['en'] ?? texts['nl'] ?? '';
  }

  Future<void> saveAndTranslate(String nlText, {void Function(String lang)? onProgress}) async {
    final translations = <String, String>{'nl': nlText};

    final results = <String, String>{};
    for (final lang in TranslateService.translationTargets) {
      onProgress?.call(lang);
      results[lang] = await _translator.translate(nlText, targetLang: lang);
      await Future.delayed(const Duration(milliseconds: 50));
    }
    translations.addAll(results);

    await _supabase.from('app_settings').upsert({
      'key': _key,
      'value': translations,
    }, onConflict: 'key');
    _cache = translations;
  }

  void invalidateCache() => _cache = null;
}
