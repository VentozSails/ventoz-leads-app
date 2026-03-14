-- Add 'admark' as a valid platform to all marketplace tables.
-- DROP + recreate CHECK constraints (Postgres does not support ALTER CHECK).

ALTER TABLE marketplace_credentials
  DROP CONSTRAINT IF EXISTS marketplace_credentials_platform_check;
ALTER TABLE marketplace_credentials
  ADD CONSTRAINT marketplace_credentials_platform_check
  CHECK (platform IN ('bol_com', 'ebay', 'amazon', 'marktplaats', 'admark'));

ALTER TABLE marketplace_listings
  DROP CONSTRAINT IF EXISTS marketplace_listings_platform_check;
ALTER TABLE marketplace_listings
  ADD CONSTRAINT marketplace_listings_platform_check
  CHECK (platform IN ('bol_com', 'ebay', 'amazon', 'marktplaats', 'admark'));

ALTER TABLE marketplace_orders
  DROP CONSTRAINT IF EXISTS marketplace_orders_platform_check;
ALTER TABLE marketplace_orders
  ADD CONSTRAINT marketplace_orders_platform_check
  CHECK (platform IN ('bol_com', 'ebay', 'amazon', 'marktplaats', 'admark'));
