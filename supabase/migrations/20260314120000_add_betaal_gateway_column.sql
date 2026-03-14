-- Add betaal_gateway column to track which payment provider processed the transaction
ALTER TABLE orders ADD COLUMN IF NOT EXISTS betaal_gateway TEXT;
