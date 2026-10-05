-- F-04 phase 2: reference numbers for verification logs, e.g. VER-2026-000123.
--
-- verification_logs is immutable evidence (migration 026 turns UPDATE into a
-- no-op), so the existing rows cannot be numbered with a normal UPDATE. The
-- backfill below therefore removes the no-update rule, numbers the old rows
-- oldest-first, and restores the identical rule. The runner sends this file as
-- a single multi-statement query, which Postgres executes as one transaction:
-- if anything fails, the rule is never left dropped. No application data
-- other than the new reference_no column is modified.

CREATE SEQUENCE IF NOT EXISTS verification_reference_seq;

ALTER TABLE verification_logs ADD COLUMN IF NOT EXISTS reference_no VARCHAR(20);

DROP RULE IF EXISTS no_update_verification_logs ON verification_logs;

WITH numbered AS (
  SELECT id, verified_at,
         row_number() OVER (ORDER BY verified_at, id) AS n
  FROM verification_logs WHERE reference_no IS NULL
)
UPDATE verification_logs v
SET reference_no = 'VER-' || to_char(numbered.verified_at, 'YYYY') || '-' ||
                   lpad(numbered.n::text, 6, '0')
FROM numbered WHERE v.id = numbered.id;

CREATE RULE no_update_verification_logs
  AS ON UPDATE TO verification_logs
  DO INSTEAD NOTHING;

-- Continue after the highest existing number (safe to re-run).
SELECT setval('verification_reference_seq',
              GREATEST((SELECT MAX(right(reference_no, 6)::int) FROM verification_logs), 1),
              (SELECT COUNT(*) FROM verification_logs) > 0);

-- Defaults and constraints are table metadata, not row updates, so they are
-- not affected by the immutability rule.
ALTER TABLE verification_logs
  ALTER COLUMN reference_no SET DEFAULT next_reference('VER', 'verification_reference_seq', now()),
  ALTER COLUMN reference_no SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_verification_logs_reference_no
  ON verification_logs (reference_no);
