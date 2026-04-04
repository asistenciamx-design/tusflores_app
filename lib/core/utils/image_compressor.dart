import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Comprime y convierte imágenes PNG/JPG a WebP antes de subir.
/// En Flutter Web la compresión no está soportada — se devuelven los bytes
/// originales con la extensión original.
class ImageCompressor {
  ImageCompressor._();

  /// Compress from raw bytes + extension name.
  /// This avoids blob URL issues on Flutter Web.
  static Future<({Uint8List bytes, String ext})> compressBytes(
    Uint8List rawBytes,
    String fileName, {
    int maxWidth = 1200,
    int maxHeight = 1200,
    int quality = 80,
  }) async {
    final originalExt = fileName.split('.').last.toLowerCase();

    // Flutter Web no soporta flutter_image_compress → devolver sin procesar
    if (kIsWeb) {
      return (bytes: rawBytes, ext: originalExt);
    }

    // WebP ya está optimizado → devolver sin procesar
    if (originalExt == 'webp') {
      return (bytes: rawBytes, ext: 'webp');
    }

    // GIF no se comprime
    if (originalExt == 'gif') {
      return (bytes: rawBytes, ext: 'gif');
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

  /// Legacy: compress from XFile. Reads bytes first to avoid blob URL issues.
  static Future<({Uint8List bytes, String ext})> compress(
    XFile file, {
    int maxWidth = 1200,
    int maxHeight = 1200,
    int quality = 80,
  }) async {
    final rawBytes = Uint8List.fromList(await file.readAsBytes());
    return compressBytes(
      rawBytes,
      file.name,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      quality: quality,
    );
  }
}
