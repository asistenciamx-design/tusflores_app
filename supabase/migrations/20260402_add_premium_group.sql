-- Agrega "Premium" como valor permitido en el CHECK constraint de categories.group_name
-- El constraint original no incluía grupos creados manualmente por el admin.

ALTER TABLE categories DROP CONSTRAINT IF EXISTS categories_group_name_check;

ALTER TABLE categories ADD CONSTRAINT categories_group_name_check
  CHECK (group_name = ANY (ARRAY[
    'Comerciales'::text,
    'Relleno'::text,
    'Bulbo'::text,
    'Silvestres'::text,
    'Tropicales'::text,
    'Orquídeas'::text,
    'Jardín'::text,
    'Verano'::text,
    'Aromáticas'::text,
    'Temporada'::text,
    'Flor'::text,
    'Ocasión'::text,
    'Tipo'::text,
    'Premium'::text
  ]));
