-- ──────────────────────────────────────────────────────────────────────────────
-- VULN-011: order_tracking_attempts tiene RLS habilitado pero sin políticas.
-- El rate limiting de tracking no funciona porque nadie puede insertar ni leer.
-- Las funciones SECURITY DEFINER bypasean RLS, pero necesitamos políticas
-- explícitas para que el sistema funcione correctamente.
-- ──────────────────────────────────────────────────────────────────────────────

-- Permitir INSERT desde anónimos y autenticados (el tracking es público)
CREATE POLICY "allow_insert_tracking_attempts"
  ON order_tracking_attempts
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Permitir SELECT para que check_tracking_rate_limit() funcione
CREATE POLICY "allow_select_tracking_attempts"
  ON order_tracking_attempts
  FOR SELECT
  TO anon, authenticated
  USING (true);
