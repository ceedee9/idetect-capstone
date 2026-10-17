-- ============================================================
-- Migration 007: disputes
-- Beneficiary-submitted challenges to incorrect denials.
-- Submitted via the Beneficiary Mobile App.
-- Routed to OSCA or PDAO based on the beneficiary's type.
-- SLA: 24h acknowledgment, 48-72h resolution.
-- ============================================================

CREATE TYPE dispute_type AS ENUM (
  'wrong_denial',           -- "I am valid but was denied"
  'unauthorized_use',       -- "My ID was used without my knowledge"
  'business_refusal',       -- "Business refused despite system approval"
  'incorrect_db_info',      -- "My record has wrong information"
  'other'                   -- Other dispute category
);

CREATE TYPE dispute_status AS ENUM (
  'submitted',      -- Just received
  'acknowledged',   -- LGU confirmed receipt (within 24h SLA)
  'under_review',   -- Staff actively investigating
  'resolved',       -- Closed with explanation
  'rejected'        -- Dispute found to be invalid
);

CREATE TABLE disputes (
  id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Who submitted
  beneficiary_account_id  UUID            NOT NULL REFERENCES beneficiary_accounts(id) ON DELETE RESTRICT,

  -- What transaction this is about
  verification_log_id     UUID            REFERENCES verification_logs(id) ON DELETE SET NULL,

  -- Dispute details
  dispute_type            dispute_type    NOT NULL,
  explanation             TEXT            NOT NULL,
  supporting_doc_path     VARCHAR(500),    -- Supabase Storage URL (ID photo, barangay cert, etc.)

  -- Resolution
  status                  dispute_status  NOT NULL DEFAULT 'submitted',
  staff_response          TEXT,
  handled_by              UUID            REFERENCES users(id) ON DELETE SET NULL,

  -- SLA tracking
  submitted_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  acknowledged_at         TIMESTAMPTZ,
  resolved_at             TIMESTAMPTZ
);

CREATE INDEX idx_disputes_beneficiary_account_id ON disputes(beneficiary_account_id);
CREATE INDEX idx_disputes_status                 ON disputes(status);
CREATE INDEX idx_disputes_submitted_at           ON disputes(submitted_at DESC);

COMMENT ON TABLE  disputes                       IS 'Beneficiary-submitted challenges to incorrect denials or database errors.';
COMMENT ON COLUMN disputes.dispute_type          IS 'Category selected for a beneficiary-submitted dispute.';
COMMENT ON COLUMN disputes.acknowledged_at       IS 'Must be filled within 24 hours of submission per SLA.';
COMMENT ON COLUMN disputes.resolved_at           IS 'Target: 48-72 hours from submission for database errors.';
