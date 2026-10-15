-- Staff alerts need enough context for actionable, deduplicated notifications.
ALTER TABLE staff_alerts
  ADD COLUMN IF NOT EXISTS alert_type VARCHAR(80) NOT NULL DEFAULT 'general',
  ADD COLUMN IF NOT EXISTS severity VARCHAR(20) NOT NULL DEFAULT 'medium',
  ADD COLUMN IF NOT EXISTS target_route TEXT,
  ADD COLUMN IF NOT EXISTS related_dispute_id UUID REFERENCES disputes(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS dedupe_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_alerts_dedupe_key
  ON staff_alerts (dedupe_key)
  WHERE dedupe_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_staff_alerts_dispute
  ON staff_alerts (related_dispute_id);
