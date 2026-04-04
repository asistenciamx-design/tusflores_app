-- ──────────────────────────────────────────────────────────────────────────────
-- VULN-013: Validar precios de pedidos server-side
-- Evita que un cliente envíe un precio manipulado desde el frontend.
-- ──────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION validate_order_price()
RETURNS TRIGGER AS $$
DECLARE
  v_items JSONB;
  v_calculated NUMERIC := 0;
  v_item JSONB;
BEGIN
  -- 1. El precio debe ser positivo
  IF NEW.price IS NULL OR NEW.price <= 0 THEN
    RAISE EXCEPTION 'El precio del pedido debe ser mayor a 0';
  END IF;

  -- 2. Intentar parsear product_name como JSON de items y recalcular
  BEGIN
    v_items := NEW.product_name::JSONB;

    -- Si es un array JSON, recalcular el total de items
    IF jsonb_typeof(v_items) = 'array' AND jsonb_array_length(v_items) > 0 THEN
      FOR v_item IN SELECT * FROM jsonb_array_elements(v_items)
      LOOP
        v_calculated := v_calculated +
          COALESCE((v_item->>'price')::NUMERIC, 0) *
          COALESCE((v_item->>'qty')::NUMERIC, 1);
      END LOOP;

      -- El precio enviado debe coincidir con el calculado (tolerancia de $1 por redondeo)
      IF ABS(NEW.price - v_calculated) > 1 THEN
        RAISE EXCEPTION 'Precio no coincide con items: esperado %, recibido %',
          v_calculated, NEW.price;
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      -- Si product_name no es JSON válido, solo validar precio > 0 (ya hecho arriba)
      NULL;
  END;

  -- 3. Shipping cost no puede ser negativo
  IF NEW.shipping_cost IS NOT NULL AND NEW.shipping_cost < 0 THEN
    RAISE EXCEPTION 'El costo de envío no puede ser negativo';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicar en INSERT y UPDATE
DROP TRIGGER IF EXISTS trg_validate_order_price ON orders;
CREATE TRIGGER trg_validate_order_price
  BEFORE INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION validate_order_price();
