-- Preserve immutable scan data while allowing ON DELETE SET NULL to clear only
-- the optional beneficiary reference when a revoked beneficiary is deleted.
DROP RULE IF EXISTS no_update_verification_logs ON verification_logs;

CREATE OR REPLACE FUNCTION protect_verification_log_immutability()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.beneficiary_id IS NOT NULL
     AND NEW.beneficiary_id IS NULL
     AND ROW(
       NEW.id,
       NEW.establishment_id,
       NEW.id_number_scanned,
       NEW.beneficiary_type_detected,
       NEW.result,
       NEW.ocr_confidence_score,
       NEW.ocr_raw_text,
       NEW.image_path,
       NEW.manually_entered,
       NEW.verified_at,
       NEW.id_format,
       NEW.synced_from_offline
     ) IS NOT DISTINCT FROM ROW(
       OLD.id,
       OLD.establishment_id,
       OLD.id_number_scanned,
       OLD.beneficiary_type_detected,
       OLD.result,
       OLD.ocr_confidence_score,
       OLD.ocr_raw_text,
       OLD.image_path,
       OLD.manually_entered,
       OLD.verified_at,
       OLD.id_format,
       OLD.synced_from_offline
     ) THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'verification_logs rows are immutable'
    USING ERRCODE = '55000';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_protect_verification_log_immutability
  ON verification_logs;

CREATE TRIGGER trg_protect_verification_log_immutability
  BEFORE UPDATE ON verification_logs
  FOR EACH ROW EXECUTE FUNCTION protect_verification_log_immutability();