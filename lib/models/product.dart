class Product {
  final int id;
  final String naam;
  final String? webshopUrl;

  const Product({
    required this.id,
    required this.naam,
    this.webshopUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      naam: (json['naam'] as String?) ?? '',
      webshopUrl: json['webshop_url'] as String?,
    );
  }
}
