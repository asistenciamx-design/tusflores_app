import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final rows = await _db
        .from('profiles')
        .select('id, shop_name, whatsapp_number, created_at, average_rating, review_count')
        .eq('role', 'shop_owner')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
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
    await _db.from('category_groups').insert({'name': name.trim()});
  }

  // ── Categories CRUD ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCategories() async {
    final rows = await _db
        .from('categories')
        .select()
        .order('group_name')
        .order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> createCategory({
    required String name,
    required String groupName,
    String? parentId,
    String? imageUrl,
    int sortOrder = 999,
  }) async {
    await _db.from('categories').insert({
      'name': name,
      'group_name': groupName,
      if (parentId != null) 'parent_id': parentId,
      if (imageUrl != null) 'image_url': imageUrl,
      'sort_order': sortOrder,
    });
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required String groupName,
    String? imageUrl,
    bool clearImage = false,
  }) async {
    await _db.from('categories').update({
      'name': name,
      'group_name': groupName,
      if (clearImage) 'image_url': null else if (imageUrl != null) 'image_url': imageUrl,
    }).eq('id', id);
  }

  Future<void> deleteCategory(String id) async {
    await _db.from('categories').delete().eq('id', id);
  }

  // ── Category image upload ───────────────────────────────────────────────────

  Future<String> uploadCategoryImage(XFile file) async {
    const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};
    final ext = file.name.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      throw Exception('Tipo de archivo no permitido: .$ext');
    }

    final bytes = await file.readAsBytes();

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
      default:
        return false;
    }
  }
}
