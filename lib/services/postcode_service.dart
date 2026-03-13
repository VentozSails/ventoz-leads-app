import 'dart:convert';
import 'package:http/http.dart' as http;

class AddressResult {
  final String straat;
  final String plaats;
  final String gemeente;
  final String provincie;
  final String postcode;
  final int huisnummer;
  final String country;

  const AddressResult({
    required this.straat,
    required this.plaats,
    required this.gemeente,
    required this.provincie,
    required this.postcode,
    required this.huisnummer,
    required this.country,
  });

  factory AddressResult.fromJson(Map<String, dynamic> json) => AddressResult(
    straat: json['straat'] as String? ?? '',
    plaats: json['plaats'] as String? ?? '',
    gemeente: json['gemeente'] as String? ?? '',
    provincie: json['provincie'] as String? ?? '',
    postcode: json['postcode'] as String? ?? '',
    huisnummer: (json['huisnummer'] as num?)?.toInt() ?? 0,
    country: json['country'] as String? ?? 'nl',
  );
}

class PostcodeService {
  static const _baseUrl = 'https://gratis-postcodedata.nl/api';

  /// Lookup address by postcode and house number.
  /// Works for NL and BE postcodes.
  static Future<AddressResult?> lookup(String postcode, String huisnummer) async {
    final cleaned = postcode.replaceAll(RegExp(r'\s'), '').toUpperCase();
    final nr = huisnummer.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty || nr.isEmpty) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/postcode/$cleaned/$nr'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        final data = jsonDecode(response.body.trim());
        if (data is Map<String, dynamic> && data['straat'] != null) {
          return AddressResult.fromJson(data);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Validate Dutch postcode format: 4 digits + 2 letters
  static bool isValidNlPostcode(String postcode) {
    return RegExp(r'^\d{4}\s?[A-Za-z]{2}$').hasMatch(postcode.trim());
  }

  /// Validate Belgian postcode format: 4 digits
  static bool isValidBePostcode(String postcode) {
    return RegExp(r'^\d{4}$').hasMatch(postcode.trim());
  }
}
