-- ──────────────────────────────────────────────────────────────────────────────
-- Agregar columna bio a sub_categories (variantes de flores)
-- Los sub_colors (tonos) NO tienen bio — solo categories y sub_categories
-- ──────────────────────────────────────────────────────────────────────────────
ALTER TABLE sub_categories
  ADD COLUMN IF NOT EXISTS bio TEXT;
