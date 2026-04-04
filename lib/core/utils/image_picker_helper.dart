import 'dart:typed_data';

import 'image_picker_helper_stub.dart'
    if (dart.library.html) 'image_picker_helper_web.dart'
    if (dart.library.io) 'image_picker_helper_native.dart' as platform;

/// Helper para obtener bytes de una imagen seleccionada.
///
/// En web, usa dart:html FileReader directamente para evitar
/// el problema de blob URL revocado que tiene XFile.readAsBytes().
/// En nativo, usa XFile.readAsBytes() normalmente.
class ImagePickerHelper {
  ImagePickerHelper._();

  /// Lee los bytes de un archivo seleccionado por ImagePicker.
  /// [path] es file.path, [name] es file.name.
  /// En web, [path] es un blob: URL que se lee con FileReader.
  /// En nativo, [path] es un file path que se lee con dart:io File.
  static Future<Uint8List> readBytes(String path, String name) {
    return platform.readImageBytes(path, name);
  }
}
