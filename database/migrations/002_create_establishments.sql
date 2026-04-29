-- ============================================================
-- Migration 002: establishments
-- Business accounts managed by BPLO.
-- Each establishment maps to one login (user_id) for
-- the mobile Client Portal.
-- ============================================================

CREATE TYPE establishment_status AS ENUM (
  'pending',    -- Registered, awaiting BPLO approval
  'approved',   -- Active, can perform verifications
  'suspended',  -- Temporarily blocked by BPLO
  'revoked'     -- Permanently removed
);

CREATE TABLE establishments (
  id                  UUID                 PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Auth: one dedicated login per establishment
  email               VARCHAR(255)         NOT NULL UNIQUE,
  password_hash       VARCHAR(255)         NOT NULL,

  -- Business identity
  business_name       VARCHAR(255)         NOT NULL,
  business_permit_no  VARCHAR(100)         NOT NULL UNIQUE,
  owner_name          VARCHAR(255)         NOT NULL,
  address             TEXT                 NOT NULL,
  contact_number      VARCHAR(20)          NOT NULL,
  business_type       VARCHAR(100)         NOT NULL DEFAULT 'Food Service',

  -- Account lifecycle
  status              establishment_status NOT NULL DEFAULT 'pending',
  approved_by         UUID                 REFERENCES users(id) ON DELETE SET NULL,
  approved_at         TIMESTAMPTZ,
  suspended_reason    TEXT,

  created_at          TIMESTAMPTZ          NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ          NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_establishments_status       ON establishments(status);
CREATE INDEX idx_establishments_permit_no    ON establishments(business_permit_no);

CREATE TRIGGER trg_establishments_updated_at
  BEFORE UPDATE ON establishments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE  establishments               IS 'Food service businesses registered to use the Client Portal.';
COMMENT ON COLUMN establishments.approved_by   IS 'BPLO admin user who approved this account.';
COMMENT ON COLUMN establishments.status        IS 'Only "approved" establishments can perform ID verifications.';
