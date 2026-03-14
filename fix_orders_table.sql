-- =======================================================
-- FIX: Añadir nuevas columnas a la tabla 'orders' y política RLS
-- Ejecuta este script en Supabase > SQL Editor
-- =======================================================

-- 1. Añadir todas las nuevas columnas generadas en el Checkout (si no existen)
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT false;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS recipient_name TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS recipient_phone TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS dedication_message TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_address TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_references TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_location_type TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_state TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_city TEXT;

-- 2. Asegurarse de que exista una política que permita a los clientes (anon) crear pedidos
-- Elimina políticas viejas conflictivas de inserción pública si las hay
DROP POLICY IF EXISTS "Anyone can insert orders" ON public.orders;

-- Habilita RLS por si acaso
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- 3. Crea la política para que cualquier visitante (anon) pueda guardar su pedido
CREATE POLICY "Anyone can insert orders"
ON public.orders
FOR INSERT
WITH CHECK (true);

-- =======================================================
-- LISTO: Ya puedes guardar pedidos desde la aplicación
-- =======================================================
