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

type Lang = "nl" | "en" | "de" | "fr";

interface Strings {
  subject: string;
  welcome: string;
  invitedAs: string;
  toGetStarted: string;
  step1: string;
  step2: string;
  cta: string;
  fallbackLink: string;
  mfaTitle: string;
  mfaText: (label: string) => string;
  mfaInstall: string;
  questions: string;
  contact_form_mode_subject: string;
}

const i18n: Record<Lang, Strings> = {
  nl: {
    subject: "Uitnodiging Ventoz — maak je account aan",
    welcome: "Welkom bij Ventoz!",
    invitedAs: "Je bent uitgenodigd als",
    toGetStarted: "voor het Ventoz platform. Om aan de slag te gaan, maak je een account aan met dit e-mailadres",
    step1: "Stap 1: Ga naar het registratiescherm",
    step2: "Stap 2: Klik op \"Uitgenodigd? Account aanmaken\"",
    cta: "Account aanmaken →",
    fallbackLink: "Werkt de knop niet? Kopieer deze link in je browser:",
    mfaTitle: "🔒 Tweefactorauthenticatie (MFA) vereist",
    mfaText: (label) => `Als ${label} is MFA verplicht. Na je eerste login word je gevraagd om MFA in te richten.`,
    mfaInstall: "Installeer alvast een authenticator-app op je telefoon:",
    questions: "Vragen? Neem contact op met de Ventoz beheerder die je heeft uitgenodigd.",
    contact_form_mode_subject: "Contactformulier",
  },
  en: {
    subject: "Ventoz Invitation — create your account",
    welcome: "Welcome to Ventoz!",
    invitedAs: "You have been invited as",
    toGetStarted: "to the Ventoz platform. To get started, create an account with this email address",
    step1: "Step 1: Go to the registration screen",
    step2: "Step 2: Click \"Invited? Create account\"",
    cta: "Create account →",
    fallbackLink: "Button not working? Copy this link into your browser:",
    mfaTitle: "🔒 Two-factor authentication (MFA) required",
    mfaText: (label) => `As ${label}, MFA is required. After your first login, you will be asked to set up MFA.`,
    mfaInstall: "Please install an authenticator app on your phone:",
    questions: "Questions? Contact the Ventoz administrator who invited you.",
    contact_form_mode_subject: "Contact form",
  },
  de: {
    subject: "Ventoz-Einladung — erstelle dein Konto",
    welcome: "Willkommen bei Ventoz!",
    invitedAs: "Du wurdest eingeladen als",
    toGetStarted: "für die Ventoz-Plattform. Um loszulegen, erstelle ein Konto mit dieser E-Mail-Adresse",
    step1: "Schritt 1: Gehe zum Registrierungsbildschirm",
    step2: "Schritt 2: Klicke auf \"Eingeladen? Konto erstellen\"",
    cta: "Konto erstellen →",
    fallbackLink: "Funktioniert der Button nicht? Kopiere diesen Link in deinen Browser:",
    mfaTitle: "🔒 Zwei-Faktor-Authentifizierung (MFA) erforderlich",
    mfaText: (label) => `Als ${label} ist MFA Pflicht. Nach deinem ersten Login wirst du aufgefordert, MFA einzurichten.`,
    mfaInstall: "Installiere bitte eine Authenticator-App auf deinem Telefon:",
    questions: "Fragen? Wende dich an den Ventoz-Administrator, der dich eingeladen hat.",
    contact_form_mode_subject: "Kontaktformular",
  },
  fr: {
    subject: "Invitation Ventoz — créez votre compte",
    welcome: "Bienvenue chez Ventoz !",
    invitedAs: "Vous avez été invité(e) en tant que",
    toGetStarted: "sur la plateforme Ventoz. Pour commencer, créez un compte avec cette adresse e-mail",
    step1: "Étape 1 : Accédez à l'écran d'inscription",
    step2: "Étape 2 : Cliquez sur « Invité ? Créer un compte »",
    cta: "Créer un compte →",
    fallbackLink: "Le bouton ne fonctionne pas ? Copiez ce lien dans votre navigateur :",
    mfaTitle: "🔒 Authentification à deux facteurs (MFA) requise",
    mfaText: (label) => `En tant que ${label}, la MFA est obligatoire. Après votre première connexion, vous serez invité(e) à configurer la MFA.`,
    mfaInstall: "Installez une application d'authentification sur votre téléphone :",
    questions: "Des questions ? Contactez l'administrateur Ventoz qui vous a invité(e).",
    contact_form_mode_subject: "Formulaire de contact",
  },
};

function detectLang(lang?: string): Lang {
  if (!lang) return "nl";
  const l = lang.toLowerCase().slice(0, 2);
  if (l in i18n) return l as Lang;
  return "en";
}

function buildHtml(
  toEmail: string,
  userTypeLabel: string,
  mfaRequired: boolean,
  registerUrl: string,
  lang: Lang,
): string {
  const s = i18n[lang];

  const mfaSection = mfaRequired
    ? `
<tr><td style="padding:20px 28px 0;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#FFF8E1;border:1px solid #F59E0B;border-radius:8px;">
<tr><td style="padding:16px 20px;">
<strong style="color:#92400E;font-size:14px;">${s.mfaTitle}</strong>
<p style="margin:8px 0 0;font-size:13px;line-height:1.6;color:#78350F;">
${s.mfaText(escHtml(userTypeLabel))}<br/>
${s.mfaInstall}
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
<h2 style="margin:0 0 8px;font-size:20px;color:#1E293B;">${s.welcome}</h2>
<p style="font-size:14px;line-height:1.7;color:#334155;margin:0 0 20px;">
${s.invitedAs} <strong>${escHtml(userTypeLabel)}</strong> ${s.toGetStarted}
(<strong>${escHtml(toEmail)}</strong>).
</p>

<table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f1f5f9;border-radius:8px;margin-bottom:20px;">
<tr><td style="padding:20px;text-align:center;">
<p style="margin:0 0 4px;font-size:13px;color:#64748B;">${s.step1}</p>
<p style="margin:0 0 16px;font-size:13px;color:#64748B;">${s.step2}</p>
<!--[if mso]>
<v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" href="${registerUrl}"
style="height:44px;v-text-anchor:middle;width:260px;" arcsize="12%"
strokecolor="#37474F" fillcolor="#455A64">
<center style="color:#ffffff;font-family:Arial,sans-serif;font-size:15px;font-weight:bold;">${s.cta}</center>
</v:roundrect><![endif]-->
<!--[if !mso]><!-->
<a href="${registerUrl}" target="_blank"
style="display:inline-block;background-color:#455A64;color:#ffffff;
font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:bold;
text-decoration:none;padding:12px 32px;border-radius:6px;">${s.cta}</a>
<!--<![endif]-->
</td></tr>
</table>

<p style="font-size:13px;line-height:1.6;color:#64748B;margin:0;">
${s.fallbackLink}<br/>
<a href="${registerUrl}" style="color:#455A64;word-break:break-all;">${registerUrl}</a>
</p>
</td></tr>
${mfaSection}
<tr><td style="padding:20px 28px;font-family:Arial,Helvetica,sans-serif;">
<p style="font-size:13px;line-height:1.6;color:#64748B;margin:0;">
${s.questions}
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
  lang: Lang,
): string {
  const s = i18n[lang];
  let text =
    `${s.welcome}\n\n` +
    `${s.invitedAs} ${userTypeLabel} ${s.toGetStarted} (${toEmail}).\n\n` +
    `${s.step1}\n${s.step2}\n\n` +
    `${registerUrl}\n\n`;

  if (mfaRequired) {
    text += `${s.mfaTitle}\n${s.mfaText(userTypeLabel)}\n${s.mfaInstall}\n` +
      `• Google Authenticator (Android / iOS)\n• Microsoft Authenticator (Android / iOS)\n\n`;
  }

  text += `${s.questions}\n\nVentoz B.V. — ventoz.com`;
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
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const body = await req.json();

    // Contact form mode — no auth required
    if (body.mode === "contact_form") {
      const smtp = await loadSmtpSettings(supabase);
      if (!smtp) {
        return new Response(
          JSON.stringify({ error: "SMTP not configured" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const transportConfig = buildTransportConfig(smtp);
      const transport = nodemailer.createTransport(transportConfig);

      await new Promise<void>((resolve, reject) => {
        transport.sendMail(
          {
            from: `"${smtp.from_name || "Ventoz Sails"}" <${smtp.from_email}>`,
            to: body.to_email,
            replyTo: body.reply_to,
            subject: body.subject,
            text: body.plain_body,
            html: body.html_body,
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
    }

    // Invite mode — requires auth
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Not authorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await createClient(
      SUPABASE_URL,
      Deno.env.get("SUPABASE_ANON_KEY") ?? SERVICE_ROLE_KEY,
    ).auth.getUser(token);

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: "Invalid session" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const {
      to_email,
      user_type_label,
      mfa_required,
      app_url,
      lang,
    } = body as {
      to_email: string;
      user_type_label: string;
      mfa_required: boolean;
      app_url: string;
      lang?: string;
    };

    if (!to_email || !user_type_label || !app_url) {
      return new Response(
        JSON.stringify({ error: "Required fields: to_email, user_type_label, app_url" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const smtp = await loadSmtpSettings(supabase);
    if (!smtp || !smtp.host || !smtp.username || !smtp.password || !smtp.from_email) {
      return new Response(
        JSON.stringify({ error: "SMTP not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const registerUrl = app_url.endsWith("/")
      ? `${app_url}inloggen`
      : `${app_url}/inloggen`;

    const detectedLang = detectLang(lang);
    const s = i18n[detectedLang];
    const html = buildHtml(to_email, user_type_label, mfa_required ?? false, registerUrl, detectedLang);
    const text = buildPlainText(to_email, user_type_label, mfa_required ?? false, registerUrl, detectedLang);

    const transportConfig = buildTransportConfig(smtp);
    const transport = nodemailer.createTransport(transportConfig);

    await new Promise<void>((resolve, reject) => {
      transport.sendMail(
        {
          from: `"${smtp.from_name || "Ventoz Sails"}" <${smtp.from_email}>`,
          to: to_email,
          bcc: smtp.from_email,
          subject: s.subject,
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

function buildTransportConfig(smtp: SmtpConfig): Record<string, unknown> {
  const config: Record<string, unknown> = {
    host: smtp.host,
    port: smtp.port || 587,
    auth: { user: smtp.username, pass: smtp.password },
  };
  if (smtp.encryption === "ssl") {
    config.secure = true;
  } else if (smtp.encryption === "starttls") {
    config.secure = false;
    config.requireTLS = true;
  } else {
    config.secure = false;
  }
  if (smtp.allow_invalid_certificate) {
    config.tls = { rejectUnauthorized: false };
  }
  return config;
}
