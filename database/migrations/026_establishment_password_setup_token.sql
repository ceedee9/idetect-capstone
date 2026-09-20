-- ============================================================
-- Migration 026: establishment password-setup token
-- Replaces emailing a plaintext temporary password (frequently
-- blocked by mail providers as phishing-like content) with a
-- single-use, expiring setup link the establishment uses to
-- choose their own password.
-- ============================================================

ALTER TABLE establishments
  ADD COLUMN IF NOT EXISTS password_setup_token          VARCHAR(64),
  ADD COLUMN IF NOT EXISTS password_setup_token_expires  TIMESTAMPTZ;
