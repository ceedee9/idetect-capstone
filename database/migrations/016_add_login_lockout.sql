-- ============================================================
-- Migration 016: Login lockout for staff and establishments
-- REQ-2.1.4: Lock after 3 consecutive failed login attempts.
-- ============================================================

-- Staff (portal admins)
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS failed_attempts SMALLINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS locked_until    TIMESTAMPTZ;

-- Establishments (mobile client portal)
ALTER TABLE establishments
  ADD COLUMN IF NOT EXISTS failed_attempts SMALLINT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS locked_until    TIMESTAMPTZ;

-- Also add new audit actions for lockout events
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'account_locked';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'account_unlocked';
