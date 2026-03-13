-- Enrich marketplace_orders with full customer, shipping, billing and item details

ALTER TABLE marketplace_orders
  ADD COLUMN IF NOT EXISTS klant_telefoon text,
  ADD COLUMN IF NOT EXISTS klant_aanhef text,

  -- Shipping address
  ADD COLUMN IF NOT EXISTS verzend_straat text,
  ADD COLUMN IF NOT EXISTS verzend_huisnummer text,
  ADD COLUMN IF NOT EXISTS verzend_huisnummer_ext text,
  ADD COLUMN IF NOT EXISTS verzend_postcode text,
  ADD COLUMN IF NOT EXISTS verzend_stad text,
  ADD COLUMN IF NOT EXISTS verzend_land text DEFAULT 'NL',

  -- Billing address (can differ from shipping)
  ADD COLUMN IF NOT EXISTS factuur_naam text,
  ADD COLUMN IF NOT EXISTS factuur_straat text,
  ADD COLUMN IF NOT EXISTS factuur_huisnummer text,
  ADD COLUMN IF NOT EXISTS factuur_huisnummer_ext text,
  ADD COLUMN IF NOT EXISTS factuur_postcode text,
  ADD COLUMN IF NOT EXISTS factuur_stad text,
  ADD COLUMN IF NOT EXISTS factuur_land text DEFAULT 'NL',
  ADD COLUMN IF NOT EXISTS factuur_email text,

  -- Order dates
  ADD COLUMN IF NOT EXISTS besteld_op timestamptz,
  ADD COLUMN IF NOT EXISTS uiterste_leverdatum date,

  -- Fulfillment / transport
  ADD COLUMN IF NOT EXISTS fulfillment_methode text,
  ADD COLUMN IF NOT EXISTS transport_id text,
  ADD COLUMN IF NOT EXISTS track_trace text,

  -- Financial
  ADD COLUMN IF NOT EXISTS commissie numeric(10,2),
  ADD COLUMN IF NOT EXISTS aantal_items integer DEFAULT 1,

  -- Product details (denormalized for quick display)
  ADD COLUMN IF NOT EXISTS product_ean text,
  ADD COLUMN IF NOT EXISTS product_titel text,
  ADD COLUMN IF NOT EXISTS product_hoeveelheid integer DEFAULT 1,
  ADD COLUMN IF NOT EXISTS stukprijs numeric(10,2),

  -- Multi-item support: full items array as JSONB
  ADD COLUMN IF NOT EXISTS order_items jsonb DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS idx_marketplace_orders_besteld_op
  ON marketplace_orders(besteld_op DESC);
CREATE INDEX IF NOT EXISTS idx_marketplace_orders_klant_naam
  ON marketplace_orders(klant_naam);
CREATE INDEX IF NOT EXISTS idx_marketplace_orders_product_ean
  ON marketplace_orders(product_ean);
