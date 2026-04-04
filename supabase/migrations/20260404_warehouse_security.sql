-- ═══════════════════════════════════════════════════════════════════════════════
-- Security hardening para módulo Bodega de Insumos
-- Corrige: storage path-based access, RLS granular, rate limiting, audit log
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── 1. Storage: restricción por path de usuario ─────────────────────────────
-- Cada florería solo puede operar sobre su carpeta: warehouse/{userId}/...

DROP POLICY IF EXISTS "warehouse_upload" ON storage.objects;
CREATE POLICY "warehouse_upload" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'warehouse'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "warehouse_read" ON storage.objects;
CREATE POLICY "warehouse_read" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'warehouse'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "warehouse_delete" ON storage.objects;
CREATE POLICY "warehouse_delete" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'warehouse'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ── 2. RLS granular: warehouse_categories ───────────────────────────────────

DROP POLICY IF EXISTS "warehouse_categories_owner" ON warehouse_categories;

CREATE POLICY "warehouse_categories_select" ON warehouse_categories
  FOR SELECT USING (floreria_id = auth.uid());

CREATE POLICY "warehouse_categories_insert" ON warehouse_categories
  FOR INSERT WITH CHECK (floreria_id = auth.uid());

CREATE POLICY "warehouse_categories_update" ON warehouse_categories
  FOR UPDATE USING (floreria_id = auth.uid())
  WITH CHECK (floreria_id = auth.uid());

CREATE POLICY "warehouse_categories_delete" ON warehouse_categories
  FOR DELETE USING (floreria_id = auth.uid());

-- ── 3. RLS granular: warehouse_products ─────────────────────────────────────

DROP POLICY IF EXISTS "warehouse_products_owner" ON warehouse_products;

CREATE POLICY "warehouse_products_select" ON warehouse_products
  FOR SELECT USING (floreria_id = auth.uid());

CREATE POLICY "warehouse_products_insert" ON warehouse_products
  FOR INSERT WITH CHECK (floreria_id = auth.uid());

CREATE POLICY "warehouse_products_update" ON warehouse_products
  FOR UPDATE USING (floreria_id = auth.uid())
  WITH CHECK (floreria_id = auth.uid());

CREATE POLICY "warehouse_products_delete" ON warehouse_products
  FOR DELETE USING (floreria_id = auth.uid());

-- ── 4. RLS granular: warehouse_purchases ────────────────────────────────────

DROP POLICY IF EXISTS "warehouse_purchases_owner" ON warehouse_purchases;

CREATE POLICY "warehouse_purchases_select" ON warehouse_purchases
  FOR SELECT USING (floreria_id = auth.uid());

CREATE POLICY "warehouse_purchases_insert" ON warehouse_purchases
  FOR INSERT WITH CHECK (floreria_id = auth.uid());

CREATE POLICY "warehouse_purchases_delete" ON warehouse_purchases
  FOR DELETE USING (floreria_id = auth.uid());

-- ── 5. Validaciones a nivel de base de datos ────────────────────────────────
-- Constraints para prevenir datos inválidos incluso si la app no valida

ALTER TABLE warehouse_products
  DROP CONSTRAINT IF EXISTS chk_product_price,
  ADD CONSTRAINT chk_product_price CHECK (unit_price >= 0 AND unit_price <= 999999.99);

ALTER TABLE warehouse_products
  DROP CONSTRAINT IF EXISTS chk_product_stock,
  ADD CONSTRAINT chk_product_stock CHECK (stock >= 0 AND stock <= 999999);

ALTER TABLE warehouse_products
  DROP CONSTRAINT IF EXISTS chk_product_min_stock,
  ADD CONSTRAINT chk_product_min_stock CHECK (min_stock >= 0 AND min_stock <= 999999);

ALTER TABLE warehouse_products
  DROP CONSTRAINT IF EXISTS chk_product_name_length,
  ADD CONSTRAINT chk_product_name_length CHECK (char_length(name) BETWEEN 1 AND 500);

ALTER TABLE warehouse_products
  DROP CONSTRAINT IF EXISTS chk_product_sku_length,
  ADD CONSTRAINT chk_product_sku_length CHECK (sku IS NULL OR char_length(sku) <= 50);

ALTER TABLE warehouse_purchases
  DROP CONSTRAINT IF EXISTS chk_purchase_quantity,
  ADD CONSTRAINT chk_purchase_quantity CHECK (quantity > 0 AND quantity <= 999999);

ALTER TABLE warehouse_purchases
  DROP CONSTRAINT IF EXISTS chk_purchase_price,
  ADD CONSTRAINT chk_purchase_price CHECK (unit_price IS NULL OR (unit_price >= 0 AND unit_price <= 999999.99));

ALTER TABLE warehouse_categories
  DROP CONSTRAINT IF EXISTS chk_category_name_length,
  ADD CONSTRAINT chk_category_name_length CHECK (char_length(name) BETWEEN 1 AND 500);

-- ── 6. Rate limiting para operaciones de bodega ─────────────────────────────

CREATE TABLE IF NOT EXISTS warehouse_rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  floreria_id UUID NOT NULL,
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE warehouse_rate_limits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "warehouse_rate_limits_own" ON warehouse_rate_limits
  FOR ALL USING (floreria_id = auth.uid());

-- Función que verifica rate limit (máx 120 operaciones/minuto)
CREATE OR REPLACE FUNCTION check_warehouse_rate_limit()
RETURNS TRIGGER AS $$
BEGIN
  -- Limpiar registros viejos (> 2 minutos)
  DELETE FROM warehouse_rate_limits
  WHERE attempted_at < now() - interval '2 minutes';

  -- Contar operaciones en el último minuto
  IF (
    SELECT COUNT(*) FROM warehouse_rate_limits
    WHERE floreria_id = auth.uid()
    AND attempted_at > now() - interval '1 minute'
  ) >= 120 THEN
    RAISE EXCEPTION 'Demasiadas operaciones. Intenta de nuevo en un momento.';
  END IF;

  -- Registrar esta operación
  INSERT INTO warehouse_rate_limits (floreria_id) VALUES (auth.uid());

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Aplicar rate limit a productos (INSERT/UPDATE)
DROP TRIGGER IF EXISTS trg_warehouse_products_rate_limit ON warehouse_products;
CREATE TRIGGER trg_warehouse_products_rate_limit
  BEFORE INSERT OR UPDATE ON warehouse_products
  FOR EACH ROW
  EXECUTE FUNCTION check_warehouse_rate_limit();

-- Aplicar rate limit a compras (INSERT)
DROP TRIGGER IF EXISTS trg_warehouse_purchases_rate_limit ON warehouse_purchases;
CREATE TRIGGER trg_warehouse_purchases_rate_limit
  BEFORE INSERT ON warehouse_purchases
  FOR EACH ROW
  EXECUTE FUNCTION check_warehouse_rate_limit();

-- ── 7. Audit log para operaciones sensibles ─────────────────────────────────

CREATE TABLE IF NOT EXISTS warehouse_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  floreria_id UUID NOT NULL,
  table_name TEXT NOT NULL,
  operation TEXT NOT NULL,
  record_id UUID,
  old_data JSONB,
  new_data JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE warehouse_audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "warehouse_audit_log_own" ON warehouse_audit_log
  FOR SELECT USING (floreria_id = auth.uid());

-- Función de auditoría genérica
CREATE OR REPLACE FUNCTION warehouse_audit_fn()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    INSERT INTO warehouse_audit_log (floreria_id, table_name, operation, record_id, old_data)
    VALUES (OLD.floreria_id, TG_TABLE_NAME, TG_OP, OLD.id, to_jsonb(OLD));
    RETURN OLD;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO warehouse_audit_log (floreria_id, table_name, operation, record_id, old_data, new_data)
    VALUES (NEW.floreria_id, TG_TABLE_NAME, TG_OP, NEW.id, to_jsonb(OLD), to_jsonb(NEW));
    RETURN NEW;
  ELSIF TG_OP = 'INSERT' THEN
    INSERT INTO warehouse_audit_log (floreria_id, table_name, operation, record_id, new_data)
    VALUES (NEW.floreria_id, TG_TABLE_NAME, TG_OP, NEW.id, to_jsonb(NEW));
    RETURN NEW;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger de auditoría en productos
DROP TRIGGER IF EXISTS trg_warehouse_products_audit ON warehouse_products;
CREATE TRIGGER trg_warehouse_products_audit
  AFTER INSERT OR UPDATE OR DELETE ON warehouse_products
  FOR EACH ROW
  EXECUTE FUNCTION warehouse_audit_fn();

-- Trigger de auditoría en compras
DROP TRIGGER IF EXISTS trg_warehouse_purchases_audit ON warehouse_purchases;
CREATE TRIGGER trg_warehouse_purchases_audit
  AFTER INSERT OR DELETE ON warehouse_purchases
  FOR EACH ROW
  EXECUTE FUNCTION warehouse_audit_fn();
