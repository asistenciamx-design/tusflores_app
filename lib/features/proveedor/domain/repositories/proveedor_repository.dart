import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/proveedor_models.dart';

class ProveedorRepository {
  final _db = Supabase.instance.client;

  String get _uid => _db.auth.currentUser!.id;

  // ── Maestro catalog (read-only, no admin check needed — public read) ─────────

  Future<List<MaestroCategory>> getMaestroCategories() async {
    final rows = await _db
        .from('categories')
        .select('id, name, group_name, image_url, is_active')
        .eq('is_active', true)
        .order('group_name')
        .order('name');
    return rows.map((r) => MaestroCategory.fromMap(r)).toList();
  }

  Future<List<MaestroSubCategory>> getMaestroSubCategories(
      String categoryId) async {
    final rows = await _db
        .from('sub_categories')
        .select('id, parent_id, name, color, image_url, is_active')
        .eq('parent_id', categoryId)
        .eq('is_active', true)
        .order('name');
    return rows.map((r) => MaestroSubCategory.fromMap(r)).toList();
  }

  Future<List<MaestroSubColor>> getMaestroSubColors(
      String subCategoryId) async {
    final rows = await _db
        .from('sub_colors')
        .select('id, parent_id, name, color, is_active')
        .eq('parent_id', subCategoryId)
        .eq('is_active', true)
        .order('name');
    return rows.map((r) => MaestroSubColor.fromMap(r)).toList();
  }

  // ── Mi Catálogo ─────────────────────────────────────────────────────────────

  Future<List<ProveedorProducto>> getMisProductos() async {
    final rows = await _db
        .from('proveedor_productos')
        .select('''
          *,
          categories(name, group_name, image_url),
          sub_categories(name),
          sub_colors(name, color)
        ''')
        .eq('proveedor_id', _uid)
        .order('created_at', ascending: false);
    return rows.map((r) => ProveedorProducto.fromMap(r)).toList();
  }

  /// Returns the set of (categoryId, subCategoryId, subColorId) already in
  /// proveedor's catalog — used to mark items in Maestro as "already added".
  Future<Set<MaestroSelection>> getMisSelecciones() async {
    final rows = await _db
        .from('proveedor_productos')
        .select('category_id, sub_category_id, sub_color_id')
        .eq('proveedor_id', _uid);
    return rows
        .map((r) => MaestroSelection(
              categoryId: r['category_id'] as String,
              subCategoryId: r['sub_category_id'] as String?,
              subColorId: r['sub_color_id'] as String?,
            ))
        .toSet();
  }

  /// Add one or more products from Maestro in bulk.
  Future<void> addProductosFromMaestro(
      List<MaestroSelection> selections) async {
    for (final sel in selections) {
      // Get next SKU
      final sku = await _getNextSku();
      await _db.from('proveedor_productos').insert({
        'proveedor_id': _uid,
        'category_id': sel.categoryId,
        if (sel.subCategoryId != null) 'sub_category_id': sel.subCategoryId,
        if (sel.subColorId != null) 'sub_color_id': sel.subColorId,
        'sku': sku,
      });
    }
  }

  Future<String> _getNextSku() async {
    final result = await _db.rpc(
      'get_next_proveedor_producto_sku',
      params: {'p_proveedor_id': _uid},
    );
    return result as String;
  }

  Future<void> updateProducto({
    required String id,
    double? precio,
    int? cantidad,
    String? calidad,
    String? presentacion,
    String? fotoUrl,
    bool clearFoto = false,
  }) async {
    await _db.from('proveedor_productos').update({
      if (precio != null) 'precio': precio,
      if (cantidad != null) 'cantidad': cantidad,
      if (calidad != null) 'calidad': calidad,
      if (presentacion != null) 'presentacion': presentacion,
      if (clearFoto) 'foto_url': null else if (fotoUrl != null) 'foto_url': fotoUrl,
    }).eq('id', id).eq('proveedor_id', _uid);
  }

  Future<void> removeProducto(String id) async {
    await _db
        .from('proveedor_productos')
        .delete()
        .eq('id', id)
        .eq('proveedor_id', _uid);
  }

  // ── Photo upload ─────────────────────────────────────────────────────────────

  Future<String> uploadFoto({
    required Uint8List rawBytes,
    required String ext,
  }) async {
    final storageName = 'proveedor/$_uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage.from('product-images').uploadBinary(
          storageName,
          rawBytes,
          fileOptions: FileOptions(
            contentType: 'image/$ext',
            upsert: true,
          ),
        );
    return _db.storage.from('product-images').getPublicUrl(storageName);
  }
}
