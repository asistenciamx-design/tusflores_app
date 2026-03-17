class GiftItem {
  final String? id;
  final String? sku;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final bool isActive;

  GiftItem({
    this.id,
    this.sku,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.isActive = true,
  });

  factory GiftItem.fromJson(Map<String, dynamic> json) => GiftItem(
        id: json['id'],
        sku: json['sku'],
        name: json['name'] ?? '',
        description: json['description'],
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        imageUrl: json['image_url'],
        isActive: json['is_active'] ?? true,
      );

  /// Serializes this gift as a product line for the order JSON array.
  Map<String, dynamic> toOrderMap() => {
        'name': name,
        'sku': sku ?? '',
        'qty': 1,
        'price': price,
      };
}
