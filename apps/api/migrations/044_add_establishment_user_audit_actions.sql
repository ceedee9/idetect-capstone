-- Migration 044: audit actions for establishment-user management
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_user_login_failed';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_user_invited';
