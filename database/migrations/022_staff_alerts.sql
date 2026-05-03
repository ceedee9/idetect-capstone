-- ============================================================
-- Migration 022: staff_alerts
-- In-portal notification system for LGU admin staff.
-- Rows are inserted by the API when notable system events occur
-- (e.g. auto-suspension triggered by fraud flag threshold).
-- Portals poll this table to surface dismissible alert banners.
-- ============================================================

CREATE TABLE staff_alerts (
  id                     UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  target_role            user_role     NOT NULL,          -- 'osca_admin' | 'pdao_admin'
  title                  VARCHAR(255)  NOT NULL,
  body                   TEXT          NOT NULL,
  related_beneficiary_id UUID          REFERENCES beneficiaries(id) ON DELETE SET NULL,
  is_read                BOOLEAN       NOT NULL DEFAULT FALSE,
  created_at             TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Fast lookup: unread alerts for a given role, newest first
CREATE INDEX idx_staff_alerts_role_read
  ON staff_alerts (target_role, is_read, created_at DESC);
