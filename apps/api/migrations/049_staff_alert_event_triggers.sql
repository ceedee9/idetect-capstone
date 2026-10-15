-- Database-level staff alerts. Triggers fire for every API instance and every
-- submission path, so a notification-worthy event cannot be silently missed.
-- Alert text is intentionally privacy-safe: references only, no ID numbers,
-- birth dates, or free-text explanations.

CREATE INDEX IF NOT EXISTS idx_staff_alerts_created_at
  ON staff_alerts (created_at DESC);

-- ── Disputes ─────────────────────────────────────────────────────────────
-- Business-refusal disputes are visible to BPLO and to the beneficiary's own
-- office, so both are alerted. Every other type goes to the beneficiary's office.
CREATE OR REPLACE FUNCTION notify_staff_of_dispute_submission()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  beneficiary_kind TEXT;
  beneficiary_record_id UUID;
  office_role user_role;
  dispute_reference TEXT;
  target user_role;
BEGIN
  SELECT b.beneficiary_type::TEXT, b.id
    INTO beneficiary_kind, beneficiary_record_id
    FROM beneficiary_accounts ba
    JOIN beneficiaries b ON b.id = ba.beneficiary_id
   WHERE ba.id = NEW.beneficiary_account_id;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  office_role := CASE
    WHEN beneficiary_kind = 'senior_citizen' THEN 'osca_admin'::user_role
    ELSE 'pdao_admin'::user_role
  END;

  dispute_reference := COALESCE(
    NEW.reference_no,
    'DSP-' || UPPER(LEFT(NEW.id::TEXT, 8))
  );

  FOREACH target IN ARRAY (
    CASE
      WHEN NEW.dispute_type = 'business_refusal'
        THEN ARRAY['bplo_admin'::user_role, office_role]
      ELSE ARRAY[office_role]
    END
  )
  LOOP
    INSERT INTO staff_alerts (
      target_role, alert_type, severity, title, body, target_route,
      related_beneficiary_id, related_dispute_id, dedupe_key
    )
    VALUES (
      target,
      'dispute_submitted',
      'high',
      'New dispute submitted',
      'A beneficiary submitted dispute ' || dispute_reference ||
        '. Please review the dispute queue.',
      CASE WHEN target = 'bplo_admin' THEN '/business-refusals' ELSE '/disputes' END,
      beneficiary_record_id,
      NEW.id,
      'dispute_submitted:' || NEW.id::TEXT || ':' || target::TEXT
    )
    ON CONFLICT (dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING;
  END LOOP;

  RETURN NEW;
END;
$$;

-- Repair recent disputes that are missing an alert for an office that can
-- see them (the previous trigger alerted only one role).
INSERT INTO staff_alerts (
  target_role, alert_type, severity, title, body, target_route,
  related_beneficiary_id, related_dispute_id, dedupe_key
)
SELECT
  r.role,
  'dispute_submitted',
  'high',
  'New dispute submitted',
  'A beneficiary submitted dispute ' || d.reference_no ||
    '. Please review the dispute queue.',
  CASE WHEN r.role = 'bplo_admin' THEN '/business-refusals' ELSE '/disputes' END,
  b.id,
  d.id,
  'dispute_submitted:' || d.id::TEXT || ':' || r.role::TEXT
FROM disputes d
JOIN beneficiary_accounts ba ON ba.id = d.beneficiary_account_id
JOIN beneficiaries b ON b.id = ba.beneficiary_id
CROSS JOIN LATERAL (
  SELECT unnest(
    CASE
      WHEN d.dispute_type = 'business_refusal' THEN ARRAY[
        'bplo_admin'::user_role,
        CASE WHEN b.beneficiary_type = 'senior_citizen'
             THEN 'osca_admin'::user_role ELSE 'pdao_admin'::user_role END
      ]
      ELSE ARRAY[
        CASE WHEN b.beneficiary_type = 'senior_citizen'
             THEN 'osca_admin'::user_role ELSE 'pdao_admin'::user_role END
      ]
    END
  ) AS role
) r
WHERE d.submitted_at >= NOW() - INTERVAL '1 day'
  AND d.status IN ('submitted', 'acknowledged', 'under_review')
  AND NOT EXISTS (
    SELECT 1 FROM staff_alerts sa
     WHERE sa.related_dispute_id = d.id
       AND sa.target_role = r.role
  )
ON CONFLICT (dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING;

-- ── Fraud flags ──────────────────────────────────────────────────────────
-- Covers establishment flags, beneficiary self-reports, and unauthorized-use
-- reports, because they all create fraud_flags rows.
CREATE OR REPLACE FUNCTION notify_staff_of_fraud_flag()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO staff_alerts (
    target_role, alert_type, severity, title, body, target_route,
    related_beneficiary_id, dedupe_key
  )
  VALUES (
    CASE WHEN NEW.beneficiary_type = 'senior_citizen'
         THEN 'osca_admin'::user_role ELSE 'pdao_admin'::user_role END,
    'fraud_flag_created',
    'high',
    CASE WHEN COALESCE(NEW.is_supplementary, FALSE)
         THEN 'Additional fraud flag received'
         ELSE 'New fraud flag received' END,
    'Fraud flag ' || NEW.reference_no || ' is awaiting review.',
    '/fraud-flags',
    NEW.beneficiary_id,
    'fraud_flag_created:' || NEW.id::TEXT
  )
  ON CONFLICT (dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_staff_of_fraud_flag ON fraud_flags;
CREATE TRIGGER trg_notify_staff_of_fraud_flag
AFTER INSERT ON fraud_flags
FOR EACH ROW
EXECUTE FUNCTION notify_staff_of_fraud_flag();

-- ── Establishment self-registration ──────────────────────────────────────
CREATE OR REPLACE FUNCTION notify_staff_of_establishment_registration()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status <> 'pending' THEN
    RETURN NEW;
  END IF;

  INSERT INTO staff_alerts (
    target_role, alert_type, severity, title, body, target_route, dedupe_key
  )
  VALUES (
    'bplo_admin',
    'establishment_registration',
    'medium',
    'New establishment registration',
    NEW.business_name || ' (' || NEW.reference_no || ') is awaiting approval.',
    '/establishments',
    'establishment_registration:' || NEW.id::TEXT
  )
  ON CONFLICT (dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_staff_of_establishment_registration ON establishments;
CREATE TRIGGER trg_notify_staff_of_establishment_registration
AFTER INSERT ON establishments
FOR EACH ROW
EXECUTE FUNCTION notify_staff_of_establishment_registration();
