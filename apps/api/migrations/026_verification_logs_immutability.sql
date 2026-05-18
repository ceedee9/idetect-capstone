-- ============================================================
-- Migration 026: enforce verification_logs immutability at DB level
--
-- The verification_logs table is the permanent audit trail for every
-- ID scan ever performed. The schema comment says "Never delete rows"
-- but nothing enforced that at the database level — a bug or a
-- privileged query could silently destroy audit evidence.
--
-- This migration adds PostgreSQL RULEs that make DELETE and UPDATE
-- no-ops on verification_logs. The rows can still be INSERT-ed by the
-- application, but no existing row can ever be changed or removed.
--
-- Same protection is applied to audit_logs, which has an identical
-- immutability requirement.
-- ============================================================

-- ── verification_logs ────────────────────────────────────────
CREATE RULE no_delete_verification_logs
  AS ON DELETE TO verification_logs
  DO INSTEAD NOTHING;

CREATE RULE no_update_verification_logs
  AS ON UPDATE TO verification_logs
  DO INSTEAD NOTHING;

-- ── audit_logs ───────────────────────────────────────────────
CREATE RULE no_delete_audit_logs
  AS ON DELETE TO audit_logs
  DO INSTEAD NOTHING;

CREATE RULE no_update_audit_logs
  AS ON UPDATE TO audit_logs
  DO INSTEAD NOTHING;
