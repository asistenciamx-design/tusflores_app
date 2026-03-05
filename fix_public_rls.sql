-- =======================================================
-- FIX: Permitir acceso anónimo (visitantes sin login)
-- Solo AGREGA políticas, NO elimina las existentes
-- Ejecuta en: Supabase > SQL Editor
-- =======================================================

-- 1. PROFILES: Visitantes necesitan leer perfiles para ver la tienda
CREATE POLICY "Public read profiles" ON public.profiles
FOR SELECT USING (true);

-- 2. PRODUCTS: Visitantes necesitan ver productos activos
CREATE POLICY "Public read active products" ON public.products
FOR SELECT TO anon USING (is_active = true);

-- Si alguna de las líneas anteriores da error "policy already exists",
-- significa que la política YA existe y está bien. Puedes ignorar ese error.

-- 3. VERIFICACIÓN: Ejecuta esto para ver las políticas actuales:
SELECT tablename, policyname, roles, cmd 
FROM pg_policies 
WHERE tablename IN ('profiles', 'products')
ORDER BY tablename, policyname;
