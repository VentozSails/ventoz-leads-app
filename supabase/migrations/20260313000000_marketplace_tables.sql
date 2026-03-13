-- Marketplace Integration Tables
-- Supports: Bol.com, eBay, Amazon, Marktplaats.nl

-- Platform credentials (API keys, OAuth tokens)
CREATE TABLE IF NOT EXISTS marketplace_credentials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  platform text NOT NULL CHECK (platform IN ('bol_com', 'ebay', 'amazon', 'marktplaats')),
  credential_type text NOT NULL,
  encrypted_value text NOT NULL,
  actief boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (platform, credential_type)
);

-- Product <-> marketplace listing mapping
CREATE TABLE IF NOT EXISTS marketplace_listings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id integer NOT NULL REFERENCES product_catalogus(id) ON DELETE CASCADE,
  platform text NOT NULL CHECK (platform IN ('bol_com', 'ebay', 'amazon', 'marktplaats')),
  extern_id text,
  extern_url text,
  status text NOT NULL DEFAULT 'concept' CHECK (status IN ('concept', 'actief', 'gepauzeerd', 'verwijderd', 'fout')),
  prijs numeric(10,2),
  taal text NOT NULL DEFAULT 'nl',
  voorraad_sync boolean NOT NULL DEFAULT true,
  laatste_sync timestamptz,
  sync_fout text,
  platform_data jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (product_id, platform, taal)
);

CREATE INDEX idx_marketplace_listings_platform ON marketplace_listings(platform);
CREATE INDEX idx_marketplace_listings_product ON marketplace_listings(product_id);
CREATE INDEX idx_marketplace_listings_status ON marketplace_listings(status);

-- Marketplace orders (imported from external platforms)
CREATE TABLE IF NOT EXISTS marketplace_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  platform text NOT NULL CHECK (platform IN ('bol_com', 'ebay', 'amazon', 'marktplaats')),
  extern_order_id text NOT NULL,
  order_id uuid REFERENCES orders(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'nieuw' CHECK (status IN ('nieuw', 'verwerkt', 'verzonden', 'geannuleerd')),
  klant_naam text,
  klant_email text,
  totaal numeric(10,2),
  order_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (platform, extern_order_id)
);

CREATE INDEX idx_marketplace_orders_platform ON marketplace_orders(platform);
CREATE INDEX idx_marketplace_orders_status ON marketplace_orders(status);

-- Sync audit log
CREATE TABLE IF NOT EXISTS marketplace_sync_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  platform text NOT NULL,
  actie text NOT NULL,
  status text NOT NULL DEFAULT 'succes' CHECK (status IN ('succes', 'fout')),
  listing_id uuid REFERENCES marketplace_listings(id) ON DELETE SET NULL,
  details jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_marketplace_sync_log_platform ON marketplace_sync_log(platform);
CREATE INDEX idx_marketplace_sync_log_created ON marketplace_sync_log(created_at DESC);

-- Auto-update updated_at triggers
CREATE OR REPLACE FUNCTION update_marketplace_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_marketplace_credentials_updated
  BEFORE UPDATE ON marketplace_credentials
  FOR EACH ROW EXECUTE FUNCTION update_marketplace_updated_at();

CREATE TRIGGER trg_marketplace_listings_updated
  BEFORE UPDATE ON marketplace_listings
  FOR EACH ROW EXECUTE FUNCTION update_marketplace_updated_at();

CREATE TRIGGER trg_marketplace_orders_updated
  BEFORE UPDATE ON marketplace_orders
  FOR EACH ROW EXECUTE FUNCTION update_marketplace_updated_at();

-- RLS policies
ALTER TABLE marketplace_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_sync_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can manage marketplace_credentials"
  ON marketplace_credentials FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can manage marketplace_listings"
  ON marketplace_listings FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can manage marketplace_orders"
  ON marketplace_orders FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can read marketplace_sync_log"
  ON marketplace_sync_log FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert marketplace_sync_log"
  ON marketplace_sync_log FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');
