-- Migration 045: establishment-user invitation tokens
ALTER TABLE establishment_users
  ADD COLUMN IF NOT EXISTS invitation_token_hash VARCHAR(64),
  ADD COLUMN IF NOT EXISTS invitation_token_expires TIMESTAMPTZ;

CREATE UNIQUE INDEX IF NOT EXISTS uq_establishment_users_invitation_token
  ON establishment_users(invitation_token_hash)
  WHERE invitation_token_hash IS NOT NULL;
