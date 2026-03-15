-- ============================================================
-- Security hardening migration
-- ============================================================

-- ── 1. RLS voor kanaal_valuta ──
ALTER TABLE kanaal_valuta ENABLE ROW LEVEL SECURITY;

CREATE POLICY kanaal_valuta_select_auth ON kanaal_valuta
    FOR SELECT TO authenticated USING (true);

CREATE POLICY kanaal_valuta_select_anon ON kanaal_valuta
    FOR SELECT TO anon USING (true);

CREATE POLICY kanaal_valuta_modify_auth ON kanaal_valuta
    FOR ALL TO authenticated
    USING (true) WITH CHECK (true);

-- ── 2. RLS voor wisselkoersen ──
ALTER TABLE wisselkoersen ENABLE ROW LEVEL SECURITY;

CREATE POLICY wisselkoersen_select_auth ON wisselkoersen
    FOR SELECT TO authenticated USING (true);

CREATE POLICY wisselkoersen_select_anon ON wisselkoersen
    FOR SELECT TO anon USING (true);

CREATE POLICY wisselkoersen_modify_auth ON wisselkoersen
    FOR ALL TO authenticated
    USING (true) WITH CHECK (true);

-- ── 3. Beperk anon toegang tot orders (was: USING (true)) ──
DROP POLICY IF EXISTS orders_select_anon ON orders;

CREATE POLICY orders_select_anon ON orders
    FOR SELECT TO anon
    USING (user_id IS NULL);

-- ── 4. Beperk anon toegang tot order_regels ──
DROP POLICY IF EXISTS order_regels_select_anon ON order_regels;

CREATE POLICY order_regels_select_anon ON order_regels
    FOR SELECT TO anon
    USING (
      EXISTS (
        SELECT 1 FROM orders
        WHERE orders.id = order_regels.order_id
        AND orders.user_id IS NULL
      )
    );

-- ── 5. Storage: beperk update/delete op product-images tot admins ──
DROP POLICY IF EXISTS "product_images_auth_update" ON storage.objects;
DROP POLICY IF EXISTS "product_images_auth_delete" ON storage.objects;

CREATE POLICY "product_images_admin_update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'product-images'
    AND EXISTS (
      SELECT 1 FROM ventoz_users
      WHERE ventoz_users.auth_user_id = auth.uid()
      AND (ventoz_users.is_owner = true OR ventoz_users.is_admin = true
           OR ventoz_users.user_type IN ('owner', 'admin'))
    )
  );

CREATE POLICY "product_images_admin_delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'product-images'
    AND EXISTS (
      SELECT 1 FROM ventoz_users
      WHERE ventoz_users.auth_user_id = auth.uid()
      AND (ventoz_users.is_owner = true OR ventoz_users.is_admin = true
           OR ventoz_users.user_type IN ('owner', 'admin'))
    )
  );
