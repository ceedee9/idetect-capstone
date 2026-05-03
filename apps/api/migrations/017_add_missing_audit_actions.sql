-- ============================================================
-- Migration 017: Add remaining missing audit_action enum values
-- ============================================================

ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_created';
