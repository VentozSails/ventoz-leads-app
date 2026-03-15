-- Fix eBay listings that have taal='nl' but their ebay_marketplaces indicates
-- a different marketplace. Derive taal from the first marketplace entry.

UPDATE marketplace_listings
SET taal = 'uk', updated_at = now()
WHERE platform = 'ebay'
  AND ebay_marketplaces IS NOT NULL
  AND (ebay_marketplaces::jsonb @> '"EBAY_GB"'::jsonb)
  AND taal != 'uk';

UPDATE marketplace_listings
SET taal = 'de', updated_at = now()
WHERE platform = 'ebay'
  AND ebay_marketplaces IS NOT NULL
  AND (ebay_marketplaces::jsonb @> '"EBAY_DE"'::jsonb OR ebay_marketplaces::jsonb @> '"EBAY_AT"'::jsonb)
  AND taal NOT IN ('de', 'uk');

UPDATE marketplace_listings
SET taal = 'fr', updated_at = now()
WHERE platform = 'ebay'
  AND ebay_marketplaces IS NOT NULL
  AND (ebay_marketplaces::jsonb @> '"EBAY_FR"'::jsonb)
  AND taal NOT IN ('fr');

UPDATE marketplace_listings
SET taal = 'it', updated_at = now()
WHERE platform = 'ebay'
  AND ebay_marketplaces IS NOT NULL
  AND (ebay_marketplaces::jsonb @> '"EBAY_IT"'::jsonb)
  AND taal NOT IN ('it');

UPDATE marketplace_listings
SET taal = 'es', updated_at = now()
WHERE platform = 'ebay'
  AND ebay_marketplaces IS NOT NULL
  AND (ebay_marketplaces::jsonb @> '"EBAY_ES"'::jsonb)
  AND taal NOT IN ('es');

UPDATE marketplace_listings
SET taal = 'be', updated_at = now()
WHERE platform = 'ebay'
  AND ebay_marketplaces IS NOT NULL
  AND (ebay_marketplaces::jsonb @> '"EBAY_BE"'::jsonb)
  AND taal NOT IN ('be');

UPDATE marketplace_listings
SET taal = 'ie', updated_at = now()
WHERE platform = 'ebay'
  AND ebay_marketplaces IS NOT NULL
  AND (ebay_marketplaces::jsonb @> '"EBAY_IE"'::jsonb)
  AND taal NOT IN ('ie');

UPDATE marketplace_listings
SET taal = 'pl', updated_at = now()
WHERE platform = 'ebay'
  AND ebay_marketplaces IS NOT NULL
  AND (ebay_marketplaces::jsonb @> '"EBAY_PL"'::jsonb)
  AND taal NOT IN ('pl');
