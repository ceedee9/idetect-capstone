-- Migration 054: Optional on-site contact person for establishments.
-- owner_name remains the registered owner (as on the business permit).
-- contact_person is the operational contact, which may differ for franchises
-- and branches. Nullable; existing rows are not backfilled.
ALTER TABLE establishments
  ADD COLUMN IF NOT EXISTS contact_person VARCHAR(255);
