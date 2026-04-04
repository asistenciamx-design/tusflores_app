-- ═══════════════════════════════════════════════════════════════════════════════
-- Módulo Bodega de Insumos
-- Tabla de productos de bodega + historial de compras
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── 1. Categorías de bodega ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS warehouse_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  floreria_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(floreria_id, name)
);

ALTER TABLE warehouse_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "warehouse_categories_owner" ON warehouse_categories;
CREATE POLICY "warehouse_categories_owner" ON warehouse_categories
  FOR ALL USING (floreria_id = auth.uid());

-- ── 2. Productos de bodega ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS warehouse_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  floreria_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  category_id UUID REFERENCES warehouse_categories(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  sku TEXT,
  unit TEXT NOT NULL DEFAULT 'unidad',
  unit_price NUMERIC(10,2) NOT NULL DEFAULT 0,
  stock INT NOT NULL DEFAULT 0,
  min_stock INT NOT NULL DEFAULT 0,
  image_url TEXT,
  supplier_name TEXT,
  notes TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  low_stock_alert BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE warehouse_products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "warehouse_products_owner" ON warehouse_products;
CREATE POLICY "warehouse_products_owner" ON warehouse_products
  FOR ALL USING (floreria_id = auth.uid());

-- ── 3. Historial de compras ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS warehouse_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES warehouse_products(id) ON DELETE CASCADE,
  floreria_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  quantity INT NOT NULL,
  unit_price NUMERIC(10,2),
  supplier_name TEXT,
  purchased_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE warehouse_purchases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "warehouse_purchases_owner" ON warehouse_purchases;
CREATE POLICY "warehouse_purchases_owner" ON warehouse_purchases
  FOR ALL USING (floreria_id = auth.uid());

-- ── 4. Storage bucket para imágenes de bodega ───────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('warehouse', 'warehouse', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "warehouse_upload" ON storage.objects;
CREATE POLICY "warehouse_upload" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'warehouse' AND auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "warehouse_read" ON storage.objects;
CREATE POLICY "warehouse_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'warehouse');

DROP POLICY IF EXISTS "warehouse_delete" ON storage.objects;
CREATE POLICY "warehouse_delete" ON storage.objects
  FOR DELETE USING (bucket_id = 'warehouse' AND auth.uid() IS NOT NULL);
