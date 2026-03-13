import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lead.dart';

class LeadsService {
  final _client = Supabase.instance.client;

  Future<List<Lead>> fetchLeads({String tableName = 'leads_nl'}) async {
    try {
      final List<dynamic> response = await _client
          .from(tableName)
          .select()
          .order('id', ascending: true);
      return response
          .cast<Map<String, dynamic>>()
          .map((json) => Lead.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Supabase fout (${e.code}): ${e.message}');
    }
  }

  Future<List<Lead>> searchLeads(String query, {String tableName = 'leads_nl'}) async {
    try {
      final List<dynamic> response = await _client
          .from(tableName)
          .select()
          .ilike('naam', '%${query.replaceAll('%', '').replaceAll('_', '\\_')}%')
          .order('id', ascending: true);
      return response
          .cast<Map<String, dynamic>>()
          .map((json) => Lead.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Supabase fout (${e.code}): ${e.message}');
    }
  }

  Future<void> updateStatus(int id, String status, {String tableName = 'leads_nl'}) async {
    try {
      await _client.from(tableName).update({
        'status': status,
        'laatste_actie': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Status bijwerken mislukt (${e.code}): ${e.message}');
    }
  }

  Future<Lead> updateLead(Lead lead, {String tableName = 'leads_nl'}) async {
    try {
      final data = _toJsonForTable(lead, tableName);
      data['laatste_actie'] = DateTime.now().toUtc().toIso8601String();
      final response = await _client
          .from(tableName)
          .update(data)
          .eq('id', lead.id)
          .select()
          .single();
      return Lead.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Lead bijwerken mislukt (${e.code}): ${e.message}');
    }
  }

  Future<Lead> insertLead(Map<String, dynamic> data, {String tableName = 'leads_nl'}) async {
    try {
      data['laatste_actie'] = DateTime.now().toUtc().toIso8601String();
      final response = await _client
          .from(tableName)
          .insert(data)
          .select()
          .single();
      return Lead.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Lead aanmaken mislukt (${e.code}): ${e.message}');
    }
  }

  Map<String, dynamic> _toJsonForTable(Lead lead, String tableName) {
    switch (tableName) {
      case 'leads_de':
        return lead.toJsonDe();
      case 'leads_be':
        return lead.toJsonBe();
      default:
        return lead.toJsonNl();
    }
  }
}
