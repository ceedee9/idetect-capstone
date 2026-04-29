-- ============================================================
-- Migration 008: notifications
-- Push and SMS notifications sent to beneficiary app users.
-- Every verification attempt triggers a notification to the
-- beneficiary (if they have an account) — this is the
-- real-time transparency mechanism from the manuscript.
-- ============================================================

CREATE TYPE notification_channel AS ENUM (
  'push',   -- Firebase FCM / APNs push notification
  'sms'     -- SMS (works without app / data connection)
);

CREATE TYPE notification_type AS ENUM (
  'verification_approved',   -- ID was scanned and came back VALID
  'verification_denied',     -- ID came back SUSPICIOUS or INVALID
  'dispute_acknowledged',    -- LGU acknowledged their dispute
  'dispute_resolved',        -- Dispute has been closed
  'flag_confirmed',          -- Their ID was confirmed fraudulent (unauthorized use)
  'id_expiring_soon',        -- Upcoming expiration reminder
  'general'
);

CREATE TABLE notifications (
  id                      UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
  beneficiary_account_id  UUID                  NOT NULL REFERENCES beneficiary_accounts(id) ON DELETE CASCADE,

  -- Content
  notification_type       notification_type     NOT NULL,
  title                   VARCHAR(255)          NOT NULL,
  body                    TEXT                  NOT NULL,
  channel                 notification_channel  NOT NULL,

  -- Related records (for deep-linking in the app)
  verification_log_id     UUID                  REFERENCES verification_logs(id) ON DELETE SET NULL,
  dispute_id              UUID                  REFERENCES disputes(id) ON DELETE SET NULL,

  -- State
  is_read                 BOOLEAN               NOT NULL DEFAULT FALSE,
  sent_at                 TIMESTAMPTZ           NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_account_id ON notifications(beneficiary_account_id);
CREATE INDEX idx_notifications_is_read    ON notifications(beneficiary_account_id, is_read);
CREATE INDEX idx_notifications_sent_at    ON notifications(sent_at DESC);

COMMENT ON TABLE  notifications                    IS 'Push and SMS alerts sent to beneficiaries on each verification attempt.';
COMMENT ON COLUMN notifications.channel            IS 'SMS channel functions without smartphone data — serves beneficiaries without smartphones.';
COMMENT ON COLUMN notifications.verification_log_id IS 'Allows deep-linking from a notification to the specific transaction in the app.';
