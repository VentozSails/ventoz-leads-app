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

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // GET: health check — SnelStart may ping this to verify the URL exists
  if (req.method === "GET") {
    return json({ status: "ok", service: "ventoz-snelstart-webhook", timestamp: new Date().toISOString() });
  }

  // POST: receive webhook events from SnelStart
  if (req.method === "POST") {
    try {
      const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

      let body: Record<string, unknown> = {};
      const contentType = req.headers.get("content-type") || "";

      if (contentType.includes("application/json")) {
        body = await req.json();
      } else {
        const text = await req.text();
        try { body = JSON.parse(text); } catch { body = { raw: text }; }
      }

      // Log the incoming webhook event for debugging and future processing
      const event = {
        source: "snelstart",
        event_type: (body.action as string) || (body.type as string) || (body.event as string) || "unknown",
        payload: body,
        headers: Object.fromEntries(
          [...req.headers.entries()].filter(
            ([k]) => !k.startsWith("x-forwarded") && k !== "host"
          )
        ),
        received_at: new Date().toISOString(),
        processed: false,
      };

      const { error: insertErr } = await supabase
        .from("webhook_events")
        .insert(event);

      if (insertErr) {
        // Table might not exist yet — log to console as fallback
        console.log("SnelStart webhook received (table not ready):", JSON.stringify(event));
      }

      // Always return 200 quickly so SnelStart doesn't retry
      return json({ received: true });
    } catch (err) {
      console.error("SnelStart webhook error:", err);
      return json({ received: true });
    }
  }

  return json({ error: "Method not allowed" }, 405);
});
