import 'package:supabase_flutter/supabase_flutter.dart';
import 'crypto_service.dart';

class SupplierConfig {
  final String name;
  final String websiteUrl;
  final String username;
  final String password;
  final String notes;

  const SupplierConfig({
    this.name = '',
    this.websiteUrl = '',
    this.username = '',
    this.password = '',
    this.notes = '',
  });

  factory SupplierConfig.fromJson(Map<String, dynamic> json) => SupplierConfig(
    name: json['name'] as String? ?? '',
    websiteUrl: json['website_url'] as String? ?? '',
    username: json['username'] as String? ?? '',
    password: json['password'] as String? ?? '',
    notes: json['notes'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'website_url': websiteUrl,
    'username': username,
    'password': password,
    'notes': notes,
  };
}

class SupplierService {
  final _client = Supabase.instance.client;
  static const _tableName = 'app_settings';
  static const _settingKey = 'suppliers_config';
  static const _secretFields = ['password'];

  Future<List<SupplierConfig>> loadSuppliers() async {
    try {
      final List<dynamic> response = await _client
          .from(_tableName)
          .select()
          .eq('key', _settingKey);
      if (response.isEmpty) return [];
      final row = response.first as Map<String, dynamic>;
      final value = row['value'];
      if (value is! Map<String, dynamic>) return [];

      final list = value['suppliers'] as List<dynamic>? ?? [];
      final result = <SupplierConfig>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          var decrypted = item;
          try {
            final d = await _client.rpc('decrypt_settings_secrets', params: {
              'p_settings': item,
              'p_secret_fields': _secretFields,
            });
            if (d is Map<String, dynamic>) decrypted = d;
          } catch (_) {
            decrypted = _decryptFallback(item);
          }
          result.add(SupplierConfig.fromJson(decrypted));
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSuppliers(List<SupplierConfig> suppliers) async {
    final encrypted = <Map<String, dynamic>>[];
    for (final s in suppliers) {
      var json = s.toJson();
      try {
        final e = await _client.rpc('encrypt_settings_secrets', params: {
          'p_settings': json,
          'p_secret_fields': _secretFields,
        });
        if (e is Map<String, dynamic>) json = e;
      } catch (_) {
        json = _encryptFallback(json);
      }
      encrypted.add(json);
    }

    await _client.from(_tableName).upsert({
      'key': _settingKey,
      'value': {'suppliers': encrypted},
    }, onConflict: 'key');
  }

  Map<String, dynamic> _decryptFallback(Map<String, dynamic> json) {
    final result = Map<String, dynamic>.from(json);
    for (final f in _secretFields) {
      if (result[f] is String) result[f] = CryptoService.decrypt(result[f] as String);
    }
    return result;
  }

  Map<String, dynamic> _encryptFallback(Map<String, dynamic> json) {
    final result = Map<String, dynamic>.from(json);
    for (final f in _secretFields) {
      if (result[f] is String) result[f] = CryptoService.encrypt(result[f] as String);
    }
    return result;
  }
}
