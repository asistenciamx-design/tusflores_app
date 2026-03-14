-- =======================================================
-- FIX: Añadir todas las columnas faltantes a la tabla 'orders'
-- Ejecuta este script en Supabase > SQL Editor
-- =======================================================

-- 1. Añadir columnas principales que faltan
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS shop_id UUID; -- Asumiendo que usa UUID para relacionar con perfiles/tiendas
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS folio TEXT DEFAULT '#0000';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS product_name TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_name TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_phone TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS quantity INTEGER DEFAULT 1;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS price NUMERIC DEFAULT 0.0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS sale_date TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_info TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS is_paid BOOLEAN DEFAULT false;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_method TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS shipping_cost NUMERIC DEFAULT 0.0;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_method TEXT DEFAULT 'Envío a domicilio';

-- 2. Añadir columnas del nuevo flujo de Checkout (por si acaso no se ejecutó el script anterior correctamente)
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT false;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS recipient_name TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS recipient_phone TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS dedication_message TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_address TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_references TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_location_type TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_state TEXT;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_city TEXT;

-- 3. Asegurarse de que exista una política que permita a los clientes (anon) crear pedidos
DROP POLICY IF EXISTS "Anyone can insert orders" ON public.orders;

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can insert orders"
ON public.orders
FOR INSERT
WITH CHECK (true);

-- =======================================================
-- LISTO: Ya puedes guardar pedidos desde la aplicación
-- =======================================================
