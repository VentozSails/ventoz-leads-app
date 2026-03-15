import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";
import { encode as b64Encode } from "https://deno.land/std@0.168.0/encoding/base64.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const PAYNL_NAME_NORMALIZE: Record<string, string> = {
  "overboeking (sct)": "banktransfer",
  "eps uberweisung": "eps",
  "bancontact online": "bancontact",
  "visa mastercard": "creditcard",
  "mobilepay": "mobilepay",
  "wero payment": "wero",
  "vipps payment": "vipps",
  "pay by bank": "paybybank",
  "mb way": "mbway",
};

const BUCKAROO_SERVICES = [
  "ideal", "creditcard", "paypal", "bancontactmrcash", "sofort",
  "transfer", "giropay", "eps", "applepay",
];
const BUCKAROO_ID_MAP: Record<string, string> = {
  bancontactmrcash: "bancontact",
  transfer: "banktransfer",
};

interface ProviderMethod {
  id: string;
  name: string;
  providerMethodId: number | string;
}

async function getPayNlMethods(config: {
  at_code: string;
  api_token: string;
  service_id: string;
}): Promise<{ ok: boolean; methods: ProviderMethod[]; error?: string }> {
  const auth = btoa(`${config.at_code}:${config.api_token}`);
  const url = `https://rest.pay.nl/v2/services/${config.service_id}/paymentmethods`;
  try {
    const res = await fetch(url, {
      headers: { Authorization: `Basic ${auth}`, Accept: "application/json" },
      signal: AbortSignal.timeout(15000),
    });
    if (!res.ok) {
      const txt = await res.text();
      return { ok: false, methods: [], error: `HTTP ${res.status}: ${txt.substring(0, 200)}` };
    }
    const data = await res.json();
    const list = data.paymentMethods || [];
    const methods: ProviderMethod[] = [];
    for (const pm of list) {
      if (!pm.active) continue;
      const rawName = (pm.name as string || "").toLowerCase();
      const normalized = PAYNL_NAME_NORMALIZE[rawName] || rawName.replace(/[^a-z0-9]/g, "");
      methods.push({
        id: normalized,
        name: pm.name as string,
        providerMethodId: pm.id as number,
      });
    }
    return { ok: true, methods };
  } catch (e) {
    return { ok: false, methods: [], error: (e as Error).message };
  }
}

async function buckarooHmac(
  websiteKey: string,
  secretKey: string,
  method: string,
  url: string
): Promise<string> {
  const nonce = crypto.randomUUID().replace(/-/g, "");
  const timestamp = Math.floor(Date.now() / 1000).toString();
  const parsed = new URL(url);
  const encodedUri = encodeURIComponent(`${parsed.host}${parsed.pathname}`).toLowerCase();
  const rawString = `${websiteKey}${method}${encodedUri}${timestamp}${nonce}`;
  const key = new TextEncoder().encode(secretKey);
  const dataBytes = new TextEncoder().encode(rawString);
  const cryptoKey = await crypto.subtle.importKey("raw", key, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", cryptoKey, dataBytes);
  return `hmac ${websiteKey}:${b64Encode(new Uint8Array(sig))}:${nonce}:${timestamp}`;
}

const BUCKAROO_DISPLAY: Record<string, string> = {
  ideal: "iDEAL", creditcard: "Credit Card", paypal: "PayPal",
  bancontact: "Bancontact", sofort: "Sofort", banktransfer: "Bank Transfer",
  giropay: "Giropay", eps: "EPS", applepay: "Apple Pay",
};

async function getBuckarooMethods(config: {
  website_key: string;
  secret_key: string;
  test_mode?: boolean;
}): Promise<{ ok: boolean; methods: ProviderMethod[]; error?: string }> {
  const base = config.test_mode ? "https://testcheckout.buckaroo.nl" : "https://checkout.buckaroo.nl";
  const methods: ProviderMethod[] = [];
  let anySuccess = false;

  const checks = BUCKAROO_SERVICES.map(async (svc) => {
    const url = `${base}/json/Transaction/Specification/${svc}`;
    try {
      const authHeader = await buckarooHmac(config.website_key, config.secret_key, "GET", url);
      const res = await fetch(url, {
        headers: { Authorization: authHeader, Accept: "application/json" },
        signal: AbortSignal.timeout(8000),
      });
      if (res.ok) {
        anySuccess = true;
        const normalized = BUCKAROO_ID_MAP[svc] || svc;
        methods.push({
          id: normalized,
          name: BUCKAROO_DISPLAY[normalized] || svc,
          providerMethodId: svc,
        });
      }
    } catch { /* not available */ }
  });

  await Promise.all(checks);
  return { ok: anySuccess || methods.length > 0, methods };
}

async function syncMethods(supabase: ReturnType<typeof createClient>) {
  const { data: settings } = await supabase
    .from("app_settings")
    .select("value")
    .eq("key", "payment_config");
  const config = settings?.[0]?.value;
  if (!config) return { error: "No payment config found" };

  const payNlConfig = config.pay_nl as { at_code?: string; api_token?: string; service_id?: string } | null;
  const buckarooConfig = config.buckaroo as { website_key?: string; secret_key?: string; test_mode?: boolean } | null;

  const [payNlResult, buckarooResult] = await Promise.all([
    payNlConfig?.at_code && payNlConfig?.api_token && payNlConfig?.service_id
      ? getPayNlMethods(payNlConfig as { at_code: string; api_token: string; service_id: string })
      : Promise.resolve({ ok: false, methods: [] as ProviderMethod[], error: "Not configured" }),
    buckarooConfig?.website_key && buckarooConfig?.secret_key
      ? getBuckarooMethods(buckarooConfig as { website_key: string; secret_key: string; test_mode?: boolean })
      : Promise.resolve({ ok: false, methods: [] as ProviderMethod[], error: "Not configured" }),
  ]);

  const payNlIds = new Set(payNlResult.methods.map((m) => m.id));
  const buckarooIds = new Set(buckarooResult.methods.map((m) => m.id));

  const allMethodIds = new Set([...payNlIds, ...buckarooIds]);

  const { data: existingPrefs } = await supabase
    .from("payment_method_preferences")
    .select("*")
    .order("sort_order");
  const existing = (existingPrefs || []) as Array<{
    id: number; method_id: string; display_name: string;
    preferred_gateway: string; countries: string[];
    enabled: boolean; sort_order: number;
  }>;
  const existingIds = new Set(existing.map((p) => p.method_id));

  const newMethods: Array<{
    method_id: string; display_name: string; preferred_gateway: string;
    countries: string[]; enabled: boolean; sort_order: number;
  }> = [];
  let nextSort = existing.length > 0 ? Math.max(...existing.map((p) => p.sort_order)) + 1 : 1;

  for (const mid of allMethodIds) {
    if (existingIds.has(mid)) continue;
    const inPayNl = payNlIds.has(mid);
    const inBuckaroo = buckarooIds.has(mid);
    const pm = payNlResult.methods.find((m) => m.id === mid)
      || buckarooResult.methods.find((m) => m.id === mid);
    newMethods.push({
      method_id: mid,
      display_name: pm?.name || mid,
      preferred_gateway: inPayNl ? "pay_nl" : "buckaroo",
      countries: [],
      enabled: true,
      sort_order: nextSort++,
    });
  }

  if (newMethods.length > 0) {
    await supabase.from("payment_method_preferences").insert(newMethods);
  }

  const availability: Record<string, { pay_nl: boolean; buckaroo: boolean }> = {};
  for (const mid of allMethodIds) {
    availability[mid] = { pay_nl: payNlIds.has(mid), buckaroo: buckarooIds.has(mid) };
  }
  for (const pref of existing) {
    if (!availability[pref.method_id]) {
      availability[pref.method_id] = { pay_nl: false, buckaroo: false };
    }
  }

  return {
    pay_nl: { ok: payNlResult.ok, count: payNlResult.methods.length, error: payNlResult.error },
    buckaroo: { ok: buckarooResult.ok, count: buckarooResult.methods.length, error: buckarooResult.error },
    availability,
    added: newMethods.length,
    total: existingIds.size + newMethods.length,
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Not authorized" }, 401);

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data: { user } } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
    if (!user) return json({ error: "Not authorized" }, 401);

    const body = await req.json();
    const action = body.action || body.provider;

    if (action === "pay_nl") {
      const payNlConfig = body.config as { at_code: string; api_token: string; service_id: string };
      const result = await getPayNlMethods(payNlConfig);
      return json({
        ok: result.ok,
        details: result.ok ? `Verbinding OK. ${result.methods.length} actieve betaalmethode(n).` : undefined,
        error: result.error,
      });
    }

    if (action === "buckaroo") {
      const buckarooConfig = body.config as { website_key: string; secret_key: string; test_mode?: boolean };
      const result = await getBuckarooMethods(buckarooConfig);
      return json({
        ok: result.ok,
        details: result.ok ? `Verbinding OK. ${result.methods.length} betaalmethode(n) beschikbaar.` : undefined,
        error: result.error,
      });
    }

    if (action === "sync") {
      const result = await syncMethods(supabase);
      return json(result);
    }

    return json({ error: "Unknown action" }, 400);
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
