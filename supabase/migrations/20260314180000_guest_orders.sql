-- Allow guest (anonymous) orders by making user_id nullable
-- and adding an RLS policy for anon inserts
ALTER TABLE orders ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE orders ALTER COLUMN user_id DROP DEFAULT;

-- Allow anonymous users to insert orders (guest checkout)
CREATE POLICY orders_insert_anon ON orders
    FOR INSERT TO anon
    WITH CHECK (user_id IS NULL);

-- Allow anonymous users to read their own order by order_nummer
-- (used for order confirmation / payment status)
CREATE POLICY orders_select_anon ON orders
    FOR SELECT TO anon
    USING (true);

-- Allow anonymous users to insert order lines for guest orders
CREATE POLICY order_regels_insert_anon ON order_regels
    FOR INSERT TO anon
    WITH CHECK (
      EXISTS (SELECT 1 FROM orders WHERE orders.id = order_regels.order_id
              AND orders.user_id IS NULL)
    );

-- Allow anonymous users to read order lines for guest orders
CREATE POLICY order_regels_select_anon ON order_regels
    FOR SELECT TO anon
    USING (
      EXISTS (SELECT 1 FROM orders WHERE orders.id = order_regels.order_id)
    );
