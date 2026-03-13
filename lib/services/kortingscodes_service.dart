import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/kortingscode.dart';

class KortingscodesService {
  final _client = Supabase.instance.client;

  /// Deterministic code from sorted product ids + action params: SHA-256 -> first 6 hex -> VTZ-XXXXXX
  static String generateCode(
    List<int> productIds, {
    int kortingspercentage = 10,
    DateTime? geldigTot,
    int proefperiodeDagen = 30,
  }) {
    final sorted = List<int>.from(productIds)..sort();
    final parts = <String>[
      sorted.join(','),
      'k$kortingspercentage',
      'p$proefperiodeDagen',
    ];
    if (geldigTot != null) {
      parts.add('g${geldigTot.year}${geldigTot.month}${geldigTot.day}');
    }
    final input = parts.join('|');
    final hash = sha256.convert(utf8.encode(input)).toString();
    return 'VTZ-${hash.substring(0, 6).toUpperCase()}';
  }

  Future<List<Kortingscode>> fetchAll() async {
    try {
      final List<dynamic> response = await _client
          .from('kortingscodes')
          .select()
          .order('created_at', ascending: false);
      return response
          .cast<Map<String, dynamic>>()
          .map((json) => Kortingscode.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Kortingscodes laden mislukt (${e.code}): ${e.message}');
    }
  }

  /// Find existing code for this exact product + action combination.
  Future<Kortingscode?> findByParams({
    required List<int> productIds,
    required int kortingspercentage,
    DateTime? geldigTot,
    required int proefperiodeDagen,
  }) async {
    final sorted = List<int>.from(productIds)..sort();
    try {
      var query = _client
          .from('kortingscodes')
          .select()
          .eq('product_ids', sorted)
          .eq('kortingspercentage', kortingspercentage)
          .eq('proefperiode_dagen', proefperiodeDagen);

      if (geldigTot != null) {
        query = query.eq('geldig_tot', geldigTot.toIso8601String().split('T').first);
      } else {
        query = query.isFilter('geldig_tot', null);
      }

      final List<dynamic> response = await query;
      if (response.isEmpty) return null;
      return Kortingscode.fromJson(response.first as Map<String, dynamic>);
    } on PostgrestException {
      return null;
    }
  }

  /// Find or create a code for this product + action combination.
  Future<Kortingscode> findOrCreate(
    List<int> productIds,
    String productNamen, {
    int kortingspercentage = 10,
    DateTime? geldigTot,
    int proefperiodeDagen = 30,
  }) async {
    final existing = await findByParams(
      productIds: productIds,
      kortingspercentage: kortingspercentage,
      geldigTot: geldigTot,
      proefperiodeDagen: proefperiodeDagen,
    );
    if (existing != null) return existing;

    final code = generateCode(
      productIds,
      kortingspercentage: kortingspercentage,
      geldigTot: geldigTot,
      proefperiodeDagen: proefperiodeDagen,
    );
    return create(
      code,
      productIds,
      productNamen,
      kortingspercentage: kortingspercentage,
      geldigTot: geldigTot,
      proefperiodeDagen: proefperiodeDagen,
    );
  }

  Future<Kortingscode> create(
    String code,
    List<int> productIds,
    String productNamen, {
    int kortingspercentage = 10,
    DateTime? geldigTot,
    int proefperiodeDagen = 30,
  }) async {
    final sorted = List<int>.from(productIds)..sort();
    try {
      final data = <String, dynamic>{
        'code': code,
        'product_ids': sorted,
        'product_namen': productNamen,
        'kortingspercentage': kortingspercentage,
        'proefperiode_dagen': proefperiodeDagen,
      };
      if (geldigTot != null) {
        data['geldig_tot'] = geldigTot.toIso8601String().split('T').first;
      }
      final response = await _client
          .from('kortingscodes')
          .insert(data)
          .select()
          .single();
      return Kortingscode.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Kortingscode aanmaken mislukt (${e.code}): ${e.message}');
    }
  }

  Future<void> update(int id, {
    String? code,
    bool? actief,
    int? kortingspercentage,
    DateTime? geldigTot,
    bool clearGeldigTot = false,
    int? proefperiodeDagen,
  }) async {
    final data = <String, dynamic>{};
    if (code != null) data['code'] = code;
    if (actief != null) data['actief'] = actief;
    if (kortingspercentage != null) data['kortingspercentage'] = kortingspercentage;
    if (geldigTot != null) data['geldig_tot'] = geldigTot.toIso8601String().split('T').first;
    if (clearGeldigTot) data['geldig_tot'] = null;
    if (proefperiodeDagen != null) data['proefperiode_dagen'] = proefperiodeDagen;
    if (data.isEmpty) return;

    try {
      await _client.from('kortingscodes').update(data).eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Kortingscode bijwerken mislukt (${e.code}): ${e.message}');
    }
  }

  Future<void> delete(int id) async {
    try {
      await _client.from('kortingscodes').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Kortingscode verwijderen mislukt (${e.code}): ${e.message}');
    }
  }
}
