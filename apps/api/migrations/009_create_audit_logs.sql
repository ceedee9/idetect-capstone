-- ============================================================
-- Migration 009: audit_logs
-- Immutable record of every administrative action.
-- Covers: user logins, record changes, dispute handling,
-- flag confirmations, establishment approvals/suspensions.
-- Never delete or update rows in this table.
-- Required for ISO 25010 Security — Non-repudiation.
-- ============================================================

CREATE TYPE audit_action AS ENUM (
  -- Auth events
  'login',
  'logout',
  'password_changed',
  'otp_requested',
  'otp_verified',

  -- Beneficiary record management
  'beneficiary_created',
  'beneficiary_updated',
  'beneficiary_status_changed',

  -- Establishment management
  'establishment_approved',
  'establishment_suspended',
  'establishment_revoked',

  -- Fraud flag actions
  'flag_created',
  'flag_reviewed',
  'flag_confirmed',
  'flag_dismissed',

  -- Dispute actions
  'dispute_submitted',
  'dispute_acknowledged',
  'dispute_resolved',
  'dispute_rejected',

  -- System
  'data_export',
  'report_generated'
);

CREATE TABLE audit_logs (
  id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Who did it (NULL for system-generated actions)
  user_id       UUID          REFERENCES users(id) ON DELETE SET NULL,
  establishment_id UUID       REFERENCES establishments(id) ON DELETE SET NULL,

  -- What happened
  action        audit_action  NOT NULL,
  target_table  VARCHAR(100),
  target_id     UUID,

  -- Full context (before/after values, request body, etc.)
  metadata      JSONB         NOT NULL DEFAULT '{}',

  -- Where from
  ip_address    INET,
  user_agent    TEXT,

  created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Never add an updated_at trigger — rows must never change
CREATE INDEX idx_audit_logs_user_id       ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_action        ON audit_logs(action);
CREATE INDEX idx_audit_logs_target        ON audit_logs(target_table, target_id);
CREATE INDEX idx_audit_logs_created_at    ON audit_logs(created_at DESC);

COMMENT ON TABLE  audit_logs             IS 'Immutable audit trail. No row in this table should ever be updated or deleted.';
COMMENT ON COLUMN audit_logs.metadata    IS 'JSONB blob with full context: previous values, new values, request details.';
COMMENT ON COLUMN audit_logs.target_id   IS 'The UUID of the affected row (e.g. the beneficiary_id that was updated).';
