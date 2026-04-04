import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

class PickedImageResult {
  final Uint8List bytes;
  final String name;
  const PickedImageResult({required this.bytes, required this.name});
}

/// Web: abre un file picker nativo y lee los bytes con FileReader
/// en el momento de la selección — antes de que el blob pueda revocarse.
/// Esto evita el error "Could not load Blob from its URL. Has it been revoked?"
/// que ocurre cuando XFile.readAsBytes() intenta rehidratar el blob via XHR.
Future<PickedImageResult?> pickAndReadImageWeb() async {
  final completer = Completer<PickedImageResult?>();

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..style.display = 'none';

  web.document.body!.append(input);

  input.onchange = (web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      completer.complete(null);
      return;
    }
    final file = files.item(0)!;
    final reader = web.FileReader();

    reader.onload = (web.Event _) {
      final result = reader.result as JSArrayBuffer?;
      if (result == null) {
        completer.completeError(Exception('No se pudo leer la imagen'));
        return;
      }
      completer.complete(
        PickedImageResult(
          bytes: result.toDart.asUint8List(),
          name: file.name,
        ),
      );
    }.toJS;

    reader.onerror = (web.Event _) {
      completer.completeError(Exception('Error al leer la imagen'));
    }.toJS;

    reader.readAsArrayBuffer(file);
  }.toJS;

  input.oncancel = (web.Event _) {
    completer.complete(null);
  }.toJS;

  Future.microtask(() => input.click());

  try {
    return await completer.future;
  } finally {
    input.remove();
  }
}

/// No usado en web.
Future<Uint8List> readNativeBytes(String path) {
  throw UnsupportedError('Native only');
}
