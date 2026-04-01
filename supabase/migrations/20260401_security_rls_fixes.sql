-- ──────────────────────────────────────────────────────────────────────────────
-- Seguridad: corrección de políticas RLS vulnerables
-- ──────────────────────────────────────────────────────────────────────────────

-- ── 1. orders: eliminar INSERT abierto ────────────────────────────────────────

DROP POLICY IF EXISTS "Anyone can insert orders" ON orders;
DROP POLICY IF EXISTS "anon_insert_order" ON orders;

-- Solo usuarios autenticados pueden insertar pedidos,
-- y únicamente con su propio shop_id (o florist_id).
-- is_paid solo puede ser false al crear — no se acepta pedido ya "pagado" desde cliente.
CREATE POLICY "auth_insert_own_order"
  ON orders
  FOR INSERT
  TO authenticated
  WITH CHECK (
    shop_id = auth.uid()
    AND (is_paid IS NULL OR is_paid = false)
  );

-- ── 2. profiles: eliminar INSERT irrestricto ──────────────────────────────────

-- La política "Enable insert for authenticated users only" tiene WITH CHECK (true),
-- lo que permite enviar cualquier role, can_be_proveedor=true, is_proveedor=true.
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON profiles;

-- Reemplazar con política que:
--  • Solo el propio usuario puede insertar su perfil.
--  • role únicamente puede ser 'shop_owner' o 'proveedor'.
--  • can_be_proveedor e is_proveedor deben ser false al registrarse.
DROP POLICY IF EXISTS "auth_insert_own_profile" ON profiles;

CREATE POLICY "auth_insert_own_profile"
  ON profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (
    id = auth.uid()
    AND role IN ('shop_owner', 'proveedor')
    AND (can_be_proveedor IS NULL OR can_be_proveedor = false)
    AND (is_proveedor IS NULL OR is_proveedor = false)
  );

-- ── 3. profiles: prevenir escalada de privilegios en UPDATE ──────────────────

-- El usuario no puede asignarse role='super_admin' ni can_be_proveedor=true.
-- Aplica a cualquier política UPDATE que permita al usuario editar su propio perfil.
-- Añadimos una política restrictiva (RESTRICTIVE = se evalúa antes de las permisivas).
DROP POLICY IF EXISTS "prevent_privilege_escalation" ON profiles;

CREATE POLICY "prevent_privilege_escalation"
  ON profiles
  AS RESTRICTIVE
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (
    -- No permitir que un usuario se auto-asigne super_admin
    role != 'super_admin'
    -- No permitir que un usuario se auto-conceda can_be_proveedor=true
    AND can_be_proveedor = (SELECT can_be_proveedor FROM profiles WHERE id = auth.uid())
  );
