-- ============================================================
-- RPC functions para la Tienda pública (acceso anónimo)
-- Usan SECURITY DEFINER para bypasear RLS de profiles
-- ============================================================

-- 1. Listar proveedores con productos activos
CREATE OR REPLACE FUNCTION get_proveedores_tienda()
RETURNS json
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(json_agg(t), '[]'::json)
  FROM (
    WITH active_prods AS (
      SELECT proveedor_id, category_id
      FROM proveedor_productos
      WHERE precio IS NOT NULL
        AND cantidad > 0
        AND is_paused = false
    ),
    prod_counts AS (
      SELECT proveedor_id, count(*)::int AS active_count
      FROM active_prods
      GROUP BY proveedor_id
    ),
    top_group AS (
      SELECT DISTINCT ON (sub.proveedor_id)
        sub.proveedor_id,
        sub.group_name
      FROM (
        SELECT ap.proveedor_id, c.group_name, count(*) AS n
        FROM active_prods ap
        JOIN categories c ON c.id = ap.category_id
        WHERE c.group_name IS NOT NULL AND c.group_name <> ''
        GROUP BY ap.proveedor_id, c.group_name
        ORDER BY ap.proveedor_id, n DESC
      ) sub
    )
    SELECT
      p.id,
      p.shop_name,
      p.logo_url,
      tg.group_name,
      pc.active_count
    FROM profiles p
    JOIN prod_counts pc ON pc.proveedor_id = p.id
    LEFT JOIN top_group tg ON tg.proveedor_id = p.id
    WHERE p.role = 'proveedor'
       OR (p.is_proveedor = true AND p.can_be_proveedor = true)
    ORDER BY pc.active_count DESC
  ) t;
$$;

-- 2. Listar productos activos de un proveedor
CREATE OR REPLACE FUNCTION get_productos_proveedor(p_proveedor_id uuid)
RETURNS json
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(json_agg(t), '[]'::json)
  FROM (
    SELECT
      pp.id,
      pp.sku,
      pp.precio,
      pp.cantidad,
      pp.calidad,
      pp.presentacion,
      pp.foto_url,
      c.name        AS category_name,
      c.group_name  AS category_group_name,
      c.image_url   AS category_image_url,
      sc.name       AS sub_category_name,
      sc.image_url  AS sub_category_image_url,
      scl.name      AS sub_color_name,
      scl.color     AS sub_color_hex,
      scl.image_url AS sub_color_image_url
    FROM proveedor_productos pp
    LEFT JOIN categories c      ON c.id   = pp.category_id
    LEFT JOIN sub_categories sc ON sc.id  = pp.sub_category_id
    LEFT JOIN sub_colors scl    ON scl.id = pp.sub_color_id
    WHERE pp.proveedor_id = p_proveedor_id
      AND pp.precio IS NOT NULL
      AND pp.cantidad > 0
      AND pp.is_paused = false
    ORDER BY pp.created_at DESC
  ) t;
$$;

-- Permitir acceso anónimo a estas funciones
GRANT EXECUTE ON FUNCTION get_proveedores_tienda() TO anon;
GRANT EXECUTE ON FUNCTION get_productos_proveedor(uuid) TO anon;
