-- Migration 015: Widen image_path columns to TEXT
-- VARCHAR(500) was for Cloudinary URLs, but we now store full absolute HTTP URLs
-- which may exceed 500 chars once you factor in host + path.
-- verification_logs and fraud_flags both reference image paths.

ALTER TABLE verification_logs
  ALTER COLUMN image_path TYPE TEXT;

ALTER TABLE fraud_flags
  ALTER COLUMN image_path TYPE TEXT;
