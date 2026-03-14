import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PackagingBox {
  final String? id;
  final String naam;
  final int gewicht;
  final int lengteCm;
  final int breedteCm;
  final int hoogteCm;
  final int maxGewichtGram;
  final int sortOrder;

  const PackagingBox({
    this.id,
    required this.naam,
    required this.gewicht,
    this.lengteCm = 0,
    this.breedteCm = 0,
    this.hoogteCm = 0,
    this.maxGewichtGram = 0,
    this.sortOrder = 0,
  });

  factory PackagingBox.fromJson(Map<String, dynamic> json) => PackagingBox(
    id: json['id'] as String?,
    naam: json['naam'] as String? ?? '',
    gewicht: (json['gewicht'] as num?)?.toInt() ?? 0,
    lengteCm: (json['lengte_cm'] as num?)?.toInt() ?? 0,
    breedteCm: (json['breedte_cm'] as num?)?.toInt() ?? 0,
    hoogteCm: (json['hoogte_cm'] as num?)?.toInt() ?? 0,
    maxGewichtGram: (json['max_gewicht_gram'] as num?)?.toInt() ?? 0,
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'naam': naam,
    'gewicht': gewicht,
    'lengte_cm': lengteCm,
    'breedte_cm': breedteCm,
    'hoogte_cm': hoogteCm,
    'max_gewicht_gram': maxGewichtGram,
    'sort_order': sortOrder,
  };

  String get label => '$naam (${gewicht}g)';

  bool get hasAfmetingen => lengteCm > 0 && breedteCm > 0 && hoogteCm > 0;

  String get afmetingenLabel =>
      hasAfmetingen ? '$lengteCm x $breedteCm x $hoogteCm cm' : '';

  /// Circumference used for carrier limit checks: 2*(B+H) + L
  int get omtrekCm => hasAfmetingen ? 2 * (breedteCm + hoogteCm) + lengteCm : 0;
}

class BoxProductLink {
  final String? id;
  final String verpakkingId;
  final String productId;
  final String productNaam;

  const BoxProductLink({
    this.id,
    required this.verpakkingId,
    required this.productId,
    required this.productNaam,
  });

  factory BoxProductLink.fromJson(Map<String, dynamic> json) => BoxProductLink(
    id: json['id'] as String?,
    verpakkingId: json['verpakking_id'] as String,
    productId: json['product_id'] as String,
    productNaam: json['product_naam'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'verpakking_id': verpakkingId,
    'product_id': productId,
    'product_naam': productNaam,
  };
}

class PackagingService {
  static final PackagingService _instance = PackagingService._();
  factory PackagingService() => _instance;
  PackagingService._();

  final _client = Supabase.instance.client;
  static const _table = 'verpakkingen';
  static const _linkTable = 'verpakking_producten';

  Future<List<PackagingBox>> getAll() async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .order('sort_order', ascending: true);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(PackagingBox.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(PackagingBox box) async {
    if (box.id != null) {
      await _client.from(_table).update(box.toJson()).eq('id', box.id!);
    } else {
      await _client.from(_table).insert(box.toJson());
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from(_linkTable).delete().eq('verpakking_id', id);
    } catch (_) {}
    await _client.from(_table).delete().eq('id', id);
  }

  Future<void> updateSortOrder(List<PackagingBox> boxes) async {
    for (var i = 0; i < boxes.length; i++) {
      if (boxes[i].id != null) {
        await _client
            .from(_table)
            .update({'sort_order': i})
            .eq('id', boxes[i].id!);
      }
    }
  }

  // ── Product links ──

  Future<List<BoxProductLink>> getLinksForBox(String boxId) async {
    try {
      final rows = await _client
          .from(_linkTable)
          .select()
          .eq('verpakking_id', boxId);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(BoxProductLink.fromJson)
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('getLinksForBox error: $e');
      return [];
    }
  }

  Future<Map<String, List<BoxProductLink>>> getAllLinks() async {
    try {
      final rows = await _client.from(_linkTable).select();
      final links = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(BoxProductLink.fromJson)
          .toList();
      final map = <String, List<BoxProductLink>>{};
      for (final link in links) {
        map.putIfAbsent(link.verpakkingId, () => []).add(link);
      }
      return map;
    } catch (e) {
      if (kDebugMode) debugPrint('getAllLinks error: $e');
      return {};
    }
  }

  Future<void> setLinksForBox(
      String boxId, List<BoxProductLink> links) async {
    await _client.from(_linkTable).delete().eq('verpakking_id', boxId);
    if (links.isNotEmpty) {
      await _client.from(_linkTable).insert(
        links.map((l) => l.toJson()).toList(),
      );
    }
  }

  /// Find boxes that can hold all given product IDs (based on links).
  Future<List<PackagingBox>> suggestBoxes({
    required Set<String> productIds,
    required int totalWeightGrams,
  }) async {
    final boxes = await getAll();
    final allLinks = await getAllLinks();

    final result = <PackagingBox>[];
    for (final box in boxes) {
      final links = allLinks[box.id] ?? [];
      if (links.isEmpty) {
        result.add(box);
        continue;
      }
      final linkedProductIds = links.map((l) => l.productId).toSet();
      if (productIds.every((pid) => linkedProductIds.contains(pid))) {
        result.add(box);
      }
    }

    result.sort((a, b) {
      if (a.maxGewichtGram > 0 && b.maxGewichtGram > 0) {
        return a.maxGewichtGram.compareTo(b.maxGewichtGram);
      }
      if (a.maxGewichtGram > 0) return -1;
      if (b.maxGewichtGram > 0) return 1;
      return a.gewicht.compareTo(b.gewicht);
    });

    return result;
  }
}
