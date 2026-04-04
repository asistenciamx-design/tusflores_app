/// Color de flor con nombre y código hex para visualización.
class FlowerColor {
  final String name;
  final String hex;
  final bool isBasic;

  const FlowerColor(this.name, this.hex, {this.isBasic = false});
}

/// Catálogo completo de colores de flores para autocompletado en inventario.
/// Básicos primero (A-Z), luego tonos del catálogo (por hex oscuro→claro).
const List<FlowerColor> kFlowerColorCatalog = [
  // ── Colores básicos ────────────────────────────────────────────────────────
  FlowerColor('Amarillo',    '#FFD700', isBasic: true),
  FlowerColor('Azul',        '#6A90D0', isBasic: true),
  FlowerColor('Blanco',      '#F8F8F5', isBasic: true),
  FlowerColor('Champagne',   '#EDD9A3', isBasic: true),
  FlowerColor('Coral',       '#FF6F61', isBasic: true),
  FlowerColor('Crema',       '#FFF9F0', isBasic: true),
  FlowerColor('Durazno',     '#FFCBA4', isBasic: true),
  FlowerColor('Fucsia',      '#D5006D', isBasic: true),
  FlowerColor('Lavanda',     '#C9B1D9', isBasic: true),
  FlowerColor('Lila',        '#C8A2C8', isBasic: true),
  FlowerColor('Marfil',      '#F3E5C0', isBasic: true),
  FlowerColor('Morado',      '#7B2D8B', isBasic: true),
  FlowerColor('Naranja',     '#FF8C55', isBasic: true),
  FlowerColor('Rojo',        '#CC0000', isBasic: true),
  FlowerColor('Rosa',        '#F4A7B9', isBasic: true),
  FlowerColor('Salmón',      '#FA8072', isBasic: true),
  FlowerColor('Verde',       '#8DB83A', isBasic: true),
  // ── Tonos del catálogo ─────────────────────────────────────────────────────
  FlowerColor('Ébano',             '#100408'),
  FlowerColor('Black Baccara',     '#1A060E'),
  FlowerColor('Centro negro',      '#1A0A06'),
  FlowerColor('Kokarde',           '#1A0A0A'),
  FlowerColor('Black Jack',        '#1A0A0E'),
  FlowerColor('Schwarzwalder',     '#1A0A10'),
  FlowerColor('Baya madura',       '#1A1A1A'),
  FlowerColor('Centro verde',      '#1A2A0A'),
  FlowerColor('Botella',           '#1B5E20'),
  FlowerColor('Queen of Night',    '#1C0A10'),
  FlowerColor('Centro gris',       '#1E1A18'),
  FlowerColor('Terciopelo',        '#200810'),
  FlowerColor('Borgoña',           '#2A0818'),
  FlowerColor('Centro café',       '#2A1008'),
  FlowerColor('Oscuro brillante',  '#2A5A2A'),
  FlowerColor('Profundo',          '#3A0858'),
  FlowerColor('Ciruela',           '#3A0A28'),
  FlowerColor('Marino',            '#3A3A8A'),
  FlowerColor('Medio',             '#3A6A3A'),
  FlowerColor('Hoja',              '#3A7D44'),
  FlowerColor('Oscuro',            '#4A0D6A'),
  FlowerColor('Violeta',           '#5A5090'),
  FlowerColor('Acero',             '#5A80A0'),
  FlowerColor('Oscuro (Ming)',     '#5A8A3A'),
  FlowerColor('Variegado',         '#5A8A5A'),
  FlowerColor('Bordeaux',          '#5C1230'),
  FlowerColor('Intenso',           '#6A006A'),
  FlowerColor('Loro',              '#6B8E23'),
  FlowerColor('Vino',              '#722F37'),
  FlowerColor('Denim',             '#7B90B8'),
  FlowerColor('Cereza',            '#7D0C0C'),
  FlowerColor('Granate',           '#800020'),
  FlowerColor('Plateado azulado',  '#8090B8'),
  FlowerColor('Púrpura',           '#8B1A6B'),
  FlowerColor('Manzana',           '#A8D040'),
  FlowerColor('Malva',             '#9B59B6'),
  FlowerColor('Carmesí',           '#A40000'),
  FlowerColor('Viejo',             '#B07880'),
  FlowerColor('Bl+Violeta',        '#B0A0D0'),
  FlowerColor('Cobrizo',           '#B5651D'),
  FlowerColor('Baby Blue',         '#B8C8D0'),
  FlowerColor('Pálido',            '#B8C8E8'),
  FlowerColor('Rosa+Morado',       '#C060A0'),
  FlowerColor('Terracota',         '#C0634A'),
  FlowerColor('Silver Dollar',     '#C0C8B8'),
  FlowerColor('Gris plateado',     '#C0C8C0'),
  FlowerColor('Magenta',           '#C2185B'),
  FlowerColor('Frambuesa',         '#C41E5B'),
  FlowerColor('Bronce',            '#C88030'),
  FlowerColor('Antiguo',           '#C8A0A0'),
  FlowerColor('Verde-amarillo nube','#C8D8A0'),
  FlowerColor('Verde plateado',    '#C8D8C0'),
  FlowerColor('Blanco plateado',   '#C8D8E0'),
  FlowerColor('Menta',             '#C8E6C9'),
  FlowerColor('Quemado',           '#CC4400'),
  FlowerColor('Lila rosado',       '#D0A0C0'),
  FlowerColor('Miel',              '#D4900A'),
  FlowerColor('Cobre',             '#D4907A'),
  FlowerColor('Ocre',              '#D4A017'),
  FlowerColor('Rosado lila',       '#D8A0C8'),
  FlowerColor('Perla',             '#D8D0C8'),
  FlowerColor('Lino',              '#DED0B0'),
  FlowerColor('Mandarina',         '#E84E20'),
  FlowerColor('Stargazer',         '#E8607A'),
  FlowerColor('Beige dorado',      '#E8C97A'),
  FlowerColor('Fuerte',            '#E91E8C'),
  FlowerColor('Chicle',            '#F06292'),
  FlowerColor('Azulado',           '#F0F0F8'),
  FlowerColor('Verdoso',           '#F0F5E8'),
  FlowerColor('Beige',             '#F2D0BE'),
  FlowerColor('Claro',             '#FFF176'),
  FlowerColor('Bl+Rosa',           '#F4C0CC'),
  FlowerColor('Bl+Rojo',           '#F5C0C0'),
  FlowerColor('Nieve',             '#F5F5F5'),
  FlowerColor('Bebé',              '#F8C8D0'),
  FlowerColor('Pastel',            '#F9C0CB'),
  FlowerColor('Limón',             '#F9E84A'),
  FlowerColor('Escarlata',         '#FF2400'),
  FlowerColor('Fuego',             '#FF3B1E'),
  FlowerColor('Ardiente',          '#FF5F1F'),
  FlowerColor('Bi.Amarillo',       '#FF8C00'),
  FlowerColor('Coral salmón',      '#FF8C72'),
  FlowerColor('Coral pálido',      '#FFAA90'),
  FlowerColor('Suave',             '#FFAB60'),
  FlowerColor('Albaricoque',       '#FFAB76'),
  FlowerColor('Melocotón',         '#FFBE9A'),
  FlowerColor('Sol',               '#FFC200'),
  FlowerColor('Dorado',            '#FFD700'),
  FlowerColor('Canario',           '#FFE135'),
  FlowerColor('Mantequilla',       '#FFF0A0'),
];

/// Lista plana de nombres para compatibilidad / búsqueda rápida.
List<String> get kFlowerColors =>
    kFlowerColorCatalog.map((c) => c.name).toSet().toList();

/// Buscar el hex de un color por nombre (primera coincidencia).
String? flowerColorHex(String name) {
  final lower = name.toLowerCase();
  for (final c in kFlowerColorCatalog) {
    if (c.name.toLowerCase() == lower) return c.hex;
  }
  return null;
}
