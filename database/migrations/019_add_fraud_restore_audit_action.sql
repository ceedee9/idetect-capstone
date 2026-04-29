-- ============================================================
-- Migration 019: Add audit action for fraud flag restore
-- REQ-2.7.2: Supports dispute-driven status restore
-- ============================================================

ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'flag_confirmed';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'flag_restored';
