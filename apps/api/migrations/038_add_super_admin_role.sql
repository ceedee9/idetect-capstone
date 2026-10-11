-- Phase 1 authority foundation: system-level staff administration.
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'super_admin';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'staff_role_changed';
