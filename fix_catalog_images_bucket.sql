-- =======================================================
-- Bucket para imágenes de portada del catálogo (catalog-images)
-- Ejecuta en Supabase > SQL Editor
-- =======================================================

-- 1. Crear el bucket 'catalog-images' (público para que las imágenes sean visibles)
INSERT INTO storage.buckets (id, name, public)
VALUES ('catalog-images', 'catalog-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Política SELECT: cualquiera puede ver las imágenes del catálogo
DROP POLICY IF EXISTS "Anyone can view catalog images" ON storage.objects;
CREATE POLICY "Anyone can view catalog images"
ON storage.objects
FOR SELECT
USING (bucket_id = 'catalog-images');

-- 3. Política INSERT: solo usuarios autenticados pueden subir su imagen de portada
DROP POLICY IF EXISTS "Authenticated users can upload catalog images" ON storage.objects;
CREATE POLICY "Authenticated users can upload catalog images"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'catalog-images'
  AND auth.role() = 'authenticated'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 4. Política UPDATE: solo el dueño puede actualizar su imagen
DROP POLICY IF EXISTS "Florists can update their catalog image" ON storage.objects;
CREATE POLICY "Florists can update their catalog image"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'catalog-images'
  AND auth.role() = 'authenticated'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 5. Política DELETE: solo el dueño puede eliminar su imagen
DROP POLICY IF EXISTS "Florists can delete their catalog image" ON storage.objects;
CREATE POLICY "Florists can delete their catalog image"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'catalog-images'
  AND auth.role() = 'authenticated'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
