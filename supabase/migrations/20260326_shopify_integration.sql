-- ─────────────────────────────────────────────────────────────────────────────
-- Migración: Integración Shopify
-- Fecha: 2026-03-26
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Columnas nuevas en tabla orders
-- ─────────────────────────────────────────────────────────────────────────────

-- Origen del pedido: 'manual' | 'shopify' | 'woocommerce'
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'manual';

-- ID del pedido en Shopify (para evitar duplicados)
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS shopify_order_id TEXT;

-- Fecha de entrega como campo DATE (antes solo vivía en delivery_info como texto)
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS delivery_date DATE;

-- Rango de hora de entrega (ej. "01:00 PM - 04:00 PM")
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS delivery_time_range TEXT;

-- Índice único para evitar importar el mismo pedido de Shopify dos veces
CREATE UNIQUE INDEX IF NOT EXISTS orders_shopify_order_id_idx
  ON orders (shopify_order_id)
  WHERE shopify_order_id IS NOT NULL;


-- 2. Tabla shopify_connections
-- Cada florería conecta su tienda Shopify aquí.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS shopify_connections (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  shopify_domain   TEXT NOT NULL,          -- ej. holamercadojamaica.myshopify.com
  access_token     TEXT NOT NULL,          -- shpat_...
  client_secret    TEXT NOT NULL,          -- shpss_... (para verificar HMAC del webhook)
  is_active        BOOLEAN NOT NULL DEFAULT true,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (shop_id, shopify_domain)
);

-- Solo el dueño de la tienda puede ver/modificar su conexión
ALTER TABLE shopify_connections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Owner can manage their shopify connection"
  ON shopify_connections
  FOR ALL
  USING (auth.uid() = shop_id)
  WITH CHECK (auth.uid() = shop_id);

-- La Edge Function usa service_role key → bypasea RLS → puede leer todas las conexiones


-- 3. Trigger: actualizar updated_at automáticamente
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION update_shopify_connections_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_shopify_connections_updated_at ON shopify_connections;
CREATE TRIGGER trg_shopify_connections_updated_at
  BEFORE UPDATE ON shopify_connections
  FOR EACH ROW EXECUTE FUNCTION update_shopify_connections_updated_at();
