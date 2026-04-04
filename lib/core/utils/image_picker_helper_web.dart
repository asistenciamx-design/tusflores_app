import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Web: lee bytes usando XMLHttpRequest para evitar el error
/// "Could not load Blob from its URL. Has it been revoked?"
/// que ocurre con XFile.readAsBytes() en Flutter Web.
Future<Uint8List> readImageBytes(String blobUrl, String name) async {
  final completer = Completer<Uint8List>();

  final xhr = web.XMLHttpRequest();
  xhr.open('GET', blobUrl);
  xhr.responseType = 'arraybuffer';

  xhr.onload = (web.Event event) {
    final buffer = xhr.response as JSArrayBuffer;
    completer.complete(buffer.toDart.asUint8List());
  }.toJS;

  xhr.onerror = (web.Event event) {
    completer.completeError(
      Exception('No se pudo leer la imagen seleccionada'),
    );
  }.toJS;

  xhr.send();
  return completer.future;
}
