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
        // Return a model with empty lists if not found
        return ShopSettingsModel(storeHours: [], deliveryRanges: [], shippingRates: []);
      }
      return ShopSettingsModel.fromJson(response['settings'] as Map<String, dynamic>);
    } catch (e) {
      print('Error en getSettings: \$e');
      return ShopSettingsModel(storeHours: [], deliveryRanges: [], shippingRates: []);
    }
  }

  Future<bool> updateSettings(String shopId, ShopSettingsModel settings) async {
    try {
      await _client.from('shop_settings').upsert({
        'shop_id': shopId,
        'settings': settings.toJson(),
      });
      return true;
    } catch (e) {
      print('Error en updateSettings: \$e');
      return false;
    }
  }
}
