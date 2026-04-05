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
    final cat = map['categories'] as Map<String, dynamic>?;
    final sub = map['sub_categories'] as Map<String, dynamic>?;
    final color = map['sub_colors'] as Map<String, dynamic>?;
    return ProveedorProductoPublic(
      id: map['id'] as String,
      sku: map['sku'] as String,
      precio: (map['precio'] as num).toDouble(),
      cantidad: (map['cantidad'] as int?) ?? 0,
      calidad: map['calidad'] as String?,
      presentacion: map['presentacion'] as String?,
      fotoUrl: map['foto_url'] as String?,
      categoryName: cat?['name'] as String?,
      categoryGroupName: cat?['group_name'] as String?,
      categoryImageUrl: cat?['image_url'] as String?,
      subCategoryName: sub?['name'] as String?,
      subCategoryImageUrl: sub?['image_url'] as String?,
      subColorName: color?['name'] as String?,
      subColorHex: color?['color'] as String?,
      subColorImageUrl: color?['image_url'] as String?,
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
  /// Incluye shop_name, logo_url y cuenta de productos activos.
  Future<List<ProveedorTienda>> getProveedoresActivos({
    String pais = 'mx',
  }) async {
    // 1. Obtener conteos por proveedor desde proveedor_productos
    final counts = await _db
        .from('proveedor_productos')
        .select('proveedor_id')
        .eq('is_active', true);

    // Agrupar conteos en Dart
    final countMap = <String, int>{};
    for (final r in counts) {
      final pid = r['proveedor_id'] as String;
      countMap[pid] = (countMap[pid] ?? 0) + 1;
    }

    if (countMap.isEmpty) return [];

    // 2. Fetch perfiles de esos proveedores
    final ids = countMap.keys.toList();
    final profiles = await _db
        .from('profiles')
        .select('id, shop_name, logo_url, can_be_proveedor, is_proveedor, role')
        .inFilter('id', ids);

    // 3. Fetch grupo más común por proveedor (categoría con más productos)
    final groupRows = await _db
        .from('proveedor_productos')
        .select('proveedor_id, categories(group_name)')
        .eq('is_active', true)
        .inFilter('proveedor_id', ids);

    // Mapa proveedor → grupo más frecuente
    final groupFreq = <String, Map<String, int>>{};
    for (final r in groupRows) {
      final pid = r['proveedor_id'] as String;
      final cat = r['categories'] as Map<String, dynamic>?;
      final gn = cat?['group_name'] as String? ?? '';
      if (gn.isEmpty) continue;
      groupFreq.putIfAbsent(pid, () => {});
      groupFreq[pid]![gn] = (groupFreq[pid]![gn] ?? 0) + 1;
    }

    String? _topGroup(String pid) {
      final freq = groupFreq[pid];
      if (freq == null || freq.isEmpty) return null;
      return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

    final result = <ProveedorTienda>[];
    for (final p in profiles) {
      final role = p['role'] as String? ?? '';
      final isProveedor = p['is_proveedor'] as bool? ?? false;
      final canBe = p['can_be_proveedor'] as bool? ?? false;
      // Solo proveedores autorizados
      if (role != 'proveedor' && !(isProveedor && canBe)) continue;

      final pid = p['id'] as String;
      result.add(ProveedorTienda(
        id: pid,
        shopName: p['shop_name'] as String? ?? 'Proveedor',
        logoUrl: p['logo_url'] as String?,
        groupName: _topGroup(pid),
        activeCount: countMap[pid] ?? 0,
      ));
    }

    // Ordenar por más activos primero
    result.sort((a, b) => b.activeCount.compareTo(a.activeCount));
    return result;
  }

  /// Devuelve los productos activos de un proveedor para vista pública.
  Future<List<ProveedorProductoPublic>> getProductosProveedor(
      String proveedorId) async {
    final rows = await _db
        .from('proveedor_productos')
        .select('''
          id, sku, precio, cantidad, calidad, presentacion, foto_url,
          categories(name, group_name, image_url),
          sub_categories(name, image_url),
          sub_colors(name, color, image_url)
        ''')
        .eq('proveedor_id', proveedorId)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return rows.map((r) => ProveedorProductoPublic.fromMap(r)).toList();
  }
}
