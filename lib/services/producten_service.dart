import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';

class ProductenService {
  final _client = Supabase.instance.client;

  Future<List<Product>> fetchProducten() async {
    try {
      final List<dynamic> response = await _client
          .from('producten')
          .select()
          .order('naam', ascending: true);
      return response
          .cast<Map<String, dynamic>>()
          .map((json) => Product.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Producten laden mislukt (${e.code}): ${e.message}');
    }
  }
}
