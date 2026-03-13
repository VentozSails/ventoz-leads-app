import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/email_template.dart';

class EmailTemplatesService {
  final _client = Supabase.instance.client;

  Future<List<EmailTemplate>> fetchTemplates() async {
    try {
      final List<dynamic> response = await _client
          .from('email_templates')
          .select()
          .order('created_at', ascending: false);
      return response
          .cast<Map<String, dynamic>>()
          .map((json) => EmailTemplate.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Templates laden mislukt (${e.code}): ${e.message}');
    }
  }

  Future<EmailTemplate> createTemplate(EmailTemplate template) async {
    try {
      final response = await _client
          .from('email_templates')
          .insert(template.toJson())
          .select()
          .single();
      return EmailTemplate.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Template aanmaken mislukt (${e.code}): ${e.message}');
    }
  }

  Future<EmailTemplate> updateTemplate(EmailTemplate template) async {
    try {
      final response = await _client
          .from('email_templates')
          .update(template.toJson())
          .eq('id', template.id!)
          .select()
          .single();
      return EmailTemplate.fromJson(response);
    } on PostgrestException catch (e) {
      throw Exception('Template bijwerken mislukt (${e.code}): ${e.message}');
    }
  }

  Future<void> deleteTemplate(int id) async {
    try {
      await _client.from('email_templates').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Template verwijderen mislukt (${e.code}): ${e.message}');
    }
  }
}
