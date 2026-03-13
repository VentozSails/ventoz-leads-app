import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SalesChannel {
  final String? id;
  final String naam;
  final String code;
  final bool actief;
  final int sortOrder;
  final DateTime? createdAt;

  const SalesChannel({
    this.id,
    required this.naam,
    required this.code,
    this.actief = true,
    this.sortOrder = 0,
    this.createdAt,
  });

  factory SalesChannel.fromJson(Map<String, dynamic> json) => SalesChannel(
    id: json['id'] as String?,
    naam: (json['naam'] as String?) ?? '',
    code: (json['code'] as String?) ?? '',
    actief: (json['actief'] as bool?) ?? true,
    sortOrder: (json['sort_order'] as int?) ?? 0,
    createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    'naam': naam,
    'code': code,
    'actief': actief,
    'sort_order': sortOrder,
  };

  static const defaultChannels = <Map<String, String>>[
    {'naam': 'Ventoz Website', 'code': 'website'},
    {'naam': 'eBay', 'code': 'ebay'},
    {'naam': 'Amazon', 'code': 'amazon'},
    {'naam': 'Bol.com', 'code': 'bol_com'},
    {'naam': 'Marktplaats', 'code': 'marktplaats'},
    {'naam': 'Handmatig', 'code': 'handmatig'},
    {'naam': 'Overig', 'code': 'overig'},
  ];
}

class SalesChannelService {
  final _client = Supabase.instance.client;
  static const _table = 'verkoopkanalen';

  Future<List<SalesChannel>> getAll({bool activeOnly = false}) async {
    try {
      var query = _client.from(_table).select();
      if (activeOnly) query = query.eq('actief', true);
      final List<dynamic> rows = await query.order('sort_order', ascending: true).order('naam', ascending: true);
      return rows.cast<Map<String, dynamic>>().map(SalesChannel.fromJson).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('SalesChannelService.getAll error: $e');
      return [];
    }
  }

  Future<SalesChannel?> getByCode(String code) async {
    try {
      final row = await _client.from(_table).select().eq('code', code).maybeSingle();
      if (row == null) return null;
      return SalesChannel.fromJson(row);
    } catch (e) {
      if (kDebugMode) debugPrint('SalesChannelService.getByCode error: $e');
      return null;
    }
  }

  Future<SalesChannel?> save(SalesChannel channel) async {
    try {
      final json = channel.toJson();
      if (channel.id != null) {
        final rows = await _client.from(_table).update(json).eq('id', channel.id!).select();
        if (rows.isNotEmpty) return SalesChannel.fromJson(rows.first);
      } else {
        final rows = await _client.from(_table).insert(json).select();
        if (rows.isNotEmpty) return SalesChannel.fromJson(rows.first);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('SalesChannelService.save error: $e');
      rethrow;
    }
    return null;
  }

  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  Future<void> toggleActive(String id, bool actief) async {
    await _client.from(_table).update({'actief': actief}).eq('id', id);
  }
}
