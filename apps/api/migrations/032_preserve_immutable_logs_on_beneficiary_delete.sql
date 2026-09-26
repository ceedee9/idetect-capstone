-- Verification logs are immutable historical evidence. Keep the original
-- beneficiary UUID as a historical reference instead of mutating the log via
-- ON DELETE SET NULL when a beneficiary record is permanently deleted.
ALTER TABLE verification_logs
  DROP CONSTRAINT IF EXISTS verification_logs_beneficiary_id_fkey;

DROP TRIGGER IF EXISTS trg_protect_verification_log_immutability
  ON verification_logs;
DROP FUNCTION IF EXISTS protect_verification_log_immutability();

DROP RULE IF EXISTS no_update_verification_logs ON verification_logs;
CREATE RULE no_update_verification_logs
  AS ON UPDATE TO verification_logs
  DO INSTEAD NOTHING;

COMMENT ON COLUMN verification_logs.beneficiary_id IS
  'Historical beneficiary UUID. It may refer to a permanently deleted record; retained unchanged for immutable scan history.';