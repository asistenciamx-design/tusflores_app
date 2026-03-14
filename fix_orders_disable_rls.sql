-- =======================================================
-- FIX DEFINITIVO: Deshabilitar RLS en la tabla 'orders'
-- La tabla es pública (clientes sin login hacen pedidos)
-- Ejecuta este script en Supabase > SQL Editor
-- =======================================================

-- Opción A (Recomendada): Deshabilitar RLS completamente en orders
-- Esto permite que cualquiera pueda insertar y el owner pueda leer.
ALTER TABLE public.orders DISABLE ROW LEVEL SECURITY;

-- Opción B (Alternativa): Si prefieres mantener RLS, ejecuta en cambio estas líneas:
-- ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
-- DROP POLICY IF EXISTS "Public can insert orders" ON public.orders;
-- DROP POLICY IF EXISTS "Anyone can insert orders" ON public.orders;
-- CREATE POLICY "Allow all inserts" ON public.orders AS PERMISSIVE FOR INSERT TO PUBLIC WITH CHECK (true);
-- CREATE POLICY "Allow all reads" ON public.orders AS PERMISSIVE FOR SELECT TO PUBLIC USING (true);
