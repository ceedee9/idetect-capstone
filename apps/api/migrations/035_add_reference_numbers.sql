-- F-04: human-readable reference numbers, e.g. DSP-2026-000123.
--   DSP disputes | FLG fraud flags | EST establishments | BEN beneficiaries
-- Numbers come from a per-record-type sequence, so they are unique and safe
-- under concurrent inserts. The year is taken from the record's own date.
-- To number another table later, add one row to the list below.

CREATE OR REPLACE FUNCTION next_reference(prefix TEXT, seq REGCLASS, at TIMESTAMPTZ)
RETURNS TEXT AS $$
  SELECT prefix || '-' || to_char(at, 'YYYY') || '-' || lpad(nextval(seq)::text, 6, '0');
$$ LANGUAGE sql;

DO $$
DECLARE
  t RECORD;

BEGIN
  FOR t IN
    SELECT * FROM (VALUES
      ('disputes',        'DSP', 'dispute_reference_seq',       'submitted_at'),
      ('fraud_flags',     'FLG', 'fraud_flag_reference_seq',    'flagged_at'),
      ('establishments',  'EST', 'establishment_reference_seq', 'created_at'),
      ('beneficiaries',   'BEN', 'beneficiary_reference_seq',   'created_at')
    ) AS v(tbl, prefix, seq, date_col)
  LOOP
    EXECUTE format('CREATE SEQUENCE IF NOT EXISTS %I', t.seq);
    EXECUTE format('ALTER TABLE %I ADD COLUMN IF NOT EXISTS reference_no VARCHAR(20)', t.tbl);

    -- Backfill existing rows oldest-first so numbers follow creation order.
    EXECUTE format($q$
      WITH numbered AS (
        SELECT id, %2$I AS at,
               row_number() OVER (ORDER BY %2$I, id) AS n
        FROM %1$I WHERE reference_no IS NULL
      )
      UPDATE %1$I x
      SET reference_no = %3$L || '-' || to_char(numbered.at, 'YYYY') || '-' ||
                         lpad(numbered.n::text, 6, '0')
      FROM numbered WHERE x.id = numbered.id
    $q$, t.tbl, t.date_col, t.prefix);

    -- Continue after the highest existing number (safe to re-run).
    EXECUTE format(
      'SELECT setval(%L, GREATEST((SELECT MAX(right(reference_no, 6)::int) FROM %I), 1), (SELECT COUNT(*) FROM %I) > 0)',
      t.seq, t.tbl, t.tbl);

    EXECUTE format(
      'ALTER TABLE %I ALTER COLUMN reference_no SET DEFAULT next_reference(%L, %L, now())',
      t.tbl, t.prefix, t.seq);
    EXECUTE format('ALTER TABLE %I ALTER COLUMN reference_no SET NOT NULL', t.tbl);
    EXECUTE format(
      'CREATE UNIQUE INDEX IF NOT EXISTS %I ON %I (reference_no)',
      'idx_' || t.tbl || '_reference_no', t.tbl);
  END LOOP;
END $$;
