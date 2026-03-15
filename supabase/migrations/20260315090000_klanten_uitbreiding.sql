-- Extend klanten table with fields for Snelstart import, classification, and statistics

ALTER TABLE klanten
  ADD COLUMN IF NOT EXISTS snelstart_klantcode  TEXT,
  ADD COLUMN IF NOT EXISTS klantcode_aliases     TEXT[]    DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS is_zakelijk           BOOLEAN  DEFAULT false,
  ADD COLUMN IF NOT EXISTS contactpersoon        TEXT,
  ADD COLUMN IF NOT EXISTS mobiel                TEXT,
  ADD COLUMN IF NOT EXISTS kvk_nummer            TEXT,
  ADD COLUMN IF NOT EXISTS totale_omzet          NUMERIC(12,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS eerste_factuur_datum   DATE,
  ADD COLUMN IF NOT EXISTS laatste_factuur_datum  DATE,
  ADD COLUMN IF NOT EXISTS aantal_facturen       INTEGER  DEFAULT 0,
  ADD COLUMN IF NOT EXISTS bron_prospect_id      INTEGER,
  ADD COLUMN IF NOT EXISTS bron_prospect_land    TEXT,
  ADD COLUMN IF NOT EXISTS naam                  TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_klanten_snelstart_code
  ON klanten(snelstart_klantcode) WHERE snelstart_klantcode IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_klanten_is_zakelijk ON klanten(is_zakelijk);
CREATE INDEX IF NOT EXISTS idx_klanten_land_code   ON klanten(land_code);
CREATE INDEX IF NOT EXISTS idx_klanten_naam        ON klanten(naam);
