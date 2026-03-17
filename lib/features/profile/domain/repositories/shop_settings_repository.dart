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
          .select('settings, currency_code, currency_symbol')
          .eq('shop_id', shopId)
          .maybeSingle();

      if (response == null || response['settings'] == null) {
        return ShopSettingsModel(storeHours: [], deliveryRanges: [], shippingRates: []);
      }
      final settingsJson = Map<String, dynamic>.from(response['settings'] as Map<String, dynamic>);
      // Merge top-level currency columns into the JSON so fromJson picks them up
      if (response['currency_code'] != null) settingsJson['currency_code'] = response['currency_code'];
      if (response['currency_symbol'] != null) settingsJson['currency_symbol'] = response['currency_symbol'];
      final model = ShopSettingsModel.fromJson(settingsJson);
      return model;
    } catch (e) {
      return ShopSettingsModel(storeHours: [], deliveryRanges: [], shippingRates: []);
    }
  }

  Future<bool> updateSettings(String shopId, ShopSettingsModel settings) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId != shopId) {
      return false;
    }
    try {
      final json = settings.toJson();
      await _client.from('shop_settings').upsert(
        {
          'shop_id': shopId,
          'settings': json,
          'currency_code': settings.currencyCode,
          'currency_symbol': settings.currencySymbol,
        },
        onConflict: 'shop_id',
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
