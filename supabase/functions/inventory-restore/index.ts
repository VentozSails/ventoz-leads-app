import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function jsonResponse(body: object, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    // ── Auth: require admin/owner JWT ──
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return jsonResponse({ error: 'Not authorized' }, 401)

    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? serviceRoleKey
    const token = authHeader.replace('Bearer ', '')
    const { data: { user: caller }, error: authErr } = await createClient(supabaseUrl, anonKey).auth.getUser(token)
    if (authErr || !caller) return jsonResponse({ error: 'Invalid session' }, 401)

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const { data: callerRow } = await admin.from('ventoz_users').select('is_owner, is_admin, user_type').eq('auth_user_id', caller.id).maybeSingle()
    const isAdmin = callerRow?.is_owner || callerRow?.is_admin || ['owner', 'admin'].includes(callerRow?.user_type || '')
    if (!isAdmin) return jsonResponse({ error: 'Admin access required' }, 403)

    const body = await req.json()

    // Verify action: return DB stats
    if (body.action === 'verify') {
      const { data: items, error: itemsErr } = await admin
        .from('inventory_items')
        .select('voorraad_actueel, variant_label, kleur, leverancier_code, categorie')
      if (itemsErr) return jsonResponse({ error: itemsErr.message }, 500)

      const { count: mutCount } = await admin
        .from('inventory_mutations')
        .select('id', { count: 'exact', head: true })

      const totalStock = (items || []).reduce((s: number, r: Record<string, unknown>) => s + (Number(r.voorraad_actueel) || 0), 0)
      const cats: Record<string, number> = {}
      for (const r of items || []) {
        const c = (r.categorie as string) || '(geen)'
        cats[c] = (cats[c] || 0) + 1
      }
      const withStock = (items || [])
        .filter((r: Record<string, unknown>) => (Number(r.voorraad_actueel) || 0) > 0)
        .sort((a: Record<string, unknown>, b: Record<string, unknown>) =>
          (Number(b.voorraad_actueel) || 0) - (Number(a.voorraad_actueel) || 0))
        .slice(0, 15)

      return jsonResponse({
        totalRows: (items || []).length,
        totalStock,
        categories: cats,
        topProducts: withStock,
        totalMutations: mutCount || 0,
      })
    }

    const { rows } = body
    if (!rows || !Array.isArray(rows) || rows.length === 0) {
      return jsonResponse({ error: 'rows array is required' }, 400)
    }

    // 1. Delete all mutations then all inventory items
    await admin.from('inventory_mutations').delete().neq('id', 0)
    await admin.from('inventory_items').delete().neq('id', 0)

    let imported = 0
    let errors = 0
    const errorMessages: string[] = []

    // 2. Insert each row
    for (const row of rows) {
      try {
        const json: Record<string, unknown> = {
          variant_label: row.product || '',
          kleur: row.kleur || '',
          voorraad_actueel: parseInt(row.voorraad) || 0,
          voorraad_minimum: parseInt(row.minimaal) || 0,
          voorraad_besteld: parseInt(row.besteld) || 0,
          laatst_bijgewerkt: new Date().toISOString(),
        }

        if (row.categorie) json.categorie = row.categorie
        if (row.ean) json.ean_code = row.ean
        if (row.artikelnummer) json.artikelnummer = row.artikelnummer
        if (row.code) json.leverancier_code = row.code
        if (row.opmerking) json.opmerking = row.opmerking
        if (row.vervoer) json.vervoer_methode = row.vervoer

        // Price fields
        if (row.inkoop) json.inkoop_prijs = parseFloat(row.inkoop) || null
        if (row.vliegtuig_kosten) json.vliegtuig_kosten = parseFloat(row.vliegtuig_kosten) || null
        if (row.invoertax_admin) json.invoertax_admin = parseFloat(row.invoertax_admin) || null
        if (row.inkoop_totaal) json.inkoop_totaal = parseFloat(row.inkoop_totaal) || null
        if (row.netto_inkoop) json.netto_inkoop = parseFloat(row.netto_inkoop) || null
        if (row.netto_inkoop_waarde) json.netto_inkoop_waarde = parseFloat(row.netto_inkoop_waarde) || null
        if (row.import_kosten) json.import_kosten = parseFloat(row.import_kosten) || null
        if (row.bruto_inkoop) json.bruto_inkoop = parseFloat(row.bruto_inkoop) || null
        if (row.verkoopprijs_incl) json.verkoopprijs_incl = parseFloat(row.verkoopprijs_incl) || null
        if (row.verkoopprijs_excl) json.verkoopprijs_excl = parseFloat(row.verkoopprijs_excl) || null
        if (row.verkoop_waarde_excl) json.verkoop_waarde_excl = parseFloat(row.verkoop_waarde_excl) || null
        if (row.verkoop_waarde_incl) json.verkoop_waarde_incl = parseFloat(row.verkoop_waarde_incl) || null
        if (row.marge) json.marge = parseFloat(row.marge) || null

        // Weight fields
        if (row.gewicht) json.gewicht_gram = parseInt(row.gewicht) || null
        if (row.gewicht_verpakking) json.gewicht_verpakking_gram = parseInt(row.gewicht_verpakking) || null

        const { data: inserted, error: insertError } = await admin
          .from('inventory_items')
          .insert(json)
          .select('id')

        if (insertError) {
          errors++
          if (errorMessages.length < 5) errorMessages.push(`Row ${imported + errors}: ${insertError.message}`)
          continue
        }

        if (inserted && inserted.length > 0) {
          const stock = parseInt(row.voorraad) || 0
          if (stock !== 0) {
            await admin.from('inventory_mutations').insert({
              inventory_item_id: inserted[0].id,
              hoeveelheid_delta: stock,
              reden: 'Volledige herimport vanuit Excel',
              bron: 'csv_replace',
            })
          }
        }

        imported++
      } catch (e) {
        errors++
        if (errorMessages.length < 5) errorMessages.push(`Row ${imported + errors}: ${String(e)}`)
      }
    }

    return jsonResponse({
      ok: true,
      imported,
      errors,
      total: rows.length,
      errorMessages,
    })
  } catch (e) {
    return jsonResponse({ error: String(e) }, 500)
  }
})
