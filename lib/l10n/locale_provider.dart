import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_localizations.dart';

class LocaleProvider extends ChangeNotifier {
  static final LocaleProvider _instance = LocaleProvider._();
  factory LocaleProvider() => _instance;
  LocaleProvider._() {
    _detectLanguageFromIp();
  }

  String _lang = 'en';
  bool _userChoseLang = false;

  String get lang => _lang;
  AppLocalizations get l => AppLocalizations(_lang);

  static const primaryLangs = ['nl', 'en', 'de', 'fr', 'es', 'it'];
  static const otherLangs = [
    'bg', 'cs', 'da', 'el', 'et', 'fi', 'ga', 'hr', 'hu',
    'lt', 'lv', 'mt', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv',
    'zh', 'ar', 'tr',
  ];
  static const supportedLangs = [...primaryLangs, ...otherLangs];
  static const langLabels = {
    'nl': 'NL', 'en': 'EN', 'de': 'DE', 'fr': 'FR', 'es': 'ES', 'it': 'IT',
    'bg': 'BG', 'cs': 'CS', 'da': 'DA', 'el': 'EL', 'et': 'ET', 'fi': 'FI',
    'ga': 'GA', 'hr': 'HR', 'hu': 'HU', 'lt': 'LT', 'lv': 'LV', 'mt': 'MT',
    'pl': 'PL', 'pt': 'PT', 'ro': 'RO', 'sk': 'SK', 'sl': 'SL', 'sv': 'SV',
    'zh': 'ZH', 'ar': 'AR', 'tr': 'TR',
  };
  static const langNames = {
    'nl': 'Nederlands', 'en': 'English', 'de': 'Deutsch', 'fr': 'Français',
    'es': 'Español', 'it': 'Italiano', 'bg': 'Български', 'cs': 'Čeština',
    'da': 'Dansk', 'el': 'Ελληνικά', 'et': 'Eesti', 'fi': 'Suomi',
    'ga': 'Gaeilge', 'hr': 'Hrvatski', 'hu': 'Magyar', 'lt': 'Lietuvių',
    'lv': 'Latviešu', 'mt': 'Malti', 'pl': 'Polski', 'pt': 'Português',
    'ro': 'Română', 'sk': 'Slovenčina', 'sl': 'Slovenščina', 'sv': 'Svenska',
    'zh': '中文', 'ar': 'العربية', 'tr': 'Türkçe',
  };

  static const _countryToLang = {
    'NL': 'nl', 'BE': 'nl', 'SR': 'nl',
    'DE': 'de', 'AT': 'de', 'CH': 'de', 'LI': 'de', 'LU': 'de',
    'FR': 'fr', 'MC': 'fr',
    'ES': 'es',
    'IT': 'it', 'SM': 'it', 'VA': 'it',
    'PT': 'pt', 'BR': 'pt',
    'PL': 'pl',
    'CZ': 'cs',
    'SK': 'sk',
    'HU': 'hu',
    'RO': 'ro', 'MD': 'ro',
    'BG': 'bg',
    'HR': 'hr',
    'SI': 'sl',
    'GR': 'el', 'CY': 'el',
    'DK': 'da', 'GL': 'da',
    'SE': 'sv',
    'FI': 'fi',
    'EE': 'et',
    'LV': 'lv',
    'LT': 'lt',
    'IE': 'ga',
    'MT': 'mt',
    'TR': 'tr',
    'SA': 'ar', 'AE': 'ar', 'EG': 'ar', 'QA': 'ar', 'KW': 'ar',
    'BH': 'ar', 'OM': 'ar', 'JO': 'ar', 'LB': 'ar', 'IQ': 'ar',
    'CN': 'zh', 'TW': 'zh', 'HK': 'zh', 'MO': 'zh', 'SG': 'zh',
  };

  void setLang(String lang) {
    if (_lang != lang && supportedLangs.contains(lang)) {
      _lang = lang;
      _userChoseLang = true;
      notifyListeners();
    }
  }

  Future<void> _detectLanguageFromIp() async {
    if (_userChoseLang) return;
    try {
      final response = await http.get(
        Uri.parse('https://ipapi.co/json/'),
      ).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final countryCode = (data['country_code'] ?? data['countryCode']) as String?;
        if (countryCode != null && !_userChoseLang) {
          final detectedLang = _countryToLang[countryCode];
          if (detectedLang != null && supportedLangs.contains(detectedLang)) {
            _lang = detectedLang;
            notifyListeners();
          }
        }
      }
    } catch (_) {
      // IP detection failed, keep default (en)
    }
  }
}
