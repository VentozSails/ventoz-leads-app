import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const VENTOZ_DEFAULTS = {
  sellerName: "Ventoz Sails",
  phoneNumber: "0653843707",
  emailAdvertiser: true,
  postcode: "8861KM",
  brand: "Ventoz",
  condition: "new",
  cpc: 2,             // eurocenten
  totalBudget: 5000,  // eurocenten (€50)
  dailyBudget: 1000,  // eurocenten (€10)
  autobid: false,
};

serve(async (req: Request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  const url = new URL(req.url);
  const format = url.searchParams.get("format") || "xml";

  try {
    // Fetch all active marktplaats listings with product data
    const { data: listings, error: listErr } = await supabase
      .from("marketplace_listings")
      .select("*, product_catalogus(id, artikelnummer, naam, beschrijving, prijs, afbeelding_url, webshop_url, categorie, in_stock)")
      .eq("platform", "marktplaats")
      .in("status", ["actief", "concept"]);

    if (listErr) throw listErr;

    // Also fetch feed settings
    const { data: settings } = await supabase
      .from("marketplace_credentials")
      .select("credential_type, encrypted_value")
      .eq("platform", "marktplaats");

    const cfg = Object.fromEntries(
      (settings || []).map((s: any) => [s.credential_type, s.encrypted_value])
    );

    const sellerName = cfg["seller_name"] || VENTOZ_DEFAULTS.sellerName;
    const phone = cfg["phone_number"] || VENTOZ_DEFAULTS.phoneNumber;
    const postcode = cfg["postcode"] || VENTOZ_DEFAULTS.postcode;
    const defaultCategoryId = cfg["default_category_id"] || "2166";
    const emailAdvertiser = cfg["email_advertiser"] !== "false";

    if (format === "tsv") {
      const tsv = generateTSV(listings || [], { sellerName, phone, postcode, defaultCategoryId, emailAdvertiser });
      return new Response(tsv, {
        headers: {
          "Content-Type": "text/tab-separated-values; charset=utf-8",
          "Content-Disposition": 'attachment; filename="marktplaats-feed.tsv"',
        },
      });
    }

    const xml = generateXML(listings || [], { sellerName, phone, postcode, defaultCategoryId, emailAdvertiser });
    return new Response(xml, {
      headers: {
        "Content-Type": "application/xml; charset=utf-8",
        "Content-Disposition": 'attachment; filename="marktplaats-feed.xml"',
      },
    });
  } catch (error) {
    console.error("Feed generation error:", error);
    return new Response(
      `<?xml version="1.0" encoding="UTF-8"?><error>${error instanceof Error ? error.message : String(error)}</error>`,
      { status: 500, headers: { "Content-Type": "application/xml" } }
    );
  }
});

interface FeedConfig {
  sellerName: string;
  phone: string;
  postcode: string;
  defaultCategoryId: string;
  emailAdvertiser: boolean;
}

function escapeXml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function priceToCents(price: number): number {
  return Math.round(price * 100);
}

function mapCategoryId(categorie: string | null, defaultId: string): string {
  const categoryMap: Record<string, string> = {
    "zeilen": "2166",
    "sails": "2166",
    "masten": "2166",
    "masts": "2166",
    "onderdelen": "2166",
    "parts": "2166",
    "accessoires": "2166",
    "accessories": "2166",
    "boten": "2083",
    "boats": "2083",
    "kleding": "2167",
    "clothing": "2167",
  };
  if (!categorie) return defaultId;
  const lower = categorie.toLowerCase();
  for (const [key, id] of Object.entries(categoryMap)) {
    if (lower.includes(key)) return id;
  }
  return defaultId;
}

function generateXML(listings: any[], cfg: FeedConfig): string {
  let xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
  xml += '<admarkt:ads xmlns:admarkt="http://admarkt.marktplaats.nl/schemas/1.0">\n';

  for (const listing of listings) {
    const product = listing.product_catalogus;
    if (!product) continue;
    if (!product.in_stock && listing.status !== "actief") continue;

    const title = (product.naam || "").substring(0, 60);
    const description = product.beschrijving || product.naam || "";
    const price = listing.prijs || product.prijs || 0;
    const categoryId = listing.platform_data?.marktplaats_category_id
      || mapCategoryId(product.categorie, cfg.defaultCategoryId);
    const vendorId = product.artikelnummer || `ventoz-${product.id}`;
    const status = product.in_stock ? "ACTIVE" : "PAUSED";

    xml += '  <admarkt:ad>\n';
    xml += `    <admarkt:vendorId>${escapeXml(vendorId)}</admarkt:vendorId>\n`;
    xml += `    <admarkt:title>${escapeXml(title)}</admarkt:title>\n`;
    xml += `    <admarkt:description><![CDATA[${description}]]></admarkt:description>\n`;
    xml += `    <admarkt:categoryId>${escapeXml(categoryId)}</admarkt:categoryId>\n`;

    if (product.webshop_url) {
      xml += `    <admarkt:url>${escapeXml(product.webshop_url)}</admarkt:url>\n`;
      const domain = extractDomain(product.webshop_url);
      if (domain) xml += `    <admarkt:vanityUrl>${escapeXml(domain)}</admarkt:vanityUrl>\n`;
    }

    xml += `    <admarkt:price>${priceToCents(price)}</admarkt:price>\n`;
    xml += `    <admarkt:priceType>FIXED_PRICE</admarkt:priceType>\n`;
    xml += `    <admarkt:phoneNumber>${escapeXml(cfg.phone)}</admarkt:phoneNumber>\n`;
    xml += `    <admarkt:emailAdvertiser>${cfg.emailAdvertiser}</admarkt:emailAdvertiser>\n`;
    xml += `    <admarkt:sellerName>${escapeXml(cfg.sellerName)}</admarkt:sellerName>\n`;
    xml += `    <admarkt:status>${status}</admarkt:status>\n`;

    if (product.afbeelding_url) {
      xml += `    <admarkt:media>\n`;
      xml += `      <admarkt:image url="${escapeXml(product.afbeelding_url)}"/>\n`;
      xml += `    </admarkt:media>\n`;
    }

    xml += `    <admarkt:shippingOptions>\n`;
    xml += `      <admarkt:shippingOption>\n`;
    xml += `        <admarkt:shippingType>SHIP</admarkt:shippingType>\n`;
    xml += `        <admarkt:cost>${getShippingCost(price)}</admarkt:cost>\n`;
    xml += `        <admarkt:time>2d-5d</admarkt:time>\n`;
    xml += `      </admarkt:shippingOption>\n`;
    xml += `      <admarkt:shippingOption>\n`;
    xml += `        <admarkt:shippingType>PICKUP</admarkt:shippingType>\n`;
    xml += `        <admarkt:location>${escapeXml(cfg.postcode)}</admarkt:location>\n`;
    xml += `      </admarkt:shippingOption>\n`;
    xml += `    </admarkt:shippingOptions>\n`;

    xml += `    <admarkt:brand>${escapeXml(VENTOZ_DEFAULTS.brand)}</admarkt:brand>\n`;
    xml += `    <admarkt:condition>${VENTOZ_DEFAULTS.condition}</admarkt:condition>\n`;

    if (product.artikelnummer) {
      xml += `    <admarkt:gtin>${escapeXml(product.artikelnummer)}</admarkt:gtin>\n`;
    }

    xml += `    <admarkt:productType>Watersport &amp; Boten &gt; Zeilboten &gt; Onderdelen</admarkt:productType>\n`;

    const pd = listing.platform_data || {};
    const autobid = pd.autobid ?? VENTOZ_DEFAULTS.autobid;
    const cpc = pd.cpc ?? VENTOZ_DEFAULTS.cpc;
    const totalBudget = pd.total_budget ?? VENTOZ_DEFAULTS.totalBudget;
    const dailyBudget = pd.daily_budget ?? VENTOZ_DEFAULTS.dailyBudget;

    xml += `    <admarkt:budget>\n`;
    xml += `      <admarkt:autobid>${autobid}</admarkt:autobid>\n`;
    if (autobid) {
      xml += `      <admarkt:bidLevel>${pd.bid_level || "MEDIUM"}</admarkt:bidLevel>\n`;
    } else {
      xml += `      <admarkt:cpc>${cpc}</admarkt:cpc>\n`;
    }
    xml += `      <admarkt:totalBudget>${totalBudget}</admarkt:totalBudget>\n`;
    xml += `      <admarkt:dailyBudget>${dailyBudget}</admarkt:dailyBudget>\n`;
    xml += `    </admarkt:budget>\n`;

    xml += '  </admarkt:ad>\n';
  }

  xml += '</admarkt:ads>\n';
  return xml;
}

function generateTSV(listings: any[], cfg: FeedConfig): string {
  const headers = [
    "vendor id", "title", "description", "category id", "status",
    "url", "vanity url", "price type", "price", "image link",
    "seller name", "phone number", "email advertiser",
    "shipping", "pickup location", "brand", "condition", "GTIN",
    "autobid", "cpc", "total budget", "daily budget",
  ];
  const rows: string[] = [headers.join("\t")];

  for (const listing of listings) {
    const product = listing.product_catalogus;
    if (!product) continue;

    const price = listing.prijs || product.prijs || 0;
    const categoryId = listing.platform_data?.marktplaats_category_id
      || mapCategoryId(product.categorie, cfg.defaultCategoryId);
    const vendorId = product.artikelnummer || `ventoz-${product.id}`;
    const status = product.in_stock ? "ACTIVE" : "PAUSED";
    const domain = product.webshop_url ? extractDomain(product.webshop_url) : "";
    const pd = listing.platform_data || {};

    const shippingStr = `SHIP:${getShippingCost(price)}:2d-5d`;

    const row = [
      vendorId,
      (product.naam || "").substring(0, 60),
      (product.beschrijving || product.naam || "").replace(/\t/g, " ").replace(/\n/g, " "),
      categoryId,
      status,
      product.webshop_url || "",
      domain,
      "FIXED_PRICE",
      priceToCents(price).toString(),
      product.afbeelding_url || "",
      cfg.sellerName,
      cfg.phone,
      cfg.emailAdvertiser ? "true" : "false",
      shippingStr,
      cfg.postcode,
      VENTOZ_DEFAULTS.brand,
      VENTOZ_DEFAULTS.condition,
      product.artikelnummer || "",
      (pd.autobid ?? VENTOZ_DEFAULTS.autobid).toString(),
      (pd.cpc ?? VENTOZ_DEFAULTS.cpc).toString(),
      (pd.total_budget ?? VENTOZ_DEFAULTS.totalBudget).toString(),
      (pd.daily_budget ?? VENTOZ_DEFAULTS.dailyBudget).toString(),
    ];
    rows.push(row.join("\t"));
  }
  return rows.join("\n");
}

function extractDomain(url: string): string {
  try {
    return new URL(url).origin;
  } catch {
    return "";
  }
}

function getShippingCost(priceEur: number): number {
  if (priceEur >= 150) return 0;
  if (priceEur >= 50) return 695;
  return 495;
}
