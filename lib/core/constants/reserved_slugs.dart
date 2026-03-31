/// Slugs reservados que ningún usuario puede registrar.
/// Incluye rutas de la app, términos genéricos en español e inglés,
/// y slugs protegidos por el propietario de la plataforma.
const Set<String> kReservedSlugs = {
  // ── Rutas internas de la app ────────────────────────────────────────────
  'login',
  'registro',
  'crear-cuenta',
  'create-account',
  'reset-password',
  'restablecer-contrasena',
  'verificar-codigo',
  'verify-code',
  'admin',
  'dashboard',
  'catalogo',
  'catalog',
  'pedidos',
  'orders',
  'perfil',
  'profile',
  'configuracion',
  'settings',
  'reparto',
  'delivery',
  'seguimiento',
  'tracking',
  'resena',
  'resenas',
  'reviews',
  'privacidad',
  'privacy',
  'terminos',
  'terms',
  'shop',
  'tienda',
  'api',
  'app',
  'web',
  'www',
  'help',
  'ayuda',
  'soporte',
  'support',
  'contact',
  'contacto',
  'about',
  'acerca',
  'faq',
  'preguntas',

  // ── Términos genéricos que nadie puede usar ─────────────────────────────
  'flores',
  'flowers',
  'floreria',
  'florerias',
  'florist',
  'florists',
  'proveedor',
  'proveedores',
  'supplier',
  'suppliers',
  'rosas',
  'roses',
  'bouquet',
  'bouquets',
  'ramo',
  'ramos',
  'arreglo',
  'arreglos',
  'arrangement',
  'arrangements',

  // ── Sufijos bloqueados (variantes online) ───────────────────────────────
  // Cualquier slug que termine con estos sufijos se bloquea dinámicamente.
  // (ver kBlockedSuffixes abajo)

  // mercadojamaica y variantes están en kOwnerExclusiveSlugs, no aquí.
};

/// Sufijos que se bloquean dinámicamente.
/// Si un slug termina con alguno de estos, se rechaza.
/// Ej: "mi-floreria-online", "rosas-en-linea", "flores-on-line"
const Set<String> kBlockedSuffixes = {
  '-online',
  '-on-line',
  '-en-linea',
  '-en-línea',
  '-enlinea',
  '-internet',
  '-en-internet',
};

/// Prefijos de "mercadojamaica" que se bloquean para proteger la marca.
/// Ej: "mercadojamaica-flores", "mercado-jamaica-rosas"
const Set<String> kProtectedPrefixes = {
  'mercadojamaica',
  'mercado-jamaica',
};

/// Valida que un slug no sea reservado, no tenga sufijos bloqueados,
/// y no use prefijos protegidos.
/// Retorna `null` si es válido, o un mensaje de error si no lo es.
/// Slugs que son propiedad exclusiva de una cuenta específica.
/// El cliente los permite si el usuario es el dueño; el trigger
/// server-side valida el entity_id como segunda capa.
const Set<String> kOwnerExclusiveSlugs = {
  'mercadojamaica',
  'mercado-jamaica',
  'mercado-de-jamaica',
  'mercadodejamaica',
};

/// UUID del dueño de mercadojamaica (para validación client-side).
const String kMercadoJamaicaOwnerId = '01214284-1342-4b0d-acf3-46e855e33938';

String? validateSlugReserved(String slug, {String? currentUserId}) {
  final lower = slug.toLowerCase().trim();

  // Slugs exclusivos: solo el dueño puede usarlos
  if (kOwnerExclusiveSlugs.contains(lower)) {
    if (currentUserId == kMercadoJamaicaOwnerId) return null;
    return 'Este nombre no está disponible';
  }

  if (kReservedSlugs.contains(lower)) {
    return 'Este nombre no está disponible';
  }

  for (final suffix in kBlockedSuffixes) {
    if (lower.endsWith(suffix)) {
      return 'No se permiten nombres que terminen en "$suffix"';
    }
  }

  for (final prefix in kProtectedPrefixes) {
    if (lower.startsWith(prefix) && lower != 'mercadojamaica') {
      return 'Este nombre está protegido';
    }
  }

  return null;
}

/// Valida el formato del slug: solo a-z, 0-9 y guiones.
/// No puede empezar ni terminar con guion, ni tener guiones consecutivos.
String? validateSlugFormat(String slug) {
  if (slug.isEmpty) return 'Ingresa un nombre para tu URL';
  if (slug.length < 3) return 'Mínimo 3 caracteres';
  if (slug.length > 60) return 'Máximo 60 caracteres';
  if (!RegExp(r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?$').hasMatch(slug)) {
    return 'Solo letras minúsculas, números y guiones (sin empezar/terminar con guion)';
  }
  if (slug.contains('--')) return 'No se permiten guiones consecutivos';
  return null;
}
