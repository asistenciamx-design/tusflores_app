-- Agrega campo is_paused a proveedor_productos
-- Permite al proveedor pausar un producto sin eliminarlo
ALTER TABLE proveedor_productos
ADD COLUMN IF NOT EXISTS is_paused boolean NOT NULL DEFAULT false;

-- Actualizar trigger: is_active = false si is_paused = true
CREATE OR REPLACE FUNCTION fn_proveedor_producto_active()
RETURNS trigger AS $$
BEGIN
  NEW.is_active := (
    NEW.precio IS NOT NULL
    AND NEW.cantidad > 0
    AND NEW.presentacion IS NOT NULL
    AND NEW.is_paused = false
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
