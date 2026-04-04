import 'dart:typed_data';

/// Stub — nunca se usa en runtime, solo satisface el conditional import.
Future<Uint8List> compressPlatform(
  Uint8List rawBytes, {
  required int maxWidth,
  required int maxHeight,
  required int quality,
}) {
  throw UnsupportedError('Cannot compress without a platform implementation');
}
