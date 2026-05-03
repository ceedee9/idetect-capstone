-- Migration 020: Add establishment_bulk_import to audit_action enum
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_bulk_import';
