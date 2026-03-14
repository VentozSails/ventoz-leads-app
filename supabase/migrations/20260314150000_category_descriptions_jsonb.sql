-- Add JSONB column for all-language descriptions (key=locale, value=text)
ALTER TABLE category_descriptions
  ADD COLUMN IF NOT EXISTS beschrijvingen JSONB DEFAULT '{}'::jsonb;

-- Migrate existing per-column translations into the JSONB column
UPDATE category_descriptions
SET beschrijvingen = jsonb_build_object(
  'nl', COALESCE(beschrijving_nl, ''),
  'en', COALESCE(beschrijving_en, ''),
  'de', COALESCE(beschrijving_de, ''),
  'fr', COALESCE(beschrijving_fr, '')
)
WHERE beschrijvingen IS NULL OR beschrijvingen = '{}'::jsonb;

-- Allow anonymous (webshop) read access
ALTER TABLE category_descriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS category_descriptions_anon_select ON category_descriptions;
CREATE POLICY category_descriptions_anon_select ON category_descriptions
    FOR SELECT TO anon
    USING (true);

DROP POLICY IF EXISTS category_descriptions_auth_all ON category_descriptions;
CREATE POLICY category_descriptions_auth_all ON category_descriptions
    FOR ALL TO authenticated
    USING (true)
    WITH CHECK (true);
