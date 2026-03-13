-- Add language column to marketplace_listings
-- Each listing can target a specific language for the advertisement text

ALTER TABLE marketplace_listings
  ADD COLUMN IF NOT EXISTS taal text NOT NULL DEFAULT 'nl';

-- Update unique constraint: same product can be listed on same platform in different languages
ALTER TABLE marketplace_listings
  DROP CONSTRAINT IF EXISTS marketplace_listings_product_id_platform_key;

ALTER TABLE marketplace_listings
  ADD CONSTRAINT marketplace_listings_product_platform_taal_key
  UNIQUE (product_id, platform, taal);
