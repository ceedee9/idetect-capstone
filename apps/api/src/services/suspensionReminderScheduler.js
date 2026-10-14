const pool = require("../config/database");

const INTERVAL_MS = 24 * 60 * 60 * 1000;

async function runSuspensionReminderSync() {
  try {
    await pool.query(`
      INSERT INTO staff_alerts (target_role, title, body, related_beneficiary_id)
      SELECT CASE WHEN b.beneficiary_type = 'pwd' THEN 'pdao_admin'::user_role
                  ELSE 'osca_admin'::user_role END,
             'Suspension review due',
             CASE
               WHEN b.suspension_end_date < CURRENT_DATE
                 THEN 'Suspension period ended. Review the beneficiary before reinstating, extending, or revoking the record.'
               ELSE 'Suspension ends in ' ||
                 (b.suspension_end_date - CURRENT_DATE)::text ||
                 ' day(s). Review the beneficiary before the end date.'
             END,
             b.id
      FROM beneficiaries b
      WHERE b.status = 'suspended'
        AND b.suspension_end_date IS NOT NULL
        AND b.suspension_end_date <= CURRENT_DATE + 7
        AND NOT EXISTS (
          SELECT 1
          FROM staff_alerts a
          WHERE a.related_beneficiary_id = b.id
            AND a.title = 'Suspension review due'
            AND a.created_at::date = CURRENT_DATE
        )
    `);
  } catch (err) {
    console.error("[SuspensionReminderScheduler] Error:", err.message);
  }
}

function startSuspensionReminderScheduler() {
  runSuspensionReminderSync();
  setInterval(runSuspensionReminderSync, INTERVAL_MS);
  console.log("[SuspensionReminderScheduler] Started — daily review reminders enabled.");
}

module.exports = { runSuspensionReminderSync, startSuspensionReminderScheduler };
