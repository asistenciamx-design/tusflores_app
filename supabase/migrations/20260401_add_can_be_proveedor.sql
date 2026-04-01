-- Puerta 1 (super admin): autorización para que una florería pueda activar el modo proveedor.
-- Por default ninguna florería tiene este permiso.
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS can_be_proveedor BOOLEAN NOT NULL DEFAULT FALSE;
