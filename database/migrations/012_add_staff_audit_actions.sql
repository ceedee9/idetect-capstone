-- ============================================================
-- Migration 012: Add missing audit_action enum values
-- Covers staff management actions and verification events.
-- ============================================================

ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'staff_created';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'staff_updated';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'staff_activated';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'staff_deactivated';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'staff_password_reset';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'verification_performed';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_self_registered';
