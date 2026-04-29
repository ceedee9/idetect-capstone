-- ============================================================
-- Migration 011: Add disability_type to beneficiaries
-- Only relevant for PWD records (beneficiary_type = 'pwd').
-- NULL for senior_citizen records.
-- ============================================================

ALTER TABLE beneficiaries
  ADD COLUMN disability_type VARCHAR(100);

COMMENT ON COLUMN beneficiaries.disability_type
  IS 'Type of disability (e.g. visual, hearing, mental, physical, psychosocial, learning, speech). Only for PWD records.';
