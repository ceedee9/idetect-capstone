// src/services/flagDecayScheduler.js
// Automatically expires stale pending fraud flags that have gone unreviewed
// for longer than FLAG_DECAY_DAYS (default 180 days).
//
// Rationale: A flag submitted 6+ months ago with no follow-up should not
// indefinitely count toward the auto-suspend threshold. This prevents a
// single old, unreviewed report from blocking future auto-suspend resets.
//
// Runs daily. Idempotent — safe to run multiple times.

const pool = require("../config/database");

const FLAG_DECAY_DAYS = parseInt(process.env.FLAG_DECAY_DAYS || "180");
const INTERVAL_MS = 24 * 60 * 60 * 1000; // 24 hours

async function runFlagDecay() {
  console.log(
    `[FlagDecay] Running flag decay check (threshold: ${FLAG_DECAY_DAYS} days)…`,
  );

  try {
    // Find pending flags older than FLAG_DECAY_DAYS
    const staleFlags = await pool.query(
      `SELECT id, id_number_flagged, beneficiary_id, flagged_at
       FROM fraud_flags
       WHERE flag_status = 'pending'
         AND flagged_at < NOW() - ($1::int * INTERVAL '1 day')`,
      [FLAG_DECAY_DAYS],
    );

    if (staleFlags.rows.length === 0) {
      console.log("[FlagDecay] No stale flags found.");
      return;
    }

    // Auto-dismiss each stale flag and log the action
    for (const flag of staleFlags.rows) {
      await pool.query(
        `UPDATE fraud_flags
         SET flag_status   = 'dismissed',
             staff_notes   = $1,
             reviewed_at   = NOW()
         WHERE id = $2`,
        [
          `Auto-expired: pending flag exceeded the ${FLAG_DECAY_DAYS}-day review window without staff action.`,
          flag.id,
        ],
      );

      await pool.query(
        `INSERT INTO audit_logs (action, target_table, target_id, metadata)
         VALUES ('flag_dismissed', 'fraud_flags', $1, $2)`,
        [
          flag.id,
          JSON.stringify({
            auto_expired: true,
            decay_days: FLAG_DECAY_DAYS,
            flagged_at: flag.flagged_at,
            id_number: flag.id_number_flagged,
          }),
        ],
      );
    }

    // After bulk dismissal, check if any beneficiaries should be auto-restored.
    // Collect distinct beneficiary IDs from the expired flags.
    const beneficiaryIds = [
      ...new Set(
        staleFlags.rows
          .filter((f) => f.beneficiary_id)
          .map((f) => f.beneficiary_id),
      ),
    ];

    let restoredCount = 0;
    for (const beneficiaryId of beneficiaryIds) {
      // Count remaining active (non-dismissed) flags for this beneficiary
      const remaining = await pool.query(
        `SELECT COUNT(*) AS cnt
         FROM fraud_flags
         WHERE beneficiary_id = $1
           AND flag_status IN ('pending', 'reviewing')`,
        [beneficiaryId],
      );

      const remainingCount = parseInt(remaining.rows[0]?.cnt || "0");

      if (remainingCount === 0) {
        // Check if the beneficiary was auto-suspended
        const benResult = await pool.query(
          "SELECT status, status_reason FROM beneficiaries WHERE id = $1",
          [beneficiaryId],
        );

        const ben = benResult.rows[0];
        if (
          ben?.status === "suspended" &&
          ben?.status_reason?.includes("Automatically suspended")
        ) {
          await pool.query(
            `UPDATE beneficiaries
             SET status = 'active',
                 status_reason = NULL,
                 updated_at = NOW()
             WHERE id = $1`,
            [beneficiaryId],
          );

          await pool.query(
            `INSERT INTO audit_logs (action, target_table, target_id, metadata)
             VALUES ('beneficiary_status_changed', 'beneficiaries', $1, $2)`,
            [
              beneficiaryId,
              JSON.stringify({
                auto_restored: true,
                reason: "All active flags auto-expired due to decay window",
              }),
            ],
          );

          restoredCount++;
        }
      }
    }

    console.log(
      `[FlagDecay] Expired ${staleFlags.rows.length} stale flag(s). ` +
        `Restored ${restoredCount} beneficiar${restoredCount === 1 ? "y" : "ies"} to active.`,
    );
  } catch (err) {
    console.error("[FlagDecay] Error during flag decay run:", err.message);
  }
}

/**
 * Start the flag decay scheduler.
 * Runs once immediately on server boot, then every 24 hours.
 */
function startFlagDecayScheduler() {
  runFlagDecay();
  setInterval(runFlagDecay, INTERVAL_MS);
  console.log(
    `[FlagDecay] Started — auto-expiring flags older than ${FLAG_DECAY_DAYS} days, checked daily.`,
  );
}

module.exports = { startFlagDecayScheduler };
