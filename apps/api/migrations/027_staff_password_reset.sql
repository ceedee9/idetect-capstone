-- ============================================================
-- Migration 027: Staff self-service password reset
-- Adds reset_token and reset_token_expires to users table
-- so staff can reset their own password via emailed link.
-- ============================================================

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS reset_token         VARCHAR(64),
  ADD COLUMN IF NOT EXISTS reset_token_expires TIMESTAMPTZ;
