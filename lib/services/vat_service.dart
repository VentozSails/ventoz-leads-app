import 'package:vies/vies.dart';

class VatValidationResult {
  final bool valid;
  final String? name;
  final String? address;
  final String? error;
  final String countryCode;
  final String vatNumber;

  const VatValidationResult({
    required this.valid,
    this.name,
    this.address,
    this.error,
    required this.countryCode,
    required this.vatNumber,
  });
}

class VatService {
  static const euVatRates = <String, double>{
    'NL': 21, 'DE': 19, 'BE': 21, 'FR': 20, 'IT': 22,
    'ES': 21, 'AT': 20, 'PL': 23, 'SE': 25, 'DK': 25,
    'FI': 25.5, 'IE': 23, 'PT': 23, 'EL': 24, 'GR': 24,
    'CZ': 21, 'RO': 19, 'HU': 27, 'BG': 20, 'HR': 25,
    'SK': 23, 'LT': 21, 'LV': 21, 'EE': 24, 'SI': 22,
    'CY': 19, 'MT': 18, 'LU': 17,
  };

  static const _euCountryCodes = {
    'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR',
    'DE', 'GR', 'EL', 'HU', 'IE', 'IT', 'LV', 'LT', 'LU', 'MT',
    'NL', 'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'SE',
  };

  /// Alle landen waar klanten uit mogen komen: EU + CH + GB
  static const allowedCountries = {
    ..._euCountryCodes,
    'CH', 'GB',
  };

  /// Landnamen in het Nederlands, gesorteerd op naam
  static const allowedCountryLabels = <String, String>{
    'BE': 'België',
    'BG': 'Bulgarije',
    'CY': 'Cyprus',
    'DK': 'Denemarken',
    'DE': 'Duitsland',
    'EE': 'Estland',
    'FI': 'Finland',
    'FR': 'Frankrijk',
    'GR': 'Griekenland',
    'HU': 'Hongarije',
    'IE': 'Ierland',
    'IT': 'Italië',
    'HR': 'Kroatië',
    'LV': 'Letland',
    'LT': 'Litouwen',
    'LU': 'Luxemburg',
    'MT': 'Malta',
    'NL': 'Nederland',
    'AT': 'Oostenrijk',
    'PL': 'Polen',
    'PT': 'Portugal',
    'RO': 'Roemenië',
    'SK': 'Slowakije',
    'SI': 'Slovenië',
    'ES': 'Spanje',
    'CZ': 'Tsjechië',
    'GB': 'Verenigd Koninkrijk',
    'SE': 'Zweden',
    'CH': 'Zwitserland',
  };

  /// Sorted entries for dropdown use
  static List<MapEntry<String, String>> get sortedCountryEntries {
    final entries = allowedCountryLabels.entries.toList();
    entries.sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  static bool isEuCountry(String countryCode) =>
      _euCountryCodes.contains(countryCode.toUpperCase());

  static bool isAllowedCountry(String countryCode) =>
      allowedCountries.contains(countryCode.toUpperCase());

  static double getVatRate(String countryCode) =>
      euVatRates[countryCode.toUpperCase()] ?? 0;

  static final _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );

  static bool isValidEmail(String email) => _emailRegex.hasMatch(email.trim());

  static bool isSafeUrl(String url) {
    final lower = url.trim().toLowerCase();
    return lower.startsWith('https://') || lower.startsWith('http://');
  }

  /// IBAN format-validatie (basis: 2 letters + 2 cijfers + 11-30 alfanum)
  static String? validateIban(String? iban) {
    if (iban == null || iban.trim().isEmpty) return null;
    final cleaned = iban.replaceAll(RegExp(r'\s'), '').toUpperCase();
    if (cleaned.length < 15 || cleaned.length > 34) {
      return 'IBAN moet 15-34 tekens bevatten';
    }
    if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]+$').hasMatch(cleaned)) {
      return 'Ongeldig IBAN-formaat (bijv. NL91ABNA0417164300)';
    }
    return null;
  }

  static String? extractCountryCode(String vatNumber) {
    final cleaned = vatNumber.replaceAll(RegExp(r'[\s\-.]'), '').toUpperCase();
    if (cleaned.length < 4) return null;
    final cc = cleaned.substring(0, 2);
    if (RegExp(r'^[A-Z]{2}$').hasMatch(cc)) return cc;
    return null;
  }

  static String? extractNumber(String vatNumber) {
    final cleaned = vatNumber.replaceAll(RegExp(r'[\s\-.]'), '').toUpperCase();
    if (cleaned.length < 4) return null;
    return cleaned.substring(2);
  }

  /// Validates a VAT number via the EU VIES service.
  /// The [vatNumber] should include the country prefix (e.g. "NL123456789B01").
  Future<VatValidationResult> validateVat(String vatNumber) async {
    final cc = extractCountryCode(vatNumber);
    final num = extractNumber(vatNumber);

    if (cc == null || num == null || num.isEmpty) {
      return VatValidationResult(
        valid: false,
        error: 'Ongeldig BTW-nummer formaat',
        countryCode: cc ?? '',
        vatNumber: vatNumber,
      );
    }

    if (!isEuCountry(cc)) {
      return VatValidationResult(
        valid: false,
        error: 'Land $cc is geen EU-lidstaat',
        countryCode: cc,
        vatNumber: num,
      );
    }

    try {
      final response = await ViesProvider.validateVat(
        countryCode: cc,
        vatNumber: num,
        timeout: const Duration(seconds: 15),
      );

      return VatValidationResult(
        valid: response.valid,
        name: response.name,
        address: response.address,
        countryCode: response.countryCode,
        vatNumber: response.vatNumber,
      );
    } on ViesClientError catch (e) {
      return VatValidationResult(
        valid: false,
        error: _translateError(e.errorCode ?? 'UNKNOWN'),
        countryCode: cc,
        vatNumber: num,
      );
    } on ViesServerError catch (e) {
      return VatValidationResult(
        valid: false,
        error: _translateError(e.errorCode ?? 'UNKNOWN'),
        countryCode: cc,
        vatNumber: num,
      );
    } catch (e) {
      return VatValidationResult(
        valid: false,
        error: 'VIES-service niet bereikbaar. Probeer het later opnieuw.',
        countryCode: cc,
        vatNumber: num,
      );
    }
  }

  String _translateError(String code) {
    switch (code) {
      case 'INVALID_VAT_NUMBER': return 'BTW-nummer is ongeldig.';
      case 'TIMEOUT': return 'VIES-service reageert niet (timeout).';
      case 'SOCKET_EXCEPTION': return 'Geen internetverbinding.';
      case 'MS_UNAVAILABLE': return 'De VIES-service van dit land is tijdelijk niet beschikbaar.';
      case 'SERVICE_UNAVAILABLE': return 'De VIES-service is tijdelijk niet beschikbaar.';
      default: return 'VIES-validatie mislukt ($code).';
    }
  }
}
