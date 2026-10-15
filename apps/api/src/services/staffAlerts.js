const pool = require("../config/database");

function getDisputeTargetRole(disputeType, beneficiaryType) {
  if (disputeType === "business_refusal") return "bplo_admin";
  return beneficiaryType === "senior_citizen" ? "osca_admin" : "pdao_admin";
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

module.exports = { createStaffAlert, getDisputeTargetRole };
