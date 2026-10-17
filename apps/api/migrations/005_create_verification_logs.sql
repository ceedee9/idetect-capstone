-- ============================================================
-- Migration 005: verification_logs
-- Every single ID scan ever performed. This is the audit trail,
-- the source of fraud analytics, and the foundation for
-- the beneficiary's transaction history view.
-- Never delete rows from this table.
-- ============================================================

CREATE TYPE verification_result AS ENUM (
  'valid',        -- ID found in DB, status active, not expired
  'suspicious',   -- ID found but status is flagged/suspended
  'invalid',      -- ID not found in DB or status is revoked/expired
  'manual_review' -- OCR confidence too low, staff reviewed manually
);

CREATE TABLE verification_logs (
  id                    UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Who scanned, and what they scanned
  establishment_id      UUID                  NOT NULL REFERENCES establishments(id) ON DELETE RESTRICT,
  beneficiary_id        UUID                  REFERENCES beneficiaries(id) ON DELETE SET NULL,
    -- NULL when id_number_scanned does not match any record

  -- What the OCR / staff entered
  id_number_scanned     VARCHAR(50)           NOT NULL,
  beneficiary_type_detected  beneficiary_type,  -- Detected from the card image

  -- Outcome
  result                verification_result   NOT NULL,

  -- OCR metadata
  ocr_confidence_score  NUMERIC(5, 2),         -- 0.00 to 100.00
  ocr_raw_text          TEXT,                  -- Full raw OCR output for debugging
  image_path            VARCHAR(500),          -- Path/URL to stored ID image (Supabase Storage)
  manually_entered      BOOLEAN               NOT NULL DEFAULT FALSE,
    -- TRUE when staff typed ID number instead of scanning

  -- Timing
  verified_at           TIMESTAMPTZ           NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_verification_logs_establishment_id ON verification_logs(establishment_id);
CREATE INDEX idx_verification_logs_beneficiary_id   ON verification_logs(beneficiary_id);
CREATE INDEX idx_verification_logs_id_number        ON verification_logs(id_number_scanned);
CREATE INDEX idx_verification_logs_result           ON verification_logs(result);
CREATE INDEX idx_verification_logs_verified_at      ON verification_logs(verified_at DESC);
-- Composite: useful for per-establishment analytics dashboards
CREATE INDEX idx_verification_logs_est_date         ON verification_logs(establishment_id, verified_at DESC);

COMMENT ON TABLE  verification_logs                     IS 'Immutable log of every verification attempt. Never delete rows.';
COMMENT ON COLUMN verification_logs.beneficiary_id      IS 'NULL when no matching record was found in the database.';
COMMENT ON COLUMN verification_logs.ocr_confidence_score IS 'Extraction quality score (0-100): heuristic indicator based on text length, character ratios, and keyword presence. Not a true statistical OCR confidence. Below OCR_CONFIDENCE_THRESHOLD triggers manual_review.';
COMMENT ON COLUMN verification_logs.image_path          IS 'Supabase Storage URL of the captured ID image. Retained for fraud investigation.';
