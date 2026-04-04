import 'dart:typed_data';

class PickedImageResult {
  final Uint8List bytes;
  final String name;
  const PickedImageResult({required this.bytes, required this.name});
}

Future<PickedImageResult?> pickAndReadImageWeb() {
  throw UnsupportedError('Web only');
}

Future<Uint8List> readNativeBytes(String path) {
  throw UnsupportedError('Native only');
}
