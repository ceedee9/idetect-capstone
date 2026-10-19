-- ============================================================
-- Migration 059: single active phone per beneficiary account.
-- session_version is incremented on every successful beneficiary login
-- (OTP verification or PIN login). Tokens carry the version they were
-- issued with, and authenticateBeneficiary rejects any token whose version
-- no longer matches, which signs out the previously active phone.
-- ============================================================

ALTER TABLE beneficiary_accounts
  ADD COLUMN IF NOT EXISTS session_version INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN beneficiary_accounts.session_version IS 'Incremented on each successful login. Tokens issued with an older version are rejected, so only one phone stays signed in.';
