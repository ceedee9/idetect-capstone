// src/services/expiryAlertScheduler.js
// Runs once per day and creates in-app notifications for beneficiaries
// whose IDs are expiring in 30, 7, or 1 day(s).
// Also dispatches FCM push notifications for each alert.
//
// No external dependencies — uses setInterval on server start.
// In production, replace with a proper cron job or Railway cron trigger.

const pool = require("../config/database");
const { sendPushNotification } = require("./fcmService");

const ALERT_DAYS = [30, 7, 1];

/**
 * Check for expiring IDs and insert notifications where one hasn't been
 * sent in the current day already (idempotent — safe to run multiple times).
 */
async function runExpiryCheck() {
  console.log("[ExpiryScheduler] Running ID expiry check…");

  let totalCreated = 0;

  for (const days of ALERT_DAYS) {
    try {
      // Find beneficiaries whose ID expires exactly `days` days from today
      // AND who have a beneficiary_account (so they can receive notifications)
      // AND haven't already received a notification for this threshold today
      const result = await pool.query(
        `SELECT
           b.id          AS beneficiary_id,
           b.full_name,
           b.id_number,
           b.beneficiary_type,
           b.validity_end,
           ba.id         AS account_id,
           ba.device_token
         FROM beneficiaries b
         JOIN beneficiary_accounts ba ON ba.beneficiary_id = b.id
         WHERE b.status = 'active'
           AND b.validity_end::date = (CURRENT_DATE + $1::int * INTERVAL '1 day')::date
           AND NOT EXISTS (
             SELECT 1 FROM notifications n
             WHERE n.beneficiary_account_id = ba.id
               AND n.notification_type = 'id_expiring_soon'
               AND n.sent_at::date = CURRENT_DATE
           )`,
        [days],
      );

      if (result.rows.length === 0) continue;

      // Build bulk insert and dispatch FCM pushes
      const values = [];
      const params = [];
      let idx = 1;

      for (const row of result.rows) {
        const title =
          days === 1
            ? "Your ID expires tomorrow!"
            : `Your ID expires in ${days} days`;
        const message =
          days === 1
            ? `Your ${row.beneficiary_type === "senior_citizen" ? "Senior Citizen" : "PWD"} ID (${row.id_number}) expires tomorrow. Please renew it at your issuing office.`
            : `Your ${row.beneficiary_type === "senior_citizen" ? "Senior Citizen" : "PWD"} ID (${row.id_number}) will expire in ${days} days (${row.validity_end?.toISOString?.().slice(0, 10) ?? row.validity_end}). Please arrange renewal soon.`;

        values.push(`($${idx++}, $${idx++}, $${idx++}, $${idx++}, $${idx++})`);
        params.push(row.account_id, "id_expiring_soon", title, message, "push");

        // Dispatch FCM push (fire-and-forget; clear invalid tokens automatically)
        if (row.device_token) {
          sendPushNotification(row.device_token, title, message, {
            type: "id_expiring_soon",
          })
            .then((fcmResult) => {
              if (fcmResult.invalidToken) {
                pool
                  .query(
                    "UPDATE beneficiary_accounts SET device_token = NULL WHERE id = $1",
                    [row.account_id],
                  )
                  .catch(() => {});
              }
            })
            .catch(() => {});
        }
      }

      await pool.query(
        `INSERT INTO notifications
           (beneficiary_account_id, notification_type, title, body, channel)
         VALUES ${values.join(", ")}`,
        params,
      );

      console.log(
        `[ExpiryScheduler] Created ${result.rows.length} notification(s) for ${days}-day expiry warning`,
      );
      totalCreated += result.rows.length;
    } catch (err) {
      console.error(
        `[ExpiryScheduler] Error processing ${days}-day alerts:`,
        err.message,
      );
    }
  }

  console.log(
    `[ExpiryScheduler] Done. Total notifications created: ${totalCreated}`,
  );
}

/**
 * Start the daily scheduler.
 * Runs once immediately on boot, then every 24 hours.
 */
function startExpiryScheduler() {
  // Run immediately on startup (catches any missed alerts from downtime)
  runExpiryCheck();

  // Then every 24 hours
  const TWENTY_FOUR_HOURS = 24 * 60 * 60 * 1000;
  setInterval(runExpiryCheck, TWENTY_FOUR_HOURS);

  console.log("[ExpiryScheduler] Started — will check daily for expiring IDs");
}

module.exports = { startExpiryScheduler, runExpiryCheck };
