import 'dart:io';
import 'dart:typed_data';

class PickedImageResult {
  final Uint8List bytes;
  final String name;
  const PickedImageResult({required this.bytes, required this.name});
}

/// No usado en nativo — solo existe para satisfacer imports condicionales.
Future<PickedImageResult?> pickAndReadImageWeb() {
  throw UnsupportedError('Web only');
}

/// Lee bytes de un archivo nativo por path.
Future<Uint8List> readNativeBytes(String path) async {
  return Uint8List.fromList(await File(path).readAsBytes());
}
