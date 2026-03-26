-- =======================================================
-- Rate limiting para tracking de pedidos + validación shop_id
-- Fecha: 2026-03-26
-- Ejecutar en Supabase > SQL Editor
-- =======================================================

-- 1. Tabla de intentos fallidos de tracking
-- =======================================================

CREATE TABLE IF NOT EXISTS order_tracking_attempts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  folio        TEXT NOT NULL,
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE order_tracking_attempts ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS order_tracking_attempts_folio_idx
  ON order_tracking_attempts (folio, attempted_at DESC);

-- 2. check_tracking_rate_limit: ¿quedan intentos disponibles?
-- =======================================================

CREATE OR REPLACE FUNCTION check_tracking_rate_limit(p_folio TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_max_attempts CONSTANT INT := 5;
  v_window_hours CONSTANT INT := 1;
  v_count INT;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM order_tracking_attempts
  WHERE folio = p_folio
    AND attempted_at > now() - (v_window_hours || ' hours')::INTERVAL;

  RETURN json_build_object(
    'allowed',   v_count < v_max_attempts,
    'remaining', GREATEST(0, v_max_attempts - v_count)
  );
END;
$$;

-- 3. record_tracking_attempt: registra un intento fallido
-- =======================================================

CREATE OR REPLACE FUNCTION record_tracking_attempt(p_folio TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO order_tracking_attempts (folio) VALUES (p_folio);
END;
$$;

GRANT EXECUTE ON FUNCTION check_tracking_rate_limit(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION record_tracking_attempt(TEXT) TO anon, authenticated;

-- 4. Trigger: validar que shop_id en orders sea una florería válida
-- =======================================================

CREATE OR REPLACE FUNCTION validate_order_shop_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = NEW.shop_id
    AND role = 'shop_owner'
  ) THEN
    RAISE EXCEPTION 'shop_id inválido: florería no encontrada';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_order_shop_id ON orders;
CREATE TRIGGER trg_validate_order_shop_id
  BEFORE INSERT ON orders
  FOR EACH ROW EXECUTE FUNCTION validate_order_shop_id();
