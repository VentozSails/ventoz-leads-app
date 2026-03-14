import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  const url = new URL(req.url);
  const code = url.searchParams.get("code");
  const error = url.searchParams.get("error");
  const errorDescription = url.searchParams.get("error_description");
  const accountLabel = url.searchParams.get("state") || null;

  const appUrl = "https://app.ventoz.com";

  if (error) {
    return redirectWithMessage(appUrl, `eBay OAuth fout: ${errorDescription || error}`, true);
  }

  if (!code) {
    return redirectWithMessage(appUrl, "Geen autorisatiecode ontvangen van eBay.", true);
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Get existing client_id and client_secret for this account
    // First try with accountLabel, then fallback to any eBay credentials
    let resolvedLabel = accountLabel;
    let credsMap: Record<string, string> = {};

    for (const tryLabel of [accountLabel, undefined]) {
      let credsQuery = supabase
        .from("marketplace_credentials")
        .select("credential_type, encrypted_value, account_label")
        .eq("platform", "ebay")
        .eq("actief", true);

      if (tryLabel) {
        credsQuery = credsQuery.eq("account_label", tryLabel);
      } else if (tryLabel === undefined && accountLabel) {
        continue;
      } else {
        // No label specified — get all eBay credentials
      }

      const { data: creds } = await credsQuery;
      const map: Record<string, string> = {};
      if (creds && creds.length > 0) {
        resolvedLabel = creds[0].account_label || null;
        for (const c of creds) {
          map[c.credential_type] = c.encrypted_value;
        }
      }
      if (map.client_id && map.client_secret) {
        credsMap = map;
        break;
      }
    }

    if (!credsMap.client_id || !credsMap.client_secret) {
      return redirectWithMessage(appUrl, "eBay Client ID of Client Secret niet gevonden. Sla deze eerst op in de app.", true);
    }

    // Exchange authorization code for tokens
    const authString = btoa(`${credsMap.client_id}:${credsMap.client_secret}`);
    const callbackUrl = "Igor_Hulst-IgorHuls-Ventoz-fdmyguttc";

    const tokenResponse = await fetch("https://api.ebay.com/identity/v1/oauth2/token", {
      method: "POST",
      headers: {
        "Authorization": `Basic ${authString}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: `grant_type=authorization_code&code=${encodeURIComponent(code)}&redirect_uri=${encodeURIComponent(callbackUrl)}`,
    });

    if (!tokenResponse.ok) {
      const errorText = await tokenResponse.text();
      console.error("Token exchange failed:", errorText);
      return redirectWithMessage(appUrl, `Token exchange mislukt: ${tokenResponse.status}`, true);
    }

    const tokenData = await tokenResponse.json();
    const refreshToken = tokenData.refresh_token;
    const accessToken = tokenData.access_token;

    if (!refreshToken) {
      return redirectWithMessage(appUrl, "Geen refresh token ontvangen van eBay.", true);
    }

    // Save refresh_token under the same account_label as client_id/secret
    await upsertCredential(supabase, "ebay", "refresh_token", refreshToken, resolvedLabel);

    // Also save access_token for immediate use
    if (accessToken) {
      await upsertCredential(supabase, "ebay", "access_token", accessToken, resolvedLabel);
    }

    const label = resolvedLabel || "Standaard";
    return redirectWithMessage(appUrl, `eBay account "${label}" succesvol gekoppeld! Refresh token is opgeslagen.`, false);
  } catch (err: unknown) {
    console.error("OAuth callback error:", err);
    const msg = err instanceof Error ? err.message : String(err);
    return redirectWithMessage(appUrl, `Fout: ${msg}`, true);
  }
});

async function upsertCredential(
  supabase: any,
  platform: string,
  type: string,
  value: string,
  accountLabel: string | null
) {
  let query = supabase
    .from("marketplace_credentials")
    .select("id")
    .eq("platform", platform)
    .eq("credential_type", type);

  if (accountLabel) {
    query = query.eq("account_label", accountLabel);
  } else {
    query = query.is("account_label", null);
  }

  const { data: existing } = await query;

  if (existing && existing.length > 0) {
    await supabase
      .from("marketplace_credentials")
      .update({ encrypted_value: value, actief: true })
      .eq("id", existing[0].id);
  } else {
    const row: Record<string, any> = {
      platform,
      credential_type: type,
      encrypted_value: value,
      actief: true,
    };
    if (accountLabel) row.account_label = accountLabel;
    await supabase.from("marketplace_credentials").insert(row);
  }
}

function redirectWithMessage(baseUrl: string, message: string, isError: boolean): Response {
  const params = new URLSearchParams({
    ebay_oauth: isError ? "error" : "success",
    message,
  });
  return new Response(null, {
    status: 302,
    headers: { Location: `${baseUrl}?${params.toString()}` },
  });
}
