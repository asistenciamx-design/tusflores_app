-- ──────────────────────────────────────────────────────────────────────────────
-- VULN-016: Rate limiting para reviews — prevenir spam masivo
-- ──────────────────────────────────────────────────────────────────────────────

-- Reemplazar la política INSERT abierta con una que limite por IP/sesión
DROP POLICY IF EXISTS "Anyone can insert reviews" ON public.shop_reviews;

-- Función que verifica rate limit antes de insertar review
CREATE OR REPLACE FUNCTION check_review_rate_limit()
RETURNS TRIGGER AS $$
DECLARE
  v_recent_count INTEGER;
BEGIN
  -- Máximo 5 reviews por shop_id en las últimas 24 horas desde el mismo reviewer_name
  SELECT COUNT(*) INTO v_recent_count
  FROM public.shop_reviews
  WHERE shop_id = NEW.shop_id
    AND reviewer_name = NEW.reviewer_name
    AND created_at > NOW() - INTERVAL '24 hours';

  IF v_recent_count >= 5 THEN
    RAISE EXCEPTION 'Demasiadas reseñas. Intenta de nuevo más tarde.';
  END IF;

  -- Máximo 20 reviews por shop_id en las últimas 24 horas (global)
  SELECT COUNT(*) INTO v_recent_count
  FROM public.shop_reviews
  WHERE shop_id = NEW.shop_id
    AND created_at > NOW() - INTERVAL '24 hours';

  IF v_recent_count >= 20 THEN
    RAISE EXCEPTION 'Límite de reseñas alcanzado para esta tienda. Intenta mañana.';
  END IF;

  -- Si tiene order_id, verificar que el pedido pertenece a esta tienda y está entregado
  IF NEW.order_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.orders
      WHERE id = NEW.order_id
        AND shop_id = NEW.shop_id
        AND status = 'delivered'
    ) THEN
      RAISE EXCEPTION 'El pedido no existe, no pertenece a esta tienda, o no ha sido entregado.';
    END IF;
    -- Marcar como verificada
    NEW.is_verified := true;
  END IF;

  -- Rating debe ser entre 1 y 5 (ya está en CHECK pero doble validación)
  IF NEW.rating < 1 OR NEW.rating > 5 THEN
    RAISE EXCEPTION 'Rating debe ser entre 1 y 5';
  END IF;

  -- Sanitizar: truncar nombre y comentario
  NEW.reviewer_name := LEFT(TRIM(NEW.reviewer_name), 100);
  IF NEW.comment IS NOT NULL THEN
    NEW.comment := LEFT(TRIM(NEW.comment), 1000);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_review_rate_limit ON public.shop_reviews;
CREATE TRIGGER trg_review_rate_limit
  BEFORE INSERT ON public.shop_reviews
  FOR EACH ROW
  EXECUTE FUNCTION check_review_rate_limit();

-- Re-crear política INSERT (ahora el trigger valida)
CREATE POLICY "Anyone can insert reviews with rate limit"
  ON public.shop_reviews
  FOR INSERT
  WITH CHECK (true);
