-- Add columns for Chinese (zh), Arabic (ar), Turkish (tr) translations
ALTER TABLE product_catalogus
  ADD COLUMN IF NOT EXISTS naam_zh TEXT,
  ADD COLUMN IF NOT EXISTS naam_ar TEXT,
  ADD COLUMN IF NOT EXISTS naam_tr TEXT,
  ADD COLUMN IF NOT EXISTS beschrijving_zh TEXT,
  ADD COLUMN IF NOT EXISTS beschrijving_ar TEXT,
  ADD COLUMN IF NOT EXISTS beschrijving_tr TEXT;
