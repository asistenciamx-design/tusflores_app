class InventoryItem {
  final String? id;
  final String listId;
  int sequenceNumber;
  String productName;
  String color;
  String quality;
  int quantity;

  InventoryItem({
    this.id,
    required this.listId,
    required this.sequenceNumber,
    required this.productName,
    this.color = '',
    this.quality = '',
    this.quantity = 1,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> m) => InventoryItem(
        id: m['id'] as String?,
        listId: m['list_id'] as String? ?? '',
        sequenceNumber: m['sequence_number'] as int? ?? 0,
        productName: m['product_name'] as String? ?? '',
        color: m['color'] as String? ?? '',
        quality: m['quality'] as String? ?? '',
        quantity: m['quantity'] as int? ?? 1,
      );

  Map<String, dynamic> toInsertMap(String listId) => {
        'list_id': listId,
        'sequence_number': sequenceNumber,
        'product_name': productName.trim(),
        'color': color.trim().isEmpty ? null : color.trim(),
        'quality': quality.trim().isEmpty ? null : quality.trim(),
        'quantity': quantity,
      };
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
      items: rawItems
          .map((e) => InventoryItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  int get itemCount => items.length;
}
