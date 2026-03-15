import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import nodemailer from "npm:nodemailer@6.9.10";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function base64ToUint8(b64: string): Uint8Array {
  const bin = atob(b64);
  const arr = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
  return arr;
}

function esc(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function fmtEuro(amount: number): string {
  return `&euro; ${amount.toFixed(2).replace(".", ",")}`;
}

interface SmtpConfig {
  host: string;
  port: number;
  username: string;
  password: string;
  from_name: string;
  from_email: string;
  encryption: string;
  allow_invalid_certificate: boolean;
}

interface OrderLine {
  product_naam: string;
  aantal: number;
  stukprijs: number;
  regel_totaal: number;
}

interface OrderData {
  order_nummer: string;
  user_email: string;
  naam: string;
  adres: string;
  postcode: string;
  woonplaats: string;
  land_code: string;
  subtotaal: number;
  btw_bedrag: number;
  btw_percentage: number;
  btw_verlegd: boolean;
  verzendkosten: number;
  totaal: number;
  valuta: string;
}

const TR: Record<string, Record<string, string>> = {
  subject: {
    nl: "Orderbevestiging Ventoz —",
    en: "Order Confirmation Ventoz —",
    de: "Bestellbestätigung Ventoz —",
    fr: "Confirmation de commande Ventoz —",
  },
  thanks: {
    nl: "Bedankt voor je bestelling!",
    en: "Thank you for your order!",
    de: "Vielen Dank für Ihre Bestellung!",
    fr: "Merci pour votre commande !",
  },
  orderNr: {
    nl: "Ordernummer",
    en: "Order number",
    de: "Bestellnummer",
    fr: "Numéro de commande",
  },
  product: {
    nl: "Product",
    en: "Product",
    de: "Produkt",
    fr: "Produit",
  },
  qty: {
    nl: "Aantal",
    en: "Qty",
    de: "Menge",
    fr: "Qté",
  },
  price: {
    nl: "Prijs",
    en: "Price",
    de: "Preis",
    fr: "Prix",
  },
  subtotal: {
    nl: "Subtotaal",
    en: "Subtotal",
    de: "Zwischensumme",
    fr: "Sous-total",
  },
  shipping: {
    nl: "Verzendkosten",
    en: "Shipping",
    de: "Versandkosten",
    fr: "Frais de port",
  },
  vat: {
    nl: "BTW",
    en: "VAT",
    de: "MwSt.",
    fr: "TVA",
  },
  vatReverse: {
    nl: "BTW verlegd",
    en: "VAT reverse charged",
    de: "Steuerschuldnerschaft",
    fr: "TVA autoliquidation",
  },
  total: {
    nl: "Totaal",
    en: "Total",
    de: "Gesamtbetrag",
    fr: "Total",
  },
  deliveryAddr: {
    nl: "Bezorgadres",
    en: "Delivery address",
    de: "Lieferadresse",
    fr: "Adresse de livraison",
  },
  info: {
    nl: "Je ontvangt een e-mail zodra je bestelling is verzonden.",
    en: "You will receive an email once your order has been shipped.",
    de: "Sie erhalten eine E-Mail, sobald Ihre Bestellung versandt wurde.",
    fr: "Vous recevrez un e-mail dès que votre commande sera expédiée.",
  },
  free: {
    nl: "Gratis",
    en: "Free",
    de: "Kostenlos",
    fr: "Gratuit",
  },
};

function langFromCountry(code: string): string {
  const map: Record<string, string> = {
    NL: "nl", BE: "nl", DE: "de", AT: "de", CH: "de",
    FR: "fr", GB: "en", US: "en", IE: "en",
  };
  return map[code?.toUpperCase()] || "en";
}

function t(key: string, lang: string): string {
  return TR[key]?.[lang] || TR[key]?.["en"] || key;
}

function buildHtml(
  order: OrderData,
  lines: OrderLine[],
  lang: string,
): string {
  const lineRows = lines
    .map(
      (l) =>
        `<tr>
      <td style="padding:8px 12px;border-bottom:1px solid #e2e8f0;font-size:13px;color:#334155;">${esc(l.product_naam)}</td>
      <td style="padding:8px 12px;border-bottom:1px solid #e2e8f0;font-size:13px;color:#334155;text-align:center;">${l.aantal}</td>
      <td style="padding:8px 12px;border-bottom:1px solid #e2e8f0;font-size:13px;color:#334155;text-align:right;">${fmtEuro(l.stukprijs)}</td>
      <td style="padding:8px 12px;border-bottom:1px solid #e2e8f0;font-size:13px;color:#334155;text-align:right;">${fmtEuro(l.regel_totaal)}</td>
    </tr>`,
    )
    .join("");

  const shippingLabel =
    order.verzendkosten === 0 ? t("free", lang) : fmtEuro(order.verzendkosten);
  const vatLabel = order.btw_verlegd
    ? t("vatReverse", lang)
    : `${t("vat", lang)} (${order.btw_percentage}%)`;
  const vatAmount = order.btw_verlegd
    ? `${fmtEuro(0)}`
    : fmtEuro(order.btw_bedrag);

  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"></head>
<body style="margin:0;padding:0;background-color:#f8fafc;">
<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f8fafc;">
<tr><td align="center" style="padding:24px 16px;">
<table width="600" cellpadding="0" cellspacing="0" style="background-color:#fff;border-radius:8px;border:1px solid #e2e8f0;">

<tr><td style="background-color:#37474F;padding:20px 28px;border-radius:8px 8px 0 0;">
<span style="color:#fff;font-size:18px;font-weight:700;font-family:Arial,Helvetica,sans-serif;">Ventoz Sails</span>
</td></tr>

<tr><td style="padding:28px;font-family:Arial,Helvetica,sans-serif;">
<h2 style="margin:0 0 8px;font-size:20px;color:#1E293B;">${t("thanks", lang)}</h2>
<p style="font-size:14px;line-height:1.7;color:#334155;margin:0 0 4px;">
<strong>${t("orderNr", lang)}:</strong> ${esc(order.order_nummer)}
</p>

<table width="100%" cellpadding="0" cellspacing="0" style="margin:20px 0;border:1px solid #e2e8f0;border-radius:6px;">
<tr style="background-color:#f1f5f9;">
<th style="padding:10px 12px;text-align:left;font-size:12px;color:#64748B;">${t("product", lang)}</th>
<th style="padding:10px 12px;text-align:center;font-size:12px;color:#64748B;">${t("qty", lang)}</th>
<th style="padding:10px 12px;text-align:right;font-size:12px;color:#64748B;">${t("price", lang)}</th>
<th style="padding:10px 12px;text-align:right;font-size:12px;color:#64748B;">${t("total", lang)}</th>
</tr>
${lineRows}
</table>

<table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:20px;">
<tr><td style="padding:4px 0;font-size:13px;color:#64748B;">${t("subtotal", lang)}</td>
<td style="padding:4px 0;font-size:13px;color:#334155;text-align:right;">${fmtEuro(order.subtotaal)}</td></tr>
<tr><td style="padding:4px 0;font-size:13px;color:#64748B;">${t("shipping", lang)}</td>
<td style="padding:4px 0;font-size:13px;color:#334155;text-align:right;">${shippingLabel}</td></tr>
<tr><td style="padding:4px 0;font-size:13px;color:#64748B;">${vatLabel}</td>
<td style="padding:4px 0;font-size:13px;color:#334155;text-align:right;">${vatAmount}</td></tr>
<tr><td colspan="2" style="border-top:1px solid #e2e8f0;"></td></tr>
<tr><td style="padding:8px 0;font-size:15px;font-weight:700;color:#1E293B;">${t("total", lang)}</td>
<td style="padding:8px 0;font-size:15px;font-weight:700;color:#1E293B;text-align:right;">${fmtEuro(order.totaal)}</td></tr>
</table>

<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f1f5f9;border-radius:6px;margin-bottom:16px;">
<tr><td style="padding:14px 16px;">
<p style="margin:0 0 4px;font-size:12px;font-weight:700;color:#64748B;">${t("deliveryAddr", lang)}</p>
<p style="margin:0;font-size:13px;line-height:1.6;color:#334155;">
${esc(order.naam)}<br/>
${esc(order.adres)}<br/>
${esc(order.postcode)} ${esc(order.woonplaats)}<br/>
${esc(order.land_code)}
</p>
</td></tr>
</table>

<p style="font-size:13px;line-height:1.6;color:#64748B;margin:0;">
${t("info", lang)}
</p>
</td></tr>

<tr><td style="padding:16px 28px;background-color:#f8fafc;border-radius:0 0 8px 8px;border-top:1px solid #e2e8f0;">
<span style="font-size:11px;color:#94a3b8;font-family:Arial,sans-serif;">Ventoz B.V. &middot; ventoz.com</span>
</td></tr>
</table>
</td></tr></table>
</body></html>`;
}

async function loadSmtpSettings(
  supabase: ReturnType<typeof createClient>,
): Promise<SmtpConfig | null> {
  const { data, error } = await supabase
    .from("app_settings")
    .select("value")
    .eq("key", "smtp_config")
    .single();

  if (error || !data) return null;
  let config = data.value as SmtpConfig;

  if (config.password?.startsWith("ENC:")) {
    try {
      const { data: keyRow } = await supabase
        .from("vault_keys")
        .select("encryption_key")
        .eq("id", 1)
        .maybeSingle();

      const rawKey = keyRow?.encryption_key;
      if (rawKey) {
        const parts = config.password.slice(4).split(":");
        if (parts.length === 2) {
          const ivBytes = base64ToUint8(parts[0]);
          const dataBytes = base64ToUint8(parts[1]);
          const keyBytes = base64ToUint8(rawKey);

          const cryptoKey = await crypto.subtle.importKey(
            "raw",
            keyBytes,
            { name: "AES-CBC" },
            false,
            ["decrypt"],
          );
          const decrypted = await crypto.subtle.decrypt(
            { name: "AES-CBC", iv: ivBytes },
            cryptoKey,
            dataBytes,
          );
          config.password = new TextDecoder().decode(decrypted);
        }
      }
    } catch (e) {
      console.error("Password decryption failed:", e);
    }
  }

  return config;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── Auth: require authenticated user ──
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Not authorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? SERVICE_ROLE_KEY;
    const token = authHeader.replace("Bearer ", "");
    const { data: { user: caller }, error: authErr } = await createClient(SUPABASE_URL, anonKey).auth.getUser(token);
    if (authErr || !caller) {
      return new Response(JSON.stringify({ error: "Invalid session" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const body = await req.json();
    const { order_id } = body as { order_id: string };

    if (!order_id) {
      return new Response(
        JSON.stringify({ error: "order_id is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { data: order, error: orderErr } = await supabase
      .from("orders")
      .select("*")
      .eq("id", order_id)
      .single();

    if (orderErr || !order) {
      return new Response(
        JSON.stringify({ error: "Order not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { data: lines } = await supabase
      .from("order_regels")
      .select("product_naam, aantal, stukprijs, regel_totaal")
      .eq("order_id", order_id);

    const smtp = await loadSmtpSettings(supabase);
    if (!smtp || !smtp.host || !smtp.username || !smtp.password || !smtp.from_email) {
      return new Response(
        JSON.stringify({ error: "SMTP not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const lang = langFromCountry(order.land_code || "NL");
    const html = buildHtml(order as OrderData, (lines || []) as OrderLine[], lang);

    const subject = `${t("subject", lang)} ${order.order_nummer}`;
    const plainText = `${t("thanks", lang)}\n\n${t("orderNr", lang)}: ${order.order_nummer}\n${t("total", lang)}: EUR ${order.totaal.toFixed(2).replace(".", ",")}\n\n${t("info", lang)}`;

    const transportConfig: Record<string, unknown> = {
      host: smtp.host,
      port: smtp.port || 587,
      auth: { user: smtp.username, pass: smtp.password },
    };

    if (smtp.encryption === "ssl") {
      transportConfig.secure = true;
    } else if (smtp.encryption === "starttls") {
      transportConfig.secure = false;
      transportConfig.requireTLS = true;
    } else {
      transportConfig.secure = false;
    }

    if (smtp.allow_invalid_certificate) {
      transportConfig.tls = { rejectUnauthorized: false };
    }

    const transport = nodemailer.createTransport(transportConfig);

    await new Promise<void>((resolve, reject) => {
      transport.sendMail(
        {
          from: `"${smtp.from_name || "Ventoz Sails"}" <${smtp.from_email}>`,
          to: order.user_email,
          bcc: smtp.from_email,
          subject,
          text: plainText,
          html,
        },
        (error: Error | null) => {
          if (error) return reject(error);
          resolve();
        },
      );
    });

    await supabase
      .from("orders")
      .update({ bevestiging_verstuurd: true })
      .eq("id", order_id);

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    return new Response(
      JSON.stringify({ error: msg }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
