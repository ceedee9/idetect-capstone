-- ============================================================
-- Migration 018: Establishment permit expiry + password reset OTP
-- REQ-2.2.5: business_permit_expiry for expiry monitoring
-- REQ-2.2.6: OTP fields for self-service password reset
-- ============================================================

ALTER TABLE establishments
  ADD COLUMN IF NOT EXISTS business_permit_expiry DATE,
  ADD COLUMN IF NOT EXISTS reset_otp              VARCHAR(6),
  ADD COLUMN IF NOT EXISTS reset_otp_expires      TIMESTAMPTZ;
