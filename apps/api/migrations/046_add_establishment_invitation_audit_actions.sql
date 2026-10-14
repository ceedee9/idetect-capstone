-- Migration 046: audit actions for invitation lifecycle management
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_user_invitation_resent';
ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'establishment_user_invitation_revoked';
