-- Function to confirm a user's email address (used by confirm-user Edge Function)
CREATE OR REPLACE FUNCTION confirm_user_email(target_email text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE auth.users
  SET email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
      updated_at = NOW()
  WHERE lower(email) = lower(target_email);
END;
$$;
