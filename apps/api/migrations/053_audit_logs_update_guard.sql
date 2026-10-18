-- Migration 053: audit_logs immutability as triggers (F-01)
--
-- Migration 026 made audit_logs immutable with DO INSTEAD NOTHING rules.
-- Those rules break two things:
--   1. The retention archive (migration 051) runs DELETE ... RETURNING,
--      which PostgreSQL rejects on a relation with a DO INSTEAD rule.
--   2. Deleting a user or establishment that has audit rows fails, because
--      the ON DELETE SET NULL foreign key cascades as an UPDATE, which the
--      rule silently swallows.
--
-- Replace the rules with triggers:
--   - UPDATE is blocked for every app-level statement. The only exception is
--     the foreign-key cascade that clears user_id or establishment_id to NULL
--     (pg_trigger_depth() > 1), and nothing else in the row may change.
--   - DELETE is blocked unless the retention archive sets
--     idetect.audit_archive = 'on' (trigger from migration 051).

DROP RULE IF EXISTS no_delete_audit_logs ON audit_logs;
DROP RULE IF EXISTS no_update_audit_logs ON audit_logs;

CREATE OR REPLACE FUNCTION protect_audit_logs_from_update()
RETURNS trigger AS $$
BEGIN
  IF pg_trigger_depth() > 1
     AND (NEW.user_id IS NULL OR NEW.user_id = OLD.user_id)
     AND (NEW.establishment_id IS NULL OR NEW.establishment_id = OLD.establishment_id)
     AND to_jsonb(NEW) - 'user_id' - 'establishment_id'
         = to_jsonb(OLD) - 'user_id' - 'establishment_id'
  THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'audit_logs rows are immutable and cannot be updated';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_logs_protect_update ON audit_logs;
CREATE TRIGGER trg_audit_logs_protect_update
  BEFORE UPDATE ON audit_logs
  FOR EACH ROW EXECUTE FUNCTION protect_audit_logs_from_update();
