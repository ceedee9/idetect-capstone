-- ============================================================
-- Migration 021: cross_validation_and_normalization
--
-- 1. Adds OCR cross-validation tracking columns to verification_logs:
--    extracted_name, extracted_dob, name_match_score, fields_matched.
--    Records whether the OCR-extracted name and DOB matched the stored
--    beneficiary record. Enables post-hoc audits of failed validations.
--
-- 2. Adds a unique expression index on the normalized id_number in
--    beneficiaries. Prevents duplicate IDs that differ only in
--    punctuation (e.g. OSC-2024-001 vs OSC2024001 vs osc2024001).
--    The normalization formula matches verification.js normalizeIdNumber():
--      UPPER(REGEXP_REPLACE(id_number, '[^A-Za-z0-9]', '', 'g'))
--
-- NOTE: If existing data contains duplicate normalized IDs, the index
-- creation on line 43 will fail with a "unique violation" error.
-- Run a deduplication query first if needed:
--   DELETE FROM beneficiaries
--   WHERE id NOT IN (
--     SELECT MIN(id::text)::uuid
--     FROM beneficiaries
--     GROUP BY UPPER(REGEXP_REPLACE(id_number, '[^A-Za-z0-9]', '', 'g'))
--   );
-- ============================================================

-- ── 1. Cross-validation columns on verification_logs ──────────

ALTER TABLE verification_logs
  ADD COLUMN IF NOT EXISTS extracted_name   VARCHAR(255),
  ADD COLUMN IF NOT EXISTS extracted_dob    DATE,
  ADD COLUMN IF NOT EXISTS name_match_score NUMERIC(4,3),
  ADD COLUMN IF NOT EXISTS fields_matched   BOOLEAN;

COMMENT ON COLUMN verification_logs.extracted_name
  IS 'Full name as read from the card by OCR, compared against beneficiaries.full_name.';
COMMENT ON COLUMN verification_logs.extracted_dob
  IS 'Date of birth as read from the card by OCR, compared against beneficiaries.birthdate.';
COMMENT ON COLUMN verification_logs.name_match_score
  IS 'Jaro-Winkler similarity score between extracted_name and stored full_name (0.000–1.000). NULL when no name cross-validation was attempted.';
COMMENT ON COLUMN verification_logs.fields_matched
  IS 'TRUE when all provided cross-validation fields matched the stored record. FALSE if any mismatch downgraded the result to SUSPICIOUS. NULL when no cross-validation fields were provided.';

-- ── 2. Unique expression index on normalized id_number ─────────

-- Prevents storing OSC-2024-001 and OSC2024001 as separate beneficiary
-- records. Both normalize to OSC2024001, so the index treats them as
-- the same record.
CREATE UNIQUE INDEX IF NOT EXISTS idx_beneficiaries_id_number_normalized
  ON beneficiaries (UPPER(REGEXP_REPLACE(id_number, '[^A-Za-z0-9]', '', 'g')));
