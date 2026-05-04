// src/services/expiredStatusScheduler.js
// Nightly job that sets beneficiary status = 'expired' for any record
// that is still marked 'active' but whose validity_end date has passed.
//
// Without this, the 'expired' enum value is never written to the DB and
// queries like `WHERE status = 'expired'` return zero rows even when
// many IDs have lapsed. Verification logic already handles expiry
// dynamically, so this is purely for data-consistency and analytics.
//
// Idempotent — safe to run multiple times per day.

const pool = require("../config/database");

const INTERVAL_MS = 24 * 60 * 60 * 1000; // 24 hours

async function runExpiredStatusSync() {
  console.log("[ExpiredStatusScheduler] Checking for lapsed IDs…");
  try {
    const result = await pool.query(
      `UPDATE beneficiaries
         SET status = 'expired',
             status_reason = 'ID validity period has ended.',
             updated_at = NOW()
       WHERE status = 'active'
         AND validity_end < CURRENT_DATE
       RETURNING id`,
    );

    if (result.rowCount > 0) {
      // Audit-log the batch update (single row describes the whole sweep)
      await pool.query(
        `INSERT INTO audit_logs (action, target_table, metadata)
         VALUES ('beneficiary_status_changed', 'beneficiaries', $1)`,
        [
          JSON.stringify({
            auto_expired: true,
            count: result.rowCount,
            ran_at: new Date().toISOString(),
          }),
        ],
      );
    }

    console.log(
      `[ExpiredStatusScheduler] Marked ${result.rowCount} record(s) as expired.`,
    );
  } catch (err) {
    console.error("[ExpiredStatusScheduler] Error:", err.message);
  }
}

function startExpiredStatusScheduler() {
  // Run once immediately on boot to catch any records missed during downtime
  runExpiredStatusSync();

  setInterval(runExpiredStatusSync, INTERVAL_MS);
  console.log("[ExpiredStatusScheduler] Started — will run nightly.");
}

module.exports = { startExpiredStatusScheduler, runExpiredStatusSync };
