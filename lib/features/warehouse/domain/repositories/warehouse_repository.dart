import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/warehouse_models.dart';

class WarehouseRepository {
  final _client = Supabase.instance.client;

  String get userId => _client.auth.currentUser!.id;

  static const _productSelect =
      '*, warehouse_categories(name), warehouse_purchases(*)';

  /// Extensiones de imagen permitidas.
  static const _allowedImageExt = {'jpg', 'jpeg', 'png', 'webp', 'gif'};

  /// Límites de validación numérica.
  static const _maxPrice = 999999.99;
  static const _maxStock = 999999;
  static const _maxTextLength = 500;

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
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > _maxTextLength) {
      throw Exception('Nombre de categoría inválido');
    }
    final data = await _client
        .from('warehouse_categories')
        .insert({'floreria_id': userId, 'name': trimmed})
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

  // VULN-1 fix: ownership check on getProduct
  Future<WarehouseProduct> getProduct(String productId) async {
    final data = await _client
        .from('warehouse_products')
        .select(_productSelect)
        .eq('id', productId)
        .eq('floreria_id', userId)
        .single();
    return WarehouseProduct.fromMap(Map<String, dynamic>.from(data));
  }

  Future<WarehouseProduct> createProduct(WarehouseProduct product) async {
    _validateProduct(product);
    final data = await _client
        .from('warehouse_products')
        .insert({...product.toInsertMap(), 'floreria_id': userId})
        .select(_productSelect)
        .single();
    return WarehouseProduct.fromMap(Map<String, dynamic>.from(data));
  }

  Future<WarehouseProduct> updateProduct(WarehouseProduct product) async {
    _validateProduct(product);
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
    if (newStock < 0 || newStock > _maxStock) {
      throw Exception('Stock fuera de rango permitido');
    }
    await _client.from('warehouse_products').update({
      'stock': newStock,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', productId).eq('floreria_id', userId);
  }

  // ── Historial de compras ──────────────────────────────────────────────────

  // VULN-4 fix: ownership check before updating stock
  Future<void> addPurchase({
    required String productId,
    required int quantity,
    double? unitPrice,
    String? supplierName,
    String? notes,
  }) async {
    if (quantity <= 0 || quantity > _maxStock) {
      throw Exception('Cantidad fuera de rango permitido');
    }
    if (unitPrice != null && (unitPrice < 0 || unitPrice > _maxPrice)) {
      throw Exception('Precio fuera de rango permitido');
    }

    await _client.from('warehouse_purchases').insert({
      'product_id': productId,
      'floreria_id': userId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'supplier_name': _sanitizeText(supplierName),
      'notes': _sanitizeText(notes),
    });

    // Verificar ownership antes de leer stock
    final product = await _client
        .from('warehouse_products')
        .select('stock')
        .eq('id', productId)
        .eq('floreria_id', userId)
        .maybeSingle();

    if (product == null) {
      throw Exception('Producto no encontrado');
    }

    final currentStock = product['stock'] as int? ?? 0;
    final newStock = currentStock + quantity;
    if (newStock > _maxStock) {
      throw Exception('Stock resultante excede el límite');
    }
    await updateStock(productId, newStock);
  }

  // ── Upload de imagen ──────────────────────────────────────────────────────

  // VULN-8 fix: validate extension against allowlist
  Future<String> uploadImage(Uint8List bytes, String ext) async {
    final normalizedExt = ext.toLowerCase();
    if (!_allowedImageExt.contains(normalizedExt)) {
      throw Exception('Extensión no permitida: $ext');
    }

    // Validar tamaño máximo (5 MB para warehouse)
    if (bytes.length > 5 * 1024 * 1024) {
      throw Exception('La imagen excede 5 MB');
    }

    // Validar magic bytes
    if (!_isValidImageBytes(bytes, normalizedExt)) {
      throw Exception('El archivo no es una imagen válida');
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$normalizedExt';
    final path = '$userId/$fileName';

    await _client.storage.from('warehouse').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$normalizedExt'),
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

  // ── Validación interna ────────────────────────────────────────────────────

  void _validateProduct(WarehouseProduct p) {
    if (p.name.trim().isEmpty || p.name.trim().length > _maxTextLength) {
      throw Exception('Nombre de producto inválido');
    }
    if (p.unitPrice < 0 || p.unitPrice > _maxPrice) {
      throw Exception('Precio fuera de rango permitido');
    }
    if (p.stock < 0 || p.stock > _maxStock) {
      throw Exception('Stock fuera de rango permitido');
    }
    if (p.minStock < 0 || p.minStock > _maxStock) {
      throw Exception('Stock mínimo fuera de rango permitido');
    }
    if (p.sku != null && p.sku!.length > 50) {
      throw Exception('SKU demasiado largo (máx 50)');
    }
    if (p.unit.trim().isEmpty || p.unit.length > 50) {
      throw Exception('Unidad inválida');
    }
    if (p.supplierName != null && p.supplierName!.length > _maxTextLength) {
      throw Exception('Nombre de proveedor demasiado largo');
    }
    if (p.notes != null && p.notes!.length > 1000) {
      throw Exception('Notas demasiado largas (máx 1000)');
    }
  }

  String? _sanitizeText(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final trimmed = text.trim();
    if (trimmed.length > _maxTextLength) return trimmed.substring(0, _maxTextLength);
    return trimmed;
  }

  bool _isValidImageBytes(List<int> bytes, String ext) {
    if (bytes.length < 4) return false;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
      case 'png':
        return bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
      case 'gif':
        return bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46;
      case 'webp':
        return bytes.length >= 12 &&
            bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
            bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50;
      default:
        return false;
    }
  }
}
