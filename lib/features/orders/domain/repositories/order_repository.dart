import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import 'dart:math';

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
      debugPrint('Error getting orders: $e');
      return [];
    }
  }

  // Create a new order
  Future<OrderModel> createOrder(OrderModel order) async {
    try {
      // Auto-generate folio if not exists
      final orderData = order.toJson();
      if (orderData['folio'] == null || orderData['folio'] == '#0000') {
         // Create a simple random 4 digit folio
         final random = Random().nextInt(9000) + 1000;
         orderData['folio'] = '#$random';
      }
      
      final response = await _supabase.from('orders').insert(orderData).select().single();
      return OrderModel.fromJson(response);
    } catch (e) {
      debugPrint('Error creating order: $e');
      throw e;
    }
  }

  // Update order status (pending/delivered/cancelled)
  Future<bool> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': newStatus.name})
          .eq('id', orderId);
      return true;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
    }
  }

  // Update payment status
  Future<bool> updatePaymentStatus(String orderId, bool isPaid, String? paymentMethod) async {
    try {
      await _supabase
          .from('orders')
          .update({
            'is_paid': isPaid,
            'payment_method': paymentMethod
          })
          .eq('id', orderId);
      return true;
    } catch (e) {
      debugPrint('Error updating payment status: $e');
      return false;
    }
  }

  // Update entire order (e.g. from the Edit Order screen)
  Future<bool> updateOrder(OrderModel order) async {
    if (order.id == null) return false;
    try {
      await _supabase
          .from('orders')
          .update(order.toJson())
          .eq('id', order.id!);
      return true;
    } catch (e) {
      debugPrint('Error updating order: $e');
      return false;
    }
  }
}
