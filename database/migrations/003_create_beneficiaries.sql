-- ============================================================
-- Migration 003: beneficiaries
-- The core government record for Senior Citizens and PWDs.
-- Source of truth synced from / maintained by OSCA and PDAO.
-- OSCA staff only see rows where type = 'senior_citizen'.
-- PDAO staff only see rows where type = 'pwd'.
-- This compartmentalization is enforced at the API layer.
-- ============================================================

CREATE TYPE beneficiary_type AS ENUM (
  'senior_citizen',
  'pwd'
);

CREATE TYPE beneficiary_status AS ENUM (
  'active',       -- Valid, can receive discounts
  'expired',      -- Past validity_end date
  'suspended',    -- Temporarily flagged pending investigation
  'revoked'       -- Confirmed fraudulent or cancelled by LGU
);

CREATE TABLE beneficiaries (
  id                UUID               PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Identity (matches what is printed on the physical ID)
  id_number         VARCHAR(50)        NOT NULL UNIQUE,
  full_name         VARCHAR(255)       NOT NULL,
  birthdate         DATE               NOT NULL,
  beneficiary_type  beneficiary_type   NOT NULL,

  -- Credential details
  issuing_office    VARCHAR(255)       NOT NULL,  -- e.g. "OSCA Valenzuela"
  validity_start    DATE               NOT NULL,
  validity_end      DATE               NOT NULL,

  -- Record status
  status            beneficiary_status NOT NULL DEFAULT 'active',
  status_reason     TEXT,                          -- Filled when suspended/revoked

  -- Optional: registered mobile for SMS notifications
  registered_mobile VARCHAR(20),

  -- Managed by
  created_by        UUID               REFERENCES users(id) ON DELETE SET NULL,
  updated_by        UUID               REFERENCES users(id) ON DELETE SET NULL,

  created_at        TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ        NOT NULL DEFAULT NOW()
);

-- The two most common lookups: by ID number (verification) and by type (portal filtering)
CREATE INDEX idx_beneficiaries_id_number        ON beneficiaries(id_number);
CREATE INDEX idx_beneficiaries_type             ON beneficiaries(beneficiary_type);
CREATE INDEX idx_beneficiaries_status           ON beneficiaries(status);
CREATE INDEX idx_beneficiaries_type_status      ON beneficiaries(beneficiary_type, status);

CREATE TRIGGER trg_beneficiaries_updated_at
  BEFORE UPDATE ON beneficiaries
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMENT ON TABLE  beneficiaries                  IS 'Official government records for Senior Citizens and PWDs. Managed by OSCA and PDAO.';
COMMENT ON COLUMN beneficiaries.id_number        IS 'The ID number printed on the physical card. Used as the primary lookup key during verification.';
COMMENT ON COLUMN beneficiaries.beneficiary_type IS 'Determines which LGU office owns this record: senior_citizen → OSCA, pwd → PDAO.';
COMMENT ON COLUMN beneficiaries.status           IS 'Verification result depends on this value. Only "active" IDs return VALID.';
