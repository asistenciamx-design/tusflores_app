-- =======================================================
-- Migración: Actualizar estados de pedidos al nuevo sistema
-- Ejecuta este script en Supabase > SQL Editor
-- =======================================================

-- Los pedidos con estado 'pending' pasan a 'waiting' (En espera).
-- No se necesitan nuevas columnas: 'status' ya es TEXT y acepta los nuevos valores.
UPDATE public.orders
SET status = 'waiting'
WHERE status = 'pending';

-- =======================================================
-- LISTO. Estados disponibles a partir de ahora:
--   waiting    → En espera
--   processing → Elaborando
--   in_transit → En tránsito
--   delivered  → Entregado
--   cancelled  → Cancelado
-- =======================================================
