// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

/// Actualiza el JSON-LD de LocalBusiness en el <head> con datos reales de la florería.
/// Llamado desde _PublicStoreLoader una vez que se cargan los datos de Supabase.
void updateShopJsonLd({
  required String shopName,
  required double ratingValue,
  required int reviewCount,
  String? city,
}) {
  try {
    js.context.callMethod(
      'updateShopJsonLd',
      [shopName, ratingValue, reviewCount, city ?? ''],
    );
  } catch (e) {
  }
}
