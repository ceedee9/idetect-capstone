// src/services/slaEscalationScheduler.js
// REQ-2.13.6: Automated SLA escalation notifications.
//
// SLA rules:
//   - 24-hour acknowledgment: disputes in 'submitted' status for > 24h
//   - 72-hour resolution:     disputes in 'acknowledged'/'under_review' for > 72h
//
// Runs every 30 minutes. Sends an in-app notification to the beneficiary
// and logs to audit_logs. Idempotent — will not re-escalate the same
// dispute within the same SLA window (tracked via audit_logs).

const pool = require("../config/database");

const ACK_SLA_HOURS = 24;
const RESOLVE_SLA_HOURS = 72;
const INTERVAL_MS = 30 * 60 * 1000; // 30 minutes

async function runSlaCheck() {
  try {
    // ── 1. 24h acknowledgment SLA breach ──────────────────────────────────
    // Find submitted disputes that have exceeded 24h with no acknowledgment
    // AND have not already had an escalation notification sent today
    const ackBreaches = await pool.query(
      `SELECT d.id, d.beneficiary_account_id, d.submitted_at,
              d.dispute_type, b.beneficiary_type, b.id AS beneficiary_id
       FROM disputes d
       JOIN beneficiary_accounts ba ON ba.id = d.beneficiary_account_id
       JOIN beneficiaries b ON b.id = ba.beneficiary_id
       WHERE d.status = 'submitted'
         AND d.submitted_at < NOW() - INTERVAL '${ACK_SLA_HOURS} hours'
         AND NOT EXISTS (
           SELECT 1 FROM audit_logs al
           WHERE al.target_table = 'disputes'
             AND al.target_id = d.id
             AND al.action = 'sla_ack_escalation'
             AND al.created_at > NOW() - INTERVAL '24 hours'
         )`,
    );

    for (const row of ackBreaches.rows) {
      const ref = row.id.slice(0, 8).toUpperCase();

      // Notify the beneficiary that processing is delayed
      await pool.query(
        `INSERT INTO notifications
           (beneficiary_account_id, notification_type, title, body, channel, dispute_id)
         VALUES ($1, 'dispute_escalated', $2, $3, 'push', $4)`,
        [
          row.beneficiary_account_id,
          "Dispute Update — Processing Delayed",
          `Your dispute (Ref: ${ref}) is taking longer than expected. Our team has been alerted and will acknowledge it shortly.`,
          row.id,
        ],
      );

      // Alert the responsible admin staff so they can act on the overdue dispute
      const targetRole =
        row.dispute_type === "business_refusal"
          ? "bplo_admin"
          : row.beneficiary_type === "senior_citizen"
            ? "osca_admin"
            : "pdao_admin";

      await pool.query(
        `INSERT INTO staff_alerts (target_role, title, body, related_beneficiary_id)
         VALUES ($1, $2, $3, $4)`,
        [
          targetRole,
          `⏰ SLA Breach — Dispute Unacknowledged (Ref: ${ref})`,
          `Dispute ${ref} was submitted more than ${ACK_SLA_HOURS} hours ago and has not been acknowledged. Please review it immediately.`,
          row.beneficiary_id,
        ],
      );

      // Record escalation in audit log to prevent re-escalating
      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
         VALUES (NULL, 'sla_ack_escalation', 'disputes', $1, $2)`,
        [
          row.id,
          JSON.stringify({
            sla_hours: ACK_SLA_HOURS,
            submitted_at: row.submitted_at,
            escalated_at: new Date().toISOString(),
          }),
        ],
      );

      console.log(
        `[SLAScheduler] Ack escalation sent for dispute ${ref} (submitted ${row.submitted_at})`,
      );
    }

    // ── 2. 72h resolution SLA breach ─────────────────────────────────────
    // Find acknowledged/under_review disputes exceeding 72h since submission
    const resolveBreaches = await pool.query(
      `SELECT d.id, d.beneficiary_account_id, d.submitted_at, d.acknowledged_at,
              d.dispute_type, b.beneficiary_type, b.id AS beneficiary_id
       FROM disputes d
       JOIN beneficiary_accounts ba ON ba.id = d.beneficiary_account_id
       JOIN beneficiaries b ON b.id = ba.beneficiary_id
       WHERE d.status IN ('acknowledged', 'under_review')
         AND d.submitted_at < NOW() - INTERVAL '${RESOLVE_SLA_HOURS} hours'
         AND NOT EXISTS (
           SELECT 1 FROM audit_logs al
           WHERE al.target_table = 'disputes'
             AND al.target_id = d.id
             AND al.action = 'sla_resolve_escalation'
             AND al.created_at > NOW() - INTERVAL '24 hours'
         )`,
    );

    for (const row of resolveBreaches.rows) {
      const ref = row.id.slice(0, 8).toUpperCase();

      await pool.query(
        `INSERT INTO notifications
           (beneficiary_account_id, notification_type, title, body, channel, dispute_id)
         VALUES ($1, 'dispute_escalated', $2, $3, 'push', $4)`,
        [
          row.beneficiary_account_id,
          "Dispute Still Under Review",
          `Your dispute (Ref: ${ref}) is still being reviewed. We apologize for the delay. You will be notified as soon as a decision is made.`,
          row.id,
        ],
      );

      // Alert the responsible admin staff
      const targetRole =
        row.dispute_type === "business_refusal"
          ? "bplo_admin"
          : row.beneficiary_type === "senior_citizen"
            ? "osca_admin"
            : "pdao_admin";

      await pool.query(
        `INSERT INTO staff_alerts (target_role, title, body, related_beneficiary_id)
         VALUES ($1, $2, $3, $4)`,
        [
          targetRole,
          `⏰ SLA Breach — Dispute Unresolved (Ref: ${ref})`,
          `Dispute ${ref} has been open for more than ${RESOLVE_SLA_HOURS} hours without resolution. Please resolve or reject it immediately.`,
          row.beneficiary_id,
        ],
      );

      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
         VALUES (NULL, 'sla_resolve_escalation', 'disputes', $1, $2)`,
        [
          row.id,
          JSON.stringify({
            sla_hours: RESOLVE_SLA_HOURS,
            submitted_at: row.submitted_at,
            escalated_at: new Date().toISOString(),
          }),
        ],
      );

      console.log(
        `[SLAScheduler] Resolve escalation sent for dispute ${ref} (submitted ${row.submitted_at})`,
      );
    }

    const total = ackBreaches.rows.length + resolveBreaches.rows.length;
    if (total > 0) {
      console.log(`[SLAScheduler] ${total} escalation(s) sent.`);
    }
  } catch (err) {
    console.error("[SLAScheduler] Error during SLA check:", err.message);
  }
}

/**
 * Start the SLA escalation scheduler.
 * Runs immediately on boot, then every 30 minutes.
 */
function startSlaEscalationScheduler() {
  runSlaCheck();
  setInterval(runSlaCheck, INTERVAL_MS);
  console.log(
    "[SLAScheduler] Started — checking every 30 minutes for SLA breaches.",
  );
}

module.exports = { startSlaEscalationScheduler };
