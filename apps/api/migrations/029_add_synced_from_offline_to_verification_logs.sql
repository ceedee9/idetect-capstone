-- ============================================================
-- Migration 029: verification_logs.synced_from_offline
-- Distinguishes scans performed live from scans that were queued
-- on-device while offline and later replayed to the server once
-- connectivity was restored (see offline_scan_sync_service.dart's
-- syncPendingScans(), which already sends offline_queued:true on
-- every replayed scan — this column is what finally stores it).
-- ============================================================

ALTER TABLE verification_logs
  ADD COLUMN synced_from_offline BOOLEAN NOT NULL DEFAULT FALSE;

-- Supports "how many scans in this range were offline replays"
-- style reporting without a full table scan.
CREATE INDEX idx_verification_logs_synced_from_offline
  ON verification_logs(synced_from_offline)
  WHERE synced_from_offline = TRUE;

COMMENT ON COLUMN verification_logs.synced_from_offline
  IS 'TRUE if this scan was queued on-device while offline and replayed later, rather than submitted live.';
