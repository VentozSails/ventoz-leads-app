import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:encrypt/encrypt.dart' as enc;

class CryptoService {
  static const _prefix = 'ENC:';

  // Legacy client-side key (used only for migration/fallback if server RPC
  // is not yet available). Will be removed once server-side is confirmed.
  static const _rawKey = String.fromEnvironment('ENCRYPTION_KEY');

  static bool get _hasLocalKey => _rawKey.isNotEmpty;

  static SupabaseClient get _client => Supabase.instance.client;

  /// Encrypt via server-side RPC. Falls back to local if RPC unavailable.
  static Future<String> encryptAsync(String plainText) async {
    if (plainText.isEmpty) return plainText;
    if (plainText.startsWith(_prefix)) return plainText;

    try {
      final result = await _client.rpc('encrypt_secret', params: {'p_plaintext': plainText});
      if (result is String && result.startsWith(_prefix)) return result;
    } catch (_) {
      // RPC not available yet, fall back to local encryption
    }

    return _encryptLocal(plainText);
  }

  /// Decrypt via server-side RPC. Falls back to local if RPC unavailable.
  static Future<String> decryptAsync(String stored) async {
    if (stored.isEmpty || !stored.startsWith(_prefix)) return stored;

    try {
      final result = await _client.rpc('decrypt_secret', params: {'p_ciphertext': stored});
      if (result is String && !result.startsWith(_prefix)) return result;
    } catch (_) {
      // RPC not available yet, fall back to local decryption
    }

    return _decryptLocal(stored);
  }

  /// Synchronous encrypt (legacy, for backward compatibility during migration).
  static String encrypt(String plainText) {
    if (plainText.isEmpty) return plainText;
    if (plainText.startsWith(_prefix)) return plainText;
    return _encryptLocal(plainText);
  }

  /// Synchronous decrypt (legacy, for backward compatibility during migration).
  static String decrypt(String stored) {
    if (stored.isEmpty || !stored.startsWith(_prefix)) return stored;
    return _decryptLocal(stored);
  }

  // ── Local fallback (uses compile-time key if available) ──

  static String _encryptLocal(String plainText) {
    if (!_hasLocalKey) return plainText;
    final key = _getLocalKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '$_prefix${iv.base64}:${encrypted.base64}';
  }

  static String _decryptLocal(String stored) {
    if (!_hasLocalKey) return stored;
    final parts = stored.substring(_prefix.length).split(':');
    if (parts.length != 2) return stored;
    try {
      final key = _getLocalKey();
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      return encrypter.decrypt64(parts[1], iv: iv);
    } catch (_) {
      return stored;
    }
  }

  static enc.Key _getLocalKey() {
    final bytes = base64.decode(_rawKey);
    if (bytes.length != 32) {
      throw Exception('ENCRYPTION_KEY moet exact 32 bytes zijn (base64-encoded)');
    }
    return enc.Key(bytes);
  }
}
