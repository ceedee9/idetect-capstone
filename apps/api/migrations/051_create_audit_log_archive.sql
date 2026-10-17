-- Migration 051: audit-log retention archive (policy F-03)
-- Audit logs older than 5 years are MOVED to audit_logs_archive, never deleted.
-- The live audit_logs table only allows DELETE inside the archive job,
-- which sets the transaction-local flag idetect.audit_archive = 'on'.

ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'audit_logs_archived';

CREATE TABLE IF NOT EXISTS audit_logs_archive (
  id               UUID          PRIMARY KEY,
  user_id          UUID,
  establishment_id UUID,
  action           audit_action  NOT NULL,
  target_table     VARCHAR(100),
  target_id        UUID,
  metadata         JSONB,
  ip_address       INET,
  user_agent       TEXT,
  created_at       TIMESTAMPTZ   NOT NULL,
  archived_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  archived_by      UUID
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_archive_created_at
  ON audit_logs_archive(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_archive_archived_at
  ON audit_logs_archive(archived_at);

CREATE OR REPLACE FUNCTION protect_audit_logs_from_delete()
RETURNS trigger AS $$
BEGIN
  IF current_setting('idetect.audit_archive', true) IS DISTINCT FROM 'on' THEN
    RAISE EXCEPTION 'audit_logs rows can only be removed by the retention archive';
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_logs_protect_delete ON audit_logs;
CREATE TRIGGER trg_audit_logs_protect_delete
  BEFORE DELETE ON audit_logs
  FOR EACH ROW EXECUTE FUNCTION protect_audit_logs_from_delete();

CREATE OR REPLACE FUNCTION block_audit_logs_archive_change()
RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'audit_logs_archive is append-only and cannot be changed or deleted';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_logs_archive_append_only ON audit_logs_archive;
CREATE TRIGGER trg_audit_logs_archive_append_only
  BEFORE UPDATE OR DELETE ON audit_logs_archive
  FOR EACH ROW EXECUTE FUNCTION block_audit_logs_archive_change();
