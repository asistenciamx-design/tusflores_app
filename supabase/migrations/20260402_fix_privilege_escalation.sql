-- ──────────────────────────────────────────────────────────────────────────────
-- Fix: prevenir escalada de privilegios más robusta en profiles
-- ──────────────────────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "prevent_privilege_escalation" ON profiles;

CREATE POLICY "prevent_privilege_escalation"
  ON profiles
  AS RESTRICTIVE
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (
    -- No permitir auto-asignarse super_admin
    role != 'super_admin'
    -- No permitir cambiar can_be_proveedor (solo admin puede)
    AND can_be_proveedor = (SELECT p.can_be_proveedor FROM profiles p WHERE p.id = auth.uid())
    -- No permitir cambiar is_proveedor (solo admin puede)
    AND is_proveedor = (SELECT p.is_proveedor FROM profiles p WHERE p.id = auth.uid())
    -- Solo puede ser proveedor si tiene can_be_proveedor = true
    AND (role != 'proveedor' OR can_be_proveedor = true)
  );
