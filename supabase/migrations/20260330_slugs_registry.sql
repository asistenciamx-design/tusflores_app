-- ============================================================================
-- slugs_registry: tabla única de slugs para florerías y proveedores
-- Garantiza unicidad cross-tabla por (pais, slug)
-- ============================================================================

CREATE TABLE IF NOT EXISTS slugs_registry (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pais       TEXT NOT NULL CHECK (pais IN ('mx', 'co', 'ar')),
  slug       TEXT NOT NULL,
  entity_type TEXT NOT NULL CHECK (entity_type IN ('floreria', 'proveedor')),
  entity_id  UUID NOT NULL,              -- profile.id o proveedor.id
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT uq_slug_per_country UNIQUE (pais, slug)
);

-- Índice para búsquedas rápidas por slug (usado por GoRouter)
CREATE INDEX IF NOT EXISTS idx_slugs_registry_lookup
  ON slugs_registry (pais, slug);

-- Índice para buscar slugs de una entidad específica
CREATE INDEX IF NOT EXISTS idx_slugs_registry_entity
  ON slugs_registry (entity_type, entity_id);

-- ── RLS ──────────────────────────────────────────────────────────────────────
ALTER TABLE slugs_registry ENABLE ROW LEVEL SECURITY;

-- Cualquier usuario (incluso anónimo) puede leer slugs (necesario para resolver URLs)
CREATE POLICY "slugs_select_all"
  ON slugs_registry FOR SELECT
  USING (true);

-- Solo el dueño de la entidad puede insertar/actualizar/eliminar su slug
CREATE POLICY "slugs_insert_own"
  ON slugs_registry FOR INSERT
  WITH CHECK (auth.uid() = entity_id);

CREATE POLICY "slugs_update_own"
  ON slugs_registry FOR UPDATE
  USING (auth.uid() = entity_id);

CREATE POLICY "slugs_delete_own"
  ON slugs_registry FOR DELETE
  USING (auth.uid() = entity_id);

-- ── Función para validar slug desde el cliente ──────────────────────────────
CREATE OR REPLACE FUNCTION check_slug_available(p_pais TEXT, p_slug TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM slugs_registry WHERE pais = p_pais AND slug = p_slug
  );
$$;
