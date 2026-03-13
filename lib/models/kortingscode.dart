class Kortingscode {
  final int? id;
  final String code;
  final List<int> productIds;
  final String productNamen;
  final int kortingspercentage;
  final DateTime? geldigTot;
  final int proefperiodeDagen;
  final bool actief;
  final DateTime? createdAt;

  const Kortingscode({
    this.id,
    required this.code,
    required this.productIds,
    required this.productNamen,
    this.kortingspercentage = 10,
    this.geldigTot,
    this.proefperiodeDagen = 30,
    this.actief = true,
    this.createdAt,
  });

  factory Kortingscode.fromJson(Map<String, dynamic> json) {
    return Kortingscode(
      id: json['id'] as int?,
      code: (json['code'] as String?) ?? '',
      productIds: (json['product_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      productNamen: (json['product_namen'] as String?) ?? '',
      kortingspercentage: (json['kortingspercentage'] as int?) ?? 10,
      geldigTot: json['geldig_tot'] != null
          ? DateTime.tryParse(json['geldig_tot'] as String)
          : null,
      proefperiodeDagen: (json['proefperiode_dagen'] as int?) ?? 30,
      actief: (json['actief'] as bool?) ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'product_ids': productIds,
        'product_namen': productNamen,
        'kortingspercentage': kortingspercentage,
        if (geldigTot != null) 'geldig_tot': geldigTot!.toIso8601String(),
        'proefperiode_dagen': proefperiodeDagen,
        'actief': actief,
      };

  String get geldigTotLabel {
    if (geldigTot == null) return 'Onbeperkt';
    return '${geldigTot!.day}-${geldigTot!.month}-${geldigTot!.year}';
  }

  String get proefperiodeLabel {
    if (proefperiodeDagen == 30) return '1 maand';
    if (proefperiodeDagen == 60) return '2 maanden';
    if (proefperiodeDagen == 14) return '2 weken';
    return '$proefperiodeDagen dagen';
  }
}
