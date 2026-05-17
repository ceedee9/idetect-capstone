-- ============================================================
-- Migration 025: partial unique person index
-- Replaces the blanket unique index from migration 023 with a
-- partial one that excludes 'revoked' records. This allows a
-- person who was legitimately cleared to be re-registered without
-- needing to delete the old revoked record.
-- ============================================================

DROP INDEX IF EXISTS idx_beneficiaries_unique_person;

CREATE UNIQUE INDEX IF NOT EXISTS idx_beneficiaries_unique_person
  ON beneficiaries (UPPER(full_name), birthdate, beneficiary_type)
  WHERE status != 'revoked';
