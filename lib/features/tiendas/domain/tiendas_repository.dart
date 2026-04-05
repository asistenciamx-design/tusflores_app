import 'package:supabase_flutter/supabase_flutter.dart';

class ProveedorTienda {
  final String id;
  final String shopName;
  final String? logoUrl;
  final String? groupName; // grupo principal del catálogo (Flores, Follajes…)
  final int activeCount;   // productos activos en proveedor_productos

  const ProveedorTienda({
    required this.id,
    required this.shopName,
    this.logoUrl,
    this.groupName,
    required this.activeCount,
  });
}

class ProveedorProductoPublic {
  final String id;
  final String sku;
  final double precio;
  final int cantidad;
  final String? calidad;
  final String? presentacion;
  final String? fotoUrl;
  final String? categoryName;
  final String? categoryGroupName;
  final String? categoryImageUrl;
  final String? subCategoryName;
  final String? subCategoryImageUrl;
  final String? subColorName;
  final String? subColorHex;
  final String? subColorImageUrl;

  const ProveedorProductoPublic({
    required this.id,
    required this.sku,
    required this.precio,
    required this.cantidad,
    this.calidad,
    this.presentacion,
    this.fotoUrl,
    this.categoryName,
    this.categoryGroupName,
    this.categoryImageUrl,
    this.subCategoryName,
    this.subCategoryImageUrl,
    this.subColorName,
    this.subColorHex,
    this.subColorImageUrl,
  });

  factory ProveedorProductoPublic.fromMap(Map<String, dynamic> map) {
    return ProveedorProductoPublic(
      id: map['id'] as String,
      sku: map['sku'] as String,
      precio: (map['precio'] as num).toDouble(),
      cantidad: (map['cantidad'] as int?) ?? 0,
      calidad: map['calidad'] as String?,
      presentacion: map['presentacion'] as String?,
      fotoUrl: map['foto_url'] as String?,
      categoryName: map['category_name'] as String?,
      categoryGroupName: map['category_group_name'] as String?,
      categoryImageUrl: map['category_image_url'] as String?,
      subCategoryName: map['sub_category_name'] as String?,
      subCategoryImageUrl: map['sub_category_image_url'] as String?,
      subColorName: map['sub_color_name'] as String?,
      subColorHex: map['sub_color_hex'] as String?,
      subColorImageUrl: map['sub_color_image_url'] as String?,
    );
  }

  String get displayName {
    final parts = <String>[categoryName ?? sku];
    if (subCategoryName != null) parts.add(subCategoryName!);
    if (subColorName != null) parts.add(subColorName!);
    return parts.join(' · ');
  }

  /// Mejor imagen disponible: foto propia > sub-color > sub-categoría > categoría
  String? get bestImageUrl =>
      fotoUrl ?? subColorImageUrl ?? subCategoryImageUrl ?? categoryImageUrl;
}

class TiendasRepository {
  final _db = Supabase.instance.client;

  /// Devuelve proveedores con al menos 1 producto activo.
  /// Usa RPC con SECURITY DEFINER para acceso público (anon).
  Future<List<ProveedorTienda>> getProveedoresActivos() async {
    final data = await _db.rpc('get_proveedores_tienda');
    final list = (data as List).cast<Map<String, dynamic>>();
    return list
        .map((r) => ProveedorTienda(
              id: r['id'] as String,
              shopName: r['shop_name'] as String? ?? 'Proveedor',
              logoUrl: r['logo_url'] as String?,
              groupName: r['group_name'] as String?,
              activeCount: r['active_count'] as int,
            ))
        .toList();
  }

  /// Devuelve los productos activos de un proveedor para vista pública.
  /// Usa RPC con SECURITY DEFINER para acceso público (anon).
  Future<List<ProveedorProductoPublic>> getProductosProveedor(
      String proveedorId) async {
    final data = await _db.rpc('get_productos_proveedor',
        params: {'p_proveedor_id': proveedorId});
    final list = (data as List).cast<Map<String, dynamic>>();
    return list.map((r) => ProveedorProductoPublic.fromMap(r)).toList();
  }
}
