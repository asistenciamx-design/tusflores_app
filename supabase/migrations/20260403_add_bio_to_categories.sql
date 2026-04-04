-- ──────────────────────────────────────────────────────────────────────────────
-- Agregar columna bio a categories para biografía editorial de cada flor
-- ──────────────────────────────────────────────────────────────────────────────
ALTER TABLE categories
  ADD COLUMN IF NOT EXISTS bio TEXT;
