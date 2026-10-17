-- ============================================================
-- Migration 051: columns for replaying offline scans
-- client_scan_id: ID the device generates when it queues a scan.
--   A replay with an ID already stored is not recorded again,
--   so retries after a lost response are safe.
-- scanned_at: when the cashier scanned the ID. For replayed scans,
--   verified_at is the sync time and scanned_at is the original scan time.
-- offline_queued: true when the scan was replayed from the offline queue.
-- ============================================================

ALTER TABLE verification_logs
  ADD COLUMN IF NOT EXISTS client_scan_id TEXT,
  ADD COLUMN IF NOT EXISTS scanned_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS offline_queued BOOLEAN NOT NULL DEFAULT FALSE;

CREATE UNIQUE INDEX IF NOT EXISTS idx_verification_logs_client_scan
  ON verification_logs (establishment_id, client_scan_id)
  WHERE client_scan_id IS NOT NULL;
