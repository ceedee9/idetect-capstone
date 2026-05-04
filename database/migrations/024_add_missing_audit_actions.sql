-- Migration 024: Add missing audit_action enum values
-- establishment_created and establishment_deleted were missing from the enum.

ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_created';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_deleted';
