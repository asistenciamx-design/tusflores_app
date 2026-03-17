import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
class OrderRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Real-time stream of orders for a specific shop
  Stream<List<OrderModel>> getOrdersStream(String shopId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('shop_id', shopId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => OrderModel.fromJson(json)).toList());
  }

  // Get orders as a future
  Future<List<OrderModel>> getOrders(String shopId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .eq('shop_id', shopId)
          .order('created_at', ascending: false);
      
      return response.map((json) => OrderModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  // Create a new order
  Future<OrderModel> createOrder(OrderModel order) async {
    try {
      final orderData = order.toJson();
      // Folio assigned server-side by trg_assign_order_folio trigger (VULN-12 fix)
      final response = await _supabase.from('orders').insert(orderData).select().single();
      return OrderModel.fromJson(response);
    } catch (e) {
      throw e;
    }
  }

  // Update order status (pending/delivered/cancelled)
  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      await _supabase
          .from('orders')
          .update({'status': newStatus.dbValue})
          .eq('id', orderId)
          .eq('shop_id', uid);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Update payment status
  Future<bool> updatePaymentStatus(String orderId, bool isPaid, String? paymentMethod) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      await _supabase
          .from('orders')
          .update({
            'is_paid': isPaid,
            'payment_method': paymentMethod
          })
          .eq('id', orderId)
          .eq('shop_id', uid);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Upload a single order photo to Storage and return the public URL.
  // path: order-photos/{shopId}/{orderId}/{index}.jpg
  Future<String?> uploadOrderPhoto(
      String shopId, String orderId, int index, Uint8List bytes) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final path = '$shopId/$orderId/$index.jpg';
      await _supabase.storage.from('order-photos').uploadBinary(
            path,
            bytes,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      return _supabase.storage.from('order-photos').getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  // Persist the list of completion photo URLs to the orders table.
  Future<bool> updateCompletionPhotos(
      String orderId, List<String> photoUrls) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      await _supabase
          .from('orders')
          .update({'completion_photos': photoUrls})
          .eq('id', orderId)
          .eq('shop_id', uid);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Update entire order (e.g. from the Edit Order screen)
  Future<bool> updateOrder(OrderModel order) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null || order.id == null) return false;
    try {
      await _supabase
          .from('orders')
          .update(order.toJson())
          .eq('id', order.id!)
          .eq('shop_id', uid);
      return true;
    } catch (e) {
      return false;
    }
  }
}
