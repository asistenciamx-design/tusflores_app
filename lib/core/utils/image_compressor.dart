import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Comprime y convierte imágenes PNG/JPG a WebP antes de subir.
/// Las imágenes .webp se devuelven sin procesar.
class ImageCompressor {
  ImageCompressor._();

  /// Comprime un [XFile] y retorna los bytes en WebP + la extensión 'webp'.
  /// Si el archivo ya es .webp, retorna los bytes originales sin reprocesar.
  /// [maxWidth] y [maxHeight] controlan el resize (default 1200px).
  /// [quality] controla la calidad WebP (default 80).
  static Future<({Uint8List bytes, String ext})> compress(
    XFile file, {
    int maxWidth = 1200,
    int maxHeight = 1200,
    int quality = 80,
  }) async {
    final originalExt = file.name.split('.').last.toLowerCase();

    // WebP ya está optimizado → devolver sin procesar
    if (originalExt == 'webp') {
      final bytes = await file.readAsBytes();
      return (bytes: Uint8List.fromList(bytes), ext: 'webp');
    }

    final bytes = await file.readAsBytes();

    final compressed = await FlutterImageCompress.compressWithList(
      Uint8List.fromList(bytes),
      minWidth: maxWidth,
      minHeight: maxHeight,
      quality: quality,
      format: CompressFormat.webp,
    );

    return (bytes: compressed, ext: 'webp');
  }
}
