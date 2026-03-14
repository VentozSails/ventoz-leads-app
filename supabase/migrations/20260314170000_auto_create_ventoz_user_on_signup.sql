-- Auto-create ventoz_users record when a new auth user signs up.
-- This ensures webshop registrations get a ventoz_users row automatically.

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO ventoz_users (auth_user_id, email, user_type, status, is_particulier)
  VALUES (
    NEW.id,
    lower(NEW.email),
    'klant',
    'geregistreerd',
    true
  )
  ON CONFLICT (email) DO UPDATE
    SET auth_user_id = EXCLUDED.auth_user_id,
        status = 'geregistreerd'
    WHERE ventoz_users.auth_user_id IS NULL;

  RETURN NEW;
END;
$$;

-- Drop existing trigger if present, then create
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Also add locked_until column if not present (for brute-force protection)
ALTER TABLE ventoz_users ADD COLUMN IF NOT EXISTS locked_until TIMESTAMPTZ;

-- Migrate legacy user_type values to current values
UPDATE ventoz_users SET user_type = 'admin', is_admin = true
  WHERE user_type = 'medewerker';
UPDATE ventoz_users SET user_type = 'klant'
  WHERE user_type IN ('klant_particulier', 'klant_organisatie');
UPDATE ventoz_users SET user_type = 'user'
  WHERE user_type = 'generiek';

-- Ensure the owner (first user / app_settings.app_owner) has correct flags
UPDATE ventoz_users SET
  user_type = 'owner',
  is_owner = true,
  is_admin = true,
  status = 'geregistreerd'
WHERE email = (
  SELECT lower((value->>'email')::text)
  FROM app_settings
  WHERE key = 'app_owner'
  LIMIT 1
)
AND (user_type != 'owner' OR is_owner = false);
