-- ============================================================================
-- slugs_registry: tabla única de slugs para florerías y proveedores
-- Garantiza unicidad cross-tabla por (pais, slug)
-- ============================================================================

CREATE TABLE IF NOT EXISTS slugs_registry (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pais        TEXT NOT NULL CHECK (pais IN ('mx', 'co', 'ar')),
  slug        TEXT NOT NULL CHECK (slug = LOWER(slug)),
  entity_type TEXT NOT NULL CHECK (entity_type IN ('floreria', 'proveedor')),
  entity_id   UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT uq_slug_per_country UNIQUE (pais, slug),
  CONSTRAINT uq_one_slug_per_entity UNIQUE (entity_id)
);

-- Índice para búsquedas rápidas por slug (usado por GoRouter)
CREATE INDEX IF NOT EXISTS idx_slugs_registry_lookup
  ON slugs_registry (pais, slug);

-- Índice para buscar slugs de una entidad específica
CREATE INDEX IF NOT EXISTS idx_slugs_registry_entity
  ON slugs_registry (entity_type, entity_id);

-- ── Auto-actualizar updated_at ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_slugs_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_slugs_updated_at
  BEFORE UPDATE ON slugs_registry
  FOR EACH ROW EXECUTE FUNCTION update_slugs_updated_at();

-- ── Validar slugs reservados en servidor (no solo en cliente) ────────────────
CREATE OR REPLACE FUNCTION validate_slug_not_reserved()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  reserved TEXT[] := ARRAY[
    'login','registro','crear-cuenta','create-account','reset-password',
    'restablecer-contrasena','verificar-codigo','verify-code',
    'admin','dashboard','catalogo','catalog','pedidos','orders',
    'perfil','profile','configuracion','settings','reparto','delivery',
    'seguimiento','tracking','resena','resenas','reviews',
    'privacidad','privacy','terminos','terms','shop','tienda',
    'api','app','web','www','help','ayuda','soporte','support',
    'contact','contacto','about','acerca','faq','preguntas',
    'flores','flowers','floreria','florerias','florist','florists',
    'proveedor','proveedores','supplier','suppliers',
    'rosas','roses','bouquet','bouquets','ramo','ramos',
    'arreglo','arreglos','arrangement','arrangements',
    'mercadojamaica','mercado-jamaica','mercado-de-jamaica','mercadodejamaica'
  ];
  blocked_suffixes TEXT[] := ARRAY[
    '-online','-on-line','-en-linea','-enlinea','-internet','-en-internet'
  ];
  protected_prefixes TEXT[] := ARRAY['mercadojamaica','mercado-jamaica'];
  s TEXT;
BEGIN
  -- Slug reservado
  IF NEW.slug = ANY(reserved) THEN
    RAISE EXCEPTION 'slug_reserved: Este nombre no esta disponible'
      USING ERRCODE = 'P0001';
  END IF;

  -- Sufijos bloqueados
  FOREACH s IN ARRAY blocked_suffixes LOOP
    IF NEW.slug LIKE '%' || s THEN
      RAISE EXCEPTION 'slug_blocked_suffix: No se permiten nombres que terminen en %', s
        USING ERRCODE = 'P0001';
    END IF;
  END LOOP;

  -- Prefijos protegidos (solo "mercadojamaica" exacto permitido)
  FOREACH s IN ARRAY protected_prefixes LOOP
    IF NEW.slug LIKE s || '-%' THEN
      RAISE EXCEPTION 'slug_protected_prefix: Este nombre esta protegido'
        USING ERRCODE = 'P0001';
    END IF;
  END LOOP;

  -- Formato: solo a-z, 0-9, guiones; sin empezar/terminar con guion
  IF NEW.slug !~ '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$' THEN
    RAISE EXCEPTION 'slug_invalid_format: Formato de slug invalido'
      USING ERRCODE = 'P0001';
  END IF;

  IF NEW.slug ~ '--' THEN
    RAISE EXCEPTION 'slug_consecutive_hyphens: No se permiten guiones consecutivos'
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_slug
  BEFORE INSERT OR UPDATE ON slugs_registry
  FOR EACH ROW EXECUTE FUNCTION validate_slug_not_reserved();

-- ── RLS ──────────────────────────────────────────────────────────────────────
ALTER TABLE slugs_registry ENABLE ROW LEVEL SECURITY;

-- Cualquier usuario (incluso anónimo) puede leer slugs (necesario para resolver URLs)
CREATE POLICY "slugs_select_all"
  ON slugs_registry FOR SELECT
  USING (true);

-- Solo el dueño puede insertar su propio slug (entity_id debe ser su uid)
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
    SELECT 1 FROM slugs_registry WHERE pais = p_pais AND slug = LOWER(p_slug)
  );
$$;
