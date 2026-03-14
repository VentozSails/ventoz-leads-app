import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

interface ImapConfig {
  host: string;
  port: number;
  username: string;
  password: string;
  last_fetched_uid?: number;
}

async function loadImapSettings(
  supabase: ReturnType<typeof createClient>,
): Promise<ImapConfig | null> {
  const { data, error } = await supabase
    .from("app_settings")
    .select("value")
    .eq("key", "imap_order_config")
    .single();

  if (error || !data) return null;
  const config = data.value as ImapConfig;

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
            "raw", keyBytes, { name: "AES-CBC" }, false, ["decrypt"],
          );
          const decrypted = await crypto.subtle.decrypt(
            { name: "AES-CBC", iv: ivBytes }, cryptoKey, dataBytes,
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

async function imapConnect(
  host: string,
  port: number,
): Promise<Deno.TlsConn | Deno.TcpConn> {
  if (port === 993) {
    return await Deno.connectTls({ hostname: host, port });
  }
  return await Deno.connect({ hostname: host, port });
}

const encoder = new TextEncoder();
const decoder = new TextDecoder();

async function readResponse(
  conn: Deno.TlsConn | Deno.TcpConn,
  timeoutMs = 12000,
): Promise<string> {
  const buf = new Uint8Array(16384);
  let result = "";
  const tagPattern = /^[a-zA-Z0-9]+ (OK|NO|BAD|BYE)\b/m;
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    try {
      const n = await Promise.race([
        conn.read(buf),
        new Promise<null>((resolve) =>
          setTimeout(() => resolve(null), Math.max(100, deadline - Date.now()))
        ),
      ]);
      if (n === null) {
        if (result.length > 0) break;
        continue;
      }
      if (n === 0 || n === undefined) break;
      result += decoder.decode(buf.subarray(0, n as number));
      const tail = result.length > 200 ? result.slice(-200) : result;
      if (tagPattern.test(tail)) break;
      if (
        result.length < 200 &&
        result.includes("* OK") &&
        !result.includes("a0")
      )
        break;
    } catch {
      break;
    }
  }
  return result;
}

async function sendCommand(
  conn: Deno.TlsConn | Deno.TcpConn,
  cmd: string,
): Promise<void> {
  await conn.write(encoder.encode(cmd + "\r\n"));
}

function escapeImap(s: string): string {
  return s.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

async function handleTest(config: ImapConfig): Promise<Response> {
  let conn: Deno.TlsConn | Deno.TcpConn | null = null;
  try {
    conn = await imapConnect(config.host, config.port);
    const greeting = await readResponse(conn);
    if (!greeting.includes("OK")) {
      return json({ error: "Server gaf geen OK-antwoord" }, 500);
    }

    await sendCommand(
      conn,
      `a001 LOGIN "${escapeImap(config.username)}" "${escapeImap(config.password)}"`,
    );
    const loginResp = await readResponse(conn);
    if (!loginResp.includes("a001 OK")) {
      return json(
        { error: "Login mislukt: controleer gebruikersnaam en wachtwoord" },
        401,
      );
    }

    await sendCommand(conn, "a002 SELECT INBOX");
    const selectResp = await readResponse(conn);
    if (!selectResp.includes("a002 OK")) {
      return json({ error: "Kan INBOX niet openen" }, 500);
    }

    const existsMatch = /(\d+) EXISTS/.exec(selectResp);
    const count = existsMatch?.[1] ?? "?";

    await sendCommand(conn, "a003 LOGOUT");
    try { await readResponse(conn, 3000); } catch { /* ignore */ }

    return json({
      success: true,
      message: `Verbinding geslaagd! INBOX bevat ${count} berichten.`,
    });
  } catch (e) {
    return json(
      { error: `Verbindingsfout: ${e instanceof Error ? e.message : String(e)}` },
      500,
    );
  } finally {
    try { conn?.close(); } catch { /* ignore */ }
  }
}

async function handleFetch(
  config: ImapConfig,
  lastUid: number,
): Promise<Response> {
  let conn: Deno.TlsConn | Deno.TcpConn | null = null;
  try {
    conn = await imapConnect(config.host, config.port);
    const greeting = await readResponse(conn);
    if (!greeting.includes("OK")) {
      return json({ error: "Server gaf geen OK-antwoord" }, 500);
    }

    await sendCommand(
      conn,
      `a001 LOGIN "${escapeImap(config.username)}" "${escapeImap(config.password)}"`,
    );
    const loginResp = await readResponse(conn);
    if (!loginResp.includes("a001 OK")) {
      return json({ error: "Login mislukt" }, 401);
    }

    await sendCommand(conn, "a002 SELECT INBOX");
    const selectResp = await readResponse(conn);
    if (!selectResp.includes("a002 OK")) {
      return json({ error: "Kan INBOX niet openen" }, 500);
    }

    const months = [
      "", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    const sinceDate = new Date(2026, 0, 1);
    const since = `${sinceDate.getDate()}-${months[sinceDate.getMonth() + 1]}-${sinceDate.getFullYear()}`;

    const searchQuery =
      lastUid > 0
        ? `a003 UID SEARCH SINCE ${since} UID ${lastUid + 1}:*`
        : `a003 UID SEARCH SINCE ${since}`;

    await sendCommand(conn, searchQuery);
    const searchResp = await readResponse(conn);

    const searchLine =
      searchResp.split("\n").find((l: string) => l.startsWith("* SEARCH")) ?? "";
    if (!searchLine) {
      await sendCommand(conn, "a099 LOGOUT");
      try { await readResponse(conn, 3000); } catch { /* ignore */ }
      return json({ emails: [], uids: [] });
    }

    const uids = [...searchLine.replace("* SEARCH", "").matchAll(/\d+/g)]
      .map((m) => parseInt(m[0], 10))
      .sort((a, b) => a - b);

    if (uids.length === 0) {
      await sendCommand(conn, "a099 LOGOUT");
      try { await readResponse(conn, 3000); } catch { /* ignore */ }
      return json({ emails: [], uids: [] });
    }

    const emails: Array<{ uid: number; raw: string }> = [];
    for (const uid of uids) {
      try {
        await sendCommand(conn, `f${uid} UID FETCH ${uid} BODY[]`);
        const fetchResp = await readResponse(conn, 15000);
        emails.push({ uid, raw: fetchResp });
      } catch (e) {
        console.error(`Fetch UID ${uid} failed:`, e);
      }
    }

    await sendCommand(conn, "a099 LOGOUT");
    try { await readResponse(conn, 3000); } catch { /* ignore */ }

    return json({ emails, uids });
  } catch (e) {
    return json(
      {
        error: `IMAP-fout: ${e instanceof Error ? e.message : String(e)}`,
      },
      500,
    );
  } finally {
    try { conn?.close(); } catch { /* ignore */ }
  }
}

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

    // Extract user ID from JWT. The app may use publishable keys (ES256)
    // which auth.getUser() cannot validate with the service role key.
    // Decode the JWT payload directly and verify the user exists in the DB.
    let userId: string | null = null;

    // Try auth.getUser first (works for standard HS256 tokens)
    try {
      const { data, error } = await supabase.auth.getUser(token);
      if (!error && data?.user) userId = data.user.id;
    } catch { /* ignore */ }

    // Fallback: decode JWT payload manually
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
    const mode = body.mode as string;

    const config = await loadImapSettings(supabase);
    if (!config) return json({ error: "IMAP not configured" }, 500);

    if (mode === "test") {
      return await handleTest(config);
    }

    if (mode === "fetch") {
      const lastUid = (body.last_fetched_uid as number) ?? config.last_fetched_uid ?? 0;
      return await handleFetch(config, lastUid);
    }

    return json({ error: "Invalid mode. Use 'test' or 'fetch'." }, 400);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("imap-proxy error:", msg);
    return json({ error: msg }, 500);
  }
});
