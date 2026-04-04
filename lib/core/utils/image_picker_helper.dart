import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import 'image_compressor.dart';
import 'image_picker_helper_stub.dart'
    if (dart.library.html) 'image_picker_helper_web.dart' as web_picker;

/// Resultado de seleccionar una imagen.
class PickedImage {
  final Uint8List bytes;
  final String ext;
  const PickedImage({required this.bytes, required this.ext});
}

/// Selecciona una imagen y devuelve sus bytes comprimidos.
///
/// En web: usa un <input type="file"> nativo con FileReader —
/// evita el problema de blob URL revocado de XFile.readAsBytes().
///
/// En nativo: usa ImagePicker + dart:io File.readAsBytes().
class ImagePickerHelper {
  ImagePickerHelper._();

  static Future<PickedImage?> pickImage({
    ImageSource source = ImageSource.gallery,
    int maxWidth = 1200,
    int maxHeight = 1200,
    int quality = 80,
  }) async {
    if (kIsWeb) {
      // Web: file picker directo con FileReader, sin XFile.readAsBytes()
      final result = await web_picker.pickAndReadImageWeb();
      if (result == null) return null;
      final compressed = await ImageCompressor.compressBytes(
        result.bytes,
        result.name,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
      );
      return PickedImage(bytes: compressed.bytes, ext: compressed.ext);
    } else {
      // Nativo: ImagePicker + File.readAsBytes()
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source);
      if (file == null) return null;
      final rawBytes = await _readNativeFile(file.path);
      final compressed = await ImageCompressor.compressBytes(
        rawBytes,
        file.name,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
      );
      return PickedImage(bytes: compressed.bytes, ext: compressed.ext);
    }
  }

  static Future<Uint8List> _readNativeFile(String path) async {
    return web_picker.readNativeBytes(path);
  }
}
