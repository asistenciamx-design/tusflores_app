-- ============================================================================
-- Seed: 10 grupos oficiales de flores + todas las flores por categoría
-- Las flores con aparición en múltiples grupos se asignan al primero.
-- ============================================================================

-- ── 1. Insertar los 10 grupos oficiales ──────────────────────────────────────
INSERT INTO category_groups (name, sort_order)
VALUES
  ('Comerciales',  1),
  ('Relleno',      2),
  ('Bulbo',        3),
  ('Silvestres',   4),
  ('Tropicales',   5),
  ('Orquídeas',    6),
  ('Jardín',       7),
  ('Verano',       8),
  ('Aromáticas',   9),
  ('Temporada',   10)
ON CONFLICT (name) DO NOTHING;

-- ── 2. Insertar flores (una sola categoría por flor) ─────────────────────────
-- Duplicados resueltos: queda en la primera categoría donde aparecen.
-- Caléndula → Silvestres, Lisianthus → Comerciales, Sweetpea → Silvestres,
-- Convallaria → Bulbo, Violeta → Silvestres, Cempasúchil → Verano

INSERT INTO categories (name, group_name, sort_order)
VALUES
  -- ── Comerciales ────────────────────────────────────────────────────────────
  ('Rosa',              'Comerciales',  1),
  ('Tulipán',           'Comerciales',  2),
  ('Clavel',            'Comerciales',  3),
  ('Crisantemo',        'Comerciales',  4),
  ('Gerbera',           'Comerciales',  5),
  ('Lily oriental',     'Comerciales',  6),
  ('Lisianthus',        'Comerciales',  7),
  ('Gladiolo',          'Comerciales',  8),
  ('Snapdragon',        'Comerciales',  9),
  ('Alstroemeria',      'Comerciales', 10),
  ('Peonía',            'Comerciales', 11),
  ('Ranúnculo',         'Comerciales', 12),
  ('Dalia',             'Comerciales', 13),
  ('Hortensia',         'Comerciales', 14),
  ('Calla Lily',        'Comerciales', 15),

  -- ── Relleno ────────────────────────────────────────────────────────────────
  ('Gypsophila',           'Relleno',  1),
  ('Limonium / Statice',   'Relleno',  2),
  ('Trachelium',           'Relleno',  3),
  ('Bouvardia',            'Relleno',  4),
  ('Aster',                'Relleno',  5),
  ('Eryngium',             'Relleno',  6),
  ('Hypericum',            'Relleno',  7),
  ('Molucella',            'Relleno',  8),
  ('Nigella',              'Relleno',  9),
  ('Eucalipto',            'Relleno', 10),
  ('Liatris',              'Relleno', 11),
  ('Echinops',             'Relleno', 12),
  ('Carthamus',            'Relleno', 13),
  ('Feverfew',             'Relleno', 14),
  ('Azul marino / Didiscus','Relleno',15),

  -- ── Bulbo ──────────────────────────────────────────────────────────────────
  ('Jacinto',                  'Bulbo',  1),
  ('Narciso',                  'Bulbo',  2),
  ('Iris',                     'Bulbo',  3),
  ('Allium',                   'Bulbo',  4),
  ('Muscari',                  'Bulbo',  5),
  ('Crocus',                   'Bulbo',  6),
  ('Fritillaria',               'Bulbo',  7),
  ('Convallaria',               'Bulbo',  8),
  ('Nerine',                    'Bulbo',  9),
  ('Amarilis',                  'Bulbo', 10),
  ('Agapanto',                  'Bulbo', 11),
  ('Crocosmia / Montbretia',    'Bulbo', 12),
  ('Freesia',                   'Bulbo', 13),
  ('Eremurus',                  'Bulbo', 14),

  -- ── Silvestres ─────────────────────────────────────────────────────────────
  ('Lavanda',                  'Silvestres',  1),
  ('Centáurea / Aciano',       'Silvestres',  2),
  ('Lupino',                   'Silvestres',  3),
  ('Dedalera',                 'Silvestres',  4),
  ('Equinácea',                'Silvestres',  5),
  ('Rudbeckia',                'Silvestres',  6),
  ('Caléndula',                'Silvestres',  7),
  ('Helenio',                  'Silvestres',  8),
  ('Gaillardia',               'Silvestres',  9),
  ('Cosmos',                   'Silvestres', 10),
  ('Sweetpea',                 'Silvestres', 11),
  ('Godetia / Clarkia',        'Silvestres', 12),
  ('Anémona',                  'Silvestres', 13),
  ('Heléboro',                 'Silvestres', 14),
  ('Acónito',                  'Silvestres', 15),
  ('Delfinium',                'Silvestres', 16),
  ('Larkspur',                 'Silvestres', 17),
  ('Astilbe',                  'Silvestres', 18),
  ('Astrantia',                'Silvestres', 19),
  ('Campanula',                'Silvestres', 20),
  ('Escabiosa',                'Silvestres', 21),
  ('Scabiosa',                 'Silvestres', 22),
  ('Verónica',                 'Silvestres', 23),
  ('Sanguisorba',              'Silvestres', 24),
  ('Tweedia',                  'Silvestres', 25),
  ('Platycodon',               'Silvestres', 26),
  ('Dianthus / Sweet William', 'Silvestres', 27),
  ('Lirio del día',            'Silvestres', 28),
  ('Nomeolvides',              'Silvestres', 29),
  ('Pensamiento',              'Silvestres', 30),
  ('Violeta',                  'Silvestres', 31),
  ('Borraja',                  'Silvestres', 32),
  ('Manzanilla',               'Silvestres', 33),
  ('Tropaeolum',               'Silvestres', 34),
  ('Bleeding Heart',           'Silvestres', 35),
  ('Gentiana',                 'Silvestres', 36),
  ('Salvia ornamental',        'Silvestres', 37),
  ('Bomarea',                  'Silvestres', 38),
  ('Cantua',                   'Silvestres', 39),

  -- ── Tropicales ─────────────────────────────────────────────────────────────
  ('Heliconia',        'Tropicales',  1),
  ('Ave del Paraíso',  'Tropicales',  2),
  ('Anthurium',        'Tropicales',  3),
  ('Protea',           'Tropicales',  4),
  ('Leucadendron',     'Tropicales',  5),
  ('Leucospermum',     'Tropicales',  6),
  ('Kangaroo Paw',     'Tropicales',  7),
  ('Gloriosa',         'Tropicales',  8),
  ('Bromelia',         'Tropicales',  9),
  ('Alpinia',          'Tropicales', 10),
  ('Ginger tropical',  'Tropicales', 11),
  ('Banksia',          'Tropicales', 12),
  ('Wax Flower',       'Tropicales', 13),
  ('Rice Flower',      'Tropicales', 14),
  ('Cynara',           'Tropicales', 15),
  ('Brunia',           'Tropicales', 16),

  -- ── Orquídeas ──────────────────────────────────────────────────────────────
  ('Orquídea Phalaenopsis', 'Orquídeas', 1),
  ('Orquídea Dendrobium',   'Orquídeas', 2),
  ('Orquídea Cymbidium',    'Orquídeas', 3),
  ('Orquídea Vanda',        'Orquídeas', 4),
  ('Orquídea Cattleya',     'Orquídeas', 5),
  ('Orquídea Oncidium',     'Orquídeas', 6),

  -- ── Jardín ─────────────────────────────────────────────────────────────────
  ('Viburnum',              'Jardín',  1),
  ('Lila arbustiva',        'Jardín',  2),
  ('Cerezo japonés',        'Jardín',  3),
  ('Sauce Pussywillow',     'Jardín',  4),
  ('Camelia',               'Jardín',  5),
  ('Azalea',                'Jardín',  6),
  ('Hortensia paniculada',  'Jardín',  7),
  ('Pittosporum',           'Jardín',  8),
  ('Helecho asparagus',     'Jardín',  9),
  ('Magnolia',              'Jardín', 10),

  -- ── Verano ─────────────────────────────────────────────────────────────────
  ('Girasol',      'Verano', 1),
  ('Zinnia',       'Verano', 2),
  ('Celosía',      'Verano', 3),
  ('Gomphrena',    'Verano', 4),
  ('Amaranto',     'Verano', 5),
  ('Cempasúchil',  'Verano', 6),

  -- ── Aromáticas ─────────────────────────────────────────────────────────────
  -- (Lisianthus→Comerciales, Sweetpea→Silvestres, Convallaria→Bulbo, Violeta→Silvestres)
  ('Tuberosa',    'Aromáticas', 1),
  ('Eucharis',    'Aromáticas', 2),
  ('Heliotropo',  'Aromáticas', 3),
  ('Heather',     'Aromáticas', 4),
  ('Plumeria',    'Aromáticas', 5),

  -- ── Temporada ──────────────────────────────────────────────────────────────
  -- (Cempasúchil→Verano)
  ('Flor de nochebuena',        'Temporada', 1),
  ('Helichrysum / Strawflower', 'Temporada', 2),
  ('Lunaria',                   'Temporada', 3),
  ('Loto',                      'Temporada', 4),
  ('Nenúfar',                   'Temporada', 5),
  ('Leptospermum',              'Temporada', 6)

ON CONFLICT (name) DO NOTHING;
