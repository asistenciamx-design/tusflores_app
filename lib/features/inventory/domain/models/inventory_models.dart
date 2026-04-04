class InventoryItem {
  final String? id;
  final String listId;
  int sequenceNumber;
  String productName;
  String color;
  String quality;
  String presentation;
  int quantity;
  double? unitPrice;

  InventoryItem({
    this.id,
    required this.listId,
    required this.sequenceNumber,
    required this.productName,
    this.color = '',
    this.quality = '',
    this.presentation = '',
    this.quantity = 1,
    this.unitPrice,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> m) => InventoryItem(
        id: m['id'] as String?,
        listId: m['list_id'] as String? ?? '',
        sequenceNumber: m['sequence_number'] as int? ?? 0,
        productName: m['product_name'] as String? ?? '',
        color: m['color'] as String? ?? '',
        quality: m['quality'] as String? ?? '',
        presentation: m['presentation'] as String? ?? '',
        quantity: m['quantity'] as int? ?? 1,
        unitPrice: (m['unit_price'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toInsertMap(String listId) => {
        'list_id': listId,
        'sequence_number': sequenceNumber,
        'product_name': productName.trim(),
        'color': color.trim().isEmpty ? null : color.trim(),
        'quality': quality.trim().isEmpty ? null : quality.trim(),
        'presentation': presentation.trim().isEmpty ? null : presentation.trim(),
        'quantity': quantity,
        'unit_price': unitPrice,
      };

  double get subtotal => (unitPrice ?? 0) * quantity;
}

class InventoryList {
  final String id;
  final String florerId;
  final String createdByUserId;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  bool isActive;
  bool isCompleted;
  final int? folio;
  String? supplierId;
  String? supplierName;
  List<InventoryItem> items;

  InventoryList({
    required this.id,
    required this.florerId,
    required this.createdByUserId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
    required this.isCompleted,
    this.folio,
    this.supplierId,
    this.supplierName,
    this.items = const [],
  });

  factory InventoryList.fromMap(Map<String, dynamic> m) {
    final rawItems = m['inventory_items'] as List<dynamic>? ?? [];
    return InventoryList(
      id: m['id'] as String,
      florerId: m['floreria_id'] as String? ?? '',
      createdByUserId: m['created_by_user_id'] as String? ?? '',
      title: m['title'] as String? ?? '',
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
      isActive: m['is_active'] as bool? ?? true,
      isCompleted: m['is_completed'] as bool? ?? false,
      folio: m['folio'] as int?,
      supplierId: m['supplier_id'] as String?,
      supplierName: m['supplier_name'] as String?,
      items: rawItems
          .map((e) => InventoryItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  int get itemCount => items.length;

  double get total => items.fold(0.0, (sum, item) => sum + item.subtotal);
}
