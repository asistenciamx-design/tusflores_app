import '../../../features/profile/domain/models/shop_settings_model.dart';

/// Lightweight static cache for the authenticated florist's currency config.
/// Populated whenever any florist screen loads [ShopSettingsModel].
/// Customer-facing screens should read currency directly from their loaded
/// [ShopSettingsModel] instead of using this cache.
class CurrencyCache {
  static String symbol = r'$';
  static String code = 'MXN';

  static void update(ShopSettingsModel? s) {
    symbol = s?.currencySymbol ?? r'$';
    code   = s?.currencyCode   ?? 'MXN';
  }
}
