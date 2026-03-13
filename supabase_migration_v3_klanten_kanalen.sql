-- ============================================================
-- Migratie V3: Klanten, Externe Nummers, Verkoopkanalen,
--              Inventory Mutations uitbreiding, Orders.klant_id
-- ============================================================

-- 1. KLANTEN TABEL
CREATE TABLE IF NOT EXISTS klanten (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    klantnummer     TEXT UNIQUE NOT NULL,
    auth_user_id    TEXT,
    email           TEXT NOT NULL,
    voornaam        TEXT,
    achternaam      TEXT,
    bedrijfsnaam    TEXT,
    adres           TEXT,
    postcode        TEXT,
    woonplaats      TEXT,
    land_code       TEXT NOT NULL DEFAULT 'NL',
    telefoon        TEXT,
    btw_nummer      TEXT,
    opmerkingen     TEXT,
    snelstart_id    TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_klanten_email ON klanten(email);
CREATE INDEX IF NOT EXISTS idx_klanten_klantnummer ON klanten(klantnummer);
CREATE INDEX IF NOT EXISTS idx_klanten_auth_user ON klanten(auth_user_id);

ALTER TABLE klanten ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'klanten_read') THEN
        CREATE POLICY klanten_read ON klanten
            FOR SELECT TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'klanten_insert') THEN
        CREATE POLICY klanten_insert ON klanten
            FOR INSERT TO authenticated WITH CHECK (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'klanten_update') THEN
        CREATE POLICY klanten_update ON klanten
            FOR UPDATE TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'klanten_delete') THEN
        CREATE POLICY klanten_delete ON klanten
            FOR DELETE TO authenticated USING (true);
    END IF;
END $$;

-- 2. KLANT EXTERNE NUMMERS TABEL
CREATE TABLE IF NOT EXISTS klant_externe_nummers (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    klant_id        UUID NOT NULL REFERENCES klanten(id) ON DELETE CASCADE,
    platform        TEXT NOT NULL,
    extern_nummer   TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(klant_id, platform)
);

CREATE INDEX IF NOT EXISTS idx_klant_ext_klant ON klant_externe_nummers(klant_id);

ALTER TABLE klant_externe_nummers ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'klant_ext_read') THEN
        CREATE POLICY klant_ext_read ON klant_externe_nummers
            FOR SELECT TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'klant_ext_write') THEN
        CREATE POLICY klant_ext_write ON klant_externe_nummers
            FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;

-- 3. VERKOOPKANALEN TABEL
CREATE TABLE IF NOT EXISTS verkoopkanalen (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    naam        TEXT NOT NULL,
    code        TEXT UNIQUE NOT NULL,
    actief      BOOLEAN NOT NULL DEFAULT true,
    sort_order  INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE verkoopkanalen ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'verkoopkanalen_read') THEN
        CREATE POLICY verkoopkanalen_read ON verkoopkanalen
            FOR SELECT TO authenticated USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'verkoopkanalen_write') THEN
        CREATE POLICY verkoopkanalen_write ON verkoopkanalen
            FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;
END $$;

-- Standaard verkoopkanalen invoegen (als ze nog niet bestaan)
INSERT INTO verkoopkanalen (naam, code, sort_order) VALUES
    ('Ventoz Website', 'website', 0),
    ('eBay', 'ebay', 1),
    ('Amazon', 'amazon', 2),
    ('Bol.com', 'bol_com', 3),
    ('Handmatig', 'handmatig', 4),
    ('Overig', 'overig', 5)
ON CONFLICT (code) DO NOTHING;

-- 4. INVENTORY MUTATIONS UITBREIDING
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'inventory_mutations' AND column_name = 'verkoopkanaal_code') THEN
        ALTER TABLE inventory_mutations ADD COLUMN verkoopkanaal_code TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'inventory_mutations' AND column_name = 'order_nummer') THEN
        ALTER TABLE inventory_mutations ADD COLUMN order_nummer TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'inventory_mutations' AND column_name = 'klant_id') THEN
        ALTER TABLE inventory_mutations ADD COLUMN klant_id UUID;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'inventory_mutations' AND column_name = 'klant_naam') THEN
        ALTER TABLE inventory_mutations ADD COLUMN klant_naam TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'inventory_mutations' AND column_name = 'mutatie_type') THEN
        ALTER TABLE inventory_mutations ADD COLUMN mutatie_type TEXT NOT NULL DEFAULT 'correctie';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'inventory_mutations' AND column_name = 'extern_order_nummer') THEN
        ALTER TABLE inventory_mutations ADD COLUMN extern_order_nummer TEXT;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_inv_mut_kanaal ON inventory_mutations(verkoopkanaal_code);
CREATE INDEX IF NOT EXISTS idx_inv_mut_order ON inventory_mutations(order_nummer);
CREATE INDEX IF NOT EXISTS idx_inv_mut_klant ON inventory_mutations(klant_id);
CREATE INDEX IF NOT EXISTS idx_inv_mut_type ON inventory_mutations(mutatie_type);

-- 5. ORDERS: KLANT_ID KOLOM
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_name = 'orders' AND column_name = 'klant_id') THEN
        ALTER TABLE orders ADD COLUMN klant_id UUID;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_orders_klant ON orders(klant_id);
