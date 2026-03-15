-- Imported invoices (from CSV) should not appear as "te verzenden".
-- They are historical records, not actual orders awaiting shipment.

-- Ensure verzonden_op column exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'orders' AND column_name = 'verzonden_op'
  ) THEN
    ALTER TABLE orders ADD COLUMN verzonden_op timestamptz;
  END IF;
END $$;

UPDATE orders
SET status = 'verzonden',
    verzonden_op = COALESCE(betaald_op, created_at),
    updated_at = now()
WHERE order_nummer LIKE 'INV-%'
  AND status = 'betaald';
