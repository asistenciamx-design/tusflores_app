import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/review_model.dart';

class ReviewRepository {
  final SupabaseClient _client;

  ReviewRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  /// Obtiene las reseñas visibles de una florería, ordenadas por más recientes.
  Future<List<ReviewModel>> getShopReviews(String shopId,
      {int limit = 20}) async {
    try {
      final rows = await _client
          .from('shop_reviews')
          .select()
          .eq('shop_id', shopId)
          .eq('is_visible', true)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List).map((r) => ReviewModel.fromJson(r)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Crea una nueva reseña. Devuelve true si fue exitosa.
  Future<bool> createReview(ReviewModel review) async {
    try {
      await _client.from('shop_reviews').insert(review.toJson());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Verifica si ya existe una reseña para un order_id dado.
  Future<bool> hasReviewForOrder(String orderId) async {
    try {
      final rows = await _client
          .from('shop_reviews')
          .select('id')
          .eq('order_id', orderId)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Responde a una reseña (solo la florería dueña).
  Future<bool> replyToReview(String reviewId, String reply) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      await _client
          .from('shop_reviews')
          .update({'shop_reply': reply})
          .eq('id', reviewId)
          .eq('shop_id', uid);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene TODAS las reseñas de una florería (visibles e invisibles).
  /// Solo debe llamarse desde la pantalla de gestión del dueño.
  Future<List<ReviewModel>> getAllShopReviews(String shopId) async {
    try {
      final rows = await _client
          .from('shop_reviews')
          .select()
          .eq('shop_id', shopId)
          .order('created_at', ascending: false);
      return (rows as List).map((r) => ReviewModel.fromJson(r)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Oculta/muestra una reseña (solo la florería dueña).
  Future<bool> setReviewVisibility(String reviewId, bool visible) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      await _client
          .from('shop_reviews')
          .update({'is_visible': visible})
          .eq('id', reviewId)
          .eq('shop_id', uid);
      return true;
    } catch (e) {
      return false;
    }
  }
}
