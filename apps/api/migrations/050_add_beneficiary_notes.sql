-- ============================================================
-- Migration 050: add staff notes to beneficiaries
-- The record detail page displays and the edit form updates
-- a "Notes" field, but the column was never created.
-- ============================================================

ALTER TABLE beneficiaries
  ADD COLUMN IF NOT EXISTS notes TEXT;
