-- =======================================================
-- FIX: Permitir acceso anónimo (visitantes sin login)
-- Solo AGREGA políticas, NO elimina las existentes
-- Ejecuta en: Supabase > SQL Editor
-- =======================================================


-- 3. SHOP_SETTINGS: Visitantes necesitan ver los horarios y costos de envío en el Checkout
CREATE POLICY "Public read shop settings" ON public.shop_settings
FOR SELECT USING (true);

-- 4. VERIFICACIÓN: Ejecuta esto para ver las políticas actuales:
SELECT tablename, policyname, roles, cmd 
FROM pg_policies 
WHERE tablename IN ('profiles', 'products', 'shop_settings')
ORDER BY tablename, policyname;
