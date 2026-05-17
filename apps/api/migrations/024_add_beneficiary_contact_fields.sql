-- ============================================================
-- Migration 024: add contact fields to beneficiaries
-- The registration forms collect address, contact_number, and email
-- but these columns were missing from the original schema, causing
-- all submitted contact data to be silently discarded.
-- ============================================================

ALTER TABLE beneficiaries
  ADD COLUMN IF NOT EXISTS address        TEXT,
  ADD COLUMN IF NOT EXISTS contact_number VARCHAR(20),
  ADD COLUMN IF NOT EXISTS email          VARCHAR(255);
