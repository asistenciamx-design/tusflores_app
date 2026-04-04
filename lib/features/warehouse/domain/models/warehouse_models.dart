class WarehouseCategory {
  final String id;
  final String floreriaId;
  final String name;
  final int sortOrder;

  const WarehouseCategory({
    required this.id,
    required this.floreriaId,
    required this.name,
    this.sortOrder = 0,
  });

  factory WarehouseCategory.fromMap(Map<String, dynamic> m) => WarehouseCategory(
        id: m['id'] as String,
        floreriaId: m['floreria_id'] as String,
        name: m['name'] as String? ?? '',
        sortOrder: m['sort_order'] as int? ?? 0,
      );
}

class WarehouseProduct {
  final String id;
  final String floreriaId;
  String? categoryId;
  String name;
  String? sku;
  String unit;
  double unitPrice;
  int stock;
  int minStock;
  String? imageUrl;
  String? supplierName;
  String? notes;
  bool isActive;
  bool lowStockAlert;
  final DateTime createdAt;
  DateTime updatedAt;
  // Joined
  String? categoryName;
  List<WarehousePurchase> purchases;

  WarehouseProduct({
    required this.id,
    required this.floreriaId,
    this.categoryId,
    required this.name,
    this.sku,
    this.unit = 'unidad',
    this.unitPrice = 0,
    this.stock = 0,
    this.minStock = 0,
    this.imageUrl,
    this.supplierName,
    this.notes,
    this.isActive = true,
    this.lowStockAlert = true,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.purchases = const [],
  });

  factory WarehouseProduct.fromMap(Map<String, dynamic> m) {
    final rawPurchases = m['warehouse_purchases'] as List<dynamic>? ?? [];
    final cat = m['warehouse_categories'] as Map<String, dynamic>?;
    return WarehouseProduct(
      id: m['id'] as String,
      floreriaId: m['floreria_id'] as String,
      categoryId: m['category_id'] as String?,
      name: m['name'] as String? ?? '',
      sku: m['sku'] as String?,
      unit: m['unit'] as String? ?? 'unidad',
      unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0,
      stock: m['stock'] as int? ?? 0,
      minStock: m['min_stock'] as int? ?? 0,
      imageUrl: m['image_url'] as String?,
      supplierName: m['supplier_name'] as String?,
      notes: m['notes'] as String?,
      isActive: m['is_active'] as bool? ?? true,
      lowStockAlert: m['low_stock_alert'] as bool? ?? true,
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
      categoryName: cat?['name'] as String? ??
          (m['category_id'] != null ? 'Sin categoría' : null),
      purchases: rawPurchases
          .map((e) => WarehousePurchase.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => b.purchasedAt.compareTo(a.purchasedAt)),
    );
  }

  bool get isLowStock => stock <= minStock && minStock > 0;

  Map<String, dynamic> toInsertMap() => {
        'floreria_id': floreriaId,
        'category_id': categoryId,
        'name': name.trim(),
        'sku': sku?.trim().isEmpty == true ? null : sku?.trim(),
        'unit': unit.trim(),
        'unit_price': unitPrice,
        'stock': stock,
        'min_stock': minStock,
        'image_url': imageUrl,
        'supplier_name': supplierName?.trim().isEmpty == true ? null : supplierName?.trim(),
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        'is_active': isActive,
        'low_stock_alert': lowStockAlert,
      };

  Map<String, dynamic> toUpdateMap() => {
        'category_id': categoryId,
        'name': name.trim(),
        'sku': sku?.trim().isEmpty == true ? null : sku?.trim(),
        'unit': unit.trim(),
        'unit_price': unitPrice,
        'stock': stock,
        'min_stock': minStock,
        'image_url': imageUrl,
        'supplier_name': supplierName?.trim().isEmpty == true ? null : supplierName?.trim(),
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        'is_active': isActive,
        'low_stock_alert': lowStockAlert,
        'updated_at': DateTime.now().toIso8601String(),
      };
}

class WarehousePurchase {
  final String id;
  final String productId;
  final int quantity;
  final double? unitPrice;
  final String? supplierName;
  final DateTime purchasedAt;
  final String? notes;

  const WarehousePurchase({
    required this.id,
    required this.productId,
    required this.quantity,
    this.unitPrice,
    this.supplierName,
    required this.purchasedAt,
    this.notes,
  });

  factory WarehousePurchase.fromMap(Map<String, dynamic> m) => WarehousePurchase(
        id: m['id'] as String,
        productId: m['product_id'] as String,
        quantity: m['quantity'] as int? ?? 0,
        unitPrice: (m['unit_price'] as num?)?.toDouble(),
        supplierName: m['supplier_name'] as String?,
        purchasedAt: DateTime.parse(m['purchased_at'] as String),
        notes: m['notes'] as String?,
      );
}
