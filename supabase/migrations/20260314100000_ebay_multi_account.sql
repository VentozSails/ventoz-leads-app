-- Support multiple eBay accounts and enhanced listing metadata for import/matching

-- Allow multiple credential sets per platform (e.g. multiple eBay accounts)
ALTER TABLE marketplace_credentials
  DROP CONSTRAINT IF EXISTS marketplace_credentials_platform_credential_type_key;

ALTER TABLE marketplace_credentials
  ADD COLUMN IF NOT EXISTS account_label text;

ALTER TABLE marketplace_credentials
  ADD CONSTRAINT marketplace_credentials_platform_type_account_key
  UNIQUE (platform, credential_type, account_label);

-- Extra columns on marketplace_listings for eBay import & matching
ALTER TABLE marketplace_listings
  ADD COLUMN IF NOT EXISTS ebay_item_id text,
  ADD COLUMN IF NOT EXISTS ebay_offer_id text,
  ADD COLUMN IF NOT EXISTS ebay_sku text,
  ADD COLUMN IF NOT EXISTS ebay_marketplaces jsonb DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS match_status text DEFAULT 'unmatched'
    CHECK (match_status IN ('unmatched', 'suggested', 'confirmed', 'manual')),
  ADD COLUMN IF NOT EXISTS extern_title text,
  ADD COLUMN IF NOT EXISTS extern_description text,
  ADD COLUMN IF NOT EXISTS extern_image_url text,
  ADD COLUMN IF NOT EXISTS extern_quantity integer,
  ADD COLUMN IF NOT EXISTS account_label text;

CREATE INDEX IF NOT EXISTS idx_marketplace_listings_ebay_item
  ON marketplace_listings(ebay_item_id) WHERE ebay_item_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_marketplace_listings_ebay_sku
  ON marketplace_listings(ebay_sku) WHERE ebay_sku IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_marketplace_listings_match_status
  ON marketplace_listings(match_status);
CREATE INDEX IF NOT EXISTS idx_marketplace_listings_account
  ON marketplace_listings(account_label) WHERE account_label IS NOT NULL;

-- Allow marketplace_listings.product_id to be nullable for imported-but-unmatched listings
ALTER TABLE marketplace_listings
  ALTER COLUMN product_id DROP NOT NULL;

-- Drop the unique constraint that requires product_id (will fail for NULL product_id imports)
ALTER TABLE marketplace_listings
  DROP CONSTRAINT IF EXISTS marketplace_listings_product_platform_taal_key;
