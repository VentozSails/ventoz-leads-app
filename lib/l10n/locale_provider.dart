import 'package:flutter/material.dart';
import 'app_localizations.dart';

class LocaleProvider extends ChangeNotifier {
  static final LocaleProvider _instance = LocaleProvider._();
  factory LocaleProvider() => _instance;
  LocaleProvider._();

  String _lang = 'nl';

  String get lang => _lang;
  AppLocalizations get l => AppLocalizations(_lang);

  static const primaryLangs = ['nl', 'en', 'de', 'fr', 'es', 'it'];
  static const otherLangs = ['bg', 'cs', 'da', 'el', 'et', 'fi', 'ga', 'hr', 'hu', 'lt', 'lv', 'mt', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv'];
  static const supportedLangs = [...primaryLangs, ...otherLangs];
  static const langLabels = {
    'nl': 'NL', 'en': 'EN', 'de': 'DE', 'fr': 'FR', 'es': 'ES', 'it': 'IT',
    'bg': 'BG', 'cs': 'CS', 'da': 'DA', 'el': 'EL', 'et': 'ET', 'fi': 'FI',
    'ga': 'GA', 'hr': 'HR', 'hu': 'HU', 'lt': 'LT', 'lv': 'LV', 'mt': 'MT',
    'pl': 'PL', 'pt': 'PT', 'ro': 'RO', 'sk': 'SK', 'sl': 'SL', 'sv': 'SV',
  };
  static const langNames = {
    'nl': 'Nederlands', 'en': 'English', 'de': 'Deutsch', 'fr': 'Français',
    'es': 'Español', 'it': 'Italiano', 'bg': 'Български', 'cs': 'Čeština',
    'da': 'Dansk', 'el': 'Ελληνικά', 'et': 'Eesti', 'fi': 'Suomi',
    'ga': 'Gaeilge', 'hr': 'Hrvatski', 'hu': 'Magyar', 'lt': 'Lietuvių',
    'lv': 'Latviešu', 'mt': 'Malti', 'pl': 'Polski', 'pt': 'Português',
    'ro': 'Română', 'sk': 'Slovenčina', 'sl': 'Slovenščina', 'sv': 'Svenska',
  };

  void setLang(String lang) {
    if (_lang != lang && supportedLangs.contains(lang)) {
      _lang = lang;
      notifyListeners();
    }
  }
}
