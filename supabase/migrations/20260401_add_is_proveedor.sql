-- Permite que un shop_owner tenga también perfil de proveedor
-- sin necesidad de una cuenta separada.
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_proveedor BOOLEAN NOT NULL DEFAULT FALSE;
