-- ============================================================
-- Migration 043: audit permanent fraud-flag deletion
-- ============================================================

ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'flag_deleted';
