import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop_settings_model.dart';

class ShopSettingsRepository {
  final SupabaseClient _client;

  ShopSettingsRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  Future<ShopSettingsModel?> getSettings(String shopId) async {
    try {
      final response = await _client
          .from('shop_settings')
          .select('settings')
          .eq('shop_id', shopId)
          .maybeSingle();

      if (response == null || response['settings'] == null) {
        return ShopSettingsModel(storeHours: [], deliveryRanges: [], shippingRates: []);
      }
      final model = ShopSettingsModel.fromJson(response['settings'] as Map<String, dynamic>);
      debugPrint('[ShopSettings] getSettings: storeHours=${model.storeHours.length}');
      return model;
    } catch (e) {
      debugPrint('[ShopSettings] getSettings error: $e');
      return ShopSettingsModel(storeHours: [], deliveryRanges: [], shippingRates: []);
    }
  }

  Future<bool> updateSettings(String shopId, ShopSettingsModel settings) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId != shopId) {
      debugPrint('[ShopSettings] updateSettings: unauthorized (shopId=$shopId, uid=$currentUserId)');
      return false;
    }
    try {
      final json = settings.toJson();
      debugPrint('[ShopSettings] updateSettings: storeHours=${(json['store_hours'] as List).length}');
      await _client.from('shop_settings').upsert(
        {'shop_id': shopId, 'settings': json},
        onConflict: 'shop_id',
      );
      return true;
    } catch (e) {
      debugPrint('[ShopSettings] updateSettings error: $e');
      return false;
    }
  }
}
