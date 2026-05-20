-- ============================================================
-- Migration 025: add missing notification_type ENUM values
-- 'dispute_submitted' — used when a beneficiary files a dispute
-- 'dispute_escalated' — used by the SLA escalation scheduler
-- Both are safe no-ops if the values already exist.
-- ============================================================

ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'dispute_submitted';
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'dispute_escalated';
