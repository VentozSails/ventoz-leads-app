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

function escHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function buildHtml(
  toEmail: string,
  userTypeLabel: string,
  mfaRequired: boolean,
  registerUrl: string,
): string {
  const mfaSection = mfaRequired
    ? `
<tr><td style="padding:20px 28px 0;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#FFF8E1;border:1px solid #F59E0B;border-radius:8px;">
<tr><td style="padding:16px 20px;">
<strong style="color:#92400E;font-size:14px;">&#128274; Tweefactorauthenticatie (MFA) vereist</strong>
<p style="margin:8px 0 0;font-size:13px;line-height:1.6;color:#78350F;">
Als ${escHtml(userTypeLabel)} is MFA verplicht. Na je eerste login word je gevraagd om MFA in te richten.<br/>
Installeer alvast een authenticator-app op je telefoon:
</p>
<ul style="margin:8px 0 0;padding-left:20px;font-size:13px;color:#78350F;line-height:1.8;">
<li><strong>Google Authenticator</strong> (Android / iOS)</li>
<li><strong>Microsoft Authenticator</strong> (Android / iOS)</li>
</ul>
</td></tr>
</table>
</td></tr>`
    : "";

  return `<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background-color:#f8fafc;">
<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f8fafc;">
<tr><td align="center" style="padding:24px 16px;">
<table width="600" cellpadding="0" cellspacing="0" style="background-color:#ffffff;border-radius:8px;border:1px solid #e2e8f0;">

<tr><td style="background-color:#37474F;padding:20px 28px;border-radius:8px 8px 0 0;">
<span style="color:#ffffff;font-size:18px;font-weight:700;font-family:Arial,Helvetica,sans-serif;">Ventoz Sails</span>
</td></tr>

<tr><td style="padding:28px;font-family:Arial,Helvetica,sans-serif;">
<h2 style="margin:0 0 8px;font-size:20px;color:#1E293B;">Welkom bij Ventoz!</h2>
<p style="font-size:14px;line-height:1.7;color:#334155;margin:0 0 20px;">
Je bent uitgenodigd als <strong>${escHtml(userTypeLabel)}</strong> voor het Ventoz platform.
Om aan de slag te gaan, maak je een account aan met dit e-mailadres
(<strong>${escHtml(toEmail)}</strong>).
</p>

<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f1f5f9;border-radius:8px;margin-bottom:20px;">
<tr><td style="padding:20px;text-align:center;">
<p style="margin:0 0 4px;font-size:13px;color:#64748B;">Stap 1: Ga naar het registratiescherm</p>
<p style="margin:0 0 16px;font-size:13px;color:#64748B;">Stap 2: Klik op <em>&quot;Uitgenodigd? Account aanmaken&quot;</em></p>
<!--[if mso]>
<v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" href="${registerUrl}"
style="height:44px;v-text-anchor:middle;width:260px;" arcsize="12%"
strokecolor="#37474F" fillcolor="#455A64">
<center style="color:#ffffff;font-family:Arial,sans-serif;font-size:15px;font-weight:bold;">Account aanmaken &rarr;</center>
</v:roundrect><![endif]-->
<!--[if !mso]><!-->
<a href="${registerUrl}" target="_blank"
style="display:inline-block;background-color:#455A64;color:#ffffff;
font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:bold;
text-decoration:none;padding:12px 32px;border-radius:6px;">Account aanmaken &rarr;</a>
<!--<![endif]-->
</td></tr>
</table>

<p style="font-size:13px;line-height:1.6;color:#64748B;margin:0;">
Werkt de knop niet? Kopieer deze link in je browser:<br/>
<a href="${registerUrl}" style="color:#455A64;word-break:break-all;">${registerUrl}</a>
</p>
</td></tr>
${mfaSection}
<tr><td style="padding:20px 28px;font-family:Arial,Helvetica,sans-serif;">
<p style="font-size:13px;line-height:1.6;color:#64748B;margin:0;">
Vragen? Neem contact op met de Ventoz beheerder die je heeft uitgenodigd.
</p>
</td></tr>

<tr><td style="padding:16px 28px;background-color:#f8fafc;border-radius:0 0 8px 8px;border-top:1px solid #e2e8f0;">
<span style="font-size:11px;color:#94a3b8;font-family:Arial,sans-serif;">Ventoz B.V. &middot; ventoz.com</span>
</td></tr>
</table>
</td></tr></table>
</body></html>`;
}

function buildPlainText(
  toEmail: string,
  userTypeLabel: string,
  mfaRequired: boolean,
  registerUrl: string,
): string {
  let text =
    `Welkom bij Ventoz!\n\n` +
    `Je bent uitgenodigd als ${userTypeLabel} voor het Ventoz platform.\n` +
    `Maak je account aan met dit e-mailadres (${toEmail}).\n\n` +
    `Ga naar: ${registerUrl}\n` +
    `Klik op "Uitgenodigd? Account aanmaken" en maak je account aan.\n\n`;

  if (mfaRequired) {
    text +=
      `Let op: MFA (tweefactorauthenticatie) is verplicht voor jouw rol.\n` +
      `Installeer alvast Google Authenticator of Microsoft Authenticator op je telefoon.\n\n`;
  }

  text +=
    `Vragen? Neem contact op met de Ventoz beheerder die je heeft uitgenodigd.\n\n` +
    `Ventoz B.V. — ventoz.com`;

  return text;
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

  // Try server-side decryption of secrets
  try {
    const { data: decrypted } = await supabase.rpc(
      "decrypt_settings_secrets",
      {
        p_settings: config,
        p_secret_fields: ["password"],
      },
    );
    if (decrypted) config = decrypted as SmtpConfig;
  } catch {
    // If decryption RPC is unavailable, password may already be plaintext
  }

  return config;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Niet geautoriseerd" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // Verify the caller is authenticated
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await createClient(
      SUPABASE_URL,
      Deno.env.get("SUPABASE_ANON_KEY") ?? SERVICE_ROLE_KEY,
    ).auth.getUser(token);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Ongeldige sessie" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const body = await req.json();
    const {
      to_email,
      user_type_label,
      mfa_required,
      app_url,
    } = body as {
      to_email: string;
      user_type_label: string;
      mfa_required: boolean;
      app_url: string;
    };

    if (!to_email || !user_type_label || !app_url) {
      return new Response(
        JSON.stringify({ error: "Verplichte velden ontbreken: to_email, user_type_label, app_url" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const smtp = await loadSmtpSettings(supabase);
    if (!smtp || !smtp.host || !smtp.username || !smtp.password || !smtp.from_email) {
      return new Response(
        JSON.stringify({ error: "SMTP is niet geconfigureerd" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const registerUrl = app_url.endsWith("/")
      ? `${app_url}inloggen`
      : `${app_url}/inloggen`;

    const html = buildHtml(to_email, user_type_label, mfa_required ?? false, registerUrl);
    const text = buildPlainText(to_email, user_type_label, mfa_required ?? false, registerUrl);

    const transportConfig: Record<string, unknown> = {
      host: smtp.host,
      port: smtp.port || 587,
      auth: {
        user: smtp.username,
        pass: smtp.password,
      },
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
          to: to_email,
          bcc: smtp.from_email,
          subject: "Uitnodiging Ventoz \u2014 maak je account aan",
          text,
          html,
        },
        (error: Error | null) => {
          if (error) return reject(error);
          resolve();
        },
      );
    });

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
