-- ============================================================
-- Migration 042: establishment users
-- Adds individual establishment accounts while preserving the
-- legacy establishments.email/password_hash login during rollout.
-- ============================================================

CREATE TABLE IF NOT EXISTS establishment_users (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  establishment_id      UUID NOT NULL REFERENCES establishments(id) ON DELETE CASCADE,
  email                 VARCHAR(255) NOT NULL,
  password_hash         VARCHAR(255) NOT NULL,
  full_name             VARCHAR(255) NOT NULL,
  role                  VARCHAR(40) NOT NULL DEFAULT 'establishment_regular_user',
  account_status        VARCHAR(30) NOT NULL DEFAULT 'active',
  invitation_status     VARCHAR(30) NOT NULL DEFAULT 'accepted',
  created_by_user_id    UUID REFERENCES establishment_users(id) ON DELETE SET NULL,
  approved_by_user_id   UUID REFERENCES establishment_users(id) ON DELETE SET NULL,
  approved_at           TIMESTAMPTZ,
  password_reset_required BOOLEAN NOT NULL DEFAULT FALSE,
  failed_attempts       SMALLINT NOT NULL DEFAULT 0,
  locked_until          TIMESTAMPTZ,
  last_login_at         TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT establishment_users_role_check
    CHECK (role IN ('establishment_super_user', 'establishment_regular_user')),
  CONSTRAINT establishment_users_status_check
    CHECK (account_status IN ('active', 'inactive', 'suspended', 'locked')),
  CONSTRAINT establishment_users_invitation_check
    CHECK (invitation_status IN ('pending', 'accepted', 'expired', 'revoked'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_establishment_users_email
  ON establishment_users (lower(email));
CREATE INDEX IF NOT EXISTS idx_establishment_users_establishment
  ON establishment_users (establishment_id);
CREATE INDEX IF NOT EXISTS idx_establishment_users_status
  ON establishment_users (account_status);

CREATE OR REPLACE FUNCTION set_establishment_users_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_establishment_users_updated_at ON establishment_users;
CREATE TRIGGER trg_establishment_users_updated_at
  BEFORE UPDATE ON establishment_users
  FOR EACH ROW EXECUTE FUNCTION set_establishment_users_updated_at();

ALTER TABLE verification_logs
  ADD COLUMN IF NOT EXISTS establishment_user_id UUID
  REFERENCES establishment_users(id) ON DELETE SET NULL;

ALTER TABLE fraud_flags
  ADD COLUMN IF NOT EXISTS establishment_user_id UUID
  REFERENCES establishment_users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_verification_logs_establishment_user
  ON verification_logs(establishment_user_id);
CREATE INDEX IF NOT EXISTS idx_fraud_flags_establishment_user
  ON fraud_flags(establishment_user_id);

ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_user_login';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_user_login_failed';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_user_logout';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_user_invited';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_user_created';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_user_activated';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_user_deactivated';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_user_password_reset';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_user_role_changed';

INSERT INTO establishment_users (
  establishment_id,
  email,
  password_hash,
  full_name,
  role,
  account_status,
  invitation_status,
  approved_at
)
SELECT
  e.id,
  e.email,
  e.password_hash,
  e.owner_name,
  'establishment_super_user',
  CASE WHEN e.status = 'approved' THEN 'active' ELSE 'inactive' END,
  'accepted',
  e.approved_at
FROM establishments e
WHERE NOT EXISTS (
  SELECT 1
  FROM establishment_users eu
  WHERE eu.establishment_id = e.id
);

COMMENT ON TABLE establishment_users IS
  'Individual establishment accounts. Existing establishment logins are migrated as Super Users.';
COMMENT ON COLUMN establishment_users.establishment_id IS
  'Immutable tenant relationship; never accept this value from a client request.';
COMMENT ON COLUMN establishment_users.password_reset_required IS
  'Forces the user through a password reset before protected operations.';
