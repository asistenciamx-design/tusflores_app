import 'dart:typed_data';

import 'image_compressor_stub.dart'
    if (dart.library.html) 'image_compressor_web.dart'
    if (dart.library.io) 'image_compressor_native.dart' as platform;

/// Comprime imágenes PNG/JPG a WebP antes de subir (solo nativo).
///
/// ⚠️  IMPORTANTE — NO MODIFICAR SIN LEER ESTO:
/// En Flutter Web, `flutter_image_compress` NO funciona y su sola importación
/// puede interferir con los blob URLs de ImagePicker. Por eso se usa
/// conditional import: en web NO se importa flutter_image_compress.
///
///   1. Los callers DEBEN leer bytes con `await file.readAsBytes()` INMEDIATAMENTE
///      después de que ImagePicker devuelve el XFile.
///   2. Solo usar `compressBytes(rawBytes, fileName)` — nunca pasar un XFile.
///   3. En web se devuelven los bytes sin procesar.
///
/// Historial: antes del 2026-03-31 se subían bytes directamente sin compressor
/// y funcionaba perfecto. La introducción de ImageCompressor rompió la subida
/// en web por problemas con blob URLs y la importación de flutter_image_compress.
class ImageCompressor {
  ImageCompressor._();

  /// Comprime bytes crudos. En web devuelve sin procesar.
  ///
  /// Uso correcto:
  /// ```dart
  /// final file = await picker.pickImage(source: source);
  /// final rawBytes = Uint8List.fromList(await file.readAsBytes()); // ← inmediato
  /// final result = await ImageCompressor.compressBytes(rawBytes, file.name);
  /// ```
  static Future<({Uint8List bytes, String ext})> compressBytes(
    Uint8List rawBytes,
    String fileName, {
    int maxWidth = 1200,
    int maxHeight = 1200,
    int quality = 80,
  }) async {
    final originalExt = fileName.split('.').last.toLowerCase();

    // Formatos que no se comprimen
    if (originalExt == 'webp' || originalExt == 'gif') {
      return (bytes: rawBytes, ext: originalExt);
    }

    final compressed = await platform.compressPlatform(
      rawBytes,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      quality: quality,
    );

    // Si los bytes son idénticos (web), mantener extensión original
    if (identical(compressed, rawBytes)) {
      return (bytes: rawBytes, ext: originalExt);
    }

    return (bytes: compressed, ext: 'webp');
  }
}
