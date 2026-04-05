-- ── Catálogo de productos del proveedor ────────────────────────────────────
-- Cada fila representa un producto que el proveedor decide vender,
-- tomado del catálogo maestro del super admin (categories + sub_categories + sub_colors).

CREATE TABLE IF NOT EXISTS proveedor_productos (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proveedor_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Referencia al catálogo maestro del admin
  category_id      UUID NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  sub_category_id  UUID REFERENCES sub_categories(id) ON DELETE SET NULL,
  sub_color_id     UUID REFERENCES sub_colors(id) ON DELETE SET NULL,

  -- SKU auto-generado: formato PRV-{proveedor_prefix}-{seq}
  sku              TEXT NOT NULL,

  -- Datos que el proveedor configura
  precio           NUMERIC(10,2),
  cantidad         INTEGER DEFAULT 0,
  calidad          TEXT CHECK (calidad IN ('estándar','campo','primera','premium','exportación')),
  presentacion     TEXT CHECK (presentacion IN ('Pieza','Bonche','Ramo','Paquete','Caja','Gruesa','1/2 Gruesa','10 Tallos','12 Tallos','24 Tallos')),
  foto_url         TEXT,  -- override opcional de la foto del admin

  -- Aparece en tienda pública solo si precio + cantidad + presentacion están completos
  is_active        BOOLEAN DEFAULT false,

  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW(),

  -- Un proveedor no puede tener el mismo color/variante dos veces
  UNIQUE (proveedor_id, category_id, sub_category_id, sub_color_id)
);

-- SKU único por proveedor
CREATE UNIQUE INDEX IF NOT EXISTS idx_proveedor_productos_sku
  ON proveedor_productos (proveedor_id, sku);

-- Índice para cargar catálogo de un proveedor rápido
CREATE INDEX IF NOT EXISTS idx_proveedor_productos_proveedor
  ON proveedor_productos (proveedor_id, is_active);

-- ── RLS ─────────────────────────────────────────────────────────────────────
ALTER TABLE proveedor_productos ENABLE ROW LEVEL SECURITY;

-- El proveedor solo ve y modifica sus propios productos
CREATE POLICY "proveedor_own_productos" ON proveedor_productos
  FOR ALL USING (proveedor_id = auth.uid());

-- Lectura pública para tienda pública (solo productos activos)
CREATE POLICY "public_read_active_productos" ON proveedor_productos
  FOR SELECT USING (is_active = true);

-- ── Trigger: actualizar is_active automáticamente ───────────────────────────
-- Un producto se activa en tienda pública cuando tiene precio + cantidad + presentacion
CREATE OR REPLACE FUNCTION update_proveedor_producto_active()
RETURNS TRIGGER AS $$
BEGIN
  NEW.is_active := (
    NEW.precio IS NOT NULL AND NEW.precio > 0 AND
    NEW.cantidad IS NOT NULL AND NEW.cantidad > 0 AND
    NEW.presentacion IS NOT NULL AND NEW.presentacion != ''
  );
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_proveedor_producto_active
  BEFORE INSERT OR UPDATE ON proveedor_productos
  FOR EACH ROW EXECUTE FUNCTION update_proveedor_producto_active();

-- ── Función para generar SKU auto ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_next_proveedor_producto_sku(p_proveedor_id UUID)
RETURNS TEXT AS $$
DECLARE
  v_prefix TEXT;
  v_count  INTEGER;
  v_sku    TEXT;
BEGIN
  -- Prefijo: primeras 3 letras del shop_name en mayúsculas
  SELECT UPPER(LEFT(REGEXP_REPLACE(shop_name, '[^a-zA-Z]', '', 'g'), 3))
  INTO v_prefix
  FROM profiles WHERE id = p_proveedor_id;

  IF v_prefix IS NULL OR v_prefix = '' THEN
    v_prefix := 'PRV';
  END IF;

  -- Contador de productos del proveedor
  SELECT COUNT(*) + 1 INTO v_count
  FROM proveedor_productos WHERE proveedor_id = p_proveedor_id;

  v_sku := v_prefix || '-' || LPAD(v_count::TEXT, 4, '0');

  -- Garantizar unicidad
  WHILE EXISTS (
    SELECT 1 FROM proveedor_productos
    WHERE proveedor_id = p_proveedor_id AND sku = v_sku
  ) LOOP
    v_count := v_count + 1;
    v_sku := v_prefix || '-' || LPAD(v_count::TEXT, 4, '0');
  END LOOP;

  RETURN v_sku;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
