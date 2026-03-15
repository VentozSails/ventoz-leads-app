CREATE TABLE IF NOT EXISTS webhook_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source text NOT NULL DEFAULT 'unknown',
  event_type text NOT NULL DEFAULT 'unknown',
  payload jsonb,
  headers jsonb,
  received_at timestamptz NOT NULL DEFAULT now(),
  processed boolean NOT NULL DEFAULT false,
  processed_at timestamptz,
  error text
);

CREATE INDEX IF NOT EXISTS idx_webhook_events_source ON webhook_events (source);
CREATE INDEX IF NOT EXISTS idx_webhook_events_processed ON webhook_events (processed) WHERE NOT processed;

ALTER TABLE webhook_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can read webhook events"
  ON webhook_events FOR SELECT
  TO authenticated
  USING (true);
