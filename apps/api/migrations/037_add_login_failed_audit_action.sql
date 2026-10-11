-- Migration 037: distinguish failed authentication from successful login.
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'login_failed';
