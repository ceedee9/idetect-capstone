-- ============================================================
-- Migration 013: fraud_flags denormalization (REQ-2.6.2)
-- Add image_path and verification_outcome directly to fraud_flags
-- for quick access without JOINs. This optimizes portal performance
-- when displaying flagged ID details to OSCA/PDAO admins.
-- ============================================================

ALTER TABLE fraud_flags
  ADD COLUMN image_path VARCHAR(500),
  ADD COLUMN verification_outcome verification_result;

-- Backfill existing records by joining to verification_logs
UPDATE fraud_flags
SET
  image_path = vl.image_path,
  verification_outcome = vl.result
FROM verification_logs vl
WHERE fraud_flags.verification_log_id = vl.id;

-- Add index for image lookup
CREATE INDEX idx_fraud_flags_image_path ON fraud_flags(image_path) WHERE image_path IS NOT NULL;

COMMENT ON COLUMN fraud_flags.image_path IS 'Denormalized from verification_logs for quick access. Path/URL to captured ID image.';
COMMENT ON COLUMN fraud_flags.verification_outcome IS 'Denormalized from verification_logs. The result at time of flagging: valid, suspicious, invalid, manual_review.';
