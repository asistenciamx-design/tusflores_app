-- =======================================================
-- FIX RLS: Permitir que visitantes (anon) inserten pedidos
-- Ejecuta este script en Supabase > SQL Editor
-- =======================================================

-- Eliminar TODAS las políticas de INSERT que puedan existir en la tabla orders
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = 'orders' AND cmd = 'INSERT') LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || r.policyname || '" ON public.orders';
    END LOOP;
END $$;

-- Habilitar RLS
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Crear política limpia que permite a CUALQUIERA insertar (incluyendo anon)
CREATE POLICY "Public can insert orders"
ON public.orders
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- Permitir a los autenticados (florerías) ver TODOS sus pedidos
DROP POLICY IF EXISTS "Shop owners can view their orders" ON public.orders;
CREATE POLICY "Shop owners can view their orders"
ON public.orders
FOR SELECT
TO authenticated
USING (true);

-- Verificación: Muestra las políticas activas sobre la tabla orders
SELECT policyname, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'orders';
