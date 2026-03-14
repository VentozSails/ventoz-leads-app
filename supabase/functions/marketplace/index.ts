import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface RequestBody {
  action: string;
  listing_id?: string;
  platform?: string;
  stock?: number;
  price?: number;
  product_ids?: number[];
  account_label?: string;
  product_id?: number;
  marketplace_id?: string;
  title?: string;
  description?: string;
  quantity?: number;
  condition?: string;
  category_id?: string;
}

function getErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const body: RequestBody = await req.json();
    const { action } = body;

    switch (action) {
      case "publish_listing":
        return await handlePublishListing(supabase, body);
      case "unpublish_listing":
        return await handleUnpublishListing(supabase, body);
      case "sync_stock":
        return await handleSyncStock(supabase, body);
      case "sync_price":
        return await handleSyncPrice(supabase, body);
      case "fetch_orders":
        return await handleFetchOrders(supabase, body);
      case "sync_ebay_stock":
        return await handleSyncEbayStock(supabase, body);
      case "sync_ebay_price":
        return await handleSyncEbayPrice(supabase, body);
      case "publish_to_ebay":
        return await handlePublishToEbay(supabase, body);
      case "check_process_status":
        return await handleCheckProcessStatus(supabase, body);
      case "debug_bolcom":
        return await handleDebugBolCom(supabase);
      case "get_feed_url":
        return jsonResponse({
          success: true,
          feed_url: `${supabaseUrl}/functions/v1/marktplaats-feed`,
          feed_url_tsv: `${supabaseUrl}/functions/v1/marktplaats-feed?format=tsv`,
        });
      case "add_to_feed":
        return await handleAddToFeed(supabase, body);
      case "import_ebay_listings":
        return await handleImportEbayListings(supabase, body);
      case "get_ebay_accounts":
        return await handleGetEbayAccounts(supabase);
      case "debug_ebay_creds": {
        const { data: allCreds } = await supabase
          .from("marketplace_credentials")
          .select("credential_type, account_label, actief")
          .eq("platform", "ebay");
        return jsonResponse({ success: true, credentials: allCreds });
      }
      default:
        return jsonResponse({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (error: unknown) {
    console.error("Marketplace function error:", error);
    return jsonResponse({ error: getErrorMessage(error) }, 500);
  }
});

// ═══════════════════════════════════════════
// Bol.com API Client
// ═══════════════════════════════════════════

async function getCredentials(
  supabase: any,
  platform: string,
  accountLabel?: string | null
): Promise<Record<string, string>> {
  // Try with specified label first
  let query = supabase
    .from("marketplace_credentials")
    .select("credential_type, encrypted_value")
    .eq("platform", platform)
    .eq("actief", true);

  if (accountLabel) {
    query = query.eq("account_label", accountLabel);
  } else {
    query = query.is("account_label", null);
  }

  const { data: creds } = await query;

  const map: Record<string, string> = {};
  if (creds) {
    for (const c of creds) {
      map[c.credential_type] = c.encrypted_value;
    }
  }

  // Fallback: if no creds found with null label, get all for this platform
  if (Object.keys(map).length === 0 && !accountLabel) {
    const { data: allCreds } = await supabase
      .from("marketplace_credentials")
      .select("credential_type, encrypted_value")
      .eq("platform", platform)
      .eq("actief", true);

    if (allCreds) {
      for (const c of allCreds) {
        if (!map[c.credential_type]) {
          map[c.credential_type] = c.encrypted_value;
        }
      }
    }
  }

  return map;
}

async function getBolComToken(supabase: any): Promise<string | null> {
  const creds = await getCredentials(supabase, "bol_com");
  if (!creds.client_id || !creds.client_secret) return null;

  const authString = btoa(`${creds.client_id}:${creds.client_secret}`);
  const response = await fetch("https://login.bol.com/token", {
    method: "POST",
    headers: {
      Authorization: `Basic ${authString}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Bol.com auth failed (${response.status}): ${errorText}`);
  }

  const tokenData = await response.json();
  return tokenData.access_token;
}

async function bolComApiCall(
  token: string,
  method: string,
  path: string,
  body?: any
): Promise<any> {
  const baseUrl = "https://api.bol.com/retailer";
  const headers: Record<string, string> = {
    Authorization: `Bearer ${token}`,
    Accept: "application/vnd.retailer.v10+json",
  };
  if (body) {
    headers["Content-Type"] = "application/vnd.retailer.v10+json";
  }

  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (response.status === 429) {
    const retryAfter = response.headers.get("Retry-After") || "5";
    throw new Error(
      `Rate limit bereikt. Probeer het over ${retryAfter} seconden opnieuw.`
    );
  }

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`API error ${response.status}: ${errorText.substring(0, 500)}`);
  }

  const text = await response.text();
  return text ? JSON.parse(text) : {};
}

// ═══════════════════════════════════════════
// eBay API Client (prepared)
// ═══════════════════════════════════════════

async function getEbayToken(supabase: any, accountLabel?: string | null): Promise<string | null> {
  const creds = await getCredentials(supabase, "ebay", accountLabel);

  // If a direct access_token is stored, use it (short-lived, ~2h)
  if (creds.access_token) {
    return creds.access_token;
  }

  if (!creds.client_id || !creds.client_secret || !creds.refresh_token) return null;

  const authString = btoa(`${creds.client_id}:${creds.client_secret}`);
  const response = await fetch("https://api.ebay.com/identity/v1/oauth2/token", {
    method: "POST",
    headers: {
      Authorization: `Basic ${authString}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: `grant_type=refresh_token&refresh_token=${encodeURIComponent(creds.refresh_token)}&scope=${encodeURIComponent("https://api.ebay.com/oauth/api_scope/sell.inventory https://api.ebay.com/oauth/api_scope/sell.fulfillment https://api.ebay.com/oauth/api_scope/sell.account")}`,
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`eBay auth failed (${response.status}): ${errorText}`);
  }

  const tokenData = await response.json();
  return tokenData.access_token;
}

async function ebayApiCall(
  token: string,
  method: string,
  path: string,
  body?: any,
  apiBase = "https://api.ebay.com",
  marketplaceId = "EBAY_NL"
): Promise<any> {
  const headers: Record<string, string> = {
    Authorization: `Bearer ${token}`,
    Accept: "application/json",
    "Content-Language": "nl-NL",
    "X-EBAY-C-MARKETPLACE-ID": marketplaceId,
  };
  if (body) {
    headers["Content-Type"] = "application/json";
  }

  const response = await fetch(`${apiBase}${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (response.status === 429) {
    throw new Error("eBay rate limit bereikt. Probeer het later opnieuw.");
  }

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`eBay API error ${response.status}: ${errorText.substring(0, 500)}`);
  }

  const text = await response.text();
  return text ? JSON.parse(text) : {};
}

// ═══════════════════════════════════════════
// Handlers
// ═══════════════════════════════════════════

async function handlePublishListing(
  supabase: any,
  body: RequestBody
): Promise<Response> {
  const { listing_id } = body;
  if (!listing_id)
    return jsonResponse({ error: "listing_id is required" }, 400);

  const { data: listing } = await supabase
    .from("marketplace_listings")
    .select("*, product_catalogus(naam, ean_code, prijs, beschrijving, artikelnummer, categorie)")
    .eq("id", listing_id)
    .single();

  if (!listing) return jsonResponse({ error: "Listing not found" }, 404);

  const platform = listing.platform;
  let result: any;

  try {
    switch (platform) {
      case "bol_com":
        result = await publishToBolCom(supabase, listing);
        break;
      case "ebay":
        result = await publishToEbay(supabase, listing);
        break;
      case "amazon":
        result = { success: false, message: "Amazon SP-API integratie wordt binnenkort toegevoegd. Registreer eerst een SP-API app op Seller Central." };
        break;
      case "marktplaats":
        result = { success: false, message: "Marktplaats API integratie wordt binnenkort toegevoegd. Neem contact op met Marktplaats voor API-credentials." };
        break;
      default:
        return jsonResponse({ error: `Unknown platform: ${platform}` }, 400);
    }
  } catch (error: unknown) {
    result = { success: false, message: getErrorMessage(error) };
  }

  await logSync(supabase, platform, "listing_create", listing_id, result);
  return jsonResponse(result);
}

async function publishToBolCom(supabase: any, listing: any): Promise<any> {
  const token = await getBolComToken(supabase);
  if (!token) {
    return { success: false, message: "Bol.com credentials niet geconfigureerd. Ga naar Marktplaatsen → Bol.com → Koppelen." };
  }

  const product = listing.product_catalogus;
  if (!product?.ean_code) {
    return { success: false, message: "Product heeft geen EAN-code. Deze is verplicht voor Bol.com." };
  }

  const offerData = {
    ean: product.ean_code,
    condition: { name: "NEW" },
    reference: product.artikelnummer || `VTZ-${listing.product_id}`,
    pricing: {
      bundlePrices: [{ quantity: 1, unitPrice: listing.prijs || product.prijs }],
    },
    stock: { amount: 0, managedByRetailer: true },
    fulfilment: { method: "FBR", deliveryCode: "3-5d" },
  };

  const result = await bolComApiCall(token, "POST", "/offers", offerData);

  const updateData: any = {
    laatste_sync: new Date().toISOString(),
    platform_data: { ...listing.platform_data, process_status_id: result.processStatusId },
  };

  // Bol.com offers are async: poll process status to get the offer ID
  if (result.processStatusId) {
    try {
      const offerId = await pollBolComProcessStatus(token, result.processStatusId);
      if (offerId) {
        updateData.extern_id = offerId;
        updateData.extern_url = `https://www.bol.com/nl/nl/p/-/${product.ean_code}/`;
        updateData.status = "actief";
        updateData.sync_fout = null;
      } else {
        updateData.status = "actief";
        updateData.platform_data.note = "Offer wordt verwerkt. Extern ID wordt later opgehaald.";
      }
    } catch (pollError: unknown) {
      updateData.status = "actief";
      updateData.sync_fout = `Process status polling: ${getErrorMessage(pollError)}`;
    }
  }

  await supabase.from("marketplace_listings").update(updateData).eq("id", listing.id);

  return {
    success: true,
    message: updateData.extern_id
      ? `Offer aangemaakt op Bol.com (ID: ${updateData.extern_id})`
      : "Offer aangemaakt op Bol.com, wordt verwerkt...",
    extern_id: updateData.extern_id,
    process_status_id: result.processStatusId,
  };
}

async function pollBolComProcessStatus(
  token: string,
  processStatusId: string,
  maxAttempts = 5
): Promise<string | null> {
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    await new Promise((resolve) => setTimeout(resolve, 2000 * (attempt + 1)));
    try {
      const status = await bolComApiCall(token, "GET", `/process-status/${processStatusId}`);
      if (status.status === "SUCCESS") {
        return status.entityId || null;
      }
      if (status.status === "FAILURE" || status.status === "TIMEOUT") {
        throw new Error(`Bol.com process ${status.status}: ${JSON.stringify(status.errorMessage || "")}`);
      }
    } catch (e: unknown) {
      if (attempt === maxAttempts - 1) throw e;
    }
  }
  return null;
}

async function publishToEbay(supabase: any, listing: any): Promise<any> {
  const token = await getEbayToken(supabase);
  if (!token) {
    return { success: false, message: "eBay credentials niet geconfigureerd. Registreer een app op developer.ebay.com." };
  }

  const product = listing.product_catalogus;
  const sku = product.artikelnummer || `VTZ-${listing.product_id}`;

  // Step 1: Create/update inventory item
  const inventoryItem = {
    availability: {
      shipToLocationAvailability: { quantity: 0 },
    },
    condition: "NEW",
    product: {
      title: product.naam,
      description: product.beschrijving || product.naam,
      aspects: {} as Record<string, string[]>,
      ...(product.ean_code ? { ean: [product.ean_code] } : {}),
    },
  };

  if (product.categorie) {
    inventoryItem.product.aspects["Type"] = [product.categorie];
  }

  await ebayApiCall(token, "PUT", `/sell/inventory/v1/inventory_item/${sku}`, inventoryItem);

  // Step 2: Create offer
  const offerData = {
    sku,
    marketplaceId: "EBAY_NL",
    format: "FIXED_PRICE",
    listingDescription: product.beschrijving || product.naam,
    pricingSummary: {
      price: {
        value: String(listing.prijs || product.prijs || 0),
        currency: "EUR",
      },
    },
    quantityLimitPerBuyer: 5,
    availableQuantity: 0,
  };

  const offerResult = await ebayApiCall(token, "POST", "/sell/inventory/v1/offer", offerData);
  const offerId = offerResult.offerId;

  // Step 3: Publish the offer
  let listingId: string | null = null;
  if (offerId) {
    try {
      const publishResult = await ebayApiCall(token, "POST", `/sell/inventory/v1/offer/${offerId}/publish`);
      listingId = publishResult.listingId;
    } catch (pubError: unknown) {
      console.error("eBay publish error:", pubError);
    }
  }

  await supabase.from("marketplace_listings").update({
    extern_id: listingId || offerId,
    extern_url: listingId ? `https://www.ebay.nl/itm/${listingId}` : null,
    status: "actief",
    laatste_sync: new Date().toISOString(),
    sync_fout: null,
    platform_data: { ...listing.platform_data, sku, offer_id: offerId, listing_id: listingId },
  }).eq("id", listing.id);

  return {
    success: true,
    message: listingId
      ? `eBay listing aangemaakt (ID: ${listingId})`
      : `eBay offer aangemaakt (ID: ${offerId}), publicatie wordt verwerkt`,
    extern_id: listingId || offerId,
  };
}

// ── Unpublish ──

async function handleUnpublishListing(
  supabase: any,
  body: RequestBody
): Promise<Response> {
  const { listing_id } = body;
  if (!listing_id)
    return jsonResponse({ error: "listing_id is required" }, 400);

  const { data: listing } = await supabase
    .from("marketplace_listings")
    .select("*")
    .eq("id", listing_id)
    .single();

  if (!listing) return jsonResponse({ error: "Listing not found" }, 404);

  try {
    if (listing.platform === "bol_com" && listing.extern_id) {
      const token = await getBolComToken(supabase);
      if (token) {
        await bolComApiCall(token, "DELETE", `/offers/${listing.extern_id}`);
      }
    } else if (listing.platform === "ebay" && listing.platform_data?.offer_id) {
      const token = await getEbayToken(supabase);
      if (token) {
        await ebayApiCall(token, "DELETE", `/sell/inventory/v1/offer/${listing.platform_data.offer_id}`);
        if (listing.platform_data?.sku) {
          await ebayApiCall(token, "DELETE", `/sell/inventory/v1/inventory_item/${listing.platform_data.sku}`);
        }
      }
    }
  } catch (error: unknown) {
    console.error("Unpublish platform error:", error);
  }

  await supabase.from("marketplace_listings").update({ status: "verwijderd" }).eq("id", listing_id);
  await logSync(supabase, listing.platform, "listing_delete", listing_id, { success: true });
  return jsonResponse({ success: true, message: "Listing verwijderd van platform" });
}

// ── Stock Sync ──

async function handleSyncStock(
  supabase: any,
  body: RequestBody
): Promise<Response> {
  const { listing_id, stock } = body;
  if (!listing_id || stock === undefined) {
    return jsonResponse({ error: "listing_id and stock are required" }, 400);
  }

  const { data: listing } = await supabase
    .from("marketplace_listings")
    .select("*")
    .eq("id", listing_id)
    .single();

  if (!listing) return jsonResponse({ error: "Listing not found" }, 404);

  try {
    if (listing.platform === "bol_com" && listing.extern_id) {
      const token = await getBolComToken(supabase);
      if (token) {
        await bolComApiCall(token, "PUT", `/offers/${listing.extern_id}/stock`, {
          amount: stock,
          managedByRetailer: true,
        });
      }
    } else if (listing.platform === "ebay" && listing.platform_data?.sku) {
      const token = await getEbayToken(supabase);
      if (token) {
        await ebayApiCall(token, "PUT", `/sell/inventory/v1/inventory_item/${listing.platform_data.sku}`, {
          availability: { shipToLocationAvailability: { quantity: stock } },
        });
      }
    } else {
      return jsonResponse({
        success: false,
        message: `Voorraad sync voor ${listing.platform} vereist een actieve listing met extern ID`,
      });
    }

    await supabase.from("marketplace_listings").update({
      laatste_sync: new Date().toISOString(),
      sync_fout: null,
    }).eq("id", listing_id);

    await logSync(supabase, listing.platform, "stock_sync", listing_id, { success: true, stock });
    return jsonResponse({ success: true, stock });
  } catch (error: unknown) {
    const msg = getErrorMessage(error);
    await supabase.from("marketplace_listings").update({ sync_fout: msg }).eq("id", listing_id);
    await logSync(supabase, listing.platform, "stock_sync", listing_id, { success: false, error: msg });
    return jsonResponse({ success: false, message: msg }, 500);
  }
}

// ── Price Sync ──

async function handleSyncPrice(
  supabase: any,
  body: RequestBody
): Promise<Response> {
  const { listing_id, price } = body;
  if (!listing_id || price === undefined) {
    return jsonResponse({ error: "listing_id and price are required" }, 400);
  }

  const { data: listing } = await supabase
    .from("marketplace_listings")
    .select("*")
    .eq("id", listing_id)
    .single();

  if (!listing) return jsonResponse({ error: "Listing not found" }, 404);

  try {
    if (listing.platform === "bol_com" && listing.extern_id) {
      const token = await getBolComToken(supabase);
      if (token) {
        await bolComApiCall(token, "PUT", `/offers/${listing.extern_id}/price`, {
          pricing: { bundlePrices: [{ quantity: 1, unitPrice: price }] },
        });
      }
    } else if (listing.platform === "ebay" && listing.platform_data?.offer_id) {
      const token = await getEbayToken(supabase);
      if (token) {
        await ebayApiCall(token, "PUT", `/sell/inventory/v1/offer/${listing.platform_data.offer_id}`, {
          pricingSummary: { price: { value: String(price), currency: "EUR" } },
        });
      }
    } else {
      return jsonResponse({
        success: false,
        message: `Prijs sync voor ${listing.platform} vereist een actieve listing`,
      });
    }

    await supabase.from("marketplace_listings").update({
      prijs: price,
      laatste_sync: new Date().toISOString(),
      sync_fout: null,
    }).eq("id", listing_id);

    await logSync(supabase, listing.platform, "price_sync", listing_id, { success: true, price });
    return jsonResponse({ success: true, price });
  } catch (error: unknown) {
    const msg = getErrorMessage(error);
    await logSync(supabase, listing.platform, "price_sync", listing_id, { success: false, error: msg });
    return jsonResponse({ success: false, message: msg }, 500);
  }
}

// ── Process Status Check (Bol.com async operations) ──

async function handleCheckProcessStatus(
  supabase: any,
  body: RequestBody
): Promise<Response> {
  const { listing_id } = body;
  if (!listing_id) return jsonResponse({ error: "listing_id is required" }, 400);

  const { data: listing } = await supabase
    .from("marketplace_listings")
    .select("*")
    .eq("id", listing_id)
    .single();

  if (!listing) return jsonResponse({ error: "Listing not found" }, 404);
  if (listing.platform !== "bol_com") {
    return jsonResponse({ success: true, message: "Alleen relevant voor Bol.com" });
  }

  const processStatusId = listing.platform_data?.process_status_id;
  if (!processStatusId) {
    return jsonResponse({ success: false, message: "Geen process status ID gevonden" });
  }

  const token = await getBolComToken(supabase);
  if (!token) return jsonResponse({ success: false, message: "Geen Bol.com credentials" });

  try {
    const status = await bolComApiCall(token, "GET", `/process-status/${processStatusId}`);

    if (status.status === "SUCCESS" && status.entityId) {
      const product = listing.product_catalogus;
      await supabase.from("marketplace_listings").update({
        extern_id: status.entityId,
        extern_url: product?.ean_code ? `https://www.bol.com/nl/nl/p/-/${product.ean_code}/` : null,
        sync_fout: null,
        platform_data: { ...listing.platform_data, process_status: "SUCCESS" },
      }).eq("id", listing_id);

      return jsonResponse({
        success: true,
        status: "SUCCESS",
        extern_id: status.entityId,
        message: `Offer ID ontvangen: ${status.entityId}`,
      });
    }

    return jsonResponse({
      success: true,
      status: status.status,
      message: `Process status: ${status.status}`,
    });
  } catch (error: unknown) {
    return jsonResponse({ success: false, message: getErrorMessage(error) }, 500);
  }
}

// ── Order Fetch ──

async function handleFetchOrders(
  supabase: any,
  body: RequestBody
): Promise<Response> {
  const { platform } = body;
  if (!platform) return jsonResponse({ error: "platform is required" }, 400);

  try {
    switch (platform) {
      case "bol_com":
        return await fetchBolComOrders(supabase);
      case "ebay":
        return await fetchEbayOrders(supabase, body.account_label);
      default:
        return jsonResponse({
          success: false,
          message: `Order import voor ${platform} is nog niet geïmplementeerd`,
        });
    }
  } catch (error: unknown) {
    const msg = getErrorMessage(error);
    await logSync(supabase, platform, "order_import", null, { success: false, error: msg });
    return jsonResponse({ success: false, message: msg }, 500);
  }
}

async function fetchBolComOrders(supabase: any): Promise<Response> {
  const token = await getBolComToken(supabase);
  if (!token) {
    return jsonResponse({ success: false, message: "Bol.com credentials niet geconfigureerd" });
  }

  let imported = 0;
  let totalFound = 0;

  // 1. Fetch orders via /orders endpoint (recent open + shipped)
  for (const status of ["OPEN", "SHIPPED"]) {
    for (const method of ["FBR", "FBB"]) {
      let page = 1;
      let hasMore = true;
      while (hasMore) {
        try {
          const resp = await bolComApiCall(token, "GET", `/orders?status=${status}&fulfilment-method=${method}&page=${page}`);
          const batch = resp.orders || [];
          console.log(`Orders ${status}_${method} page ${page}: ${batch.length} found`);
          for (const order of batch) {
            totalFound++;
            try {
              const result = await importBolComOrder(supabase, token, order.orderId);
              if (result) imported++;
            } catch (importErr: unknown) {
              console.error(`Import error for order ${order.orderId}: ${getErrorMessage(importErr)}`);
            }
          }
          hasMore = batch.length >= 50;
          page++;
        } catch (e: unknown) {
          console.log(`Orders ${status}_${method}: ${getErrorMessage(e)} (this may be normal if no orders exist)`);
          hasMore = false;
        }
      }
    }
  }

  // 2. Fetch via /shipments endpoint (all shipped orders, goes back much further)
  const seenOrderIds = new Set<string>();
  const errors: string[] = [];
  for (const method of ["FBR", "FBB"]) {
    let shipmentPage = 1;
    let hasMoreShipments = true;
    while (hasMoreShipments) {
      try {
        const resp = await bolComApiCall(token, "GET", `/shipments?page=${shipmentPage}&fulfilment-method=${method}`);
        const shipments = resp.shipments || [];
        console.log(`Shipments ${method} page ${shipmentPage}: ${shipments.length} found`);
        for (const shipment of shipments) {
          const orderId = shipment.order?.orderId;
          console.log(`Shipment ${shipment.shipmentId}: orderId=${orderId}`);
          if (orderId && !seenOrderIds.has(orderId)) {
            seenOrderIds.add(orderId);
            totalFound++;
            try {
              const result = await importBolComOrder(supabase, token, orderId);
              if (result) imported++;
            } catch (importErr: unknown) {
              const msg = `Import error for ${orderId}: ${getErrorMessage(importErr)}`;
              console.error(msg);
              errors.push(msg);
            }
          }
        }
        hasMoreShipments = shipments.length >= 50;
        shipmentPage++;
      } catch (e: unknown) {
        const msg = `Shipments ${method} page ${shipmentPage}: ${getErrorMessage(e)}`;
        console.error(msg);
        errors.push(msg);
        hasMoreShipments = false;
      }
    }
  }

  await logSync(supabase, "bol_com", "order_import", null, {
    success: true,
    total_from_api: totalFound,
    new_imported: imported,
    errors: errors.length > 0 ? errors : undefined,
  });

  return jsonResponse({
    success: true,
    message: `${imported} nieuwe order(s) geïmporteerd van ${totalFound} totaal`,
    imported,
    total: totalFound,
    errors: errors.length > 0 ? errors : undefined,
  });
}

async function importBolComOrder(supabase: any, token: string, orderId: string): Promise<boolean> {
  const { data: existing } = await supabase
    .from("marketplace_orders")
    .select("id, product_ean, verzend_straat")
    .eq("platform", "bol_com")
    .eq("extern_order_id", orderId)
    .maybeSingle();

  if (existing) {
    const needsEnrich = !existing.product_ean && !existing.verzend_straat;
    if (!needsEnrich) return false;
  }

  try {
    const od = await bolComApiCall(token, "GET", `/orders/${orderId}`);
    const sd = od.shipmentDetails || {};
    const bd = od.billingDetails || {};
    const items = od.orderItems || [];
    const firstItem = items[0] || {};
    const fulfilment = firstItem.fulfilment || {};

    const klantNaam = `${sd.firstName || ""} ${sd.surname || ""}`.trim();
    const totaal = items.reduce(
      (sum: number, item: any) => sum + (item.totalPrice || item.unitPrice || 0) * (item.quantity || 1), 0
    );
    const totalCommission = items.reduce(
      (sum: number, item: any) => sum + (item.commission || 0), 0
    );
    const totalQuantity = items.reduce(
      (sum: number, item: any) => sum + (item.quantity || 1), 0
    );

    let internalStatus = "nieuw";
    if (items.every((i: any) => i.cancellationRequest)) {
      internalStatus = "geannuleerd";
    } else if (items.every((i: any) => (i.quantityShipped || 0) >= (i.quantity || 1))) {
      internalStatus = "verzonden";
    }

    const orderItems = items.map((item: any) => ({
      orderItemId: item.orderItemId,
      ean: item.product?.ean,
      title: item.product?.title,
      quantity: item.quantity || 1,
      quantityShipped: item.quantityShipped || 0,
      quantityCancelled: item.quantityCancelled || 0,
      unitPrice: item.unitPrice,
      totalPrice: item.totalPrice,
      commission: item.commission,
      offerId: item.offer?.offerId,
      cancellationRequest: item.cancellationRequest || false,
      latestChangedDateTime: item.latestChangedDateTime,
    }));

    // Try to get transport/track-trace info from shipments
    let transportId: string | null = null;
    let trackTrace: string | null = null;
    try {
      const shipmentsResp = await bolComApiCall(token, "GET", `/shipments?order-id=${orderId}`);
      const firstShipment = (shipmentsResp.shipments || [])[0];
      if (firstShipment) {
        transportId = firstShipment.transport?.transportId?.toString() || null;
        trackTrace = firstShipment.transport?.trackAndTrace || null;
      }
    } catch { /* track & trace is best-effort */ }

    const record = {
      platform: "bol_com",
      extern_order_id: orderId,
      status: internalStatus,
      klant_naam: klantNaam,
      klant_email: sd.email || null,
      klant_telefoon: sd.deliveryPhoneNumber || null,
      klant_aanhef: sd.salutation || null,

      verzend_straat: sd.streetName || null,
      verzend_huisnummer: sd.houseNumber || null,
      verzend_huisnummer_ext: sd.houseNumberExtension || null,
      verzend_postcode: sd.zipCode || null,
      verzend_stad: sd.city || null,
      verzend_land: sd.countryCode || "NL",

      factuur_naam: `${bd.firstName || ""} ${bd.surname || ""}`.trim() || null,
      factuur_straat: bd.streetName || null,
      factuur_huisnummer: bd.houseNumber || null,
      factuur_huisnummer_ext: bd.houseNumberExtension || null,
      factuur_postcode: bd.zipCode || null,
      factuur_stad: bd.city || null,
      factuur_land: bd.countryCode || "NL",
      factuur_email: bd.email || null,

      besteld_op: od.orderPlacedDateTime || null,
      uiterste_leverdatum: fulfilment.latestDeliveryDate || null,
      fulfillment_methode: fulfilment.method || null,
      transport_id: transportId,
      track_trace: trackTrace,

      totaal,
      commissie: totalCommission > 0 ? totalCommission : null,
      aantal_items: items.length,

      product_ean: firstItem.product?.ean || null,
      product_titel: firstItem.product?.title || null,
      product_hoeveelheid: totalQuantity,
      stukprijs: firstItem.unitPrice || null,

      order_items: orderItems,
      order_data: od,
    };

    if (existing) {
      await supabase.from("marketplace_orders")
        .update(record)
        .eq("id", existing.id);
    } else {
      await supabase.from("marketplace_orders").insert(record);
    }
    return true;
  } catch (e: unknown) {
    console.error(`Failed to import Bol.com order ${orderId}:`, e);
    return false;
  }
}

async function fetchEbayOrders(supabase: any, accountLabel?: string | null): Promise<Response> {
  const token = await getEbayToken(supabase, accountLabel);
  if (!token) {
    return jsonResponse({ success: false, message: "eBay credentials niet geconfigureerd" });
  }

  const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString();
  let imported = 0;
  let totalFound = 0;
  let offset = 0;
  const errors: string[] = [];

  let hasMore = true;
  while (hasMore) {
    try {
      const ordersResponse = await ebayApiCall(
        token, "GET",
        `/sell/fulfillment/v1/order?filter=creationdate:[${thirtyDaysAgo}..]&limit=50&offset=${offset}`
      );
      const orders = ordersResponse.orders || [];
      totalFound += orders.length;

      for (const order of orders) {
        try {
          const orderId = order.orderId;

          const { data: existing } = await supabase
            .from("marketplace_orders")
            .select("id, verzend_straat")
            .eq("platform", "ebay")
            .eq("extern_order_id", orderId)
            .maybeSingle();

          if (existing && existing.verzend_straat) continue;

          const buyer = order.buyer || {};
          const fulfillmentStart = order.fulfillmentStartInstructions?.[0] || {};
          const shipTo = fulfillmentStart.shippingStep?.shipTo || {};
          const contact = shipTo.contactAddress || {};
          const lineItems = order.lineItems || [];
          const firstItem = lineItems[0] || {};

          const klantNaam = shipTo.fullName || buyer.username || "";
          const totaal = parseFloat(order.pricingSummary?.total?.value || "0");

          let internalStatus = "nieuw";
          const fulfillmentStatus = order.orderFulfillmentStatus;
          if (fulfillmentStatus === "FULFILLED") {
            internalStatus = "verzonden";
          } else if (order.cancelStatus?.cancelState === "CANCELED") {
            internalStatus = "geannuleerd";
          }

          const orderItems = lineItems.map((li: any) => ({
            lineItemId: li.lineItemId,
            title: li.title,
            sku: li.sku,
            quantity: li.quantity || 1,
            unitPrice: parseFloat(li.lineItemCost?.value || "0"),
            totalPrice: parseFloat(li.total?.value || li.lineItemCost?.value || "0"),
            legacyItemId: li.legacyItemId,
          }));

          const totalQuantity = lineItems.reduce(
            (sum: number, li: any) => sum + (li.quantity || 1), 0
          );

          const addressLine1 = contact.addressLine1 || "";
          const streetMatch = addressLine1.match(/^(.+?)\s+(\d+\S*)$/);

          const record: Record<string, any> = {
            platform: "ebay",
            extern_order_id: orderId,
            status: internalStatus,
            klant_naam: klantNaam,
            klant_email: buyer.buyerRegistrationAddress?.email || "",

            verzend_straat: streetMatch ? streetMatch[1] : addressLine1,
            verzend_huisnummer: streetMatch ? streetMatch[2] : null,
            verzend_postcode: contact.postalCode || null,
            verzend_stad: contact.city || null,
            verzend_land: contact.countryCode || null,

            besteld_op: order.creationDate || null,
            totaal,
            aantal_items: lineItems.length,

            product_ean: firstItem.sku || null,
            product_titel: firstItem.title || null,
            product_hoeveelheid: totalQuantity,
            stukprijs: firstItem.lineItemCost?.value ? parseFloat(firstItem.lineItemCost.value) : null,

            order_items: orderItems,
            order_data: order,
          };

          if (existing) {
            await supabase.from("marketplace_orders").update(record).eq("id", existing.id);
          } else {
            await supabase.from("marketplace_orders").insert(record);
          }
          imported++;
        } catch (itemErr: unknown) {
          errors.push(`Order ${order.orderId}: ${getErrorMessage(itemErr)}`);
        }
      }

      hasMore = orders.length >= 50;
      offset += orders.length;
    } catch (pageErr: unknown) {
      errors.push(`Page offset ${offset}: ${getErrorMessage(pageErr)}`);
      hasMore = false;
    }
  }

  await logSync(supabase, "ebay", "order_import", null, {
    success: true,
    account_label: accountLabel,
    total_from_api: totalFound,
    new_imported: imported,
    errors: errors.length > 0 ? errors : undefined,
  });

  return jsonResponse({
    success: true,
    message: `${imported} nieuwe/bijgewerkte order(s) van ${totalFound} totaal`,
    imported,
    total: totalFound,
    errors: errors.length > 0 ? errors : undefined,
  });
}

// ═══════════════════════════════════════════
// eBay Controlled Write Operations (Fase 2)
// ═══════════════════════════════════════════

async function handleSyncEbayStock(
  supabase: any,
  body: RequestBody & { listing_id: string; stock: number }
): Promise<Response> {
  const { listing_id, stock } = body;
  if (!listing_id || stock === undefined) {
    return jsonResponse({ error: "listing_id and stock are required" }, 400);
  }

  const { data: listing } = await supabase
    .from("marketplace_listings")
    .select("*")
    .eq("id", listing_id)
    .single();

  if (!listing) return jsonResponse({ error: "Listing not found" }, 404);
  if (listing.platform !== "ebay") return jsonResponse({ error: "Not an eBay listing" }, 400);

  const sku = listing.ebay_sku || listing.platform_data?.sku;
  if (!sku) return jsonResponse({ success: false, message: "Geen SKU gevonden voor deze listing" });

  try {
    const token = await getEbayToken(supabase, listing.account_label);
    if (!token) return jsonResponse({ success: false, message: "eBay credentials niet geconfigureerd" });

    // First GET current inventory item to merge, not overwrite
    const existing = await ebayApiCall(token, "GET", `/sell/inventory/v1/inventory_item/${encodeURIComponent(sku)}`);

    const updatedItem = {
      ...existing,
      availability: {
        ...(existing.availability || {}),
        shipToLocationAvailability: { quantity: stock },
      },
    };

    await ebayApiCall(token, "PUT", `/sell/inventory/v1/inventory_item/${encodeURIComponent(sku)}`, updatedItem);

    await supabase.from("marketplace_listings").update({
      extern_quantity: stock,
      laatste_sync: new Date().toISOString(),
      sync_fout: null,
    }).eq("id", listing_id);

    await logSync(supabase, "ebay", "stock_sync", listing_id, {
      success: true,
      sku,
      stock,
      account_label: listing.account_label,
    });

    return jsonResponse({ success: true, message: `Voorraad bijgewerkt naar ${stock}`, stock });
  } catch (error: unknown) {
    const msg = getErrorMessage(error);
    await supabase.from("marketplace_listings").update({ sync_fout: msg }).eq("id", listing_id);
    await logSync(supabase, "ebay", "stock_sync", listing_id, { success: false, error: msg });
    return jsonResponse({ success: false, message: msg }, 500);
  }
}

async function handleSyncEbayPrice(
  supabase: any,
  body: RequestBody & { listing_id: string; price: number }
): Promise<Response> {
  const { listing_id, price } = body;
  if (!listing_id || price === undefined) {
    return jsonResponse({ error: "listing_id and price are required" }, 400);
  }

  const { data: listing } = await supabase
    .from("marketplace_listings")
    .select("*")
    .eq("id", listing_id)
    .single();

  if (!listing) return jsonResponse({ error: "Listing not found" }, 404);
  if (listing.platform !== "ebay") return jsonResponse({ error: "Not an eBay listing" }, 400);

  const offerId = listing.ebay_offer_id || listing.platform_data?.offer_id;
  if (!offerId) return jsonResponse({ success: false, message: "Geen offer ID gevonden voor deze listing" });

  try {
    const token = await getEbayToken(supabase, listing.account_label);
    if (!token) return jsonResponse({ success: false, message: "eBay credentials niet geconfigureerd" });

    // Get existing offer to merge
    const existingOffer = await ebayApiCall(token, "GET", `/sell/inventory/v1/offer/${offerId}`);

    const updatedOffer = {
      ...existingOffer,
      pricingSummary: {
        ...(existingOffer.pricingSummary || {}),
        price: { value: String(price), currency: "EUR" },
      },
    };

    await ebayApiCall(token, "PUT", `/sell/inventory/v1/offer/${offerId}`, updatedOffer);

    await supabase.from("marketplace_listings").update({
      prijs: price,
      laatste_sync: new Date().toISOString(),
      sync_fout: null,
    }).eq("id", listing_id);

    await logSync(supabase, "ebay", "price_sync", listing_id, {
      success: true,
      offerId,
      price,
      account_label: listing.account_label,
    });

    return jsonResponse({ success: true, message: `Prijs bijgewerkt naar € ${price}`, price });
  } catch (error: unknown) {
    const msg = getErrorMessage(error);
    await supabase.from("marketplace_listings").update({ sync_fout: msg }).eq("id", listing_id);
    await logSync(supabase, "ebay", "price_sync", listing_id, { success: false, error: msg });
    return jsonResponse({ success: false, message: msg }, 500);
  }
}

async function handlePublishToEbay(
  supabase: any,
  body: RequestBody & {
    product_id?: number;
    marketplace_id?: string;
    title?: string;
    description?: string;
    price?: number;
    quantity?: number;
    condition?: string;
    category_id?: string;
    account_label?: string;
  }
): Promise<Response> {
  const {
    product_id,
    marketplace_id = "EBAY_NL",
    title,
    description,
    price,
    quantity = 1,
    condition = "NEW",
    category_id,
    account_label,
  } = body;

  if (!product_id) return jsonResponse({ error: "product_id is required" }, 400);

  const { data: product } = await supabase
    .from("product_catalogus")
    .select("*")
    .eq("id", product_id)
    .single();

  if (!product) return jsonResponse({ error: "Product not found" }, 404);

  try {
    const token = await getEbayToken(supabase, account_label);
    if (!token) return jsonResponse({ success: false, message: "eBay credentials niet geconfigureerd" });

    const sku = product.artikelnummer || `VTZ-${product_id}`;
    const productTitle = title || product.naam;
    const productDescription = description || product.beschrijving || product.naam;
    const productPrice = price || product.prijs || 0;

    // Step 1: Create inventory item
    const inventoryItem: Record<string, any> = {
      availability: {
        shipToLocationAvailability: { quantity },
      },
      condition,
      product: {
        title: productTitle,
        description: productDescription,
        aspects: {} as Record<string, string[]>,
      },
    };

    if (product.ean_code) {
      inventoryItem.product.ean = [product.ean_code];
    }
    if (product.categorie) {
      inventoryItem.product.aspects["Type"] = [product.categorie];
    }

    await ebayApiCall(
      token, "PUT",
      `/sell/inventory/v1/inventory_item/${encodeURIComponent(sku)}`,
      inventoryItem,
      undefined,
      marketplace_id
    );

    // Step 2: Create offer
    const offerData: Record<string, any> = {
      sku,
      marketplaceId: marketplace_id,
      format: "FIXED_PRICE",
      listingDescription: productDescription,
      pricingSummary: {
        price: { value: String(productPrice), currency: "EUR" },
      },
      quantityLimitPerBuyer: 5,
      availableQuantity: quantity,
    };

    if (category_id) {
      offerData.categoryId = category_id;
    }

    const offerResult = await ebayApiCall(
      token, "POST",
      "/sell/inventory/v1/offer",
      offerData,
      undefined,
      marketplace_id
    );
    const offerId = offerResult.offerId;

    // Step 3: Publish the offer
    let listingId: string | null = null;
    if (offerId) {
      try {
        const publishResult = await ebayApiCall(
          token, "POST",
          `/sell/inventory/v1/offer/${offerId}/publish`,
          undefined,
          undefined,
          marketplace_id
        );
        listingId = publishResult.listingId;
      } catch (pubError: unknown) {
        console.error("eBay publish error:", pubError);
      }
    }

    // Save listing
    await supabase.from("marketplace_listings").insert({
      product_id,
      platform: "ebay",
      ebay_sku: sku,
      ebay_offer_id: offerId,
      ebay_item_id: listingId,
      ebay_marketplaces: [marketplace_id],
      extern_id: listingId || offerId,
      extern_url: listingId ? `https://www.ebay.com/itm/${listingId}` : null,
      extern_title: productTitle,
      extern_quantity: quantity,
      status: "actief",
      prijs: productPrice,
      taal: "nl",
      match_status: "confirmed",
      account_label,
      laatste_sync: new Date().toISOString(),
      platform_data: {
        sku,
        offer_id: offerId,
        listing_id: listingId,
        condition,
        marketplace_id,
        category_id: category_id || null,
      },
    });

    await logSync(supabase, "ebay", "publish_listing", null, {
      success: true,
      product_id,
      sku,
      offerId,
      listingId,
      marketplace_id,
      account_label,
    });

    return jsonResponse({
      success: true,
      message: listingId
        ? `eBay listing aangemaakt (ID: ${listingId})`
        : `eBay offer aangemaakt (ID: ${offerId}), publicatie wordt verwerkt`,
      extern_id: listingId || offerId,
      offer_id: offerId,
      listing_id: listingId,
    });
  } catch (error: unknown) {
    const msg = getErrorMessage(error);
    await logSync(supabase, "ebay", "publish_listing", null, {
      success: false,
      product_id,
      error: msg,
    });
    return jsonResponse({ success: false, message: msg }, 500);
  }
}

// ═══════════════════════════════════════════
// ── Debug ──

async function handleDebugBolCom(supabase: any): Promise<Response> {
  const token = await getBolComToken(supabase);
  if (!token) {
    return jsonResponse({ success: false, message: "Geen Bol.com token verkregen" });
  }

  const debug: any = { token_obtained: true, orders: {}, shipments: {} };

  // Test orders endpoint
  for (const status of ["OPEN", "SHIPPED", "ALL"]) {
    for (const method of ["FBR", "FBB"]) {
      try {
        const resp = await bolComApiCall(token, "GET", `/orders?status=${status}&fulfilment-method=${method}&page=1`);
        debug.orders[`${status}_${method}`] = { count: (resp.orders || []).length, sample: (resp.orders || [])[0]?.orderId || null };
      } catch (e: unknown) {
        debug.orders[`${status}_${method}`] = { error: getErrorMessage(e) };
      }
    }
  }

  // Test shipments endpoint
  for (const method of ["FBR", "FBB"]) {
    try {
      const resp = await bolComApiCall(token, "GET", `/shipments?page=1&fulfilment-method=${method}`);
      const shipments = resp.shipments || [];
      debug.shipments[method] = {
        count: shipments.length,
        first_shipment: shipments[0] || null,
      };

      // Fetch full order detail for the first shipment
      if (shipments[0]?.order?.orderId) {
        try {
          const orderDetail = await bolComApiCall(token, "GET", `/orders/${shipments[0].order.orderId}`);
          debug.full_order_detail = orderDetail;
        } catch (e: unknown) {
          debug.full_order_detail_error = getErrorMessage(e);
        }
      }
    } catch (e: unknown) {
      debug.shipments[method] = { error: getErrorMessage(e) };
    }
  }

  return jsonResponse({ success: true, debug });
}

// ── Add products to Marktplaats feed (batch) ──

async function handleAddToFeed(
  supabase: any,
  body: RequestBody
): Promise<Response> {
  const productIds = body.product_ids;
  if (!productIds || !Array.isArray(productIds) || productIds.length === 0) {
    return jsonResponse({ error: "product_ids array is required" }, 400);
  }

  let added = 0;
  let skipped = 0;
  const errors: string[] = [];

  for (const pid of productIds) {
    try {
      const { data: existing } = await supabase
        .from("marketplace_listings")
        .select("id")
        .eq("product_id", pid)
        .eq("platform", "marktplaats")
        .maybeSingle();

      if (existing) {
        skipped++;
        continue;
      }

      const { data: product } = await supabase
        .from("product_catalogus")
        .select("prijs")
        .eq("id", pid)
        .single();

      if (!product) {
        errors.push(`Product ${pid} niet gevonden`);
        continue;
      }

      await supabase.from("marketplace_listings").insert({
        product_id: pid,
        platform: "marktplaats",
        status: "actief",
        prijs: product.prijs,
        taal: "nl",
        voorraad_sync: true,
        platform_data: {
          cpc_eurocent: 2,
          total_budget_eurocent: 5000,
          daily_budget_eurocent: 1000,
          autobid: false,
        },
      });
      added++;
    } catch (e: unknown) {
      errors.push(`Product ${pid}: ${getErrorMessage(e)}`);
    }
  }

  await logSync(supabase, "marktplaats", "batch_add_to_feed", null, {
    success: true,
    requested: productIds.length,
    added,
    skipped,
    errors: errors.length > 0 ? errors : undefined,
  });

  return jsonResponse({
    success: true,
    message: `${added} producten toegevoegd, ${skipped} overgeslagen`,
    added,
    skipped,
    errors: errors.length > 0 ? errors : undefined,
  });
}

// ═══════════════════════════════════════════
// eBay Listing Import (READ-ONLY)
// ═══════════════════════════════════════════

async function handleGetEbayAccounts(supabase: any): Promise<Response> {
  const { data: creds } = await supabase
    .from("marketplace_credentials")
    .select("account_label")
    .eq("platform", "ebay")
    .eq("actief", true);

  const labels = new Set<string | null>();
  if (creds) {
    for (const c of creds) {
      labels.add(c.account_label || null);
    }
  }

  const accounts = [...labels].map((label) => ({
    account_label: label,
    display_name: label || "Standaard eBay-account",
  }));

  return jsonResponse({ success: true, accounts });
}

async function handleImportEbayListings(
  supabase: any,
  body: RequestBody
): Promise<Response> {
  const accountLabel = body.account_label || null;
  const token = await getEbayToken(supabase, accountLabel);
  if (!token) {
    return jsonResponse({
      success: false,
      message: accountLabel
        ? `eBay credentials niet geconfigureerd voor account "${accountLabel}"`
        : "eBay credentials niet geconfigureerd",
    });
  }

  let imported = 0;
  let updated = 0;
  let skipped = 0;
  let offset = 0;
  const limit = 200;
  let totalInventoryItems = 0;
  const errors: string[] = [];

  // Paginate through all inventory items
  let hasMore = true;
  while (hasMore) {
    try {
      const invResp = await ebayApiCall(
        token, "GET",
        `/sell/inventory/v1/inventory_item?limit=${limit}&offset=${offset}`
      );

      const items = invResp.inventoryItems || [];
      totalInventoryItems += items.length;

      for (const item of items) {
        try {
          const sku = item.sku;
          const product = item.product || {};
          const availability = item.availability?.shipToLocationAvailability;

          // Check if listing already exists
          const { data: existing } = await supabase
            .from("marketplace_listings")
            .select("id")
            .eq("platform", "ebay")
            .eq("ebay_sku", sku)
            .is("account_label", accountLabel)
            .maybeSingle();

          // Fetch offers for this SKU to get price and marketplace info
          let offers: any[] = [];
          try {
            const offerResp = await ebayApiCall(
              token, "GET",
              `/sell/inventory/v1/offer?sku=${encodeURIComponent(sku)}`
            );
            offers = offerResp.offers || [];
          } catch { /* no offers */ }

          const primaryOffer = offers[0];
          const price = primaryOffer?.pricingSummary?.price?.value
            ? parseFloat(primaryOffer.pricingSummary.price.value)
            : null;
          const offerId = primaryOffer?.offerId || null;
          const listingId = primaryOffer?.listing?.listingId || null;
          const marketplaces = offers.map((o: any) => o.marketplaceId).filter(Boolean);
          const listingStatus = primaryOffer?.status === "ACTIVE" ? "actief" : "concept";
          const imageUrl = product.imageUrls?.[0] || null;

          const record: Record<string, any> = {
            platform: "ebay",
            ebay_sku: sku,
            ebay_item_id: listingId,
            ebay_offer_id: offerId,
            ebay_marketplaces: marketplaces,
            extern_id: listingId || offerId,
            extern_url: listingId ? `https://www.ebay.com/itm/${listingId}` : null,
            extern_title: product.title || null,
            extern_description: product.description || null,
            extern_image_url: imageUrl,
            extern_quantity: availability?.quantity ?? null,
            status: listingStatus,
            prijs: price,
            taal: "nl",
            account_label: accountLabel,
            laatste_sync: new Date().toISOString(),
            sync_fout: null,
            match_status: "unmatched",
            platform_data: {
              sku,
              offer_id: offerId,
              listing_id: listingId,
              condition: item.condition,
              ean: product.ean?.[0] || null,
              aspects: product.aspects || {},
              marketplaces,
              all_offers: offers.map((o: any) => ({
                offerId: o.offerId,
                status: o.status,
                marketplaceId: o.marketplaceId,
                price: o.pricingSummary?.price,
                quantity: o.availableQuantity,
                listingId: o.listing?.listingId,
              })),
            },
          };

          if (existing) {
            // Don't overwrite product_id or match_status if already set
            delete record.match_status;
            await supabase.from("marketplace_listings").update(record).eq("id", existing.id);
            updated++;
          } else {
            record.product_id = null;
            await supabase.from("marketplace_listings").insert(record);
            imported++;
          }
        } catch (itemErr: unknown) {
          const msg = `SKU ${item.sku}: ${getErrorMessage(itemErr)}`;
          console.error(msg);
          errors.push(msg);
          skipped++;
        }
      }

      hasMore = items.length >= limit;
      offset += items.length;
    } catch (pageErr: unknown) {
      const msg = `Page offset ${offset}: ${getErrorMessage(pageErr)}`;
      console.error(msg);
      errors.push(msg);
      hasMore = false;
    }
  }

  // If Inventory API returned 0, fallback to sell.fulfillment/browse to find active listings
  if (totalInventoryItems === 0) {
    try {
      // Use the sell/inventory/v1/bulk_migrate_listing endpoint is not available,
      // fallback: search own listings via Buy Browse API (marketplace search with seller filter)
      // Or use the getOrders to find recent item IDs
      // Best approach: use the Sell Feed API or Trading API via REST

      // Try the RESTful Trading API (GetMyeBaySelling equivalent)
      // This uses the sell.inventory scope but via the trading endpoint
      let pageNumber = 1;
      let totalPages = 1;

      while (pageNumber <= totalPages) {
        const xmlBody = `<?xml version="1.0" encoding="utf-8"?>
<GetMyeBaySellingRequest xmlns="urn:ebay:apis:eBLBaseComponents">
  <RequesterCredentials>
    <eBayAuthToken>${token}</eBayAuthToken>
  </RequesterCredentials>
  <ActiveList>
    <Sort>TimeLeft</Sort>
    <Pagination>
      <EntriesPerPage>200</EntriesPerPage>
      <PageNumber>${pageNumber}</PageNumber>
    </Pagination>
  </ActiveList>
  <ErrorLanguage>en_US</ErrorLanguage>
  <WarningLevel>Low</WarningLevel>
</GetMyeBaySellingRequest>`;

        const tradingResp = await fetch("https://api.ebay.com/ws/api.dll", {
          method: "POST",
          headers: {
            "X-EBAY-API-SITEID": "146",
            "X-EBAY-API-COMPATIBILITY-LEVEL": "1349",
            "X-EBAY-API-CALL-NAME": "GetMyeBaySelling",
            "Content-Type": "text/xml",
          },
          body: xmlBody,
        });

        const xmlText = await tradingResp.text();

        // Parse items from XML
        const itemMatches = xmlText.matchAll(/<Item>([\s\S]*?)<\/Item>/g);
        for (const match of itemMatches) {
          try {
            const itemXml = match[1];
            const itemId = extractXml(itemXml, "ItemID");
            const title = extractXml(itemXml, "Title");
            const currentPrice = extractXml(itemXml, "CurrentPrice");
            const quantity = extractXml(itemXml, "Quantity");
            const quantitySold = extractXml(itemXml, "QuantitySold");
            const listingType = extractXml(itemXml, "ListingType");
            const viewItemURL = extractXml(itemXml, "ViewItemURL");
            const pictureURL = extractXml(itemXml, "PictureURL") || extractXml(itemXml, "GalleryURL");
            const sku = extractXml(itemXml, "SKU");
            const remainingQty = quantity && quantitySold
              ? parseInt(quantity) - parseInt(quantitySold)
              : (quantity ? parseInt(quantity) : null);
            const price = currentPrice ? parseFloat(currentPrice) : null;

            if (!itemId) continue;

            const { data: existing } = await supabase
              .from("marketplace_listings")
              .select("id")
              .eq("platform", "ebay")
              .eq("ebay_item_id", itemId)
              .maybeSingle();

            const record: Record<string, any> = {
              platform: "ebay",
              ebay_item_id: itemId,
              ebay_sku: sku || null,
              extern_id: itemId,
              extern_url: viewItemURL || `https://www.ebay.com/itm/${itemId}`,
              extern_title: title,
              extern_image_url: pictureURL || null,
              extern_quantity: remainingQty,
              status: "actief",
              prijs: price,
              taal: "nl",
              account_label: accountLabel,
              laatste_sync: new Date().toISOString(),
              sync_fout: null,
              platform_data: {
                listing_id: itemId,
                sku: sku || null,
                listing_type: listingType,
                source: "trading_api",
              },
            };

            if (existing) {
              await supabase.from("marketplace_listings").update(record).eq("id", existing.id);
              updated++;
            } else {
              record.product_id = null;
              record.match_status = "unmatched";
              await supabase.from("marketplace_listings").insert(record);
              imported++;
            }
            totalInventoryItems++;
          } catch (itemErr: unknown) {
            const msg = `Trading API item: ${getErrorMessage(itemErr)}`;
            console.error(msg);
            errors.push(msg);
            skipped++;
          }
        }

        // Check pagination
        const totalPagesMatch = xmlText.match(/<TotalNumberOfPages>(\d+)<\/TotalNumberOfPages>/);
        if (totalPagesMatch) {
          totalPages = parseInt(totalPagesMatch[1]);
        }
        pageNumber++;
      }
    } catch (tradingErr: unknown) {
      const msg = `Trading API fallback: ${getErrorMessage(tradingErr)}`;
      console.error(msg);
      errors.push(msg);
    }
  }

  await logSync(supabase, "ebay", "import_listings", null, {
    success: true,
    account_label: accountLabel,
    total_inventory_items: totalInventoryItems,
    new_imported: imported,
    updated,
    skipped,
    errors: errors.length > 0 ? errors : undefined,
  });

  return jsonResponse({
    success: true,
    message: `${imported} nieuwe listing(s) geïmporteerd, ${updated} bijgewerkt van ${totalInventoryItems} totaal`,
    imported,
    updated,
    skipped,
    total: totalInventoryItems,
    errors: errors.length > 0 ? errors : undefined,
  });
}

function extractXml(xml: string, tag: string): string | null {
  const match = xml.match(new RegExp(`<${tag}[^>]*>([^<]*)</${tag}>`));
  return match ? match[1] : null;
}

// Utilities
// ═══════════════════════════════════════════

async function logSync(
  supabase: any,
  platform: string,
  actie: string,
  listingId: string | null,
  details: any
): Promise<void> {
  try {
    const data: any = {
      platform,
      actie,
      status: details.success === false ? "fout" : "succes",
      details,
    };
    if (listingId) data.listing_id = listingId;
    await supabase.from("marketplace_sync_log").insert(data);
  } catch (e: unknown) {
    console.error("Failed to log sync:", e);
  }
}

function jsonResponse(data: any, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
