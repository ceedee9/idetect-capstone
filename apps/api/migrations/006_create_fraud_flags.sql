-- ============================================================
-- Migration 006: fraud_flags
-- Created when an establishment flags a suspicious credential
-- during or after a verification. Automatically routed to
-- OSCA (senior_citizen) or PDAO (pwd) based on beneficiary type.
-- When status → 'confirmed', beneficiaries.status is set to
-- 'suspended' or 'revoked' — propagating across the network.
-- ============================================================

CREATE TYPE flag_status AS ENUM (
  'pending',    -- Flagged by establishment, awaiting LGU review
  'reviewing',  -- LGU admin has opened the case
  'confirmed',  -- Confirmed fraudulent — beneficiary record updated
  'dismissed'   -- Investigated, found to be legitimate
);

CREATE TABLE fraud_flags (
  id                    UUID         PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Source of the flag
  verification_log_id   UUID         NOT NULL REFERENCES verification_logs(id) ON DELETE RESTRICT,
  establishment_id      UUID         NOT NULL REFERENCES establishments(id) ON DELETE RESTRICT,

  -- Subject of the flag
  beneficiary_id        UUID         REFERENCES beneficiaries(id) ON DELETE SET NULL,
  id_number_flagged     VARCHAR(50)  NOT NULL,  -- Stored directly in case beneficiary_id is NULL
  beneficiary_type      beneficiary_type NOT NULL, -- Routes flag to correct portal

  -- Investigation
  flag_status           flag_status  NOT NULL DEFAULT 'pending',
  establishment_notes   TEXT,         -- Optional notes from the establishment
  staff_notes           TEXT,         -- Notes from OSCA/PDAO investigator
  reviewed_by           UUID         REFERENCES users(id) ON DELETE SET NULL,

  flagged_at            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  reviewed_at           TIMESTAMPTZ
);

CREATE INDEX idx_fraud_flags_status           ON fraud_flags(flag_status);
CREATE INDEX idx_fraud_flags_beneficiary_type ON fraud_flags(beneficiary_type);
CREATE INDEX idx_fraud_flags_beneficiary_id   ON fraud_flags(beneficiary_id);
CREATE INDEX idx_fraud_flags_flagged_at       ON fraud_flags(flagged_at DESC);
-- Portal query: OSCA sees pending senior_citizen flags
CREATE INDEX idx_fraud_flags_type_status      ON fraud_flags(beneficiary_type, flag_status);

COMMENT ON TABLE  fraud_flags                     IS 'Suspicious ID reports from establishments, routed to OSCA or PDAO for investigation.';
COMMENT ON COLUMN fraud_flags.beneficiary_type    IS 'Determines which portal owns this flag: senior_citizen → OSCA, pwd → PDAO.';
COMMENT ON COLUMN fraud_flags.id_number_flagged   IS 'Stored directly so flagged IDs can be tracked even if no matching DB record exists.';
