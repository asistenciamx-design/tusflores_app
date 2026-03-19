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

    // Top 5 shops by order count
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
    int sortOrder = 999,
  }) async {
    await _db.from('categories').insert({
      'name': name,
      'group_name': groupName,
      if (parentId != null) 'parent_id': parentId,
      'sort_order': sortOrder,
    });
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required String groupName,
  }) async {
    await _db.from('categories').update({
      'name': name,
      'group_name': groupName,
    }).eq('id', id);
  }

  Future<void> deleteCategory(String id) async {
    await _db.from('categories').delete().eq('id', id);
  }
}
