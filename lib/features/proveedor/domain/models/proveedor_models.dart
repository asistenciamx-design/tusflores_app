class ProveedorProducto {
  final String id;
  final String proveedorId;
  final String categoryId;
  final String? subCategoryId;
  final String? subColorId;
  final String sku;
  final double? precio;
  final int cantidad;
  final String? calidad;
  final String? presentacion;
  final String? fotoUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields from maestro catalog
  final String? categoryName;
  final String? categoryGroupName;
  final String? categoryImageUrl;
  final String? subCategoryName;
  final String? subColorName;
  final String? subColorHex;

  const ProveedorProducto({
    required this.id,
    required this.proveedorId,
    required this.categoryId,
    this.subCategoryId,
    this.subColorId,
    required this.sku,
    this.precio,
    required this.cantidad,
    this.calidad,
    this.presentacion,
    this.fotoUrl,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.categoryGroupName,
    this.categoryImageUrl,
    this.subCategoryName,
    this.subColorName,
    this.subColorHex,
  });

  factory ProveedorProducto.fromMap(Map<String, dynamic> map) {
    final cat = map['categories'] as Map<String, dynamic>?;
    final sub = map['sub_categories'] as Map<String, dynamic>?;
    final color = map['sub_colors'] as Map<String, dynamic>?;
    return ProveedorProducto(
      id: map['id'] as String,
      proveedorId: map['proveedor_id'] as String,
      categoryId: map['category_id'] as String,
      subCategoryId: map['sub_category_id'] as String?,
      subColorId: map['sub_color_id'] as String?,
      sku: map['sku'] as String,
      precio: (map['precio'] as num?)?.toDouble(),
      cantidad: (map['cantidad'] as int?) ?? 0,
      calidad: map['calidad'] as String?,
      presentacion: map['presentacion'] as String?,
      fotoUrl: map['foto_url'] as String?,
      isActive: map['is_active'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      categoryName: cat?['name'] as String?,
      categoryGroupName: cat?['group_name'] as String?,
      categoryImageUrl: cat?['image_url'] as String?,
      subCategoryName: sub?['name'] as String?,
      subColorName: color?['name'] as String?,
      subColorHex: color?['color'] as String?,
    );
  }

  String get displayName {
    final parts = <String>[categoryName ?? sku];
    if (subCategoryName != null) parts.add(subCategoryName!);
    if (subColorName != null) parts.add(subColorName!);
    return parts.join(' · ');
  }
}

class MaestroCategory {
  final String id;
  final String name;
  final String groupName;
  final String? imageUrl;
  final bool isActive;
  final List<MaestroSubCategory> subCategories;

  const MaestroCategory({
    required this.id,
    required this.name,
    required this.groupName,
    this.imageUrl,
    required this.isActive,
    this.subCategories = const [],
  });

  factory MaestroCategory.fromMap(Map<String, dynamic> map) => MaestroCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        groupName: map['group_name'] as String? ?? '',
        imageUrl: map['image_url'] as String?,
        isActive: map['is_active'] as bool? ?? true,
      );
}

class MaestroSubCategory {
  final String id;
  final String parentId;
  final String name;
  final String? color;
  final String? imageUrl;
  final bool isActive;
  final List<MaestroSubColor> subColors;

  const MaestroSubCategory({
    required this.id,
    required this.parentId,
    required this.name,
    this.color,
    this.imageUrl,
    required this.isActive,
    this.subColors = const [],
  });

  factory MaestroSubCategory.fromMap(Map<String, dynamic> map) =>
      MaestroSubCategory(
        id: map['id'] as String,
        parentId: map['parent_id'] as String,
        name: map['name'] as String,
        color: map['color'] as String?,
        imageUrl: map['image_url'] as String?,
        isActive: map['is_active'] as bool? ?? true,
      );
}

class MaestroSubColor {
  final String id;
  final String parentId;
  final String name;
  final String? color;
  final String? imageUrl;
  final bool isActive;

  const MaestroSubColor({
    required this.id,
    required this.parentId,
    required this.name,
    this.color,
    this.imageUrl,
    required this.isActive,
  });

  factory MaestroSubColor.fromMap(Map<String, dynamic> map) => MaestroSubColor(
        id: map['id'] as String,
        parentId: map['parent_id'] as String,
        name: map['name'] as String,
        color: map['color'] as String?,
        imageUrl: map['image_url'] as String?,
        isActive: map['is_active'] as bool? ?? true,
      );
}

/// Represents a selection in the Maestro screen before saving.
class MaestroSelection {
  final String categoryId;
  final String? subCategoryId;
  final String? subColorId;

  const MaestroSelection({
    required this.categoryId,
    this.subCategoryId,
    this.subColorId,
  });

  @override
  bool operator ==(Object other) =>
      other is MaestroSelection &&
      other.categoryId == categoryId &&
      other.subCategoryId == subCategoryId &&
      other.subColorId == subColorId;

  @override
  int get hashCode =>
      Object.hash(categoryId, subCategoryId, subColorId);
}
