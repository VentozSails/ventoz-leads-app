-- Fix eBay listings that were imported with taal='en' instead of 'uk'.
-- The SalesChannel model uses country codes (uk, de, etc.), not language codes (en, de, etc.).

UPDATE marketplace_listings
SET taal = 'uk',
    updated_at = now()
WHERE platform = 'ebay'
  AND taal = 'en';
