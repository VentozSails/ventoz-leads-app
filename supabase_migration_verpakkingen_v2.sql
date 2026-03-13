-- =====================================================================
-- Ventoz Leads App — Migratie: Verpakkingen uitbreiding + productkoppeling
-- =====================================================================
-- Voer dit script uit in de Supabase SQL Editor.
-- Veilig om meerdere keren uit te voeren (IF NOT EXISTS / DO $$ blocks).
-- =====================================================================

-- ── 0. Verpakkingen tabel aanmaken als deze nog niet bestaat ──

CREATE TABLE IF NOT EXISTS verpakkingen (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  naam TEXT NOT NULL,
  gewicht INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE verpakkingen ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY verpakkingen_read ON verpakkingen
    FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY verpakkingen_write ON verpakkingen
    FOR ALL TO authenticated
    USING (is_ventoz_admin()) WITH CHECK (is_ventoz_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Standaard verpakkingen invoegen als de tabel leeg is
INSERT INTO verpakkingen (naam, gewicht, sort_order)
SELECT * FROM (VALUES
  ('Kleine doos', 500, 1),
  ('Standaard doos', 800, 2),
  ('Grote doos', 1200, 3),
  ('Extra grote doos', 2000, 4)
) AS v(naam, gewicht, sort_order)
WHERE NOT EXISTS (SELECT 1 FROM verpakkingen LIMIT 1);


-- ── 1. Verpakkingen tabel uitbreiden met afmetingen en max gewicht ──

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'verpakkingen' AND column_name = 'lengte_cm'
  ) THEN
    ALTER TABLE verpakkingen ADD COLUMN lengte_cm INTEGER NOT NULL DEFAULT 0;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'verpakkingen' AND column_name = 'breedte_cm'
  ) THEN
    ALTER TABLE verpakkingen ADD COLUMN breedte_cm INTEGER NOT NULL DEFAULT 0;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'verpakkingen' AND column_name = 'hoogte_cm'
  ) THEN
    ALTER TABLE verpakkingen ADD COLUMN hoogte_cm INTEGER NOT NULL DEFAULT 0;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'verpakkingen' AND column_name = 'max_gewicht_gram'
  ) THEN
    ALTER TABLE verpakkingen ADD COLUMN max_gewicht_gram INTEGER NOT NULL DEFAULT 0;
  END IF;
END $$;


-- ── 2. Koppeltabel: welke producten passen in welke doos ──

CREATE TABLE IF NOT EXISTS verpakking_producten (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  verpakking_id UUID NOT NULL REFERENCES verpakkingen(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL,
  product_naam TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_verpakking_producten_box
  ON verpakking_producten(verpakking_id);

ALTER TABLE verpakking_producten ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY verpakking_producten_select
    ON verpakking_producten FOR SELECT TO authenticated
    USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY verpakking_producten_insert
    ON verpakking_producten FOR INSERT TO authenticated
    WITH CHECK (is_ventoz_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY verpakking_producten_update
    ON verpakking_producten FOR UPDATE TO authenticated
    USING (is_ventoz_admin()) WITH CHECK (is_ventoz_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY verpakking_producten_delete
    ON verpakking_producten FOR DELETE TO authenticated
    USING (is_ventoz_admin());
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
