const pool = require("../config/database");

// Business-refusal disputes are visible to BPLO and to the beneficiary's own
// office; every other dispute belongs to the beneficiary's office only.
function getDisputeAlertRoles(disputeType, beneficiaryType) {
  const officeRole =
    beneficiaryType === "senior_citizen" ? "osca_admin" : "pdao_admin";
  return disputeType === "business_refusal"
    ? ["bplo_admin", officeRole]
    : [officeRole];
}

function getDisputeAlertRoute(role) {
  return role === "bplo_admin" ? "/business-refusals" : "/disputes";
}

async function createStaffAlert({
  targetRole,
  alertType,
  severity = "medium",
  title,
  body,
  targetRoute = null,
  relatedBeneficiaryId = null,
  relatedDisputeId = null,
  dedupeKey = null,
}) {
  const { rows } = await pool.query(
    `INSERT INTO staff_alerts
      (target_role, alert_type, severity, title, body, target_route,
       related_beneficiary_id, related_dispute_id, dedupe_key)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
     ON CONFLICT (dedupe_key) WHERE dedupe_key IS NOT NULL DO NOTHING
     RETURNING id`,
    [
      targetRole,
      alertType,
      severity,
      title,
      body,
      targetRoute,
      relatedBeneficiaryId,
      relatedDisputeId,
      dedupeKey,
    ],
  );
  return rows[0] || null;
}

module.exports = {
  createStaffAlert,
  getDisputeAlertRoles,
  getDisputeAlertRoute,
};
