CREATE OR REPLACE FUNCTION notify_staff_of_dispute_submission()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  beneficiary_kind TEXT;
  beneficiary_record_id UUID;
  notification_role user_role;
  dispute_reference TEXT;
BEGIN
  SELECT b.beneficiary_type::TEXT, b.id
    INTO beneficiary_kind, beneficiary_record_id
    FROM beneficiary_accounts ba
    JOIN beneficiaries b ON b.id = ba.beneficiary_id
   WHERE ba.id = NEW.beneficiary_account_id;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  IF NEW.dispute_type = 'business_refusal' THEN
    notification_role := 'bplo_admin';
  ELSIF beneficiary_kind = 'senior_citizen' THEN
    notification_role := 'osca_admin';
  ELSE
    notification_role := 'pdao_admin';
  END IF;

  dispute_reference := COALESCE(
    NEW.reference_no,
    'DSP-' || UPPER(LEFT(NEW.id::TEXT, 8))
  );

  INSERT INTO staff_alerts (
    target_role,
    alert_type,
    severity,
    title,
    body,
    target_route,
    related_beneficiary_id,
    related_dispute_id,
    dedupe_key
  )
  VALUES (
    notification_role,
    'dispute_submitted',
    'high',
    'New dispute submitted',
    'A beneficiary submitted dispute ' || dispute_reference ||
      '. Please review the dispute queue.',
      '/disputes',
      beneficiary_record_id,
    NEW.id,
    'dispute_submitted:' || NEW.id::TEXT
  )
  ON CONFLICT (dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_staff_of_dispute_submission ON disputes;

CREATE TRIGGER trg_notify_staff_of_dispute_submission
AFTER INSERT ON disputes
FOR EACH ROW
EXECUTE FUNCTION notify_staff_of_dispute_submission();

INSERT INTO staff_alerts (
  target_role,
  alert_type,
  severity,
  title,
  body,
  target_route,
  related_beneficiary_id,
  related_dispute_id,
  dedupe_key
)
SELECT
  CASE
    WHEN d.dispute_type = 'business_refusal' THEN 'bplo_admin'::user_role
    WHEN b.beneficiary_type = 'senior_citizen' THEN 'osca_admin'::user_role
    ELSE 'pdao_admin'::user_role
  END,
  'dispute_submitted',
  'high',
  'New dispute submitted',
  'A beneficiary submitted dispute ' || d.reference_no ||
    '. Please review the dispute queue.',
  '/disputes',
  b.id,
  d.id,
  'dispute_submitted:' || d.id::TEXT
FROM disputes d
JOIN beneficiary_accounts ba ON ba.id = d.beneficiary_account_id
JOIN beneficiaries b ON b.id = ba.beneficiary_id
WHERE d.submitted_at >= NOW() - INTERVAL '1 day'
  AND d.status IN ('submitted', 'acknowledged', 'under_review')
  AND NOT EXISTS (
    SELECT 1
      FROM staff_alerts sa
     WHERE sa.related_dispute_id = d.id
  )
ON CONFLICT (dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING;
