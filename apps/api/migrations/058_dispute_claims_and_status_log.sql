-- ============================================================
-- Migration 058: dispute claims, beneficiary response acknowledgement,
-- and dispute status history (A-09).
-- claimed_by/claimed_at: optional claim by one staff member. Claims are
--   advisory: a claim held by someone else blocks a new claim, but does
--   not block acknowledge or resolve.
-- beneficiary_acknowledged_at: when the beneficiary confirmed they read
--   the staff response.
-- dispute_status_logs: append-only history of status and claim changes.
-- ============================================================

ALTER TABLE disputes
  ADD COLUMN IF NOT EXISTS claimed_by                UUID        REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS claimed_at                TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS beneficiary_acknowledged_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS dispute_status_logs (
  id                            UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
  dispute_id                    UUID            NOT NULL REFERENCES disputes(id) ON DELETE CASCADE,
  action                        VARCHAR(40)     NOT NULL,
  from_status                   dispute_status,
  to_status                     dispute_status,
  actor_user_id                 UUID            REFERENCES users(id) ON DELETE SET NULL,
  actor_beneficiary_account_id  UUID            REFERENCES beneficiary_accounts(id) ON DELETE SET NULL,
  created_at                    TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dispute_status_logs_dispute_id
  ON dispute_status_logs(dispute_id, created_at);

COMMENT ON TABLE  dispute_status_logs IS 'Append-only history of dispute status, claim, and beneficiary acknowledgement events.';
COMMENT ON COLUMN disputes.claimed_by IS 'Staff member who claimed the dispute. Advisory; null when unclaimed.';
COMMENT ON COLUMN disputes.beneficiary_acknowledged_at IS 'When the beneficiary confirmed receipt of the staff response.';
