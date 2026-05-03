-- ============================================================
-- Migration 001: users
-- Staff/admin accounts for all three web portals.
-- Role drives data access at the API layer.
-- ============================================================

CREATE TYPE user_role AS ENUM (
  'bplo_admin',
  'osca_admin',
  'pdao_admin'
);

CREATE TABLE users (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email            VARCHAR(255) NOT NULL UNIQUE,
  password_hash    VARCHAR(255) NOT NULL,
  full_name        VARCHAR(255) NOT NULL,
  role             user_role    NOT NULL,
  is_active        BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Index for login lookup
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role  ON users(role);

-- Auto-update updated_at on any row change
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE  users              IS 'Admin staff accounts for BPLO, OSCA, and PDAO portals.';
COMMENT ON COLUMN users.role         IS 'Controls which portal the user can access and which data is visible.';
COMMENT ON COLUMN users.is_active    IS 'Soft-disable accounts without deleting audit history.';
