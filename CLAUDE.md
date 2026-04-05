# Reglas de desarrollo — tusflores_app

## REGLAS CRÍTICAS — leer antes de cualquier cambio

### 1. Commits atómicos — OBLIGATORIO
Cada commit toca UN solo tema. Nunca mezclar features, fixes y refactors en un solo commit.
- ✅ `fix(proveedor): corregir guard de role en proveedor_layout`
- ❌ `fix: corregir imágenes + proveedor + URLs + repo`

Antes de hacer `git add -A` o `git add .`, revisar CADA archivo y confirmar que pertenece al mismo cambio.

### 2. Archivos con fixes críticos — NO tocar sin razón
Estos archivos tienen fixes importantes que NO deben revertirse accidentalmente:

| Archivo | Fix crítico |
|---|---|
| `lib/features/proveedor/presentation/screens/proveedor_layout.dart` | role=='proveedor' OR (is_proveedor && can_be_proveedor) — ambos casos |
| `lib/core/utils/image_picker_helper_web.dart` | FileReader nativo — NUNCA usar XFile.readAsBytes() en web |
| `lib/core/utils/image_picker_helper.dart` | Conditional import web/native |
| `lib/features/warehouse/domain/models/warehouse_models.dart` | Sin columna low_stock_alert |
| `vercel.json` | Sin redirect www — lo maneja Vercel dashboard |

### 3. Subida de imágenes — arquitectura protegida
Ver `docs/image_upload_web_solution.md` para la arquitectura completa.
**NUNCA** usar `XFile.readAsBytes()` en Flutter Web.
**NUNCA** almacenar `XFile` en estado de un widget.
Toda nueva pantalla con imágenes usa `ImagePickerHelper.pickImage()`.

### 4. Modo Proveedor — lógica de autorización
Un usuario puede ser proveedor de dos formas:
- `role = 'proveedor'` — proveedor puro
- `role = 'shop_owner'` + `is_proveedor = true` + `can_be_proveedor = true` — florería que también es proveedor

El `ProveedorLayout` y cualquier guard de proveedor debe aceptar AMBOS casos.

### 5. Dominios y routing
- `tusflores.app/` → landing page (`landing.html`)
- `tusflores.app/mx/:slug` → tienda pública de florería (app Flutter)
- `tusflores.app/login` → app Flutter
- `www.tusflores.app` → redirect a `tusflores.app` (configurado en Vercel dashboard, NO en vercel.json)
- NO agregar redirect www en `vercel.json` — causa loop infinito

### 6. Base de datos — columnas que NO existen
- `warehouse_products` NO tiene columna `low_stock_alert`
- Verificar siempre contra el schema real antes de agregar campos en `toInsertMap()`/`toUpdateMap()`
