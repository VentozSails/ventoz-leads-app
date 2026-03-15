-- Add translated_specs JSONB column to product_catalogus.
-- Structure: {"de": {"materiaal": "...", "inclusief": "..."}, "en": {...}, ...}
-- Only long-form spec values (materiaal, inclusief) are translated.
-- Numeric specs (luff, foot, sail_area) don't need translation.
ALTER TABLE product_catalogus
  ADD COLUMN IF NOT EXISTS translated_specs jsonb DEFAULT '{}'::jsonb;
