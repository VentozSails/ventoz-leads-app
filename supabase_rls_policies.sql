-- ============================================================
-- Ventoz Sails App – Row-Level Security Policies
-- ============================================================
-- Voer dit uit in de Supabase SQL Editor (https://supabase.com/dashboard)
-- Dit zorgt ervoor dat alleen ingelogde gebruikers toegang hebben.
-- Niet-ingelogde gebruikers (anon key) worden volledig geblokkeerd.
-- ============================================================

-- 1. RLS inschakelen op alle tabellen
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads_nl ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads_de ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads_be ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE producten ENABLE ROW LEVEL SECURITY;
ALTER TABLE kortingscodes ENABLE ROW LEVEL SECURITY;

-- 2. Verwijder ALLE bestaande policies op public tabellen (schone lei)
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN
        SELECT policyname, tablename
        FROM pg_policies
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I', pol.policyname, pol.tablename);
    END LOOP;
END $$;

-- ============================================================
-- 2b. HELPER-FUNCTIES (moeten vóór de policies bestaan)
-- ============================================================

-- is_ventoz_admin: eigenaar of admin?
CREATE OR REPLACE FUNCTION is_ventoz_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT
        NOT EXISTS (SELECT 1 FROM app_settings WHERE key = 'app_owner')
        OR
        (SELECT (value->>'email') = lower(auth.email())
         FROM app_settings WHERE key = 'app_owner')
        OR
        (SELECT value->'emails' ? lower(auth.email())
         FROM app_settings WHERE key = 'admin_users');
$$;

-- is_ventoz_staff: owner or admin role?
CREATE OR REPLACE FUNCTION is_ventoz_staff()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT
        is_ventoz_admin()
        OR EXISTS (
            SELECT 1 FROM ventoz_users
            WHERE email = lower(auth.email())
              AND user_type IN ('owner', 'admin')
              AND status = 'geregistreerd'
        );
$$;

-- ============================================================
-- 3. LEADS tabellen – alleen staff (medewerkers + admins)
-- Klanten/wederverkopers/generieke users mogen geen leads zien
-- ============================================================

-- leads_nl
CREATE POLICY ventoz_leads_nl_select ON leads_nl
    FOR SELECT TO authenticated USING (is_ventoz_staff());
CREATE POLICY ventoz_leads_nl_insert ON leads_nl
    FOR INSERT TO authenticated WITH CHECK (is_ventoz_staff());
CREATE POLICY ventoz_leads_nl_update ON leads_nl
    FOR UPDATE TO authenticated USING (is_ventoz_staff()) WITH CHECK (is_ventoz_staff());
CREATE POLICY ventoz_leads_nl_delete ON leads_nl
    FOR DELETE TO authenticated USING (is_ventoz_admin());

-- leads_de
CREATE POLICY ventoz_leads_de_select ON leads_de
    FOR SELECT TO authenticated USING (is_ventoz_staff());
CREATE POLICY ventoz_leads_de_insert ON leads_de
    FOR INSERT TO authenticated WITH CHECK (is_ventoz_staff());
CREATE POLICY ventoz_leads_de_update ON leads_de
    FOR UPDATE TO authenticated USING (is_ventoz_staff()) WITH CHECK (is_ventoz_staff());
CREATE POLICY ventoz_leads_de_delete ON leads_de
    FOR DELETE TO authenticated USING (is_ventoz_admin());

-- leads_be
CREATE POLICY ventoz_leads_be_select ON leads_be
    FOR SELECT TO authenticated USING (is_ventoz_staff());
CREATE POLICY ventoz_leads_be_insert ON leads_be
    FOR INSERT TO authenticated WITH CHECK (is_ventoz_staff());
CREATE POLICY ventoz_leads_be_update ON leads_be
    FOR UPDATE TO authenticated USING (is_ventoz_staff()) WITH CHECK (is_ventoz_staff());
CREATE POLICY ventoz_leads_be_delete ON leads_be
    FOR DELETE TO authenticated USING (is_ventoz_admin());

-- ============================================================
-- 4. EMAIL LOGS – alleen staff
-- ============================================================
CREATE POLICY ventoz_email_logs_select ON email_logs
    FOR SELECT TO authenticated USING (is_ventoz_staff());
CREATE POLICY ventoz_email_logs_insert ON email_logs
    FOR INSERT TO authenticated WITH CHECK (is_ventoz_staff());
CREATE POLICY ventoz_email_logs_update ON email_logs
    FOR UPDATE TO authenticated USING (is_ventoz_staff()) WITH CHECK (is_ventoz_staff());
CREATE POLICY ventoz_email_logs_delete ON email_logs
    FOR DELETE TO authenticated USING (is_ventoz_admin());

-- ============================================================
-- 5. EMAIL TEMPLATES – alleen staff
-- ============================================================
CREATE POLICY ventoz_email_templates_select ON email_templates
    FOR SELECT TO authenticated USING (is_ventoz_staff());
CREATE POLICY ventoz_email_templates_insert ON email_templates
    FOR INSERT TO authenticated WITH CHECK (is_ventoz_staff());
CREATE POLICY ventoz_email_templates_update ON email_templates
    FOR UPDATE TO authenticated USING (is_ventoz_staff()) WITH CHECK (is_ventoz_staff());
CREATE POLICY ventoz_email_templates_delete ON email_templates
    FOR DELETE TO authenticated USING (is_ventoz_admin());

-- ============================================================
-- 6. PRODUCTEN – lezen voor alle ingelogde users, schrijven alleen admins
-- ============================================================
CREATE POLICY ventoz_producten_select ON producten
    FOR SELECT TO authenticated USING (true);
CREATE POLICY ventoz_producten_insert ON producten
    FOR INSERT TO authenticated WITH CHECK (is_ventoz_admin());
CREATE POLICY ventoz_producten_update ON producten
    FOR UPDATE TO authenticated USING (is_ventoz_admin()) WITH CHECK (is_ventoz_admin());
CREATE POLICY ventoz_producten_delete ON producten
    FOR DELETE TO authenticated USING (is_ventoz_admin());

-- ============================================================
-- 7. KORTINGSCODES – alleen staff
-- ============================================================
CREATE POLICY ventoz_kortingscodes_select ON kortingscodes
    FOR SELECT TO authenticated USING (is_ventoz_staff());
CREATE POLICY ventoz_kortingscodes_insert ON kortingscodes
    FOR INSERT TO authenticated WITH CHECK (is_ventoz_staff());
CREATE POLICY ventoz_kortingscodes_update ON kortingscodes
    FOR UPDATE TO authenticated USING (is_ventoz_staff()) WITH CHECK (is_ventoz_staff());
CREATE POLICY ventoz_kortingscodes_delete ON kortingscodes
    FOR DELETE TO authenticated USING (is_ventoz_admin());

-- ============================================================
-- 8. APP_SETTINGS – de meest gevoelige tabel
--    Alle ingelogde users mogen lezen (nodig voor login-autorisatie).
--    Schrijven: alleen eigenaar of admins.
-- ============================================================

-- Lezen: alle ingelogde users (nodig voor login-autorisatie check)
-- Gevoelige keys (smtp_settings, payment_config) worden extra beperkt
CREATE POLICY ventoz_app_settings_select ON app_settings
    FOR SELECT TO authenticated
    USING (
        key NOT IN ('smtp_settings', 'payment_config', 'myparcel_config', 'smtp_config',
                    'invited_users', 'admin_users', 'role_permissions')
        OR is_ventoz_staff()
    );
CREATE POLICY ventoz_app_settings_anon_select ON app_settings
    FOR SELECT TO anon
    USING (key IN ('review_platforms', 'about_text'));

-- Schrijven: alleen eigenaar of admins
CREATE POLICY ventoz_app_settings_insert ON app_settings
    FOR INSERT TO authenticated
    WITH CHECK (is_ventoz_admin());

CREATE POLICY ventoz_app_settings_update ON app_settings
    FOR UPDATE TO authenticated
    USING (is_ventoz_admin())
    WITH CHECK (is_ventoz_admin());

CREATE POLICY ventoz_app_settings_delete ON app_settings
    FOR DELETE TO authenticated
    USING (is_ventoz_admin());

-- ============================================================
-- 9. PRODUCT CATALOGUS – lezen voor ingelogde users, schrijven voor admins
-- ============================================================

-- Tabel aanmaken (eenmalig uitvoeren)
CREATE TABLE IF NOT EXISTS product_catalogus (
  id SERIAL PRIMARY KEY,
  artikelnummer TEXT,
  naam TEXT NOT NULL,
  categorie TEXT,
  prijs NUMERIC(10,2),
  staffelprijzen JSONB,
  beschrijving TEXT,
  afbeelding_url TEXT,
  webshop_url TEXT UNIQUE,
  luff TEXT,
  foot TEXT,
  sail_area TEXT,
  in_stock BOOLEAN DEFAULT true,
  laatst_bijgewerkt TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE product_catalogus ENABLE ROW LEVEL SECURITY;

CREATE POLICY ventoz_product_catalogus_select ON product_catalogus
    FOR SELECT TO authenticated USING (true);
CREATE POLICY ventoz_product_catalogus_anon_select ON product_catalogus
    FOR SELECT TO anon USING (geblokkeerd IS NOT TRUE);
CREATE POLICY ventoz_product_catalogus_insert ON product_catalogus
    FOR INSERT TO authenticated WITH CHECK (is_ventoz_admin());
CREATE POLICY ventoz_product_catalogus_update ON product_catalogus
    FOR UPDATE TO authenticated
    USING (is_ventoz_admin()) WITH CHECK (is_ventoz_admin());
CREATE POLICY ventoz_product_catalogus_delete ON product_catalogus
    FOR DELETE TO authenticated USING (is_ventoz_admin());

-- ============================================================
-- 10. VERTALINGEN – extra kolommen voor product_catalogus
-- ============================================================

-- Vertaalde namen (alle 23 EU-talen excl. NL)
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_bg TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_cs TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_da TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_de TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_el TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_en TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_es TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_et TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_fi TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_fr TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_ga TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_hr TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_hu TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_it TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_lt TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_lv TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_mt TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_pl TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_pt TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_ro TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_sk TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_sl TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_sv TEXT;

-- Vertaalde beschrijvingen (alle 23 EU-talen excl. NL)
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_bg TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_cs TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_da TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_de TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_el TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_en TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_es TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_et TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_fi TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_fr TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_ga TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_hr TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_hu TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_it TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_lt TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_lv TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_mt TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_pl TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_pt TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_ro TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_sk TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_sl TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_sv TEXT;

-- Productblokkering: eigenaar/admin kan producten blokkeren
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS geblokkeerd BOOLEAN DEFAULT false;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS geblokkeerd_door TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS geblokkeerd_op TIMESTAMPTZ;

-- Extra afbeeldingen: tot 9 extra afbeeldingen per product (JSONB array van URLs)
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS extra_afbeeldingen JSONB DEFAULT '[]'::jsonb;

-- Override-velden: handmatige aanpassingen die een scrape overleven
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS naam_override TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS beschrijving_override TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS prijs_override NUMERIC(10,2);
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS afbeelding_url_override TEXT;

-- SEO-velden (gescraped van ventoz.nl)
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS seo_title TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS seo_description TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS seo_keywords TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS canonical_url TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS og_image TEXT;

-- Gestructureerde specificatietabel (JSON), materiaal en inclusief
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS specs_tabel JSONB;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS materiaal TEXT;
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS inclusief TEXT;

-- ============================================================
-- 12. FEATURED PRODUCTS (uitgelichte producten voor homepage slider)
-- ============================================================

CREATE TABLE IF NOT EXISTS featured_products (
  id BIGSERIAL PRIMARY KEY,
  product_id BIGINT NOT NULL REFERENCES product_catalogus(id) ON DELETE CASCADE,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(product_id)
);
ALTER TABLE featured_products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS featured_read ON featured_products;
CREATE POLICY featured_read ON featured_products FOR SELECT USING (true);
DROP POLICY IF EXISTS featured_write ON featured_products;
CREATE POLICY featured_write ON featured_products
  FOR ALL USING (is_ventoz_admin()) WITH CHECK (is_ventoz_admin());

-- ============================================================
-- 13. ORDER EMAIL TEMPLATES
-- ============================================================

CREATE TABLE IF NOT EXISTS order_email_templates (
    id SERIAL PRIMARY KEY,
    template_type TEXT NOT NULL UNIQUE,
    html_template TEXT NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE order_email_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY oet_read ON order_email_templates
    FOR SELECT TO authenticated USING (is_ventoz_staff());
CREATE POLICY oet_write ON order_email_templates
    FOR ALL TO authenticated
    USING (is_ventoz_admin()) WITH CHECK (is_ventoz_admin());

-- ============================================================
-- 13. VENTOZ_USERS – gebruikerstabel met rollen, BTW, kortingen
-- ============================================================

CREATE TABLE IF NOT EXISTS ventoz_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id UUID UNIQUE,
  email TEXT NOT NULL UNIQUE,
  user_type TEXT NOT NULL DEFAULT 'user'
    CHECK (user_type IN ('owner', 'admin', 'wederverkoper', 'prospect', 'klant', 'user',
           'medewerker', 'klant_particulier', 'klant_organisatie', 'generiek')),
  status TEXT NOT NULL DEFAULT 'uitgenodigd'
    CHECK (status IN ('uitgenodigd', 'geregistreerd', 'inactief')),
  is_particulier BOOLEAN NOT NULL DEFAULT true,
  -- NAW-gegevens
  voornaam TEXT,
  achternaam TEXT,
  adres TEXT,
  postcode TEXT,
  woonplaats TEXT,
  regio TEXT,
  telefoon TEXT,
  -- Bedrijfsgegevens
  bedrijfsnaam TEXT,
  btw_nummer TEXT,
  btw_gevalideerd BOOLEAN NOT NULL DEFAULT false,
  btw_validatie_datum TIMESTAMPTZ,
  btw_verlegd BOOLEAN NOT NULL DEFAULT false,
  iban TEXT,
  -- Locatie & kortingen
  land_code TEXT NOT NULL DEFAULT 'NL',
  korting_permanent NUMERIC(5,2) DEFAULT 0,
  korting_tijdelijk NUMERIC(5,2) DEFAULT 0,
  korting_geldig_tot TIMESTAMPTZ,
  permissions JSONB NOT NULL DEFAULT '{"inzien":true,"wijzigen":false,"emails_versturen":false,"verwijderen":false,"exporteren":false,"gebruikers_beheren":false}'::jsonb,
  is_admin BOOLEAN NOT NULL DEFAULT false,
  is_owner BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Migratie: kolommen toevoegen als tabel al bestaat
ALTER TABLE ventoz_users ADD COLUMN IF NOT EXISTS voornaam TEXT;
ALTER TABLE ventoz_users ADD COLUMN IF NOT EXISTS achternaam TEXT;
ALTER TABLE ventoz_users ADD COLUMN IF NOT EXISTS adres TEXT;
ALTER TABLE ventoz_users ADD COLUMN IF NOT EXISTS postcode TEXT;
ALTER TABLE ventoz_users ADD COLUMN IF NOT EXISTS woonplaats TEXT;
ALTER TABLE ventoz_users ADD COLUMN IF NOT EXISTS regio TEXT;
ALTER TABLE ventoz_users ADD COLUMN IF NOT EXISTS telefoon TEXT;
ALTER TABLE ventoz_users ADD COLUMN IF NOT EXISTS btw_verlegd BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE ventoz_users ADD COLUMN IF NOT EXISTS iban TEXT;

-- CHECK constraint: accept both new and legacy role values for migration
ALTER TABLE ventoz_users DROP CONSTRAINT IF EXISTS ventoz_users_user_type_check;
ALTER TABLE ventoz_users ADD CONSTRAINT ventoz_users_user_type_check
  CHECK (user_type IN ('owner', 'admin', 'wederverkoper', 'prospect', 'klant', 'user',
         'medewerker', 'klant_particulier', 'klant_organisatie', 'generiek'));

ALTER TABLE ventoz_users ENABLE ROW LEVEL SECURITY;

-- Iedereen kan eigen rij lezen (by auth_user_id or email); admins alles
CREATE POLICY ventoz_users_select ON ventoz_users
    FOR SELECT TO authenticated
    USING (
      auth_user_id = auth.uid()
      OR email = lower(auth.email())
      OR is_ventoz_admin()
    );

-- Alleen admins mogen invoegen
CREATE POLICY ventoz_users_insert ON ventoz_users
    FOR INSERT TO authenticated
    WITH CHECK (is_ventoz_admin());

-- Admins mogen alles updaten; gewone users alleen eigen profiel.
-- email = lower(auth.email()) allows newly registered invited users to claim
-- their row (set auth_user_id + status) when auth_user_id is still NULL.
-- WITH CHECK guards that non-admins cannot escalate privileges.
CREATE POLICY ventoz_users_update ON ventoz_users
    FOR UPDATE TO authenticated
    USING (
        auth_user_id = auth.uid()
        OR email = lower(auth.email())
        OR is_ventoz_admin()
    )
    WITH CHECK (
        is_ventoz_admin()
        OR (
            (auth_user_id = auth.uid() OR email = lower(auth.email()))
            AND user_type  = (SELECT vu.user_type  FROM ventoz_users vu WHERE vu.email = lower(auth.email()) LIMIT 1)
            AND permissions = (SELECT vu.permissions FROM ventoz_users vu WHERE vu.email = lower(auth.email()) LIMIT 1)
            AND is_admin   = (SELECT vu.is_admin   FROM ventoz_users vu WHERE vu.email = lower(auth.email()) LIMIT 1)
            AND is_owner   = (SELECT vu.is_owner   FROM ventoz_users vu WHERE vu.email = lower(auth.email()) LIMIT 1)
            AND korting_permanent = (SELECT vu.korting_permanent FROM ventoz_users vu WHERE vu.email = lower(auth.email()) LIMIT 1)
            AND korting_tijdelijk = (SELECT vu.korting_tijdelijk FROM ventoz_users vu WHERE vu.email = lower(auth.email()) LIMIT 1)
            AND korting_geldig_tot IS NOT DISTINCT FROM (SELECT vu.korting_geldig_tot FROM ventoz_users vu WHERE vu.email = lower(auth.email()) LIMIT 1)
            AND (status = (SELECT vu.status FROM ventoz_users vu WHERE vu.email = lower(auth.email()) LIMIT 1)
                 OR (status = 'geregistreerd' AND (SELECT vu.status FROM ventoz_users vu WHERE vu.email = lower(auth.email()) LIMIT 1) = 'uitgenodigd'))
        )
    );

-- Alleen admins mogen verwijderen
CREATE POLICY ventoz_users_delete ON ventoz_users
    FOR DELETE TO authenticated
    USING (is_ventoz_admin());

-- ============================================================
-- 12. FAVORIETEN – koppeltabel user-product
-- ============================================================

CREATE TABLE IF NOT EXISTS favorieten (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL DEFAULT auth.uid(),
  product_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, product_id)
);

ALTER TABLE favorieten ENABLE ROW LEVEL SECURITY;

CREATE POLICY favorieten_select ON favorieten
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY favorieten_insert ON favorieten
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY favorieten_delete ON favorieten
    FOR DELETE TO authenticated
    USING (user_id = auth.uid());

-- ============================================================
-- 13. ORDERS – bestellingen
-- ============================================================

CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_nummer TEXT UNIQUE NOT NULL,
  user_id UUID NOT NULL DEFAULT auth.uid(),
  user_email TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'concept'
    CHECK (status IN ('concept', 'betaling_gestart', 'betaald', 'verzonden', 'afgeleverd', 'geannuleerd')),
  subtotaal NUMERIC(10,2) NOT NULL DEFAULT 0,
  btw_bedrag NUMERIC(10,2) NOT NULL DEFAULT 0,
  btw_percentage NUMERIC(5,2) NOT NULL DEFAULT 0,
  btw_verlegd BOOLEAN NOT NULL DEFAULT false,
  verzendkosten NUMERIC(10,2) NOT NULL DEFAULT 0,
  totaal NUMERIC(10,2) NOT NULL DEFAULT 0,
  valuta TEXT NOT NULL DEFAULT 'EUR',
  betaal_methode TEXT,
  betaal_referentie TEXT,
  factuur_nummer TEXT,
  naam TEXT,
  adres TEXT,
  postcode TEXT,
  woonplaats TEXT,
  land_code TEXT NOT NULL DEFAULT 'NL',
  btw_nummer TEXT,
  iban TEXT,
  bedrijfsnaam TEXT,
  opmerkingen TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  betaald_op TIMESTAMPTZ,
  track_trace_code TEXT,
  track_trace_carrier TEXT DEFAULT 'postnl',
  track_trace_url TEXT,
  verzonden_op TIMESTAMPTZ,
  factuur_pdf BYTEA,
  bevestiging_verzonden BOOLEAN NOT NULL DEFAULT false,
  verzend_email_verzonden BOOLEAN NOT NULL DEFAULT false
);

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY orders_select ON orders
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR is_ventoz_admin());

CREATE POLICY orders_insert ON orders
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

-- Users can only update their own draft orders; admins can update any order
CREATE POLICY orders_update ON orders
    FOR UPDATE TO authenticated
    USING (
        is_ventoz_admin()
        OR (user_id = auth.uid() AND status = 'concept')
    )
    WITH CHECK (
        is_ventoz_admin()
        OR (user_id = auth.uid() AND status = 'concept')
    );

CREATE POLICY orders_delete ON orders
    FOR DELETE TO authenticated
    USING (is_ventoz_admin());

-- ============================================================
-- 14. ORDER_REGELS – orderregels
-- ============================================================

CREATE TABLE IF NOT EXISTS order_regels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL,
  product_naam TEXT NOT NULL,
  product_afbeelding TEXT,
  aantal INT NOT NULL DEFAULT 1,
  stukprijs NUMERIC(10,2) NOT NULL DEFAULT 0,
  korting_percentage NUMERIC(5,2) NOT NULL DEFAULT 0,
  regel_totaal NUMERIC(10,2) NOT NULL DEFAULT 0
);

ALTER TABLE order_regels ENABLE ROW LEVEL SECURITY;

CREATE POLICY order_regels_select ON order_regels
    FOR SELECT TO authenticated
    USING (
      EXISTS (SELECT 1 FROM orders WHERE orders.id = order_regels.order_id
              AND (orders.user_id = auth.uid() OR is_ventoz_admin()))
    );

CREATE POLICY order_regels_insert ON order_regels
    FOR INSERT TO authenticated
    WITH CHECK (
      EXISTS (SELECT 1 FROM orders WHERE orders.id = order_regels.order_id
              AND orders.user_id = auth.uid())
    );

CREATE POLICY order_regels_update ON order_regels
    FOR UPDATE TO authenticated
    USING (
      EXISTS (SELECT 1 FROM orders WHERE orders.id = order_regels.order_id
              AND is_ventoz_admin())
    )
    WITH CHECK (
      EXISTS (SELECT 1 FROM orders WHERE orders.id = order_regels.order_id
              AND is_ventoz_admin())
    );

CREATE POLICY order_regels_delete ON order_regels
    FOR DELETE TO authenticated
    USING (
      EXISTS (SELECT 1 FROM orders WHERE orders.id = order_regels.order_id
              AND is_ventoz_admin())
    );

-- ============================================================
-- 15. INVITE_FROM_LEAD – SECURITY DEFINER functie
-- Medewerkers zonder gebruikersBeheren recht mogen leads
-- uitnodigen als klant/wederverkoper bij het versturen van
-- een download-link email. Dit bypast de RLS INSERT policies
-- op ventoz_users en app_settings op een gecontroleerde manier.
-- ============================================================

CREATE OR REPLACE FUNCTION invite_from_lead(
  p_email TEXT,
  p_user_type TEXT DEFAULT 'prospect',
  p_bedrijfsnaam TEXT DEFAULT NULL,
  p_land_code TEXT DEFAULT 'NL',
  p_korting_permanent NUMERIC DEFAULT 0
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Niet ingelogd';
  END IF;

  IF NOT is_ventoz_staff() THEN
    RAISE EXCEPTION 'Geen rechten om leads uit te nodigen';
  END IF;

  IF p_user_type NOT IN ('prospect', 'klant', 'wederverkoper', 'user',
       'klant_organisatie', 'klant_particulier', 'generiek') THEN
    RAISE EXCEPTION 'Ongeldig gebruikerstype: %', p_user_type;
  END IF;

  IF p_korting_permanent > 50 THEN
    RAISE EXCEPTION 'Korting mag niet hoger zijn dan 50%%';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM ventoz_users WHERE lower(email) = lower(p_email)
  ) INTO v_exists;

  IF v_exists THEN
    RETURN FALSE;
  END IF;

  INSERT INTO ventoz_users (
    email, user_type, status, is_particulier,
    bedrijfsnaam, land_code, korting_permanent,
    permissions, is_admin, is_owner
  ) VALUES (
    lower(p_email),
    p_user_type,
    'uitgenodigd',
    false,
    p_bedrijfsnaam,
    COALESCE(p_land_code, 'NL'),
    COALESCE(p_korting_permanent, 0),
    '{"inzien":false,"wijzigen":false,"emails_versturen":false,"verwijderen":false,"exporteren":false,"gebruikers_beheren":false}'::jsonb,
    false,
    false
  );

  RETURN TRUE;
END;
$$;

-- ============================================================
-- 16. FACTUUR_VERTALINGEN
-- ============================================================
CREATE TABLE IF NOT EXISTS factuur_vertalingen (
  id SERIAL PRIMARY KEY,
  sleutel TEXT NOT NULL,
  taal TEXT NOT NULL,
  tekst TEXT NOT NULL,
  UNIQUE(sleutel, taal)
);
ALTER TABLE factuur_vertalingen ENABLE ROW LEVEL SECURITY;

CREATE POLICY fv_select ON factuur_vertalingen FOR SELECT TO authenticated USING (true);
CREATE POLICY fv_insert ON factuur_vertalingen FOR INSERT TO authenticated WITH CHECK (is_ventoz_admin());
CREATE POLICY fv_update ON factuur_vertalingen FOR UPDATE TO authenticated USING (is_ventoz_admin()) WITH CHECK (is_ventoz_admin());
CREATE POLICY fv_delete ON factuur_vertalingen FOR DELETE TO authenticated USING (is_ventoz_admin());

-- Seed: 8 talen x ~20 sleutels
INSERT INTO factuur_vertalingen (sleutel, taal, tekst) VALUES
-- NL
('factuur_titel','nl','FACTUUR'),('tav','nl','T.a.v.'),('factuurnummer','nl','Factuurnummer'),
('factuurdatum','nl','Factuurdatum'),('betaald_op','nl','Betaald op'),('ordernummer','nl','Ordernummer'),
('betaalmethode','nl','Betaalmethode'),('btw_vat','nl','BTW/VAT'),('omschrijving','nl','Omschrijving'),
('aantal','nl','Aantal'),('prijs','nl','Prijs'),('totaal','nl','Totaal'),
('totaal_excl_btw','nl','Totaal excl. BTW/VAT'),('totaal_btw','nl','Totaal BTW/VAT'),
('te_betalen','nl','Te betalen'),('verzendkosten_naar','nl','Verzendkosten naar'),
('btw_verlegd_titel','nl','BTW verlegd / VAT Reverse Charge'),
('btw_verlegd_tekst','nl','BTW verlegd op grond van artikel 138 Richtlijn 2006/112/EG (intracommunautaire levering). BTW wordt verlegd naar de afnemer.'),
('betaald_via','nl','Betaald via'),('opmerkingen','nl','Opmerkingen'),
('klant_btw','nl','Klant BTW/VAT'),('leverancier_btw','nl','Ventoz BTW/VAT'),
-- EN
('factuur_titel','en','INVOICE'),('tav','en','Att.'),('factuurnummer','en','Invoice number'),
('factuurdatum','en','Invoice date'),('betaald_op','en','Paid on'),('ordernummer','en','Order number'),
('betaalmethode','en','Payment method'),('btw_vat','en','VAT'),('omschrijving','en','Description'),
('aantal','en','Quantity'),('prijs','en','Price'),('totaal','en','Total'),
('totaal_excl_btw','en','Total excl. VAT'),('totaal_btw','en','Total VAT'),
('te_betalen','en','Amount due'),('verzendkosten_naar','en','Shipping costs to'),
('btw_verlegd_titel','en','VAT Reverse Charge'),
('btw_verlegd_tekst','en','VAT reverse charged according to article 138 Directive 2006/112/EC (intra-Community supply). VAT to be accounted for by the recipient.'),
('betaald_via','en','Paid via'),('opmerkingen','en','Notes'),
('klant_btw','en','Customer VAT'),('leverancier_btw','en','Ventoz VAT'),
-- DE
('factuur_titel','de','RECHNUNG'),('tav','de','z.Hd.'),('factuurnummer','de','Rechnungsnummer'),
('factuurdatum','de','Rechnungsdatum'),('betaald_op','de','Bezahlt am'),('ordernummer','de','Bestellnummer'),
('betaalmethode','de','Zahlungsmethode'),('btw_vat','de','MwSt.'),('omschrijving','de','Beschreibung'),
('aantal','de','Menge'),('prijs','de','Preis'),('totaal','de','Gesamt'),
('totaal_excl_btw','de','Gesamt exkl. MwSt.'),('totaal_btw','de','Gesamt MwSt.'),
('te_betalen','de','Zu zahlen'),('verzendkosten_naar','de','Versandkosten nach'),
('btw_verlegd_titel','de','Steuerschuldnerschaft / Reverse Charge'),
('btw_verlegd_tekst','de','Steuerschuldnerschaft gemäß Artikel 138 Richtlinie 2006/112/EG (innergemeinschaftliche Lieferung). Die MwSt. ist vom Leistungsempfänger abzuführen.'),
('betaald_via','de','Bezahlt über'),('opmerkingen','de','Anmerkungen'),
('klant_btw','de','Kunden-USt-IdNr.'),('leverancier_btw','de','Ventoz USt-IdNr.'),
-- FR
('factuur_titel','fr','FACTURE'),('tav','fr','À l''attention de'),('factuurnummer','fr','Numéro de facture'),
('factuurdatum','fr','Date de facture'),('betaald_op','fr','Payé le'),('ordernummer','fr','Numéro de commande'),
('betaalmethode','fr','Mode de paiement'),('btw_vat','fr','TVA'),('omschrijving','fr','Description'),
('aantal','fr','Quantité'),('prijs','fr','Prix'),('totaal','fr','Total'),
('totaal_excl_btw','fr','Total HT'),('totaal_btw','fr','Total TVA'),
('te_betalen','fr','Montant dû'),('verzendkosten_naar','fr','Frais de livraison vers'),
('btw_verlegd_titel','fr','Autoliquidation de la TVA'),
('btw_verlegd_tekst','fr','TVA autoliquidée conformément à l''article 138 de la directive 2006/112/CE (livraison intracommunautaire). La TVA est à acquitter par le destinataire.'),
('betaald_via','fr','Payé par'),('opmerkingen','fr','Remarques'),
('klant_btw','fr','TVA client'),('leverancier_btw','fr','TVA Ventoz'),
-- ES
('factuur_titel','es','FACTURA'),('tav','es','A la atención de'),('factuurnummer','es','Número de factura'),
('factuurdatum','es','Fecha de factura'),('betaald_op','es','Pagado el'),('ordernummer','es','Número de pedido'),
('betaalmethode','es','Método de pago'),('btw_vat','es','IVA'),('omschrijving','es','Descripción'),
('aantal','es','Cantidad'),('prijs','es','Precio'),('totaal','es','Total'),
('totaal_excl_btw','es','Total sin IVA'),('totaal_btw','es','Total IVA'),
('te_betalen','es','Importe a pagar'),('verzendkosten_naar','es','Gastos de envío a'),
('btw_verlegd_titel','es','Inversión del sujeto pasivo'),
('btw_verlegd_tekst','es','IVA con inversión del sujeto pasivo según el artículo 138 de la Directiva 2006/112/CE (entrega intracomunitaria). El IVA debe ser declarado por el destinatario.'),
('betaald_via','es','Pagado mediante'),('opmerkingen','es','Observaciones'),
('klant_btw','es','NIF/IVA cliente'),('leverancier_btw','es','NIF/IVA Ventoz'),
-- IT
('factuur_titel','it','FATTURA'),('tav','it','All''attenzione di'),('factuurnummer','it','Numero fattura'),
('factuurdatum','it','Data fattura'),('betaald_op','it','Pagato il'),('ordernummer','it','Numero ordine'),
('betaalmethode','it','Metodo di pagamento'),('btw_vat','it','IVA'),('omschrijving','it','Descrizione'),
('aantal','it','Quantità'),('prijs','it','Prezzo'),('totaal','it','Totale'),
('totaal_excl_btw','it','Totale esclusa IVA'),('totaal_btw','it','Totale IVA'),
('te_betalen','it','Importo dovuto'),('verzendkosten_naar','it','Spese di spedizione verso'),
('btw_verlegd_titel','it','Inversione contabile IVA'),
('btw_verlegd_tekst','it','IVA in regime di inversione contabile ai sensi dell''articolo 138 della direttiva 2006/112/CE (cessione intracomunitaria). L''IVA è a carico del destinatario.'),
('betaald_via','it','Pagato tramite'),('opmerkingen','it','Note'),
('klant_btw','it','P.IVA cliente'),('leverancier_btw','it','P.IVA Ventoz'),
-- PT
('factuur_titel','pt','FATURA'),('tav','pt','Ao cuidado de'),('factuurnummer','pt','Número da fatura'),
('factuurdatum','pt','Data da fatura'),('betaald_op','pt','Pago em'),('ordernummer','pt','Número do pedido'),
('betaalmethode','pt','Método de pagamento'),('btw_vat','pt','IVA'),('omschrijving','pt','Descrição'),
('aantal','pt','Quantidade'),('prijs','pt','Preço'),('totaal','pt','Total'),
('totaal_excl_btw','pt','Total s/ IVA'),('totaal_btw','pt','Total IVA'),
('te_betalen','pt','Valor a pagar'),('verzendkosten_naar','pt','Custos de envio para'),
('btw_verlegd_titel','pt','Autoliquidação do IVA'),
('btw_verlegd_tekst','pt','IVA autoliquidado nos termos do artigo 138.º da Diretiva 2006/112/CE (fornecimento intracomunitário). O IVA é da responsabilidade do destinatário.'),
('betaald_via','pt','Pago por'),('opmerkingen','pt','Observações'),
('klant_btw','pt','NIF cliente'),('leverancier_btw','pt','NIF Ventoz'),
-- PL
('factuur_titel','pl','FAKTURA'),('tav','pl','Do rąk'),('factuurnummer','pl','Numer faktury'),
('factuurdatum','pl','Data faktury'),('betaald_op','pl','Zapłacono'),('ordernummer','pl','Numer zamówienia'),
('betaalmethode','pl','Metoda płatności'),('btw_vat','pl','VAT'),('omschrijving','pl','Opis'),
('aantal','pl','Ilość'),('prijs','pl','Cena'),('totaal','pl','Razem'),
('totaal_excl_btw','pl','Razem netto'),('totaal_btw','pl','Razem VAT'),
('te_betalen','pl','Do zapłaty'),('verzendkosten_naar','pl','Koszty wysyłki do'),
('btw_verlegd_titel','pl','Odwrotne obciążenie VAT'),
('btw_verlegd_tekst','pl','VAT rozliczany w ramach odwrotnego obciążenia zgodnie z art. 138 dyrektywy 2006/112/WE (dostawa wewnątrzwspólnotowa). VAT do rozliczenia przez nabywcę.'),
('betaald_via','pl','Zapłacono przez'),('opmerkingen','pl','Uwagi'),
('klant_btw','pl','NIP klienta'),('leverancier_btw','pl','NIP Ventoz'),
-- E-mail vertalingen (orderbevestiging + verzend-email)
-- NL
('bevestiging_onderwerp','nl','Orderbevestiging Ventoz —'),('bevestiging_bedankt','nl','Bedankt voor je bestelling!'),
('bevestiging_samenvatting','nl','Hieronder een samenvatting van je bestelling:'),
('bevestiging_factuur_later','nl','Je factuur ontvang je bij verzending van je bestelling.'),
('verzending_onderwerp','nl','Je bestelling is verzonden! —'),('verzending_tekst','nl','Goed nieuws! Je bestelling is onderweg.'),
('track_trace_label','nl','Volg je pakket'),('verzonden_via','nl','Verzonden via'),
('tracking_code','nl','Trackingcode'),('factuur_bijgevoegd','nl','Je factuur is bijgevoegd als PDF.'),
('vragen','nl','Heb je vragen? Neem gerust contact op.'),
-- EN
('bevestiging_onderwerp','en','Order Confirmation Ventoz —'),('bevestiging_bedankt','en','Thank you for your order!'),
('bevestiging_samenvatting','en','Below is a summary of your order:'),
('bevestiging_factuur_later','en','You will receive your invoice when your order ships.'),
('verzending_onderwerp','en','Your order has been shipped! —'),('verzending_tekst','en','Great news! Your order is on its way.'),
('track_trace_label','en','Track your parcel'),('verzonden_via','en','Shipped via'),
('tracking_code','en','Tracking code'),('factuur_bijgevoegd','en','Your invoice is attached as a PDF.'),
('vragen','en','Any questions? Feel free to contact us.'),
-- DE
('bevestiging_onderwerp','de','Bestellbestätigung Ventoz —'),('bevestiging_bedankt','de','Vielen Dank für Ihre Bestellung!'),
('bevestiging_samenvatting','de','Nachfolgend eine Zusammenfassung Ihrer Bestellung:'),
('bevestiging_factuur_later','de','Ihre Rechnung erhalten Sie beim Versand Ihrer Bestellung.'),
('verzending_onderwerp','de','Ihre Bestellung wurde versandt! —'),('verzending_tekst','de','Gute Nachrichten! Ihre Bestellung ist unterwegs.'),
('track_trace_label','de','Sendungsverfolgung'),('verzonden_via','de','Versandt über'),
('tracking_code','de','Sendungsnummer'),('factuur_bijgevoegd','de','Ihre Rechnung ist als PDF beigefügt.'),
('vragen','de','Haben Sie Fragen? Kontaktieren Sie uns gerne.'),
-- FR
('bevestiging_onderwerp','fr','Confirmation de commande Ventoz —'),('bevestiging_bedankt','fr','Merci pour votre commande !'),
('bevestiging_samenvatting','fr','Voici un résumé de votre commande :'),
('bevestiging_factuur_later','fr','Vous recevrez votre facture lors de l''expédition de votre commande.'),
('verzending_onderwerp','fr','Votre commande a été expédiée ! —'),('verzending_tekst','fr','Bonne nouvelle ! Votre commande est en route.'),
('track_trace_label','fr','Suivez votre colis'),('verzonden_via','fr','Expédié par'),
('tracking_code','fr','Numéro de suivi'),('factuur_bijgevoegd','fr','Votre facture est jointe en PDF.'),
('vragen','fr','Des questions ? N''hésitez pas à nous contacter.'),
-- ES
('bevestiging_onderwerp','es','Confirmación de pedido Ventoz —'),('bevestiging_bedankt','es','¡Gracias por tu pedido!'),
('bevestiging_samenvatting','es','A continuación un resumen de tu pedido:'),
('bevestiging_factuur_later','es','Recibirás tu factura cuando se envíe tu pedido.'),
('verzending_onderwerp','es','¡Tu pedido ha sido enviado! —'),('verzending_tekst','es','¡Buenas noticias! Tu pedido está en camino.'),
('track_trace_label','es','Seguimiento de tu paquete'),('verzonden_via','es','Enviado por'),
('tracking_code','es','Código de seguimiento'),('factuur_bijgevoegd','es','Tu factura está adjunta como PDF.'),
('vragen','es','¿Preguntas? No dudes en contactarnos.'),
-- IT
('bevestiging_onderwerp','it','Conferma ordine Ventoz —'),('bevestiging_bedankt','it','Grazie per il tuo ordine!'),
('bevestiging_samenvatting','it','Di seguito un riepilogo del tuo ordine:'),
('bevestiging_factuur_later','it','Riceverai la fattura alla spedizione del tuo ordine.'),
('verzending_onderwerp','it','Il tuo ordine è stato spedito! —'),('verzending_tekst','it','Buone notizie! Il tuo ordine è in viaggio.'),
('track_trace_label','it','Traccia il tuo pacco'),('verzonden_via','it','Spedito tramite'),
('tracking_code','it','Codice di tracciamento'),('factuur_bijgevoegd','it','La tua fattura è allegata come PDF.'),
('vragen','it','Hai domande? Non esitare a contattarci.'),
-- PT
('bevestiging_onderwerp','pt','Confirmação de encomenda Ventoz —'),('bevestiging_bedankt','pt','Obrigado pela sua encomenda!'),
('bevestiging_samenvatting','pt','Abaixo está um resumo da sua encomenda:'),
('bevestiging_factuur_later','pt','Receberá a sua fatura quando a encomenda for enviada.'),
('verzending_onderwerp','pt','A sua encomenda foi enviada! —'),('verzending_tekst','pt','Boas notícias! A sua encomenda está a caminho.'),
('track_trace_label','pt','Rastreie a sua encomenda'),('verzonden_via','pt','Enviado por'),
('tracking_code','pt','Código de rastreamento'),('factuur_bijgevoegd','pt','A sua fatura está anexada em PDF.'),
('vragen','pt','Tem perguntas? Não hesite em contactar-nos.'),
-- PL
('bevestiging_onderwerp','pl','Potwierdzenie zamówienia Ventoz —'),('bevestiging_bedankt','pl','Dziękujemy za zamówienie!'),
('bevestiging_samenvatting','pl','Poniżej podsumowanie Twojego zamówienia:'),
('bevestiging_factuur_later','pl','Fakturę otrzymasz przy wysyłce zamówienia.'),
('verzending_onderwerp','pl','Twoje zamówienie zostało wysłane! —'),('verzending_tekst','pl','Dobre wieści! Twoje zamówienie jest w drodze.'),
('track_trace_label','pl','Śledź swoją przesyłkę'),('verzonden_via','pl','Wysłano przez'),
('tracking_code','pl','Numer śledzenia'),('factuur_bijgevoegd','pl','Faktura jest dołączona jako PDF.'),
('vragen','pl','Masz pytania? Skontaktuj się z nami.')
ON CONFLICT (sleutel, taal) DO UPDATE SET tekst = EXCLUDED.tekst;

-- ============================================================
-- PAYMENT ICONS TABEL
-- ============================================================
-- Slaat betaalmethode-iconen op als base64 PNG zodat ze altijd
-- beschikbaar zijn, ongeacht externe CDN bereikbaarheid.

CREATE TABLE IF NOT EXISTS payment_icons (
    method_key TEXT PRIMARY KEY,
    icon_data  TEXT NOT NULL,
    format     TEXT NOT NULL DEFAULT 'svg',
    updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE payment_icons ENABLE ROW LEVEL SECURITY;

CREATE POLICY payment_icons_read ON payment_icons
    FOR SELECT TO authenticated USING (true);

CREATE POLICY payment_icons_write ON payment_icons
    FOR ALL TO authenticated USING (is_ventoz_admin()) WITH CHECK (is_ventoz_admin());

-- ============================================================
-- AUDIT_LOG – immutable audit trail
-- ============================================================

CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action TEXT NOT NULL,
    actor_email TEXT,
    target_email TEXT,
    details TEXT,
    ip_address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY audit_log_select ON audit_log
    FOR SELECT TO authenticated USING (is_ventoz_staff());
CREATE POLICY audit_log_insert ON audit_log
    FOR INSERT TO authenticated WITH CHECK (is_ventoz_staff());
CREATE POLICY audit_log_no_update ON audit_log
    FOR UPDATE TO authenticated USING (false);
CREATE POLICY audit_log_delete ON audit_log
    FOR DELETE TO authenticated USING (false);

-- ============================================================
-- LOGIN_ATTEMPTS – brute-force protection
-- ============================================================

CREATE TABLE IF NOT EXISTS login_attempts (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email TEXT NOT NULL,
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE login_attempts ENABLE ROW LEVEL SECURITY;

CREATE POLICY login_attempts_staff_read ON login_attempts
    FOR SELECT TO authenticated USING (is_ventoz_staff());
CREATE POLICY login_attempts_staff_delete ON login_attempts
    FOR DELETE TO authenticated USING (is_ventoz_staff());
CREATE POLICY login_attempts_no_direct_insert ON login_attempts
    FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY login_attempts_no_direct_update ON login_attempts
    FOR UPDATE TO authenticated USING (false);

-- locked_until column for brute-force lockout
ALTER TABLE ventoz_users ADD COLUMN IF NOT EXISTS locked_until TIMESTAMPTZ;

-- RPCs for brute-force protection (SECURITY DEFINER bypasses RLS)

CREATE OR REPLACE FUNCTION check_account_locked(p_email TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_locked TIMESTAMPTZ;
BEGIN
  SELECT locked_until INTO v_locked
    FROM ventoz_users WHERE email = lower(p_email) LIMIT 1;
  IF v_locked IS NULL THEN
    RETURN FALSE;
  END IF;
  RETURN v_locked > now();
END;
$$;

CREATE OR REPLACE FUNCTION record_failed_login(p_email TEXT)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_count INT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM ventoz_users WHERE email = lower(p_email)) THEN
    RETURN;
  END IF;

  INSERT INTO login_attempts (email) VALUES (lower(p_email));
  SELECT count(*) INTO v_count FROM login_attempts
    WHERE email = lower(p_email) AND attempted_at > now() - interval '30 minutes';
  IF v_count >= 5 THEN
    UPDATE ventoz_users
      SET locked_until = now() + interval '30 minutes'
      WHERE email = lower(p_email);
    INSERT INTO audit_log (action, actor_email, target_email, details)
      VALUES ('account_locked', 'systeem', lower(p_email),
              'Automatisch geblokkeerd na ' || v_count || ' mislukte pogingen (30 min)');
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION clear_login_attempts(p_email TEXT)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Niet ingelogd';
  END IF;
  IF NOT is_ventoz_staff() THEN
    RAISE EXCEPTION 'Geen rechten';
  END IF;
  DELETE FROM login_attempts WHERE email = lower(p_email);
END;
$$;

-- ============================================================
-- SERVER-SIDE ENCRYPTION (pgcrypto)
-- ============================================================
-- De encryptie-sleutel wordt server-side opgeslagen en is NOOIT
-- zichtbaar voor clients. Alleen SECURITY DEFINER functies hebben toegang.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Tabel voor de server-side encryption key (max 1 rij)
CREATE TABLE IF NOT EXISTS vault_keys (
  id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  encryption_key TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE vault_keys ENABLE ROW LEVEL SECURITY;

-- Niemand mag vault_keys lezen/schrijven via de API
CREATE POLICY vault_keys_deny_all ON vault_keys
    FOR ALL TO authenticated USING (false) WITH CHECK (false);
CREATE POLICY vault_keys_deny_anon ON vault_keys
    FOR ALL TO anon USING (false) WITH CHECK (false);

-- Voeg de sleutel in (eenmalig, vervang <YOUR_BASE64_KEY> door je sleutel).
-- Dit moet handmatig uitgevoerd worden in de SQL Editor:
--
--   INSERT INTO vault_keys (encryption_key)
--   VALUES ('<your-base64-encoded-32-byte-key>')
--   ON CONFLICT (id) DO UPDATE SET encryption_key = EXCLUDED.encryption_key;

-- Encrypt functie: neemt plaintext, retourneert versleutelde string
CREATE OR REPLACE FUNCTION encrypt_secret(p_plaintext TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_key BYTEA;
  v_iv BYTEA;
  v_encrypted BYTEA;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Niet ingelogd';
  END IF;
  IF NOT is_ventoz_staff() THEN
    RAISE EXCEPTION 'Geen rechten';
  END IF;

  IF p_plaintext IS NULL OR p_plaintext = '' THEN
    RETURN p_plaintext;
  END IF;

  SELECT decode(encryption_key, 'base64') INTO v_key FROM vault_keys WHERE id = 1;
  IF v_key IS NULL THEN
    RAISE EXCEPTION 'Encryption key niet geconfigureerd';
  END IF;

  v_iv := gen_random_bytes(16);
  v_encrypted := encrypt_iv(convert_to(p_plaintext, 'UTF8'), v_key, v_iv, 'aes-cbc/pad:pkcs');
  RETURN 'ENC:' || encode(v_iv, 'base64') || ':' || encode(v_encrypted, 'base64');
END;
$$;

-- Decrypt functie: neemt versleutelde string, retourneert plaintext
CREATE OR REPLACE FUNCTION decrypt_secret(p_ciphertext TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_key BYTEA;
  v_iv BYTEA;
  v_data BYTEA;
  v_parts TEXT[];
  v_payload TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Niet ingelogd';
  END IF;
  IF NOT is_ventoz_staff() THEN
    RAISE EXCEPTION 'Geen rechten';
  END IF;

  IF p_ciphertext IS NULL OR p_ciphertext = '' OR NOT p_ciphertext LIKE 'ENC:%' THEN
    RETURN p_ciphertext;
  END IF;

  v_payload := substring(p_ciphertext FROM 5);
  v_parts := string_to_array(v_payload, ':');
  IF array_length(v_parts, 1) != 2 THEN
    RETURN p_ciphertext;
  END IF;

  SELECT decode(encryption_key, 'base64') INTO v_key FROM vault_keys WHERE id = 1;
  IF v_key IS NULL THEN
    RAISE EXCEPTION 'Encryption key niet geconfigureerd';
  END IF;

  v_iv := decode(v_parts[1], 'base64');
  v_data := decode(v_parts[2], 'base64');
  RETURN convert_from(decrypt_iv(v_data, v_key, v_iv, 'aes-cbc/pad:pkcs'), 'UTF8');
END;
$$;

-- Batch encrypt: versleutelt meerdere velden in een JSON-object
CREATE OR REPLACE FUNCTION encrypt_settings_secrets(p_settings JSONB, p_secret_fields TEXT[])
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_field TEXT;
  v_value TEXT;
  v_result JSONB := p_settings;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Niet ingelogd';
  END IF;
  IF NOT is_ventoz_staff() THEN
    RAISE EXCEPTION 'Geen rechten';
  END IF;

  FOREACH v_field IN ARRAY p_secret_fields
  LOOP
    v_value := v_result ->> v_field;
    IF v_value IS NOT NULL AND v_value != '' AND NOT v_value LIKE 'ENC:%' THEN
      v_result := jsonb_set(v_result, ARRAY[v_field], to_jsonb(encrypt_secret(v_value)));
    END IF;
  END LOOP;
  RETURN v_result;
END;
$$;

-- Batch decrypt: ontsleutelt meerdere velden in een JSON-object
CREATE OR REPLACE FUNCTION decrypt_settings_secrets(p_settings JSONB, p_secret_fields TEXT[])
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_field TEXT;
  v_value TEXT;
  v_result JSONB := p_settings;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Niet ingelogd';
  END IF;
  IF NOT is_ventoz_staff() THEN
    RAISE EXCEPTION 'Geen rechten';
  END IF;

  FOREACH v_field IN ARRAY p_secret_fields
  LOOP
    v_value := v_result ->> v_field;
    IF v_value IS NOT NULL AND v_value LIKE 'ENC:%' THEN
      v_result := jsonb_set(v_result, ARRAY[v_field], to_jsonb(decrypt_secret(v_value)));
    END IF;
  END LOOP;
  RETURN v_result;
END;
$$;

-- ============================================================
-- VOORRAADBEHEERSYSTEEM
-- ============================================================

-- EAN-code kolom op product_catalogus
ALTER TABLE product_catalogus ADD COLUMN IF NOT EXISTS ean_code TEXT;

-- 1. EAN Register – alle 100+ EAN-codes met toewijzing
CREATE TABLE IF NOT EXISTS ean_registry (
  id SERIAL PRIMARY KEY,
  artikelnummer INTEGER NOT NULL,
  ean_code TEXT NOT NULL UNIQUE,
  product_naam TEXT,
  variant TEXT,
  kleur TEXT,
  opmerking TEXT,
  actief BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE ean_registry ENABLE ROW LEVEL SECURITY;

CREATE POLICY ean_registry_select ON ean_registry
    FOR SELECT TO authenticated USING (is_ventoz_staff());
CREATE POLICY ean_registry_insert ON ean_registry
    FOR INSERT TO authenticated WITH CHECK (is_ventoz_staff());
CREATE POLICY ean_registry_update ON ean_registry
    FOR UPDATE TO authenticated USING (is_ventoz_staff()) WITH CHECK (is_ventoz_staff());
CREATE POLICY ean_registry_delete ON ean_registry
    FOR DELETE TO authenticated USING (is_ventoz_admin());

-- 2. Voorraad per productvariant
CREATE TABLE IF NOT EXISTS inventory_items (
  id SERIAL PRIMARY KEY,
  product_id INTEGER REFERENCES product_catalogus(id) ON DELETE SET NULL,
  ean_code TEXT,
  artikelnummer TEXT,
  variant_label TEXT NOT NULL DEFAULT '',
  kleur TEXT NOT NULL DEFAULT '',
  leverancier_code TEXT,
  voorraad_actueel INTEGER NOT NULL DEFAULT 0,
  voorraad_minimum INTEGER NOT NULL DEFAULT 0,
  voorraad_besteld INTEGER NOT NULL DEFAULT 0,
  inkoop_prijs NUMERIC(10,2),
  vliegtuig_kosten NUMERIC(10,2),
  invoertax_admin NUMERIC(10,2),
  inkoop_totaal NUMERIC(10,2),
  netto_inkoop NUMERIC(10,2),
  netto_inkoop_waarde NUMERIC(10,2),
  import_kosten NUMERIC(10,2),
  bruto_inkoop NUMERIC(10,2),
  verkoopprijs_incl NUMERIC(10,2),
  verkoopprijs_excl NUMERIC(10,2),
  verkoop_waarde_excl NUMERIC(10,2),
  verkoop_waarde_incl NUMERIC(10,2),
  marge NUMERIC(10,4),
  vervoer_methode TEXT,
  opmerking TEXT,
  gewicht_gram INTEGER,
  gewicht_verpakking_gram INTEGER,
  laatst_bijgewerkt TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE inventory_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY inventory_items_select ON inventory_items
    FOR SELECT TO authenticated USING (is_ventoz_staff());
CREATE POLICY inventory_items_insert ON inventory_items
    FOR INSERT TO authenticated WITH CHECK (is_ventoz_staff());
CREATE POLICY inventory_items_update ON inventory_items
    FOR UPDATE TO authenticated USING (is_ventoz_staff()) WITH CHECK (is_ventoz_staff());
CREATE POLICY inventory_items_delete ON inventory_items
    FOR DELETE TO authenticated USING (is_ventoz_admin());

-- 3. Mutatie-logboek
CREATE TABLE IF NOT EXISTS inventory_mutations (
  id SERIAL PRIMARY KEY,
  inventory_item_id INTEGER NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
  hoeveelheid_delta INTEGER NOT NULL,
  reden TEXT NOT NULL DEFAULT '',
  bron TEXT NOT NULL DEFAULT 'handmatig',
  gebruiker_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE inventory_mutations ENABLE ROW LEVEL SECURITY;

CREATE POLICY inv_mutations_select ON inventory_mutations
    FOR SELECT TO authenticated USING (is_ventoz_staff());
CREATE POLICY inv_mutations_insert ON inventory_mutations
    FOR INSERT TO authenticated WITH CHECK (is_ventoz_staff());
CREATE POLICY inv_mutations_no_update ON inventory_mutations
    FOR UPDATE TO authenticated USING (false);
CREATE POLICY inv_mutations_delete ON inventory_mutations
    FOR DELETE TO authenticated USING (is_ventoz_admin());

-- 4. Zeilnummers en zeilletters
CREATE TABLE IF NOT EXISTS sail_numbers_letters (
  id SERIAL PRIMARY KEY,
  type TEXT NOT NULL CHECK (type IN ('nummer', 'letter')),
  waarde TEXT NOT NULL,
  maat_mm INTEGER NOT NULL CHECK (maat_mm IN (230, 300)),
  voorraad INTEGER NOT NULL DEFAULT 0,
  opmerking TEXT,
  laatst_bijgewerkt TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (type, waarde, maat_mm)
);

ALTER TABLE sail_numbers_letters ENABLE ROW LEVEL SECURITY;

CREATE POLICY sail_nl_select ON sail_numbers_letters
    FOR SELECT TO authenticated USING (is_ventoz_staff());
CREATE POLICY sail_nl_insert ON sail_numbers_letters
    FOR INSERT TO authenticated WITH CHECK (is_ventoz_staff());
CREATE POLICY sail_nl_update ON sail_numbers_letters
    FOR UPDATE TO authenticated USING (is_ventoz_staff()) WITH CHECK (is_ventoz_staff());
CREATE POLICY sail_nl_delete ON sail_numbers_letters
    FOR DELETE TO authenticated USING (is_ventoz_admin());

-- ============================================================
-- VERIFICATIE
-- ============================================================
