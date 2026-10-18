-- Migration 052: establishment-filed disputes on behalf of a beneficiary (A-10)
-- A beneficiary who cannot use the app asks the establishment to file the dispute.
-- The dispute still belongs to the beneficiary (beneficiary_account_id); these
-- columns record who filed it, and how the beneficiary made the request.
-- Existing rows keep filed_on_behalf = FALSE and no filer.

ALTER TABLE disputes
  ADD COLUMN IF NOT EXISTS filed_by_establishment_id UUID
    REFERENCES establishments(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS filed_by_user_id UUID
    REFERENCES establishment_users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS filed_on_behalf BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS request_channel VARCHAR(20);

ALTER TABLE disputes
  DROP CONSTRAINT IF EXISTS disputes_request_channel_check;
ALTER TABLE disputes
  ADD CONSTRAINT disputes_request_channel_check
    CHECK (request_channel IS NULL OR request_channel IN ('in_person', 'phone', 'written'));

ALTER TABLE disputes
  DROP CONSTRAINT IF EXISTS disputes_on_behalf_channel_check;
ALTER TABLE disputes
  ADD CONSTRAINT disputes_on_behalf_channel_check
    CHECK (filed_on_behalf = FALSE OR (request_channel IS NOT NULL AND filed_by_establishment_id IS NOT NULL));

CREATE INDEX IF NOT EXISTS idx_disputes_filed_by_establishment_id
  ON disputes(filed_by_establishment_id)
  WHERE filed_by_establishment_id IS NOT NULL;

COMMENT ON COLUMN disputes.filed_on_behalf IS 'TRUE when an establishment filed the dispute for a beneficiary who could not file it in the app.';
COMMENT ON COLUMN disputes.request_channel IS 'How the beneficiary asked for the filing: in_person, phone, or written.';
