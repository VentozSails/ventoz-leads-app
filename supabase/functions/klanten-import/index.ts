import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

const LAND_MAP: Record<string, string> = {
  'nederland': 'NL', 'duitsland': 'DE', 'belgi\u00eb': 'BE', 'belgie': 'BE',
  'frankrijk': 'FR', 'verenigd koninkrijk': 'GB', 'groot-brittanni\u00eb': 'GB',
  'itali\u00eb': 'IT', 'italie': 'IT', 'spanje': 'ES', 'oostenrijk': 'AT',
  'zwitserland': 'CH', 'zweden': 'SE', 'denemarken': 'DK', 'noorwegen': 'NO',
  'finland': 'FI', 'portugal': 'PT', 'ierland': 'IE', 'polen': 'PL',
  'tsjechi\u00eb': 'CZ', 'tsjechie': 'CZ', 'hongarije': 'HU', 'griekenland': 'GR',
  'kroati\u00eb': 'HR', 'kroatie': 'HR', 'roemeni\u00eb': 'RO', 'roumenie': 'RO',
  'sloveni\u00eb': 'SI', 'slovenie': 'SI', 'slowakije': 'SK', 'bulgarije': 'BG',
  'luxemburg': 'LU', 'estland': 'EE', 'letland': 'LV', 'litouwen': 'LT',
  'malta': 'MT', 'cyprus': 'CY', 'ijsland': 'IS', 'turkey': 'TR', 'turkije': 'TR',
  'thailand': 'TH', 'australi\u00eb': 'AU', 'australie': 'AU',
  'nieuw-zeeland': 'NZ', 'canada': 'CA', 'isra\u00ebl': 'IL', 'israel': 'IL',
  'japan': 'JP', 'india': 'IN', 'china': 'CN', 'brazili\u00eb': 'BR',
  'cura\u00e7ao': 'CW', 'curacao': 'CW', 'suriname': 'SR', 'aruba': 'AW',
  'mexico': 'MX', 'colombia': 'CO', 'chili': 'CL', 'argentini\u00eb': 'AR',
  'servie': 'RS', 'servi\u00eb': 'RS', 'oekra\u00efne': 'UA', 'oekraine': 'UA',
  'montenegro': 'ME', 'albani\u00eb': 'AL', 'albanie': 'AL',
  'noord-macedoni\u00eb': 'MK', 'bosni\u00eb en herzegovina': 'BA',
}

const ZAKELIJK_PATTERNS = [
  /\bb\.?v\.?\b/i, /\bv\.?o\.?f\.?\b/i, /\bnv\b/i, /\bn\.v\.?\b/i,
  /\bvzw\b/i, /\bgmbh\b/i, /\bltd\.?\b/i, /\bllc\b/i, /\binc\.?\b/i,
  /\be\.v\.?\b/i, /\bs\.?a\.?r\.?l\.?\b/i, /\baps\b/i, /\bstichting\b/i,
  /\bvereniging\b/i, /\bfoundation\b/i, /\bclub\b/i, /\byachtclub\b/i,
  /\bzeilvereniging\b/i, /\bwatersport\b/i, /\bzeilschool\b/i,
  /\bsegel\b/i, /\bsailing\b/i, /\bmaritiem\b/i, /\bmarine\b/i,
  /\bevents?\b/i, /\bevenement\b/i, /\bzeilmakerij\b/i,
  /\bsurfclub\b/i, /\bsegelverein\b/i, /\bsegelclub\b/i,
]

interface KlantRow {
  klantcode: string
  naam: string
  contactpersoon?: string
  adres?: string
  postcode?: string
  plaats?: string
  land?: string
  telefoon?: string
  mobiel?: string
  email?: string
  btw_nummer?: string
  kvk_nummer?: string
}

interface OmzetRow {
  relatiecode: string
  omzet: string
}

interface FactuurRow {
  factuurnummer: string
  factuurdatum: string
  factuurbedrag: string
  vervaldatum: string
  naam: string
}

function parseDutchDecimal(s: string): number {
  if (!s) return 0
  return parseFloat(s.replace(/\./g, '').replace(',', '.')) || 0
}

function parseDutchDate(s: string): string | null {
  if (!s) return null
  const parts = s.split('-')
  if (parts.length !== 3) return null
  const [d, m, y] = parts
  return `${y}-${m.padStart(2, '0')}-${d.padStart(2, '0')}`
}

function isZakelijk(row: KlantRow, prospectCodes: Set<string>): boolean {
  if (row.kvk_nummer && row.kvk_nummer.trim()) return true
  if (row.btw_nummer && row.btw_nummer.trim()) return true
  if (row.contactpersoon && row.contactpersoon.trim()) return true
  if (prospectCodes.has(row.klantcode)) return true
  if (row.email && row.email.toLowerCase().startsWith('info@')) return true
  const naam = row.naam || ''
  for (const pat of ZAKELIJK_PATTERNS) {
    if (pat.test(naam)) return true
  }
  return false
}

function landCode(land: string): string {
  if (!land) return 'NL'
  const key = land.toLowerCase().trim()
  return LAND_MAP[key] || 'NL'
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    // ── Auth: require admin/owner JWT ──
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Not authorized' }, 401)

    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? serviceKey
    const token = authHeader.replace('Bearer ', '')
    const { data: { user: caller }, error: authErr } = await createClient(supabaseUrl, anonKey).auth.getUser(token)
    if (authErr || !caller) return json({ error: 'Invalid session' }, 401)

    const admin = createClient(supabaseUrl, serviceKey)

    const { data: callerRow } = await admin.from('ventoz_users').select('is_owner, is_admin, user_type').eq('auth_user_id', caller.id).maybeSingle()
    const isAdmin = callerRow?.is_owner || callerRow?.is_admin || ['owner', 'admin'].includes(callerRow?.user_type || '')
    if (!isAdmin) return json({ error: 'Admin access required' }, 403)

    const body = await req.json()
    const { action } = body

    if (action === 'clear_snelstart') {
      const { error } = await admin.from('klanten')
        .delete()
        .not('snelstart_klantcode', 'is', null)
      if (error) return json({ error: error.message }, 500)
      return json({ ok: true, message: 'Cleared all Snelstart-imported customers' })
    }

    if (action === 'verify') {
      const { data: klanten } = await admin.from('klanten').select('id, snelstart_klantcode, is_zakelijk, land_code, totale_omzet, aantal_facturen, naam').range(0, 9999)
      const total = klanten?.length || 0
      const zakelijk = klanten?.filter((k: any) => k.is_zakelijk).length || 0
      const particulier = total - zakelijk
      const landen: Record<string, number> = {}
      let totalOmzet = 0
      let totalFacturen = 0
      for (const k of (klanten || [])) {
        const lc = k.land_code || 'NL'
        landen[lc] = (landen[lc] || 0) + 1
        totalOmzet += parseFloat(k.totale_omzet) || 0
        totalFacturen += k.aantal_facturen || 0
      }
      const topKlanten = (klanten || [])
        .sort((a: any, b: any) => (parseFloat(b.totale_omzet) || 0) - (parseFloat(a.totale_omzet) || 0))
        .slice(0, 15)
        .map((k: any) => ({ naam: k.naam, omzet: k.totale_omzet, facturen: k.aantal_facturen, land: k.land_code }))

      return json({
        total, zakelijk, particulier, landen, totalOmzet: totalOmzet.toFixed(2),
        totalFacturen, topKlanten,
      })
    }

    const { klanten: klantRows, omzet: omzetRows, facturen: factuurRows } = body as {
      klanten: KlantRow[]
      omzet: OmzetRow[]
      facturen: FactuurRow[]
    }

    if (!klantRows?.length) return json({ error: 'klanten array required' }, 400)

    // Build omzet lookup: relatiecode -> omzet
    const omzetMap = new Map<string, number>()
    for (const o of (omzetRows || [])) {
      omzetMap.set(o.relatiecode, parseDutchDecimal(o.omzet))
    }

    // Build factuur stats: naam -> { count, eerste, laatste }
    const factuurMap = new Map<string, { count: number; eerste: string | null; laatste: string | null; totaal: number }>()
    for (const f of (factuurRows || [])) {
      const naam = f.naam?.toLowerCase().trim()
      if (!naam) continue
      const datum = parseDutchDate(f.factuurdatum)
      const bedrag = parseDutchDecimal(f.factuurbedrag)
      const existing = factuurMap.get(naam)
      if (existing) {
        existing.count++
        existing.totaal += bedrag
        if (datum) {
          if (!existing.eerste || datum < existing.eerste) existing.eerste = datum
          if (!existing.laatste || datum > existing.laatste) existing.laatste = datum
        }
      } else {
        factuurMap.set(naam, { count: 1, eerste: datum, laatste: datum, totaal: bedrag })
      }
    }

    // Fetch prospect klantcodes from leads tables
    const prospectCodes = new Set<string>()
    const prospectMatches = new Map<string, { id: number; land: string }>()

    for (const table of ['leads_nl', 'leads_de', 'leads_be']) {
      const land = table === 'leads_nl' ? 'NL' : table === 'leads_de' ? 'DE' : 'BE'
      const { data: leads } = await admin.from(table).select('id, ventoz_klantnr, naam, email')
      if (leads) {
        for (const lead of leads) {
          const klantnr = lead.ventoz_klantnr?.trim()
          if (klantnr) {
            prospectCodes.add(klantnr)
            prospectMatches.set(klantnr, { id: lead.id, land })
          }
        }
      }
    }

    // Deduplicate: group only by non-empty email match
    const byEmail = new Map<string, KlantRow[]>()
    for (const k of klantRows) {
      const email = k.email?.toLowerCase().trim()
      if (email && email.length > 0) {
        const list = byEmail.get(email) || []
        list.push(k)
        byEmail.set(email, list)
      }
    }

    const processed = new Set<string>()
    const mergedKlanten: Array<{
      primary_code: string
      aliases: string[]
      row: KlantRow
      omzet: number
      factuur_count: number
      eerste_factuur: string | null
      laatste_factuur: string | null
      is_zakelijk: boolean
      prospect_id: number | null
      prospect_land: string | null
    }> = []

    for (const k of klantRows) {
      if (processed.has(k.klantcode)) continue

      const dupes = new Set<string>([k.klantcode])
      const email = k.email?.toLowerCase().trim()

      if (email && email.length > 0) {
        const emailGroup = byEmail.get(email) || []
        for (const d of emailGroup) dupes.add(d.klantcode)
      }

      const allCodes = Array.from(dupes).sort((a, b) => parseInt(a) - parseInt(b))
      const primaryCode = allCodes[0]
      const aliases = allCodes.slice(1)

      // Use the row with the most complete data as primary
      let bestRow = k
      for (const code of allCodes) {
        const candidate = klantRows.find(r => r.klantcode === code)
        if (!candidate) continue
        const score = [candidate.email, candidate.adres, candidate.telefoon, candidate.mobiel, candidate.contactpersoon, candidate.btw_nummer, candidate.kvk_nummer]
          .filter(Boolean).length
        const bestScore = [bestRow.email, bestRow.adres, bestRow.telefoon, bestRow.mobiel, bestRow.contactpersoon, bestRow.btw_nummer, bestRow.kvk_nummer]
          .filter(Boolean).length
        if (score > bestScore) bestRow = candidate
      }

      // Sum omzet across all codes
      let totalOmzet = 0
      for (const code of allCodes) {
        totalOmzet += omzetMap.get(code) || 0
      }

      // Aggregate factuur stats (use naam from best row)
      const fStats = factuurMap.get((bestRow.naam || '').toLowerCase().trim())
      const factuurCount = fStats?.count || 0
      const eersteFactuur = fStats?.eerste || null
      const laatsteFactuur = fStats?.laatste || null

      // Check prospect match
      let prospectId: number | null = null
      let prospectLand: string | null = null
      for (const code of allCodes) {
        const match = prospectMatches.get(code)
        if (match) {
          prospectId = match.id
          prospectLand = match.land
          break
        }
      }

      const zakelijk = isZakelijk(bestRow, prospectCodes)

      mergedKlanten.push({
        primary_code: primaryCode,
        aliases,
        row: bestRow,
        omzet: totalOmzet,
        factuur_count: factuurCount,
        eerste_factuur: eersteFactuur,
        laatste_factuur: laatsteFactuur,
        is_zakelijk: zakelijk,
        prospect_id: prospectId,
        prospect_land: prospectLand,
      })

      for (const code of allCodes) processed.add(code)
    }

    // Build all records first, then batch insert
    const now = new Date().toISOString()
    const records: Record<string, unknown>[] = []

    for (const mk of mergedKlanten) {
      const row = mk.row
      const emailVal = row.email?.toLowerCase().trim() || `noemail_${mk.primary_code}@placeholder.local`
      const naamParts = (row.naam || '').split(/[\s,]+/)

      records.push({
        klantnummer: `SNL-${mk.primary_code.padStart(4, '0')}`,
        snelstart_klantcode: mk.primary_code,
        klantcode_aliases: mk.aliases.length > 0 ? mk.aliases : [],
        naam: row.naam || '',
        email: emailVal,
        voornaam: naamParts.length > 1 ? naamParts.slice(0, -1).join(' ') : null,
        achternaam: naamParts.length > 0 ? naamParts[naamParts.length - 1] : null,
        bedrijfsnaam: mk.is_zakelijk ? (row.naam || null) : null,
        adres: row.adres || null,
        postcode: row.postcode || null,
        woonplaats: row.plaats || null,
        land_code: landCode(row.land || ''),
        telefoon: row.telefoon || null,
        mobiel: row.mobiel || null,
        btw_nummer: row.btw_nummer || null,
        kvk_nummer: row.kvk_nummer || null,
        contactpersoon: row.contactpersoon || null,
        is_zakelijk: mk.is_zakelijk,
        totale_omzet: mk.omzet,
        eerste_factuur_datum: mk.eerste_factuur,
        laatste_factuur_datum: mk.laatste_factuur,
        aantal_facturen: mk.factuur_count,
        bron_prospect_id: mk.prospect_id,
        bron_prospect_land: mk.prospect_land,
        updated_at: now,
      })
    }

    // Batch insert in chunks of 200
    let imported = 0
    let errors = 0
    const errorMessages: string[] = []
    const BATCH = 200

    for (let i = 0; i < records.length; i += BATCH) {
      const chunk = records.slice(i, i + BATCH)
      try {
        const { error } = await admin.from('klanten').insert(chunk)
        if (error) {
          errors += chunk.length
          if (errorMessages.length < 20) errorMessages.push(`batch ${i}: ${error.message}`)
        } else {
          imported += chunk.length
        }
      } catch (e: any) {
        errors += chunk.length
        if (errorMessages.length < 20) errorMessages.push(`batch ${i}: ${e.message}`)
      }
    }

    return json({
      ok: true,
      total_input: klantRows.length,
      merged_to: mergedKlanten.length,
      duplicates_found: klantRows.length - mergedKlanten.length,
      imported,
      errors,
      prospect_matches: mergedKlanten.filter(m => m.prospect_id !== null).length,
      zakelijk: mergedKlanten.filter(m => m.is_zakelijk).length,
      particulier: mergedKlanten.filter(m => !m.is_zakelijk).length,
      errorMessages,
    })

  } catch (e: any) {
    return json({ error: e.message }, 500)
  }
})
