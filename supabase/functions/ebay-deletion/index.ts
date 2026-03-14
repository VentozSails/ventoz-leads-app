import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const VERIFICATION_TOKEN = Deno.env.get("EBAY_DELETION_VERIFICATION_TOKEN") || "";

serve(async (req: Request) => {
  // eBay sends a GET challenge for endpoint verification
  if (req.method === "GET") {
    const url = new URL(req.url);
    const challengeCode = url.searchParams.get("challenge_code");

    if (challengeCode) {
      // eBay requires: SHA-256( challengeCode + verificationToken + endpoint )
      // The endpoint must match EXACTLY what was registered on eBay
      const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
      const endpoint = `${supabaseUrl}/functions/v1/ebay-deletion`;

      const toHash = challengeCode + VERIFICATION_TOKEN + endpoint;
      console.log("Challenge verification:", { challengeCode, endpoint, tokenLength: VERIFICATION_TOKEN.length });

      const encoder = new TextEncoder();
      const data = encoder.encode(toHash);
      const hashBuffer = await crypto.subtle.digest("SHA-256", data);
      const hashArray = Array.from(new Uint8Array(hashBuffer));
      const hashHex = hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");

      return new Response(
        JSON.stringify({ challengeResponse: hashHex }),
        {
          status: 200,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    return new Response("OK", { status: 200 });
  }

  // eBay sends POST notifications for actual deletion requests
  if (req.method === "POST") {
    try {
      const body = await req.json();
      const topic = body?.metadata?.topic;

      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
      const supabase = createClient(supabaseUrl, serviceRoleKey);

      // Log the deletion request
      await supabase.from("marketplace_sync_log").insert({
        platform: "ebay",
        actie: "account_deletion_notification",
        status: "succes",
        details: {
          topic,
          notification: body,
          received_at: new Date().toISOString(),
        },
      });

      // Handle MARKETPLACE_ACCOUNT_DELETION topic
      if (topic === "MARKETPLACE_ACCOUNT_DELETION") {
        const userId = body?.notification?.data?.userId;
        const username = body?.notification?.data?.username;

        if (userId || username) {
          await supabase.from("marketplace_sync_log").insert({
            platform: "ebay",
            actie: "account_deletion_processed",
            status: "succes",
            details: {
              ebay_user_id: userId,
              ebay_username: username,
              action: "Data deletion request logged. Manual review required.",
            },
          });
        }
      }

      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    } catch (error) {
      console.error("Deletion notification error:", error);
      return new Response(JSON.stringify({ error: "Internal error" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  return new Response("Method not allowed", { status: 405 });
});
