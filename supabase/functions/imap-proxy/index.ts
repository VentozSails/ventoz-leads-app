import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const VENTOZ_IMAP_API = "https://ventoz.com/api/imap";

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

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Not authorized" }, 401);

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const token = authHeader.replace("Bearer ", "");

    let userId: string | null = null;
    try {
      const { data, error } = await supabase.auth.getUser(token);
      if (!error && data?.user) userId = data.user.id;
    } catch { /* ignore */ }

    if (!userId) {
      try {
        const parts = token.split(".");
        if (parts.length === 3) {
          const payload = JSON.parse(atob(parts[1]));
          if (payload.sub) userId = payload.sub;
        }
      } catch { /* ignore */ }
    }

    if (!userId) return json({ error: "Invalid session" }, 401);

    const { data: callerRow } = await supabase
      .from("ventoz_users")
      .select("is_owner, is_admin, user_type")
      .eq("auth_user_id", userId)
      .maybeSingle();

    const isAdmin =
      callerRow?.is_owner ||
      callerRow?.is_admin ||
      ["owner", "admin", "medewerker"].includes(callerRow?.user_type || "");
    if (!isAdmin) return json({ error: "Insufficient permissions" }, 403);

    const body = await req.json();

    const proxyRes = await fetch(VENTOZ_IMAP_API, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: authHeader,
      },
      body: JSON.stringify(body),
    });

    const data = await proxyRes.json();
    return new Response(JSON.stringify(data), {
      status: proxyRes.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("imap-proxy error:", msg);
    return json({ error: msg }, 500);
  }
});
