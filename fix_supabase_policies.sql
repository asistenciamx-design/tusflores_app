-- =======================================================
-- FIX: Políticas RLS para tabla 'products'
-- Ejecuta este script en Supabase > SQL Editor
-- =======================================================

-- 1. Habilitar RLS en la tabla products (si no está activo)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- 2. Eliminar políticas viejas que puedan causar conflictos
DROP POLICY IF EXISTS "Florists can insert own products" ON public.products;
DROP POLICY IF EXISTS "Florists can update own products" ON public.products;
DROP POLICY IF EXISTS "Florists can delete own products" ON public.products;
DROP POLICY IF EXISTS "Anyone can view active products" ON public.products;
DROP POLICY IF EXISTS "products_insert_policy" ON public.products;
DROP POLICY IF EXISTS "products_update_policy" ON public.products;
DROP POLICY IF EXISTS "products_select_policy" ON public.products;

-- 3. Política SELECT: cualquier usuario (incluso anónimo) puede ver productos activos
CREATE POLICY "Anyone can view active products"
ON public.products
FOR SELECT
USING (is_active = true OR auth.uid() = florist_id);

-- 4. Política INSERT: solo el florista dueño puede insertar
CREATE POLICY "Florists can insert own products"
ON public.products
FOR INSERT
WITH CHECK (auth.uid() = florist_id);

-- 5. Política UPDATE: solo el florista dueño puede actualizar
CREATE POLICY "Florists can update own products"
ON public.products
FOR UPDATE
USING (auth.uid() = florist_id)
WITH CHECK (auth.uid() = florist_id);

-- 6. Política DELETE: solo el florista dueño puede eliminar
CREATE POLICY "Florists can delete own products"
ON public.products
FOR DELETE
USING (auth.uid() = florist_id);

-- =======================================================
-- FIX: Storage bucket 'products'
-- =======================================================

-- 7. Crear el bucket 'products' si no existe (público para leer imágenes)
INSERT INTO storage.buckets (id, name, public)
VALUES ('products', 'products', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 8. Eliminar políticas viejas de storage
DROP POLICY IF EXISTS "Authenticated users can upload product images" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view product images" ON storage.objects;
DROP POLICY IF EXISTS "Florists can update their own product images" ON storage.objects;
DROP POLICY IF EXISTS "Florists can delete their own product images" ON storage.objects;

-- 9. Política STORAGE SELECT: cualquiera puede ver las imágenes (bucket público)
CREATE POLICY "Anyone can view product images"
ON storage.objects
FOR SELECT
USING (bucket_id = 'products');

-- 10. Política STORAGE INSERT: usuarios autenticados pueden subir imágenes a su carpeta
CREATE POLICY "Authenticated users can upload product images"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'products'
  AND auth.role() = 'authenticated'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 11. Política STORAGE UPDATE: solo el dueño puede actualizar su imagen
CREATE POLICY "Florists can update their own product images"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'products'
  AND auth.role() = 'authenticated'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 12. Política STORAGE DELETE: solo el dueño puede eliminar su imagen
CREATE POLICY "Florists can delete their own product images"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'products'
  AND auth.role() = 'authenticated'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- =======================================================
-- VERIFICACIÓN: confirmar que las columnas existen
-- =======================================================
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image_urls JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS tags JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS florist_id UUID REFERENCES auth.users(id);

-- Verificar estructura final
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' AND table_name = 'products'
ORDER BY ordinal_position;
