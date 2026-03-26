-- =======================================================
-- FIX SEGURIDAD: RLS en orders + función de tracking
-- Fecha: 2026-03-26
-- Ejecutar en Supabase > SQL Editor
-- =======================================================

-- 1. Habilitar RLS (puede estar deshabilitado)
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- 2. Limpiar políticas existentes
DROP POLICY IF EXISTS "Public can insert orders" ON public.orders;
DROP POLICY IF EXISTS "Shop owners can view their orders" ON public.orders;
DROP POLICY IF EXISTS "Anyone can insert orders" ON public.orders;
DROP POLICY IF EXISTS "Allow all inserts" ON public.orders;
DROP POLICY IF EXISTS "Allow all reads" ON public.orders;
DROP POLICY IF EXISTS "Shop owners see own orders" ON public.orders;
DROP POLICY IF EXISTS "Shop owners can update their orders" ON public.orders;

-- 3. INSERT: cualquiera puede crear pedidos (clientes anón)
CREATE POLICY "Anyone can insert orders"
ON public.orders FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- 4. SELECT: cada florería solo ve sus propios pedidos
CREATE POLICY "Shop owners see own orders"
ON public.orders FOR SELECT
TO authenticated
USING (auth.uid() = shop_id);

-- 5. UPDATE: cada florería solo actualiza sus propios pedidos
CREATE POLICY "Shop owners can update their orders"
ON public.orders FOR UPDATE
TO authenticated
USING (auth.uid() = shop_id);

-- =======================================================
-- 6. Función SECURITY DEFINER para tracking anónimo
-- Bypasea RLS de forma controlada: solo devuelve campos
-- seguros si el teléfono (últimos 10 dígitos) coincide.
-- =======================================================

CREATE OR REPLACE FUNCTION get_order_tracking(p_folio TEXT, p_phone TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order RECORD;
  v_stored_phone TEXT;
  v_stored10 TEXT;
  v_entered10 TEXT;
  v_shop_name TEXT;
BEGIN
  -- Normalizar teléfono ingresado (solo dígitos, últimos 10)
  v_entered10 := right(regexp_replace(p_phone, '[^0-9]', '', 'g'), 10);

  -- Buscar pedido por folio
  SELECT id, folio, status, product_name, quantity, delivery_method,
         delivery_info, delivery_address, delivery_city, price,
         shipping_cost, recipient_name, shop_id, created_at,
         completion_photos, customer_phone
  INTO v_order
  FROM orders
  WHERE folio = p_folio
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object('found', false, 'error', 'folio_not_found');
  END IF;

  -- Verificar teléfono (últimos 10 dígitos)
  v_stored_phone := regexp_replace(coalesce(v_order.customer_phone, ''), '[^0-9]', '', 'g');
  v_stored10 := right(v_stored_phone, 10);

  IF v_stored10 <> v_entered10 THEN
    RETURN json_build_object('found', false, 'error', 'phone_mismatch');
  END IF;

  -- Obtener nombre de la florería (evita query extra desde el cliente)
  SELECT shop_name INTO v_shop_name
  FROM profiles WHERE id = v_order.shop_id;

  -- Devolver campos seguros (sin customer_phone)
  RETURN json_build_object(
    'found', true,
    'id', v_order.id,
    'folio', v_order.folio,
    'status', v_order.status,
    'product_name', v_order.product_name,
    'quantity', v_order.quantity,
    'delivery_method', v_order.delivery_method,
    'delivery_info', v_order.delivery_info,
    'delivery_address', v_order.delivery_address,
    'delivery_city', v_order.delivery_city,
    'price', v_order.price,
    'shipping_cost', v_order.shipping_cost,
    'recipient_name', v_order.recipient_name,
    'shop_id', v_order.shop_id,
    'shop_name', coalesce(v_shop_name, 'Tu florería'),
    'created_at', v_order.created_at,
    'completion_photos', v_order.completion_photos
  );
END;
$$;

-- Permisos de ejecución para anónimos y autenticados
GRANT EXECUTE ON FUNCTION get_order_tracking(TEXT, TEXT) TO anon, authenticated;
