-- ============================================================
-- Migration 014: fraud_flags duplicate detection (REQ-2.6.6)
-- Add parent_flag_id to link supplementary reports to original
-- investigation. Prevents duplicate cases for the same ID.
-- ============================================================

ALTER TABLE fraud_flags
  ADD COLUMN parent_flag_id UUID REFERENCES fraud_flags(id) ON DELETE SET NULL,
  ADD COLUMN is_supplementary BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX idx_fraud_flags_parent ON fraud_flags(parent_flag_id);
CREATE INDEX idx_fraud_flags_supplementary ON fraud_flags(is_supplementary, flag_status);

-- Index to quickly find active investigations by ID number
CREATE INDEX idx_fraud_flags_active_by_id ON fraud_flags(id_number_flagged, flag_status)
  WHERE flag_status IN ('pending', 'reviewing');

COMMENT ON COLUMN fraud_flags.parent_flag_id IS 'Links supplementary reports to original investigation. NULL if this is the original flag.';
COMMENT ON COLUMN fraud_flags.is_supplementary IS 'TRUE if this report was linked to an existing active investigation instead of creating a new case.';
