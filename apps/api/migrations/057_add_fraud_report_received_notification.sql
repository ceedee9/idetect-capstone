-- ============================================================
-- Migration 057: notification type for beneficiary fraud reports
-- beneficiaryPortal.js sends 'fraud_report_received' when a
-- beneficiary submits a fraud report. The value was never added,
-- so the insert failed after the report was saved.
-- Idempotent: safe to run more than once.
-- ============================================================

ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'fraud_report_received';
