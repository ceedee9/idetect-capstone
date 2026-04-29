-- ============================================================
-- Migration 004: beneficiary_accounts
-- Mobile app accounts for the Beneficiary Portal.
-- Intentionally separated from beneficiaries:
-- a beneficiary exists in the system even without an app account.
-- Authentication: ID number + birthdate → OTP to registered mobile.
-- ============================================================

CREATE TABLE beneficiary_accounts (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  beneficiary_id    UUID        NOT NULL UNIQUE REFERENCES beneficiaries(id) ON DELETE CASCADE,

  -- Device / session
  device_token      VARCHAR(255),   -- FCM/APNs token for push notifications
  last_login        TIMESTAMPTZ,
  is_active         BOOLEAN     NOT NULL DEFAULT TRUE,

  -- OTP state (reset after each use)
  otp_hash          VARCHAR(255),
  otp_expires_at    TIMESTAMPTZ,
  otp_attempts      SMALLINT    NOT NULL DEFAULT 0,

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_beneficiary_accounts_beneficiary_id ON beneficiary_accounts(beneficiary_id);

CREATE TRIGGER trg_beneficiary_accounts_updated_at
  BEFORE UPDATE ON beneficiary_accounts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE  beneficiary_accounts               IS 'App accounts for Senior Citizens and PWDs using the Beneficiary Mobile App.';
COMMENT ON COLUMN beneficiary_accounts.otp_hash      IS 'Hashed OTP for the current login session. Cleared after successful verification.';
COMMENT ON COLUMN beneficiary_accounts.otp_attempts  IS 'Tracks brute-force attempts. Lock after threshold.';
COMMENT ON COLUMN beneficiary_accounts.device_token  IS 'Push notification token. Updated on each app launch.';
