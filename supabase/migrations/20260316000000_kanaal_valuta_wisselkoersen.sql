-- Kanaalvaluta: valuta per verkoopkanaal (EUR, GBP, USD)
CREATE TABLE IF NOT EXISTS kanaal_valuta (
  kanaal_code TEXT PRIMARY KEY,
  valuta TEXT NOT NULL DEFAULT 'EUR',
  wisselkoers_eur NUMERIC,
  koers_gewijzigd_at TIMESTAMPTZ
);

-- Defaults voor bestaande kanalen
INSERT INTO kanaal_valuta (kanaal_code, valuta, wisselkoers_eur) VALUES
  ('eigen_site', 'EUR', 1),
  ('ebay_nl', 'EUR', 1),
  ('ebay_de', 'EUR', 1),
  ('ebay_be', 'EUR', 1),
  ('ebay_it', 'EUR', 1),
  ('ebay_fr', 'EUR', 1),
  ('ebay_es', 'EUR', 1),
  ('ebay_ie', 'EUR', 1),
  ('ebay_uk', 'GBP', 0.85),
  ('ebay_pl', 'PLN', 4.30),
  ('bol_nl', 'EUR', 1),
  ('bol_be', 'EUR', 1),
  ('amazon_de', 'EUR', 1),
  ('amazon_fr', 'EUR', 1),
  ('amazon_it', 'EUR', 1),
  ('amazon_nl', 'EUR', 1),
  ('amazon_se', 'EUR', 1),
  ('amazon_uk', 'GBP', 0.85),
  ('admark_nl', 'EUR', 1)
ON CONFLICT (kanaal_code) DO NOTHING;

-- Wisselkoersen historie (voor batch-omrekening en facturen)
CREATE TABLE IF NOT EXISTS wisselkoersen (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  van_valuta TEXT NOT NULL DEFAULT 'EUR',
  naar_valuta TEXT NOT NULL,
  koers NUMERIC NOT NULL,
  datum DATE NOT NULL DEFAULT CURRENT_DATE,
  bron TEXT DEFAULT 'handmatig',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wisselkoersen_datum ON wisselkoersen(datum DESC);
CREATE INDEX IF NOT EXISTS idx_wisselkoersen_naar ON wisselkoersen(naar_valuta);

-- Orders uitbreiden voor multi-valuta
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_valuta TEXT DEFAULT 'EUR';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_bedrag NUMERIC;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_bedrag_eur NUMERIC;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS wisselkoers NUMERIC;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS wisselkoers_datum TIMESTAMPTZ;

-- Order_regels uitbreiden (indien tabel bestaat)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_regels') THEN
    ALTER TABLE order_regels ADD COLUMN IF NOT EXISTS prijs_valuta NUMERIC;
    ALTER TABLE order_regels ADD COLUMN IF NOT EXISTS prijs_eur NUMERIC;
    ALTER TABLE order_regels ADD COLUMN IF NOT EXISTS totaal_valuta NUMERIC;
    ALTER TABLE order_regels ADD COLUMN IF NOT EXISTS totaal_eur NUMERIC;
  END IF;
END $$;
