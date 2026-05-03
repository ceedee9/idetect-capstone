-- ============================================================
-- Migration 023: unique person index
-- Prevents duplicate registration of the same person.
-- Expression index on (UPPER(full_name), birthdate, beneficiary_type)
-- ensures the same individual cannot appear twice in the same category.
--
-- NOTE: This migration will FAIL if duplicate person records already
-- exist in the beneficiaries table. Deduplicate first if needed.
-- ============================================================

CREATE UNIQUE INDEX IF NOT EXISTS idx_beneficiaries_unique_person
  ON beneficiaries (UPPER(full_name), birthdate, beneficiary_type);
