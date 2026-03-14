import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Not authorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? SERVICE_ROLE_KEY;
    const token = authHeader.replace("Bearer ", "");
    const { data: { user: caller }, error: authError } = await createClient(
      SUPABASE_URL,
      anonKey,
    ).auth.getUser(token);

    if (authError || !caller) {
      return new Response(
        JSON.stringify({ error: "Invalid session" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const { data: callerRow } = await adminClient
      .from("ventoz_users")
      .select("is_owner, is_admin, user_type")
      .eq("auth_user_id", caller.id)
      .maybeSingle();

    const isCallerAdmin = callerRow?.is_owner || callerRow?.is_admin ||
      ["owner", "admin"].includes(callerRow?.user_type || "");

    if (!isCallerAdmin) {
      return new Response(
        JSON.stringify({ error: "Only admins can delete users" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const body = await req.json();
    const { email } = body as { email: string };

    if (!email) {
      return new Response(
        JSON.stringify({ error: "email is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const normalized = email.toLowerCase();

    if (normalized === caller.email?.toLowerCase()) {
      return new Response(
        JSON.stringify({ error: "Cannot delete your own account" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { data: targetRow } = await adminClient
      .from("ventoz_users")
      .select("auth_user_id, is_owner")
      .eq("email", normalized)
      .maybeSingle();

    if (targetRow?.is_owner) {
      return new Response(
        JSON.stringify({ error: "Cannot delete the owner account" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (targetRow?.auth_user_id) {
      const { error: deleteError } = await adminClient.auth.admin.deleteUser(
        targetRow.auth_user_id,
      );
      if (deleteError) {
        console.error("Auth delete error:", deleteError.message);
      }
    }

    return new Response(
      JSON.stringify({ success: true, auth_deleted: !!targetRow?.auth_user_id }),
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
