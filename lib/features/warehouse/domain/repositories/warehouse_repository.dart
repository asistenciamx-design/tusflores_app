import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/warehouse_models.dart';

class WarehouseRepository {
  final _client = Supabase.instance.client;

  String get userId => _client.auth.currentUser!.id;

  static const _productSelect =
      '*, warehouse_categories(name), warehouse_purchases(*)';

  // ── Categorías ────────────────────────────────────────────────────────────

  Future<List<WarehouseCategory>> getCategories() async {
    final data = await _client
        .from('warehouse_categories')
        .select()
        .eq('floreria_id', userId)
        .order('sort_order', ascending: true);
    return (data as List)
        .map((e) => WarehouseCategory.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<WarehouseCategory> createCategory(String name) async {
    final data = await _client
        .from('warehouse_categories')
        .insert({'floreria_id': userId, 'name': name.trim()})
        .select()
        .single();
    return WarehouseCategory.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> deleteCategory(String categoryId) async {
    await _client
        .from('warehouse_categories')
        .delete()
        .eq('id', categoryId)
        .eq('floreria_id', userId);
  }

  // ── Productos ─────────────────────────────────────────────────────────────

  Future<List<WarehouseProduct>> getProducts({String? categoryId}) async {
    var query = _client
        .from('warehouse_products')
        .select(_productSelect)
        .eq('floreria_id', userId);

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    final data = await query.order('name', ascending: true);
    return (data as List)
        .map((e) => WarehouseProduct.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<WarehouseProduct> getProduct(String productId) async {
    final data = await _client
        .from('warehouse_products')
        .select(_productSelect)
        .eq('id', productId)
        .single();
    return WarehouseProduct.fromMap(Map<String, dynamic>.from(data));
  }

  Future<WarehouseProduct> createProduct(WarehouseProduct product) async {
    final data = await _client
        .from('warehouse_products')
        .insert({...product.toInsertMap(), 'floreria_id': userId})
        .select(_productSelect)
        .single();
    return WarehouseProduct.fromMap(Map<String, dynamic>.from(data));
  }

  Future<WarehouseProduct> updateProduct(WarehouseProduct product) async {
    final data = await _client
        .from('warehouse_products')
        .update(product.toUpdateMap())
        .eq('id', product.id)
        .eq('floreria_id', userId)
        .select(_productSelect)
        .single();
    return WarehouseProduct.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> deleteProduct(String productId) async {
    await _client
        .from('warehouse_products')
        .delete()
        .eq('id', productId)
        .eq('floreria_id', userId);
  }

  Future<void> updateStock(String productId, int newStock) async {
    await _client.from('warehouse_products').update({
      'stock': newStock,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', productId).eq('floreria_id', userId);
  }

  // ── Historial de compras ──────────────────────────────────────────────────

  Future<void> addPurchase({
    required String productId,
    required int quantity,
    double? unitPrice,
    String? supplierName,
    String? notes,
  }) async {
    await _client.from('warehouse_purchases').insert({
      'product_id': productId,
      'floreria_id': userId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'supplier_name': supplierName,
      'notes': notes,
    });

    // Actualizar stock del producto
    final product = await _client
        .from('warehouse_products')
        .select('stock')
        .eq('id', productId)
        .single();
    final currentStock = product['stock'] as int? ?? 0;
    await updateStock(productId, currentStock + quantity);
  }

  // ── Upload de imagen ──────────────────────────────────────────────────────

  Future<String> uploadImage(Uint8List bytes, String ext) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final path = '$userId/$fileName';

    await _client.storage.from('warehouse').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext'),
        );
    return _client.storage.from('warehouse').getPublicUrl(path);
  }

  // ── Estadísticas rápidas ──────────────────────────────────────────────────

  Future<Map<String, int>> getStats() async {
    final data = await _client
        .from('warehouse_products')
        .select('stock, min_stock, is_active')
        .eq('floreria_id', userId);

    int total = 0;
    int active = 0;
    int critical = 0;
    for (final row in (data as List)) {
      total++;
      final isActive = row['is_active'] as bool? ?? true;
      final stock = row['stock'] as int? ?? 0;
      final minStock = row['min_stock'] as int? ?? 0;
      if (isActive) active++;
      if (minStock > 0 && stock <= minStock) critical++;
    }
    return {'total': total, 'active': active, 'critical': critical};
  }
}
