-- ============================================================
-- Migration 010: Add PIN hash to beneficiary_accounts
-- Allows beneficiaries to set a 4-digit PIN as a fallback
-- login method when biometrics are unavailable.
-- ============================================================

ALTER TABLE beneficiary_accounts
  ADD COLUMN IF NOT EXISTS pin_hash VARCHAR(255),
  ADD COLUMN IF NOT EXISTS pin_attempts SMALLINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS pin_locked_until TIMESTAMPTZ;

COMMENT ON COLUMN beneficiary_accounts.pin_hash        IS 'Bcrypt-hashed 4-digit PIN for fallback login.';
COMMENT ON COLUMN beneficiary_accounts.pin_attempts     IS 'Failed PIN attempts. Lock after 5.';
COMMENT ON COLUMN beneficiary_accounts.pin_locked_until IS 'Timestamp until which PIN login is locked due to too many attempts.';
