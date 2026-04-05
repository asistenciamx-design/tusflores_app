# Solución definitiva: Subida de imágenes en Flutter Web

**Fecha de implementación:** 2026-04-04  
**Tiempo invertido:** ~8 horas  
**Estado:** ✅ Funcionando en producción

---

## El problema

Error en todos los navegadores (Chrome, Safari, móvil y escritorio):

```
Could not load Blob from its URL. Has it been revoked?
```

Aparecía en: Bodega de Insumos, Catálogo (productos y regalos), Perfil, Admin Categorías.

---

## Causa raíz

`XFile` de `image_picker_for_web` crea un blob URL con `URL.createObjectURL(file)`.  
Cuando se llama `file.readAsBytes()`, hace un XHR re-fetch de ese blob URL.  
Ese blob URL puede estar **revocado** para ese momento → error.

**Nunca llamar `XFile.readAsBytes()` en Flutter Web.**

---

## La solución

Usar `<input type="file">` + `FileReader.readAsArrayBuffer()` directamente.  
Los bytes se leen **en el mismo evento `onchange`**, antes de que ningún blob URL expire.

---

## Archivos clave

### 1. `lib/core/utils/image_picker_helper.dart`
Punto de entrada unificado. Usa conditional imports para separar web/nativo.

```dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart' show ImageSource;
import '../../../../core/utils/image_compressor.dart';

// Conditional import — en web carga image_picker_helper_web.dart
import 'image_picker_helper_stub.dart'
    if (dart.library.html) 'image_picker_helper_web.dart'
    if (dart.library.io) 'image_picker_helper_native.dart'
    as platform_picker;

class PickedImage {
  final Uint8List bytes;
  final String ext; // sin punto, ej: "webp", "jpg"
  const PickedImage({required this.bytes, required this.ext});
}

class ImagePickerHelper {
  static Future<PickedImage?> pickImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    if (kIsWeb) {
      final result = await platform_picker.pickAndReadImageWeb();
      if (result == null) return null;
      final compressed = await ImageCompressor.compressBytes(result.bytes, result.name);
      return PickedImage(bytes: compressed.bytes, ext: compressed.ext);
    } else {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source);
      if (file == null) return null;
      final rawBytes = await platform_picker.readNativeBytes(file.path);
      final compressed = await ImageCompressor.compressBytes(rawBytes, file.name);
      return PickedImage(bytes: compressed.bytes, ext: compressed.ext);
    }
  }
}
```

### 2. `lib/core/utils/image_picker_helper_web.dart` ← **EL ARCHIVO CRÍTICO**
Lee bytes con FileReader nativo, sin pasar por XFile ni blob URL.

```dart
import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class PickedImageResult {
  final Uint8List bytes;
  final String name;
  const PickedImageResult({required this.bytes, required this.name});
}

Future<PickedImageResult?> pickAndReadImageWeb() async {
  final completer = Completer<PickedImageResult?>();

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..style.display = 'none';
  web.document.body!.append(input);

  input.onchange = (web.Event _) {
    final file = input.files?.item(0);
    if (file == null) { completer.complete(null); return; }

    final reader = web.FileReader();
    reader.onload = (web.Event _) {
      final result = reader.result as JSArrayBuffer?;
      if (result == null) { completer.complete(null); return; }
      completer.complete(
        PickedImageResult(bytes: result.toDart.asUint8List(), name: file.name),
      );
    }.toJS;
    reader.onerror = (web.Event _) { completer.complete(null); }.toJS;
    reader.readAsArrayBuffer(file);
  }.toJS;

  Future.microtask(() => input.click());
  try {
    return await completer.future;
  } finally {
    input.remove();
  }
}

// Stub para native — no se usa en web
Future<Uint8List> readNativeBytes(String path) => throw UnimplementedError();
```

### 3. `lib/core/utils/image_picker_helper_native.dart`
```dart
import 'dart:io';
import 'dart:typed_data';

Future<dynamic> pickAndReadImageWeb() => throw UnimplementedError();

Future<Uint8List> readNativeBytes(String path) => File(path).readAsBytes();
```

### 4. `lib/core/utils/image_picker_helper_stub.dart`
```dart
import 'dart:typed_data';

Future<dynamic> pickAndReadImageWeb() => throw UnimplementedError();
Future<Uint8List> readNativeBytes(String path) => throw UnimplementedError();
```

---

## Regla de firma en repositorios

**ANTES (roto):**
```dart
Future<String?> uploadImage(XFile file) async {
  final bytes = await file.readAsBytes(); // ← FALLA en web
}
```

**DESPUÉS (correcto):**
```dart
Future<String?> uploadImage(Uint8List rawBytes, String fileName) async {
  // rawBytes ya están en memoria, nunca toca blob URL
}
```

**Todos los repositorios siguen esta firma:**
- `product_repository.dart` → `uploadProductImage(String floristId, Uint8List rawBytes, String fileName)`
- `gift_repository.dart` → `uploadGiftImage(String floristId, Uint8List rawBytes, String fileName)`
- `profile_repository.dart` → `uploadImage(Uint8List rawBytes, String fileName, {String folder})`
- `admin_repository.dart` → `uploadCategoryImage(Uint8List rawBytes, String fileName)`
- `warehouse_repository.dart` → `uploadImage(Uint8List bytes, String ext)`

---

## Regla de variable local en repositorios

Todos los repositorios tienen un parámetro llamado `fileName`.  
La variable local del nombre de storage **debe llamarse `storageName`**, no `fileName`.

```dart
// CORRECTO
Future<String?> uploadProductImage(String floristId, Uint8List rawBytes, String fileName) async {
  final compressed = await ImageCompressor.compressBytes(rawBytes, fileName);
  final storageName = '${DateTime.now().millisecondsSinceEpoch}.${compressed.ext}'; // ← storageName
  final path = '$floristId/$storageName';
  ...
}
```

Si se usa `fileName` para la variable local → error de compilación:  
`Local variable 'fileName' can't be referenced before it is declared.`

---

## Patrón en pantallas (formularios)

En cualquier pantalla que muestre y guarde una imagen:

```dart
// Estado
PickedImage? _pickedImage;   // imagen nueva seleccionada
String? _existingImageUrl;   // URL ya guardada en Supabase

// Al guardar
String? imageUrl = _existingImageUrl;
if (_pickedImage != null) {
  imageUrl = await _repo.uploadXxx(_pickedImage!.bytes, 'name.${_pickedImage!.ext}');
}

// Preview
child: _pickedImage != null
    ? Image.memory(_pickedImage!.bytes, fit: BoxFit.cover)
    : _existingImageUrl != null
        ? Image.network(_existingImageUrl!, fit: BoxFit.cover)
        : Icon(Icons.add_photo_alternate_outlined),
```

**Nunca** almacenar `XFile` en el estado de una pantalla web.

---

## Dependencia requerida en pubspec.yaml

```yaml
dependencies:
  web: ^1.1.1   # requerido para image_picker_helper_web.dart
```

---

## Pantallas actualizadas

| Pantalla | Archivo |
|----------|---------|
| Bodega de Insumos | `warehouse/presentation/screens/warehouse_screen.dart` |
| Catálogo — Productos | `catalog/presentation/screens/add_edit_product_screen.dart` |
| Catálogo — Regalos | `catalog/presentation/screens/add_edit_gift_screen.dart` |
| Perfil — Logo | `profile/presentation/screens/main_profile_settings_screen.dart` |
| Perfil — Nosotros | `profile/presentation/screens/profile_about_us_edit_screen.dart` |
| Perfil — Sucursal | `profile/presentation/screens/profile_branch_edit_screen.dart` |
| Admin — Categorías | `admin/presentation/screens/admin_categories_screen.dart` |

---

## Si vuelve a romperse — checklist

1. **¿Se importó `XFile` en una pantalla nueva?** → Reemplazar con `PickedImage` de `ImagePickerHelper`.
2. **¿Se llama `file.readAsBytes()` en algún lugar?** → Buscar con grep: `readAsBytes` — eliminar.
3. **¿Un repositorio recibe `XFile` como parámetro?** → Cambiar firma a `Uint8List + String`.
4. **Error de compilación `fileName can't be referenced`?** → Renombrar variable local a `storageName`.
5. **Error `web` package not found?** → Verificar `web: ^1.1.1` en `pubspec.yaml`.
6. **`PostgrestException` al guardar?** → El campo enviado no existe en la tabla de Supabase. Revisar `toInsertMap()` / `toUpdateMap()` contra el schema real.
