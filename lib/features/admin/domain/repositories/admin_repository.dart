import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/image_compressor.dart';

class AdminRepository {
  final _db = Supabase.instance.client;

  // ── Auth ────────────────────────────────────────────────────────────────────

  Future<bool> isSuperAdmin() async {
    try {
      final user = _db.auth.currentUser;
      if (user == null) return false;
      final row = await _db
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      return row?['role'] == 'super_admin';
    } catch (_) {
      return false;
    }
  }

  // ── Global metrics ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getGlobalMetrics() async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    final shops = await _db
        .from('profiles')
        .select('id')
        .eq('role', 'shop_owner');

    final orders = await _db
        .from('orders')
        .select('price, is_paid, created_at, shop_id');

    final totalShops = shops.length;
    final totalOrders = orders.length;

    final totalRevenue = orders
        .where((o) => o['is_paid'] == true)
        .fold<double>(0, (sum, o) => sum + ((o['price'] as num?)?.toDouble() ?? 0));

    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentOrders = orders.where((o) {
      final created = DateTime.tryParse(o['created_at'] as String? ?? '');
      return created != null && created.isAfter(weekAgo);
    }).length;

    final shopOrderCounts = <String, int>{};
    for (final o in orders) {
      final sid = o['shop_id'] as String? ?? '';
      shopOrderCounts[sid] = (shopOrderCounts[sid] ?? 0) + 1;
    }

    return {
      'total_shops': totalShops,
      'total_orders': totalOrders,
      'total_revenue': totalRevenue,
      'recent_orders': recentOrders,
      'shop_order_counts': shopOrderCounts,
    };
  }

  // ── Shops ───────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllShops() async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    final rows = await _db
        .from('profiles')
        .select('id, shop_name, whatsapp_number, created_at, average_rating, review_count, can_be_proveedor')
        .eq('role', 'shop_owner')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> toggleCanBeProveedor(String shopId, {required bool value}) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    // Si se desactiva el permiso, también apagar is_proveedor para cerrar la segunda puerta.
    final update = <String, dynamic>{'can_be_proveedor': value};
    if (!value) update['is_proveedor'] = false;
    await _db.from('profiles').update(update).eq('id', shopId);
  }

  // ── Groups CRUD ─────────────────────────────────────────────────────────────

  Future<List<String>> getGroups() async {
    final rows = await _db
        .from('category_groups')
        .select('name')
        .order('sort_order')
        .order('name');
    return (rows as List).map((r) => r['name'] as String).toList();
  }

  Future<void> createGroup(String name) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    await _db.from('category_groups').insert({'name': name.trim()});
  }

  // ── Categories CRUD ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCategories() async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    final rows = await _db
        .from('categories')
        .select()
        .order('group_name')
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> toggleCategoryActive(String id, {required bool isActive}) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    await _db
        .from('categories')
        .update({'is_active': isActive})
        .eq('id', id);
  }

  Future<void> createCategory({
    required String name,
    required String groupName,
    String? parentId,
    String? imageUrl,
    String? bio,
    int sortOrder = 999,
  }) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    await _db.from('categories').insert({
      'name': name,
      'group_name': groupName,
      if (parentId != null) 'parent_id': parentId,
      if (imageUrl != null) 'image_url': imageUrl,
      if (bio != null) 'bio': bio,
      'sort_order': sortOrder,
    });
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required String groupName,
    String? imageUrl,
    bool clearImage = false,
    String? parentId,
    bool clearParent = false,
    String? bio,
  }) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    await _db.from('categories').update({
      'name': name,
      'group_name': groupName,
      if (clearImage) 'image_url': null else if (imageUrl != null) 'image_url': imageUrl,
      if (clearParent) 'parent_id': null else if (parentId != null) 'parent_id': parentId,
      'bio': bio,
    }).eq('id', id);
  }

  Future<void> deleteCategory(String id) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    await _db.from('categories').delete().eq('id', id);
  }

  // ── Sub-categories (variantes) CRUD ─────────────────────────────────────────

  /// Obtiene todas las sub-categorías de una flor principal.
  Future<List<Map<String, dynamic>>> getSubCategories(String parentId) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    final rows = await _db
        .from('sub_categories')
        .select()
        .eq('parent_id', parentId)
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Conteo de sub-categorías por parent_id (para badges en la lista).
  Future<Map<String, int>> getSubCategoryCounts() async {
    final rows = await _db
        .from('sub_categories')
        .select('parent_id');
    final counts = <String, int>{};
    for (final r in rows) {
      final pid = r['parent_id'] as String?;
      if (pid != null) counts[pid] = (counts[pid] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> createSubCategory({
    required String parentId,
    required String name,
    String? color,
    String? imageUrl,
    String? bio,
  }) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    await _db.from('sub_categories').insert({
      'parent_id': parentId,
      'name': name,
      if (color != null && color.isNotEmpty) 'color': color,
      if (imageUrl != null) 'image_url': imageUrl,
      if (bio != null) 'bio': bio,
    });
  }

  Future<void> updateSubCategory({
    required String id,
    required String name,
    String? color,
    bool clearColor = false,
    String? imageUrl,
    bool clearImage = false,
    String? bio,
  }) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    await _db.from('sub_categories').update({
      'name': name,
      if (clearColor) 'color': null else if (color != null && color.isNotEmpty) 'color': color,
      if (clearImage) 'image_url': null else if (imageUrl != null) 'image_url': imageUrl,
      'bio': bio,
    }).eq('id', id);
  }

  Future<void> deleteSubCategory(String id) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    await _db.from('sub_categories').delete().eq('id', id);
  }

  Future<void> toggleSubCategoryActive(String id, {required bool isActive}) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    await _db
        .from('sub_categories')
        .update({'is_active': isActive})
        .eq('id', id);
  }

  // ── Sub-colors (tonos) CRUD ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSubColors(String parentId) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    final rows = await _db
        .from('sub_colors')
        .select()
        .eq('parent_id', parentId)
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, int>> getSubColorCounts() async {
    final rows = await _db
        .from('sub_colors')
        .select('parent_id');
    final counts = <String, int>{};
    for (final r in rows) {
      final pid = r['parent_id'] as String?;
      if (pid != null) counts[pid] = (counts[pid] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> createSubColor({
    required String parentId,
    required String name,
    String? color,
    String? imageUrl,
  }) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    await _db.from('sub_colors').insert({
      'parent_id': parentId,
      'name': name,
      if (color != null && color.isNotEmpty) 'color': color,
      if (imageUrl != null) 'image_url': imageUrl,
    });
  }

  Future<void> updateSubColor({
    required String id,
    required String name,
    String? color,
    bool clearColor = false,
    String? imageUrl,
    bool clearImage = false,
  }) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    await _db.from('sub_colors').update({
      'name': name,
      if (clearColor) 'color': null else if (color != null && color.isNotEmpty) 'color': color,
      if (clearImage) 'image_url': null else if (imageUrl != null) 'image_url': imageUrl,
    }).eq('id', id);
  }

  Future<void> deleteSubColor(String id) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    await _db.from('sub_colors').delete().eq('id', id);
  }

  // ── Reasignación (mover a otro padre) ───────────────────────────────────────

  /// Mueve una variante (sub_category) a otra flor (category).
  Future<void> moveSubCategory(String id, String newParentId) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    await _db.from('sub_categories').update({'parent_id': newParentId}).eq('id', id);
  }

  /// Mueve un tono (sub_color) a otra variante (sub_category).
  Future<void> moveSubColor(String id, String newParentId) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    await _db.from('sub_colors').update({'parent_id': newParentId}).eq('id', id);
  }

  // ── Category image upload ───────────────────────────────────────────────────

  Future<String> uploadCategoryImage(XFile file) async {
    if (!await isSuperAdmin()) throw Exception('No autorizado');
    const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
    final origExt = file.name.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(origExt)) {
      throw Exception('Tipo de archivo no permitido: .$origExt');
    }

    // Read bytes immediately to avoid blob URL expiration on web
    final rawBytes = Uint8List.fromList(await file.readAsBytes());

    // Comprimir y convertir a WebP (excepto si ya es .webp)
    final compressed = await ImageCompressor.compressBytes(rawBytes, file.name);
    final bytes = compressed.bytes;
    final ext = compressed.ext;

    const maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
    if (bytes.length > maxFileSizeBytes) {
      throw Exception('El archivo es demasiado grande. Máximo: 5 MB');
    }

    if (!_isValidImageBytes(bytes, ext)) {
      throw Exception('El archivo no es una imagen válida.');
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _db.storage.from('category_images').uploadBinary(
      fileName,
      bytes,
      fileOptions: FileOptions(contentType: 'image/$ext'),
    );
    return _db.storage.from('category_images').getPublicUrl(fileName);
  }

  bool _isValidImageBytes(List<int> bytes, String ext) {
    if (bytes.length < 4) return false;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
      case 'png':
        return bytes[0] == 0x89 && bytes[1] == 0x50 &&
               bytes[2] == 0x4E && bytes[3] == 0x47;
      case 'webp':
        return bytes.length >= 12 &&
               bytes[0] == 0x52 && bytes[1] == 0x49 &&
               bytes[2] == 0x46 && bytes[3] == 0x46 &&
               bytes[8] == 0x57 && bytes[9] == 0x45 &&
               bytes[10] == 0x42 && bytes[11] == 0x50;
      case 'heic':
      case 'heif':
        // HEIC/HEIF: ftyp box — bytes 4-7 = 'ftyp'
        return bytes.length >= 8 &&
               bytes[4] == 0x66 && bytes[5] == 0x74 &&
               bytes[6] == 0x79 && bytes[7] == 0x70;
      default:
        return false;
    }
  }
}
