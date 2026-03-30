import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/repartidor_model.dart';

class RepartidorRepository {
  final SupabaseClient _db = Supabase.instance.client;

  String? get _uid => _db.auth.currentUser?.id;

  // ── CRUD repartidores ─────────────────────────────────────────────────────

  Future<List<RepartidorModel>> getRepartidores(String shopId) async {
    try {
      final rows = await _db
          .from('repartidores')
          .select()
          .eq('shop_id', shopId)
          .order('name');
      return rows.map((r) => RepartidorModel.fromJson(r)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<RepartidorModel?> createRepartidor(RepartidorModel model) async {
    if (_uid == null) return null;
    try {
      final row = await _db
          .from('repartidores')
          .insert(model.toJson())
          .select()
          .single();
      return RepartidorModel.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateRepartidor(RepartidorModel model) async {
    if (_uid == null || model.id == null) return false;
    try {
      await _db
          .from('repartidores')
          .update({
            'name': model.name,
            'vehicle_plates': model.vehiclePlates,
            'vehicle_name': model.vehicleName,
          })
          .eq('id', model.id!)
          .eq('shop_id', _uid!);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setStatus(String id, String status) async {
    if (_uid == null) return false;
    try {
      await _db
          .from('repartidores')
          .update({'status': status})
          .eq('id', id)
          .eq('shop_id', _uid!);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteRepartidor(String id) async {
    if (_uid == null) return false;
    try {
      await _db
          .from('repartidores')
          .delete()
          .eq('id', id)
          .eq('shop_id', _uid!);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Order assignment ──────────────────────────────────────────────────────

  /// Assigns (or removes) a repartidor to an order and optionally sets the
  /// delivery amount billed to the driver.
  Future<bool> assignToOrder({
    required String orderId,
    String? repartidorId,
    double? deliveryAmount,
    String? driverNotes,
  }) async {
    if (_uid == null) return false;
    try {
      await _db.from('orders').update({
        'repartidor_id': repartidorId,
        'delivery_amount': deliveryAmount,
        'driver_notes': driverNotes,
      }).eq('id', orderId).eq('shop_id', _uid!);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Historico ─────────────────────────────────────────────────────────────

  /// Returns all orders assigned to a repartidor within [from]–[to] (inclusive).
  Future<List<Map<String, dynamic>>> getHistoricoOrders({
    required String shopId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final rows = await _db
          .from('orders')
          .select(
              'id, folio, delivery_date, sale_date, delivery_city, delivery_state, '
              'delivery_location_type, repartidor_id, delivery_amount, driver_notes, '
              'customer_name, price, quantity, shipping_cost')
          .eq('shop_id', shopId)
          .not('repartidor_id', 'is', null)
          .gte('delivery_date', from.toIso8601String())
          .lte('delivery_date', to.add(const Duration(hours: 23, minutes: 59)).toIso8601String())
          .order('delivery_date', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }
}
