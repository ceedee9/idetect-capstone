-- ============================================================
-- iDetect — Run All Migrations
-- Execute this file to build the full database schema from scratch.
-- Usage: psql -U postgres -d idetect -f database/migrations/run_all.sql
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

\echo '>>> Running migration 001: users'
\i 001_create_users.sql

\echo '>>> Running migration 002: establishments'
\i 002_create_establishments.sql

\echo '>>> Running migration 003: beneficiaries'
\i 003_create_beneficiaries.sql

\echo '>>> Running migration 004: beneficiary_accounts'
\i 004_create_beneficiary_accounts.sql

\echo '>>> Running migration 005: verification_logs'
\i 005_create_verification_logs.sql

\echo '>>> Running migration 006: fraud_flags'
\i 006_create_fraud_flags.sql

\echo '>>> Running migration 007: disputes'
\i 007_create_disputes.sql

\echo '>>> Running migration 034: add other dispute type'
\i 034_add_other_dispute_type.sql

\echo '>>> Running migration 008: notifications'
\i 008_create_notifications.sql

\echo '>>> Running migration 009: audit_logs'
\i 009_create_audit_logs.sql

\echo '>>> Running migration 010: add PIN to beneficiary_accounts'
\i 010_add_pin_to_beneficiary_accounts.sql

\echo '>>> Running migration 011: add disability_type to beneficiaries'
\i 011_add_disability_type.sql

\echo '>>> Running migration 012: add staff audit actions'
\i 012_add_staff_audit_actions.sql

\echo '>>> Running migration 016: add login lockout columns'
\i 016_add_login_lockout.sql

\echo '>>> Running migration 017: add missing audit actions'
\i 017_add_missing_audit_actions.sql

\echo '>>> Running migration 018: establishment permit expiry + password reset OTP'
\i 018_establishment_permit_and_reset.sql

\echo '>>> Running migration 020: add establishment_bulk_import audit action'
\i 020_add_establishment_bulk_import.sql

\echo '>>> Running migration 021: cross-validation columns + normalized ID index'
\i 021_cross_validation_and_normalization.sql

\echo '>>> Running migration 022: staff_alerts table'
\i 022_staff_alerts.sql

\echo '>>> Running migration 023: unique person index (full_name + birthdate + type)'
\i 023_unique_person_index.sql

\echo '>>> Running migration 026: establishment password-setup token'
\i 026_establishment_password_setup_token.sql

\echo ''
\echo '=== iDetect schema ready ==='
