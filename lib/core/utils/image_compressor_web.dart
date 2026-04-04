import 'dart:typed_data';

/// Implementación web — NO comprime, devuelve bytes originales.
/// flutter_image_compress no funciona en web y su importación
/// puede interferir con blob URLs de ImagePicker.
Future<Uint8List> compressPlatform(
  Uint8List rawBytes, {
  required int maxWidth,
  required int maxHeight,
  required int quality,
}) async {
  return rawBytes;
}
