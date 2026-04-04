import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Implementación nativa — usa flutter_image_compress para convertir a WebP.
Future<Uint8List> compressPlatform(
  Uint8List rawBytes, {
  required int maxWidth,
  required int maxHeight,
  required int quality,
}) async {
  return await FlutterImageCompress.compressWithList(
    rawBytes,
    minWidth: maxWidth,
    minHeight: maxHeight,
    quality: quality,
    format: CompressFormat.webp,
  );
}
