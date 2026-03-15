import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BUCKET = "product-images";

interface MigrationResult {
  total: number;
  migrated: number;
  skipped: number;
  errors: string[];
}

function getExtension(url: string): string {
  const match = url.match(/\.(\w{3,4})(?:[?#]|$)/);
  return match ? match[1].toLowerCase() : "jpg";
}

function getMimeType(ext: string): string {
  const map: Record<string, string> = {
    jpg: "image/jpeg",
    jpeg: "image/jpeg",
    png: "image/png",
    webp: "image/webp",
    gif: "image/gif",
  };
  return map[ext] || "image/jpeg";
}

function isVentozUrl(url: string): boolean {
  try {
    const host = new URL(url).hostname.toLowerCase();
    return host === "ventoz.nl" || host === "www.ventoz.nl";
  } catch {
    return false;
  }
}

async function downloadAndUpload(
  supabase: ReturnType<typeof createClient>,
  imageUrl: string,
  storagePath: string
): Promise<string | null> {
  try {
    const resp = await fetch(imageUrl);
    if (!resp.ok) return null;

    const arrayBuf = await resp.arrayBuffer();
    const bytes = new Uint8Array(arrayBuf);
    const ext = getExtension(imageUrl);

    const { error: uploadError } = await supabase.storage
      .from(BUCKET)
      .upload(storagePath, bytes, {
        contentType: getMimeType(ext),
        upsert: true,
      });

    if (uploadError) {
      console.error(`Upload error for ${storagePath}:`, uploadError.message);
      return null;
    }

    const { data } = supabase.storage.from(BUCKET).getPublicUrl(storagePath);
    return data.publicUrl;
  } catch (e) {
    console.error(`Download/upload error for ${imageUrl}:`, e);
    return null;
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" } });
  }

  // ── Auth: require admin/owner JWT ──
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Not authorized" }), { status: 401, headers: { "Content-Type": "application/json" } });
  }

  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? SERVICE_ROLE_KEY;
  const token = authHeader.replace("Bearer ", "");
  const { data: { user: caller }, error: authErr } = await createClient(SUPABASE_URL, anonKey).auth.getUser(token);
  if (authErr || !caller) {
    return new Response(JSON.stringify({ error: "Invalid session" }), { status: 401, headers: { "Content-Type": "application/json" } });
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: callerRow } = await supabase.from("ventoz_users").select("is_owner, is_admin, user_type").eq("auth_user_id", caller.id).maybeSingle();
  const isAdmin = callerRow?.is_owner || callerRow?.is_admin || ["owner", "admin"].includes(callerRow?.user_type || "");
  if (!isAdmin) {
    return new Response(JSON.stringify({ error: "Admin access required" }), { status: 403, headers: { "Content-Type": "application/json" } });
  }

  const url = new URL(req.url);
  const dryRun = url.searchParams.get("dry_run") === "true";
  const limitParam = url.searchParams.get("limit");
  const limit = limitParam ? parseInt(limitParam, 10) : 1000;

  const { data: products, error } = await supabase
    .from("product_catalogus")
    .select("id, naam, afbeelding_url, extra_afbeeldingen")
    .limit(limit);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "content-type": "application/json" },
    });
  }

  const result: MigrationResult = {
    total: products.length,
    migrated: 0,
    skipped: 0,
    errors: [],
  };

  for (const product of products) {
    const pid = product.id;
    const mainUrl = product.afbeelding_url as string | null;
    const extras = (product.extra_afbeeldingen as string[] | null) || [];
    const updates: Record<string, unknown> = {};
    let didMigrate = false;

    if (mainUrl && isVentozUrl(mainUrl)) {
      const ext = getExtension(mainUrl);
      const storagePath = `products/${pid}/main.${ext}`;

      if (dryRun) {
        console.log(`[DRY RUN] Would migrate main image for product ${pid}: ${mainUrl}`);
        didMigrate = true;
      } else {
        const newUrl = await downloadAndUpload(supabase, mainUrl, storagePath);
        if (newUrl) {
          updates["afbeelding_url"] = newUrl;
          didMigrate = true;
        } else {
          result.errors.push(`Product ${pid} (${product.naam}): main image download failed`);
        }
      }
    }

    if (extras.length > 0) {
      const newExtras: string[] = [];
      let extrasChanged = false;

      for (let i = 0; i < extras.length; i++) {
        const extraUrl = extras[i];
        if (isVentozUrl(extraUrl)) {
          const ext = getExtension(extraUrl);
          const storagePath = `products/${pid}/extra-${i + 1}.${ext}`;

          if (dryRun) {
            console.log(`[DRY RUN] Would migrate extra image ${i + 1} for product ${pid}: ${extraUrl}`);
            newExtras.push(extraUrl);
            didMigrate = true;
          } else {
            const newUrl = await downloadAndUpload(supabase, extraUrl, storagePath);
            if (newUrl) {
              newExtras.push(newUrl);
              extrasChanged = true;
              didMigrate = true;
            } else {
              newExtras.push(extraUrl);
              result.errors.push(`Product ${pid}: extra image ${i + 1} failed`);
            }
          }
        } else {
          newExtras.push(extraUrl);
        }
      }

      if (extrasChanged) {
        updates["extra_afbeeldingen"] = newExtras;
      }
    }

    if (!dryRun && Object.keys(updates).length > 0) {
      const { error: updateError } = await supabase
        .from("product_catalogus")
        .update(updates)
        .eq("id", pid);

      if (updateError) {
        result.errors.push(`Product ${pid}: DB update failed: ${updateError.message}`);
      }
    }

    if (didMigrate) {
      result.migrated++;
    } else if (!mainUrl || !isVentozUrl(mainUrl)) {
      result.skipped++;
    }
  }

  return new Response(JSON.stringify(result, null, 2), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
});
