import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function normalise(name: string | null | undefined): string {
  if (!name) return "";
  return name
    .toLowerCase()
    .replace(/[''`]/g, "")
    .replace(/ä/g, "ae").replace(/ö/g, "oe").replace(/ü/g, "ue")
    .replace(/ß/g, "ss")
    .replace(/[^\p{L}\p{N}\s]/gu, "")
    .replace(/\s+/g, " ")
    .trim();
}

interface InvoiceRow {
  factuurnummer: string;
  factuurdatum: string;
  factuurbedrag: number;
  vervaldatum: string;
  naam: string;
}

function parseCsv(raw: string): InvoiceRow[] {
  const lines = raw.replace(/^\uFEFF/, "").split(/\r?\n/).filter((l) => l.trim());
  const rows: InvoiceRow[] = [];
  for (let i = 1; i < lines.length; i++) {
    const parts = lines[i].split(";");
    if (parts.length < 5) continue;
    const bedrag = parseFloat(parts[2].replace(/\./g, "").replace(",", "."));
    rows.push({
      factuurnummer: parts[0].trim(),
      factuurdatum: parts[1].trim(),
      factuurbedrag: isNaN(bedrag) ? 0 : bedrag,
      vervaldatum: parts[3].trim(),
      naam: parts[4].trim(),
    });
  }
  return rows;
}

function parseDutchDate(d: string): string | null {
  const parts = d.split("-");
  if (parts.length !== 3) return null;
  const [day, month, year] = parts;
  return `${year}-${month.padStart(2, "0")}-${day.padStart(2, "0")}`;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    // Auth: accept service_role, authenticated users, or anon key (since --no-verify-jwt)
    const authHeader = req.headers.get("Authorization");
    const token = authHeader?.replace("Bearer ", "") || "";
    let authorized = !token || token === SERVICE_ROLE_KEY;
    if (!authorized) {
      try {
        const payload = JSON.parse(atob(token.split(".")[1]));
        if (payload.role === "service_role" || payload.role === "anon") authorized = true;
      } catch { /* */ }
    }
    if (!authorized) {
      const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? SERVICE_ROLE_KEY;
      if (token === anonKey) {
        authorized = true;
      } else {
        const { data: { user } } = await createClient(SUPABASE_URL, anonKey).auth.getUser(token);
        authorized = !!user;
      }
    }
    if (!authorized) return json({ error: "Not authorized" }, 401);

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const body = await req.json();
    const action = body.action || "preview";

    if (action === "status") {
      const { count: klantCount } = await supabase.from("klanten").select("*", { count: "exact", head: true });
      const { data: ordersWithInvoice } = await supabase
        .from("orders")
        .select("id")
        .not("factuur_nummer", "is", null)
        .limit(1);
      const { count: orderCount } = await supabase.from("orders").select("*", { count: "exact", head: true });
      return json({
        klanten: klantCount,
        orders: orderCount,
        ordersWithInvoice: ordersWithInvoice?.length || 0,
      });
    }

    const csvData = body.csv as string;
    if (!csvData) return json({ error: "csv field required" }, 400);

    const invoices = parseCsv(csvData);
    if (invoices.length === 0) return json({ error: "No valid invoice rows found" }, 400);

    // Load all klanten
    const allKlanten: Array<{ id: string; naam: string }> = [];
    let page = 0;
    const pageSize = 1000;
    while (true) {
      const { data } = await supabase
        .from("klanten")
        .select("id, naam")
        .range(page * pageSize, (page + 1) * pageSize - 1);
      if (!data || data.length === 0) break;
      allKlanten.push(...data);
      if (data.length < pageSize) break;
      page++;
    }

    // Build normalised name -> klant_id map
    const nameToKlant = new Map<string, string>();
    for (const k of allKlanten) {
      const norm = normalise(k.naam);
      if (norm) nameToKlant.set(norm, k.id);
    }

    // Match invoices to klanten
    let matched = 0;
    let unmatched = 0;
    const unmatchedNames = new Set<string>();

    const matchedInvoices: Array<{
      factuurnummer: string;
      klant_id: string;
      datum: string | null;
      bedrag: number;
      naam: string;
    }> = [];

    for (const inv of invoices) {
      const normName = normalise(inv.naam);
      const klantId = nameToKlant.get(normName);
      if (klantId) {
        matched++;
        matchedInvoices.push({
          factuurnummer: inv.factuurnummer,
          klant_id: klantId,
          datum: parseDutchDate(inv.factuurdatum),
          bedrag: inv.factuurbedrag,
          naam: inv.naam,
        });
      } else {
        unmatched++;
        unmatchedNames.add(inv.naam);
      }
    }

    if (action === "preview") {
      return json({
        totalInvoices: invoices.length,
        totalKlanten: allKlanten.length,
        matched,
        unmatched,
        unmatchedNames: [...unmatchedNames].slice(0, 50),
        sampleMatches: matchedInvoices.slice(0, 10).map((m) => ({
          factuurnummer: m.factuurnummer,
          naam: m.naam,
          klant_id: m.klant_id,
        })),
      });
    }

    if (action === "import") {
      // Group invoices by klant_id
      const byKlant = new Map<string, string[]>();
      for (const m of matchedInvoices) {
        const existing = byKlant.get(m.klant_id) || [];
        existing.push(m.factuurnummer);
        byKlant.set(m.klant_id, existing);
      }

      // For each matched invoice, create an order record with factuur_nummer + klant_id
      // First check which factuur_nummers already exist
      const allNrs = matchedInvoices.map((m) => m.factuurnummer);
      const existingNrs = new Set<string>();

      for (let i = 0; i < allNrs.length; i += 500) {
        const batch = allNrs.slice(i, i + 500);
        const { data: existing } = await supabase
          .from("orders")
          .select("factuur_nummer")
          .in("factuur_nummer", batch);
        if (existing) {
          for (const e of existing) {
            if (e.factuur_nummer) existingNrs.add(e.factuur_nummer);
          }
        }
      }

      const toInsert = matchedInvoices.filter(
        (m) => !existingNrs.has(m.factuurnummer)
      );

      let inserted = 0;
      let errors = 0;

      // Insert in batches of 100
      for (let i = 0; i < toInsert.length; i += 100) {
        const batch = toInsert.slice(i, i + 100);
        const rows = batch.map((m) => ({
          order_nummer: `INV-${m.factuurnummer}`,
          factuur_nummer: m.factuurnummer,
          klant_id: m.klant_id,
          naam: m.naam,
          status: "betaald",
          totaal: m.bedrag,
          subtotaal: m.bedrag,
          btw_bedrag: 0,
          btw_percentage: 0,
          verzendkosten: 0,
          valuta: "EUR",
          user_email: "",
          created_at: m.datum ? `${m.datum}T00:00:00Z` : undefined,
          betaald_op: m.datum ? `${m.datum}T00:00:00Z` : undefined,
        }));

        const { error } = await supabase.from("orders").insert(rows);
        if (error) {
          console.error("Insert batch error:", error.message);
          errors++;
        } else {
          inserted += batch.length;
        }
      }

      // Update klant stats (aantal_facturen, totale_omzet, eerste/laatste factuur)
      let statsUpdated = 0;
      for (const [klantId, nrs] of byKlant.entries()) {
        const invoicesForKlant = matchedInvoices.filter(
          (m) => m.klant_id === klantId
        );
        const positiveInvoices = invoicesForKlant.filter((m) => m.bedrag > 0);
        const omzet = positiveInvoices.reduce((sum, m) => sum + m.bedrag, 0);
        const datums = invoicesForKlant
          .map((m) => m.datum)
          .filter((d): d is string => !!d)
          .sort();

        const update: Record<string, unknown> = {
          aantal_facturen: nrs.length,
          totale_omzet: omzet,
        };
        if (datums.length > 0) {
          update.eerste_factuur_datum = datums[0];
          update.laatste_factuur_datum = datums[datums.length - 1];
        }

        const { error } = await supabase
          .from("klanten")
          .update(update)
          .eq("id", klantId);
        if (!error) statsUpdated++;
      }

      return json({
        matched,
        unmatched,
        inserted,
        skippedExisting: existingNrs.size,
        errors,
        statsUpdated,
        unmatchedNames: [...unmatchedNames].slice(0, 50),
      });
    }

    return json({ error: "Unknown action" }, 400);
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error("import-invoices error:", msg);
    return json({ error: msg }, 500);
  }
});
