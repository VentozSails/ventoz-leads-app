import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const ALLOWED_HOSTS = ["ventoz.nl", "www.ventoz.nl", "ventoz.com", "www.ventoz.com"];

serve(async (req: Request) => {
  const url = new URL(req.url);
  const imageUrl = url.searchParams.get("url");

  if (!imageUrl) {
    return new Response("Missing ?url= parameter", { status: 400 });
  }

  let parsed: URL;
  try {
    parsed = new URL(imageUrl);
  } catch {
    return new Response("Invalid URL", { status: 400 });
  }

  if (!ALLOWED_HOSTS.includes(parsed.hostname)) {
    return new Response("Host not allowed", { status: 403 });
  }

  try {
    const upstream = await fetch(imageUrl);
    if (!upstream.ok) {
      return new Response("Upstream error", { status: upstream.status });
    }

    const contentType = upstream.headers.get("content-type") || "image/jpeg";
    const body = await upstream.arrayBuffer();

    return new Response(body, {
      status: 200,
      headers: {
        "content-type": contentType,
        "access-control-allow-origin": "*",
        "cache-control": "public, max-age=86400",
      },
    });
  } catch (e) {
    return new Response(`Proxy error: ${e}`, { status: 502 });
  }
});
