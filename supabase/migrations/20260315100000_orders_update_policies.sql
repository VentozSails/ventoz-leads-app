-- ============================================================
-- Orders: UPDATE policies zodat betaalflow werkt
-- ============================================================

-- Anon gebruikers mogen hun eigen gastorders updaten (betaalstatus)
CREATE POLICY orders_update_anon ON orders
    FOR UPDATE TO anon
    USING (user_id IS NULL)
    WITH CHECK (user_id IS NULL);

-- Ingelogde gebruikers mogen hun eigen orders updaten
CREATE POLICY orders_update_own ON orders
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Ingelogde gebruikers mogen hun eigen orders lezen
CREATE POLICY orders_select_own ON orders
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- Ingelogde gebruikers mogen orders aanmaken
CREATE POLICY orders_insert_auth ON orders
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

-- Admin/owner mag alle orders beheren
CREATE POLICY orders_admin_all ON orders
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

-- Order regels: ingelogde gebruikers mogen regels van eigen orders lezen
CREATE POLICY order_regels_select_own ON order_regels
    FOR SELECT TO authenticated
    USING (
      EXISTS (SELECT 1 FROM orders WHERE orders.id = order_regels.order_id AND orders.user_id = auth.uid())
    );

-- Order regels: ingelogde gebruikers mogen regels toevoegen aan eigen orders
CREATE POLICY order_regels_insert_auth ON order_regels
    FOR INSERT TO authenticated
    WITH CHECK (
      EXISTS (SELECT 1 FROM orders WHERE orders.id = order_regels.order_id AND orders.user_id = auth.uid())
    );

-- Order regels: admin mag alles
CREATE POLICY order_regels_admin_all ON order_regels
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
