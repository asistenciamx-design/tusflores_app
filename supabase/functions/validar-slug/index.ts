import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const pais = url.searchParams.get('pais')
    const slug = url.searchParams.get('slug')

    if (!pais || !slug) {
      return new Response(
        JSON.stringify({ error: 'Parámetros pais y slug son requeridos' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const validCountries = ['mx', 'co', 'ar']
    if (!validCountries.includes(pais.toLowerCase())) {
      return new Response(
        JSON.stringify({ error: 'País no válido', valid: validCountries }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    const { data, error } = await supabase
      .from('slugs_registry')
      .select('entity_type, entity_id')
      .eq('pais', pais.toLowerCase())
      .eq('slug', slug.toLowerCase())
      .maybeSingle()

    if (error) throw error

    if (!data) {
      return new Response(
        JSON.stringify({ found: false }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    return new Response(
      JSON.stringify({
        found: true,
        entity_type: data.entity_type,
        entity_id: data.entity_id,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: 'Error interno del servidor' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  }
})
