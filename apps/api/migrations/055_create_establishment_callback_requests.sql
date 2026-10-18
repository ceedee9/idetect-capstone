-- Migration 055: beneficiary callback requests to an establishment (A-18)
-- A beneficiary asks BPLO to contact an establishment on their behalf.
-- The establishment's phone number is never shown to the beneficiary; BPLO
-- relays the request. Only establishments the beneficiary has transacted with
-- can be requested (enforced in the API).

ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'callback_request_handled';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'callback_requested';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'callback_request_handled';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'callback_request_updated';

CREATE TABLE IF NOT EXISTS establishment_callback_requests (
  id                      UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  beneficiary_account_id  UUID          NOT NULL REFERENCES beneficiary_accounts(id) ON DELETE CASCADE,
  establishment_id        UUID          NOT NULL REFERENCES establishments(id) ON DELETE CASCADE,
  verification_log_id     UUID          REFERENCES verification_logs(id) ON DELETE SET NULL,

  reason                  VARCHAR(30)   NOT NULL,
  note                    VARCHAR(500),

  status                  VARCHAR(20)   NOT NULL DEFAULT 'open',
  staff_note              VARCHAR(300),
  handled_by              UUID          REFERENCES users(id) ON DELETE SET NULL,
  handled_at              TIMESTAMPTZ,

  created_at              TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

  CONSTRAINT callback_requests_reason_check
    CHECK (reason IN ('transaction_question', 'record_correction', 'other')),
  CONSTRAINT callback_requests_status_check
    CHECK (status IN ('open', 'handled')),
  CONSTRAINT callback_requests_handled_check
    CHECK ((status = 'handled') = (handled_at IS NOT NULL))
);

-- One open request per beneficiary per establishment.
CREATE UNIQUE INDEX IF NOT EXISTS idx_callback_requests_one_open
  ON establishment_callback_requests(beneficiary_account_id, establishment_id)
  WHERE status = 'open';

CREATE INDEX IF NOT EXISTS idx_callback_requests_status_created
  ON establishment_callback_requests(status, created_at DESC);

COMMENT ON TABLE establishment_callback_requests IS 'Beneficiary requests for BPLO to contact an establishment. The establishment phone number is never exposed to beneficiaries.';
COMMENT ON COLUMN establishment_callback_requests.reason IS 'Short-list reason chosen by the beneficiary: transaction_question, record_correction, or other.';
COMMENT ON COLUMN establishment_callback_requests.staff_note IS 'Short BPLO note shown to the beneficiary. Must not contain contact details.';
