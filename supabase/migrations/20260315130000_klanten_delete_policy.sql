-- Ensure authenticated users can delete customers.
-- Also ensure klant_externe_nummers can be deleted for the customer.

DROP POLICY IF EXISTS klanten_delete_auth ON klanten;
CREATE POLICY klanten_delete_auth ON klanten
    FOR DELETE TO authenticated
    USING (true);

DROP POLICY IF EXISTS klant_externe_nummers_delete_auth ON klant_externe_nummers;
CREATE POLICY klant_externe_nummers_delete_auth ON klant_externe_nummers
    FOR DELETE TO authenticated
    USING (true);

-- Also ensure orders.klant_id is NULLed when a customer is deleted,
-- rather than blocking the delete.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name LIKE '%klant_id%' AND table_name = 'orders'
  ) THEN
    ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_klant_id_fkey;
  END IF;
END $$;
