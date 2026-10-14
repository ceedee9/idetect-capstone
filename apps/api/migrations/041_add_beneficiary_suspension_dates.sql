ALTER TABLE beneficiaries
  ADD COLUMN IF NOT EXISTS suspension_start_date DATE,
  ADD COLUMN IF NOT EXISTS suspension_end_date DATE;

ALTER TABLE beneficiaries
  ADD CONSTRAINT beneficiaries_suspension_dates_valid
  CHECK (
    suspension_start_date IS NULL
    OR suspension_end_date IS NULL
    OR suspension_end_date >= suspension_start_date
  );

CREATE INDEX IF NOT EXISTS idx_beneficiaries_suspension_end
  ON beneficiaries (suspension_end_date)
  WHERE status = 'suspended';
