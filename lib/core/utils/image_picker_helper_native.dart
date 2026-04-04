import 'dart:io';
import 'dart:typed_data';

/// Nativo: lee bytes desde el file path usando dart:io.
Future<Uint8List> readImageBytes(String path, String name) async {
  final file = File(path);
  return Uint8List.fromList(await file.readAsBytes());
}
