import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Comprime imágenes PNG/JPG a WebP antes de subir (solo nativo).
///
/// ⚠️  IMPORTANTE — NO MODIFICAR SIN LEER ESTO:
/// En Flutter Web, `flutter_image_compress` NO funciona y los blob URLs de
/// ImagePicker pueden expirar. Por eso:
///   1. Los callers DEBEN leer bytes con `await file.readAsBytes()` INMEDIATAMENTE
///      después de que ImagePicker devuelve el XFile.
///   2. Solo usar `compressBytes(rawBytes, fileName)` — nunca pasar un XFile.
///   3. En web se devuelven los bytes sin procesar.
///
/// Historial: antes del 2026-03-31 se subían bytes directamente sin compressor
/// y funcionaba perfecto. La introducción de ImageCompressor.compress(XFile)
/// rompió la subida en web por el problema de blob URL.
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

    // Flutter Web: devolver sin procesar (flutter_image_compress no soportado)
    if (kIsWeb) {
      return (bytes: rawBytes, ext: originalExt);
    }

    // Formatos que no se comprimen
    if (originalExt == 'webp' || originalExt == 'gif') {
      return (bytes: rawBytes, ext: originalExt);
    }

    final compressed = await FlutterImageCompress.compressWithList(
      rawBytes,
      minWidth: maxWidth,
      minHeight: maxHeight,
      quality: quality,
      format: CompressFormat.webp,
    );

    return (bytes: compressed, ext: 'webp');
  }
}
