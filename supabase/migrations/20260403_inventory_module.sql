-- ── Módulo de Inventario: Listas de Compra ────────────────────────────────────

CREATE TABLE IF NOT EXISTS inventory_lists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  floreria_id UUID NOT NULL,                        -- FK lógica al user_id (dueño)
  created_by_user_id UUID NOT NULL,
  title TEXT NOT NULL,                              -- "Nota 1", "Nota 2", etc.
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  is_active BOOLEAN DEFAULT TRUE,
  is_completed BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS inventory_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  list_id UUID NOT NULL REFERENCES inventory_lists(id) ON DELETE CASCADE,
  sequence_number INT NOT NULL,
  product_name TEXT NOT NULL,
  color TEXT,
  quality TEXT,
  quantity INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_inventory_lists_floreria_id    ON inventory_lists(floreria_id);
CREATE INDEX IF NOT EXISTS idx_inventory_lists_created_by     ON inventory_lists(created_by_user_id);
CREATE INDEX IF NOT EXISTS idx_inventory_items_list_id        ON inventory_items(list_id);

-- RLS
ALTER TABLE inventory_lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_items  ENABLE ROW LEVEL SECURITY;

-- Listas: solo el dueño accede a las suyas
CREATE POLICY "inventory_lists_owner" ON inventory_lists
  FOR ALL USING (floreria_id = auth.uid())
  WITH CHECK (floreria_id = auth.uid());

-- Items: acceso transitivo por list
CREATE POLICY "inventory_items_owner" ON inventory_items
  FOR ALL USING (
    list_id IN (
      SELECT id FROM inventory_lists WHERE floreria_id = auth.uid()
    )
  )
  WITH CHECK (
    list_id IN (
      SELECT id FROM inventory_lists WHERE floreria_id = auth.uid()
    )
  );
