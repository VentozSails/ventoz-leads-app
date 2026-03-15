-- Stores which gateway to use for each payment method, and country availability
CREATE TABLE IF NOT EXISTS payment_method_preferences (
  id SERIAL PRIMARY KEY,
  method_id TEXT NOT NULL UNIQUE,       -- e.g. 'ideal', 'creditcard', 'paypal', 'bancontact'
  display_name TEXT NOT NULL,           -- e.g. 'iDEAL', 'Credit Card', 'PayPal'
  preferred_gateway TEXT NOT NULL,      -- 'pay_nl' or 'buckaroo'
  countries TEXT[] DEFAULT '{}',        -- ISO country codes where available; empty = all countries
  enabled BOOLEAN DEFAULT true,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE payment_method_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY pmp_select_all ON payment_method_preferences
  FOR SELECT USING (true);

CREATE POLICY pmp_admin_all ON payment_method_preferences
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM ventoz_users
      WHERE ventoz_users.auth_user_id = auth.uid()
      AND (ventoz_users.is_owner = true OR ventoz_users.is_admin = true
           OR ventoz_users.user_type IN ('owner', 'admin'))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM ventoz_users
      WHERE ventoz_users.auth_user_id = auth.uid()
      AND (ventoz_users.is_owner = true OR ventoz_users.is_admin = true
           OR ventoz_users.user_type IN ('owner', 'admin'))
    )
  );

-- Seed with common methods (you can adjust preferred_gateway and countries in the admin app)
INSERT INTO payment_method_preferences (method_id, display_name, preferred_gateway, countries, sort_order) VALUES
  ('ideal',        'iDEAL',                      'buckaroo', '{NL}',      1),
  ('bancontact',   'Bancontact',                  'pay_nl',   '{BE}',      2),
  ('creditcard',   'Credit Card (Visa/MC)',       'buckaroo', '{}',        3),
  ('paypal',       'PayPal',                      'buckaroo', '{}',        4),
  ('sofort',       'Sofort / Klarna',             'pay_nl',   '{DE,AT}',   5),
  ('banktransfer', 'Bank Transfer',               'pay_nl',   '{}',        6),
  ('eps',          'EPS',                         'pay_nl',   '{AT}',      7),
  ('giropay',      'Giropay',                     'pay_nl',   '{DE}',      8),
  ('applepay',     'Apple Pay',                   'buckaroo', '{}',        9)
ON CONFLICT (method_id) DO NOTHING;
