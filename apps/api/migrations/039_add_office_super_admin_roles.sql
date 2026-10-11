-- Replace the global Super Admin concept with agency-scoped administrators.
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'bplo_super_admin';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'osca_super_admin';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'pdao_super_admin';

ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'staff_role_changed';

-- Migration 038 may already have added the legacy enum label `super_admin`.
-- It is intentionally not accepted by middleware or assigned by the API.
-- PostgreSQL enum labels are retained for compatibility; no global account is
-- created or migrated automatically because its agency cannot be inferred.
