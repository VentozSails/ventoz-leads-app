-- Add match_excluded column to inventory_items for excluding items from matching
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS match_excluded boolean NOT NULL DEFAULT false;
