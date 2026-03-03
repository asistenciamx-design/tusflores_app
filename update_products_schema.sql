-- Para soportar múltiples imágenes (máximo 5) en un producto:
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS image_urls JSONB DEFAULT '[]'::jsonb;

-- Para soportar las categorías / tags directamente en el producto:
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS tags JSONB DEFAULT '[]'::jsonb;
