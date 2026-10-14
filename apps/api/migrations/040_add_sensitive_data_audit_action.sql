-- Record controlled reveals of masked personal data.
ALTER TYPE audit_action
  ADD VALUE IF NOT EXISTS 'sensitive_data_revealed';
