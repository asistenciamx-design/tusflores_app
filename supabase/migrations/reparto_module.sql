-- ============================================================
-- MÓDULO REPARTO — tusflores_app
-- Aplica en Supabase SQL Editor
-- ============================================================

-- ── 1. Tabla repartidores ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.repartidores (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_id        UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name           TEXT NOT NULL,
  vehicle_plates TEXT,
  vehicle_name   TEXT,
  start_date     DATE NOT NULL DEFAULT CURRENT_DATE,
  status         TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused')),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índice para búsquedas por tienda
CREATE INDEX IF NOT EXISTS idx_repartidores_shop_id ON public.repartidores(shop_id);

-- ── 2. RLS en repartidores ───────────────────────────────────
ALTER TABLE public.repartidores ENABLE ROW LEVEL SECURITY;

-- Solo el dueño de la tienda puede leer/escribir sus repartidores
CREATE POLICY "owner_select" ON public.repartidores
  FOR SELECT USING (auth.uid() = shop_id);

CREATE POLICY "owner_insert" ON public.repartidores
  FOR INSERT WITH CHECK (auth.uid() = shop_id);

CREATE POLICY "owner_update" ON public.repartidores
  FOR UPDATE USING (auth.uid() = shop_id);

CREATE POLICY "owner_delete" ON public.repartidores
  FOR DELETE USING (auth.uid() = shop_id);

-- ── 3. Columnas en orders ────────────────────────────────────
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS repartidor_id  UUID REFERENCES public.repartidores(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS delivery_amount NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS driver_notes   TEXT;

-- Índice para consultas de histórico por repartidor
CREATE INDEX IF NOT EXISTS idx_orders_repartidor_id ON public.orders(repartidor_id)
  WHERE repartidor_id IS NOT NULL;
