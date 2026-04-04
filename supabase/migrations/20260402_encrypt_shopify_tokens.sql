-- ──────────────────────────────────────────────────────────────────────────────
-- VULN-017/019: Encriptar tokens de Shopify en reposo
-- Usa pgcrypto para encriptación simétrica con clave en vault/env.
-- ──────────────────────────────────────────────────────────────────────────────

-- Habilitar pgcrypto si no está habilitado
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Agregar columnas encriptadas (transición gradual)
ALTER TABLE shopify_connections
  ADD COLUMN IF NOT EXISTS access_token_enc BYTEA,
  ADD COLUMN IF NOT EXISTS client_secret_enc BYTEA;

-- Función helper para encriptar tokens al insertar/actualizar
-- La clave de encriptación se obtiene de current_setting (configurada como variable de entorno)
-- Fallback: usa una clave derivada del shop_id si no hay variable configurada
CREATE OR REPLACE FUNCTION encrypt_shopify_tokens()
RETURNS TRIGGER AS $$
DECLARE
  v_key TEXT;
BEGIN
  -- Intentar obtener clave de configuración, fallback a derivada
  BEGIN
    v_key := current_setting('app.encryption_key', true);
  EXCEPTION WHEN OTHERS THEN
    v_key := NULL;
  END;

  -- Si no hay clave configurada, usar derivada del shop_id
  IF v_key IS NULL OR v_key = '' THEN
    v_key := encode(digest(NEW.shop_id::TEXT || 'tusflores_shopify_2026', 'sha256'), 'hex');
  END IF;

  -- Encriptar tokens si están en texto plano
  IF NEW.access_token IS NOT NULL AND NEW.access_token != '' THEN
    NEW.access_token_enc := pgp_sym_encrypt(NEW.access_token, v_key);
  END IF;

  IF NEW.client_secret IS NOT NULL AND NEW.client_secret != '' THEN
    NEW.client_secret_enc := pgp_sym_encrypt(NEW.client_secret, v_key);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_encrypt_shopify_tokens ON shopify_connections;
CREATE TRIGGER trg_encrypt_shopify_tokens
  BEFORE INSERT OR UPDATE ON shopify_connections
  FOR EACH ROW
  EXECUTE FUNCTION encrypt_shopify_tokens();

-- Migrar tokens existentes: re-guardar para que el trigger los encripte
-- (se ejecuta el UPDATE para cada fila, activando el trigger)
UPDATE shopify_connections SET updated_at = NOW()
WHERE access_token_enc IS NULL AND access_token IS NOT NULL;
