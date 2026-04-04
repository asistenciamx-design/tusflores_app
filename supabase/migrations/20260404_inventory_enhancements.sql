-- ═══════════════════════════════════════════════════════════════════════════════
-- Mejoras al módulo de inventario
-- 1. Folio secuencial por florería (reemplaza folios aleatorios)
-- 2. Campo presentación en items (Bonche, Ramo, Paquete, etc.)
-- 3. Campo precio unitario en items (decimal para cotización/compra)
-- ═══════════════════════════════════════════════════════════════════════════════

-- ── 1. Secuencia de folio por florería ───────────────────────────────────────
-- Eliminamos folios aleatorios existentes y creamos secuencia real.
-- El folio se genera automáticamente con trigger, secuencial por florería.

-- Asegurar que la columna folio exista (ya existe, pero la hacemos NOT NULL con default)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inventory_lists' AND column_name = 'folio'
  ) THEN
    ALTER TABLE inventory_lists ADD COLUMN folio INT;
  END IF;
END $$;

-- Función que genera folio secuencial por florería
CREATE OR REPLACE FUNCTION generate_inventory_folio()
RETURNS TRIGGER AS $$
BEGIN
  SELECT COALESCE(MAX(folio), 0) + 1 INTO NEW.folio
  FROM inventory_lists
  WHERE floreria_id = NEW.floreria_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger antes de insertar
DROP TRIGGER IF EXISTS trg_inventory_folio ON inventory_lists;
CREATE TRIGGER trg_inventory_folio
  BEFORE INSERT ON inventory_lists
  FOR EACH ROW
  EXECUTE FUNCTION generate_inventory_folio();

-- Recalcular folios existentes para que sean secuenciales
WITH ranked AS (
  SELECT id, floreria_id,
         ROW_NUMBER() OVER (PARTITION BY floreria_id ORDER BY created_at) AS new_folio
  FROM inventory_lists
)
UPDATE inventory_lists SET folio = ranked.new_folio
FROM ranked WHERE inventory_lists.id = ranked.id;

-- ── 2. Campo presentación en inventory_items ─────────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inventory_items' AND column_name = 'presentation'
  ) THEN
    ALTER TABLE inventory_items ADD COLUMN presentation TEXT;
  END IF;
END $$;

-- ── 3. Campo precio unitario en inventory_items ──────────────────────────────
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inventory_items' AND column_name = 'unit_price'
  ) THEN
    ALTER TABLE inventory_items ADD COLUMN unit_price NUMERIC(10,2);
  END IF;
END $$;

-- ── 4. Proveedor asignado a la lista ────────────────────────────────────────
-- supplier_id referencia al perfil del proveedor (profiles.id)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inventory_lists' AND column_name = 'supplier_id'
  ) THEN
    ALTER TABLE inventory_lists ADD COLUMN supplier_id UUID REFERENCES profiles(id);
  END IF;
END $$;

-- Nombre del proveedor (cache para mostrar sin JOIN)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inventory_lists' AND column_name = 'supplier_name'
  ) THEN
    ALTER TABLE inventory_lists ADD COLUMN supplier_name TEXT;
  END IF;
END $$;
