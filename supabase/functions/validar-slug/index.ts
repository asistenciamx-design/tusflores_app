import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ALLOWED_ORIGINS = new Set([
  'https://tusflores.app',
  'https://app.tusflores.app',
])

function getCorsHeaders(origin: string | null) {
  const allowed = origin && ALLOWED_ORIGINS.has(origin) ? origin : 'https://tusflores.app'
  return {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Vary': 'Origin',
  }
}

const SLUG_REGEX = /^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/
const VALID_COUNTRIES = new Set(['mx', 'co', 'ar'])

serve(async (req: Request) => {
  const origin = req.headers.get('origin')
  const corsHeaders = getCorsHeaders(origin)

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders })
  }

  const jsonHeaders = { ...corsHeaders, 'Content-Type': 'application/json' }

  try {
    const url = new URL(req.url)
    const rawPais = (url.searchParams.get('pais') ?? '').toLowerCase().trim()
    const rawSlug = (url.searchParams.get('slug') ?? '').toLowerCase().trim()

    if (!rawPais || !rawSlug) {
      return new Response(
        JSON.stringify({ error: 'Parametros pais y slug son requeridos' }),
        { status: 400, headers: jsonHeaders },
      )
    }

    if (!VALID_COUNTRIES.has(rawPais)) {
      return new Response(
        JSON.stringify({ error: 'Pais no valido' }),
        { status: 400, headers: jsonHeaders },
      )
    }

    // Validar formato del slug en servidor (no confiar solo en el cliente)
    if (rawSlug.length < 3 || rawSlug.length > 60) {
      return new Response(
        JSON.stringify({ error: 'Slug debe tener entre 3 y 60 caracteres' }),
        { status: 400, headers: jsonHeaders },
      )
    }

    if (!SLUG_REGEX.test(rawSlug)) {
      return new Response(
        JSON.stringify({ error: 'Formato de slug invalido' }),
        { status: 400, headers: jsonHeaders },
      )
    }

    if (rawSlug.includes('--')) {
      return new Response(
        JSON.stringify({ error: 'No se permiten guiones consecutivos' }),
        { status: 400, headers: jsonHeaders },
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { data, error } = await supabase
      .from('slugs_registry')
      .select('entity_type')
      .eq('pais', rawPais)
      .eq('slug', rawSlug)
      .maybeSingle()

    if (error) throw error

    if (!data) {
      return new Response(
        JSON.stringify({ found: false }),
        { status: 404, headers: jsonHeaders },
      )
    }

    // Solo retornar tipo de entidad, NO el entity_id (evitar enumeración de UUIDs)
    return new Response(
      JSON.stringify({
        found: true,
        entity_type: data.entity_type,
      }),
      { status: 200, headers: jsonHeaders },
    )
  } catch (_err) {
    return new Response(
      JSON.stringify({ error: 'Error interno del servidor' }),
      { status: 500, headers: jsonHeaders },
    )
  }
})
