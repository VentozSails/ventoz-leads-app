import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";
import { encode as hexEncode } from "https://deno.land/std@0.168.0/encoding/hex.ts";
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

async function testPayNl(config: {
  at_code: string;
  api_token: string;
  service_id: string;
}): Promise<{ ok: boolean; error?: string; details?: string }> {
  const auth = btoa(`${config.at_code}:${config.api_token}`);
  const url = `https://rest.pay.nl/v2/services/${config.service_id}/paymentmethods`;
  try {
    const res = await fetch(url, {
      headers: {
        Authorization: `Basic ${auth}`,
        Accept: "application/json",
      },
      signal: AbortSignal.timeout(15000),
    });
    if (res.ok) {
      const data = await res.json();
      const methods = (data.paymentMethods || []).filter(
        (m: { active: boolean }) => m.active
      );
      return {
        ok: true,
        details: `Verbinding OK. ${methods.length} actieve betaalmethode(n).`,
      };
    }
    const txt = await res.text();
    return {
      ok: false,
      error: `HTTP ${res.status}`,
      details: txt.substring(0, 300),
    };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
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
  const encodedUri = encodeURIComponent(
    `${parsed.host}${parsed.pathname}`
  ).toLowerCase();

  const rawString = `${websiteKey}${method}${encodedUri}${timestamp}${nonce}`;

  const key = new TextEncoder().encode(secretKey);
  const data = new TextEncoder().encode(rawString);
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", cryptoKey, data);
  const hmacHash = b64Encode(new Uint8Array(sig));

  return `hmac ${websiteKey}:${hmacHash}:${nonce}:${timestamp}`;
}

async function testBuckaroo(config: {
  website_key: string;
  secret_key: string;
  test_mode?: boolean;
}): Promise<{ ok: boolean; error?: string; details?: string }> {
  const base = config.test_mode
    ? "https://testcheckout.buckaroo.nl"
    : "https://checkout.buckaroo.nl";
  const url = `${base}/json/Transaction/Specification/ideal`;

  try {
    const auth = await buckarooHmac(
      config.website_key,
      config.secret_key,
      "GET",
      url
    );
    const res = await fetch(url, {
      headers: {
        Authorization: auth,
        Accept: "application/json",
      },
      signal: AbortSignal.timeout(15000),
    });
    if (res.ok) {
      const data = await res.json();
      return {
        ok: true,
        details: `Verbinding OK. Service: ${data.Name || "ideal"}`,
      };
    }
    const txt = await res.text();
    return {
      ok: false,
      error: `HTTP ${res.status}`,
      details: txt.substring(0, 300),
    };
  } catch (e) {
    return { ok: false, error: (e as Error).message };
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Not authorized" }, 401);

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const {
      data: { user },
    } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
    if (!user) return json({ error: "Not authorized" }, 401);

    const body = await req.json();
    const provider = body.provider as string;

    if (provider === "pay_nl") {
      const result = await testPayNl(body.config);
      return json(result);
    }
    if (provider === "buckaroo") {
      const result = await testBuckaroo(body.config);
      return json(result);
    }

    return json({ error: "Unknown provider" }, 400);
  } catch (e) {
    return json({ error: (e as Error).message }, 500);
  }
});
