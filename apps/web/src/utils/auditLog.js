// src/utils/auditLog.js
// Converts raw audit_logs rows (action + metadata JSON) into plain-language
// sentences for display, and formats metadata into readable key/value pairs
// for the detail drawer.

function fmtName(log) {
  return log.user_name || log.establishment_name || "System";
}

function fmtList(arr) {
  if (!Array.isArray(arr) || arr.length === 0) return "—";
  return arr.map((s) => String(s).replace(/_/g, " ")).join(", ");
}

function fmtFieldName(key) {
  return String(key)
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

function fmtResult(result) {
  const map = {
    valid: "Valid",
    invalid: "Invalid",
    suspicious: "Suspicious",
    manual_review: "flagged for manual review",
  };
  return map[result] || result;
}

const TABLE_LABELS = {
  establishments: "Establishment",
  beneficiaries: "Beneficiary",
  disputes: "Dispute",
  fraud_flags: "Fraud Flag",
  audit_logs: "Audit Log",
  users: "Staff Account",
  staff_alerts: "Staff Alert",
  verification_logs: "Validation Log",
  notifications: "Notification",
};

const SESSION_ACTIONS = new Set([
  "login",
  "login_failed",
  "logout",
  "account_locked",
  "account_unlocked",
  "otp_requested",
  "otp_verified",
  "password_changed",
  "password_reset",
  "password_reset_by_admin",
]);

/**
 * Turns a raw target_table value into a readable singular label,
 * e.g. "establishments" -> "Establishment".
 */
export function formatTargetLabel(targetTable) {
  if (!targetTable) return null;
  if (TABLE_LABELS[targetTable]) return TABLE_LABELS[targetTable];
  // Fallback: underscores -> spaces, title case, naive de-pluralize
  const spaced = targetTable.replace(/_/g, " ");
  const singular = spaced.endsWith("s") ? spaced.slice(0, -1) : spaced;
  return singular.replace(/\b\w/g, (c) => c.toUpperCase());
}

export function formatAffectedRecord(log) {
  if (!log?.target_table) {
    return SESSION_ACTIONS.has(log?.action) ? "Session event" : null;
  }

  const label = formatTargetLabel(log.target_table);
  const reference = log.target_reference;
  const name = log.target_name;
  if (reference && name) return `${label}: ${name} · ${reference}`;
  if (reference) return `${label}: ${reference}`;
  if (name) return `${label}: ${name}`;
  if (log.target_id) {
    return `${label}: #${log.target_id.slice(0, 8)}`;
  }
  return label;
}

const ACTION_LABEL_OVERRIDES = {
  verification_performed: "Validation Performed",
  verification_manual: "Manual Validation",
  verification_action_taken: "Validation Action Taken",
};

/**
 * Human-readable badge label for an action, e.g. "beneficiary_created"
 * -> "Beneficiary Created". A few actions get an explicit override
 * (the verification_* family reads as "Validation" per project terminology).
 */
export function actionLabel(action) {
  if (!action) return "";
  if (ACTION_LABEL_OVERRIDES[action]) return ACTION_LABEL_OVERRIDES[action];
  return action.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

/**
 * Returns a single plain-language sentence describing the log entry.
 * Falls back to a generic best-effort sentence for unmapped actions.
 */
export function humanizeAuditLog(log) {
  const { action, metadata: m = {} } = log;
  const who = fmtName(log);

  switch (action) {
    // ── Auth ──────────────────────────────────────────────────
    case "login":
      return `${who} signed in (${m.email || "unknown email"})`;
    case "login_failed":
      return `${who} had a failed sign-in attempt${m.reason ? ` (${m.reason})` : ""}`;
    case "flag_created":
      return `${who} submitted a fraud flag`;
    case "logout":
      return m.reason === "idle_timeout"
        ? `${who} was signed out after inactivity`
        : `${who} signed out`;
    case "password_changed":
      return `${who} changed their own password`;
    case "otp_requested":
      return `${who} requested a one-time login code`;
    case "otp_verified":
      return `${who} verified their one-time login code`;
    case "account_locked":
      return `Account locked after repeated failed login attempts (${m.email || ""})`;
    case "account_unlocked":
      return `Account unlocked by an administrator (${m.email || m.business_name || ""})`;
    case "password_reset":
      return `Password reset via ${m.via === "self_service_otp" ? "self-service (OTP)" : m.via === "self_service_email_token" ? "self-service (email link)" : m.via || "self-service"}`;
    case "password_reset_by_admin":
      return `Password reset by an administrator for ${m.business_name || "an establishment"}`;

    // ── Beneficiary ──────────────────────────────────────────
    case "beneficiary_created":
      return `Created a beneficiary record (ID ${m.id_number || "—"})`;
    case "beneficiary_updated":
      return `Updated beneficiary details${m.new?.full_name ? ` for ${m.new.full_name}` : ""}`;
    case "beneficiary_status_changed":
      return `Changed beneficiary status from "${m.old_status}" to "${m.new_status}"${
        m.suspension_end_date
          ? ` — suspension expires ${m.suspension_end_date}`
          : ""
      }${m.status_reason ? ` — ${m.status_reason}` : ""}`;
    case "beneficiary_deleted":
      return `Permanently deleted beneficiary "${m.full_name || "—"}" (ID ${m.id_number || "—"})`;
    case "beneficiary_bulk_import":
      return `Bulk-imported beneficiaries: ${m.inserted ?? 0} added of ${m.total ?? 0} rows${m.duplicates ? `, ${m.duplicates} duplicate(s) skipped` : ""}${m.invalid ? `, ${m.invalid} invalid` : ""}`;
    case "beneficiary_renewed":
      return `Renewed beneficiary ID — new validity until ${m.new_validity_end || "—"}`;
    case "fraud_report_submitted":
      return `Beneficiary submitted a fraud report (${fmtFieldName(m.report_type || "unspecified")})`;

    // ── Establishment ──────────────────────────────────────────
    case "establishment_approved":
      return `Approved establishment "${m.business_name || who}"`;
    case "establishment_suspended":
      return `Suspended an establishment — reason: ${m.reason || "not specified"}`;
    case "establishment_revoked":
      return `Revoked the permit of "${m.business_name || "an establishment"}" — reason: ${m.reason || "not specified"}`;
    case "establishment_self_registered":
      return `"${m.business_name || "An establishment"}" self-registered (Permit #${m.business_permit_no || "—"})`;
    case "establishment_created":
      return `Created establishment "${m.business_name || "—"}" (Permit #${m.business_permit_no || "—"})${m.bulk_import ? " via bulk import" : ""}`;
    case "establishment_bulk_import":
      return `Bulk-imported establishments: ${m.inserted ?? 0} added of ${m.total ?? 0} rows${m.duplicates ? `, ${m.duplicates} duplicate(s) skipped` : ""}`;
    case "credentials_downloaded":
      return `Downloaded ${m.count ?? 0} one-time bulk-import credential(s) (step-up confirmed)`;
    case "establishment_updated":
      return `Updated establishment fields: ${fmtList(m.updated_fields)}`;
    case "establishment_deleted":
      return `Deleted establishment "${m.business_name || "—"}"`;

    // ── Fraud flags ──────────────────────────────────────────
    case "flag_confirmed":
      if (m.auto_suspended) {
        return `System auto-suspended a beneficiary after ${m.distinct_flaggers ?? "multiple"} establishments flagged ID ${m.id_number || "—"} (threshold: ${m.threshold ?? "—"})`;
      }
      return `Confirmed a fraud flag as valid`;
    case "flag_dismissed":
      if (m.auto_restored) {
        return `System auto-restored a beneficiary after all fraud flags were cleared`;
      }
      return `Dismissed a fraud flag`;
    case "flag_restored":
      return `Restored a beneficiary's status after flag review`;
    case "unauthorized_use_reported":
      return `Beneficiary reported unauthorized use of their ID`;

    // ── Disputes ──────────────────────────────────────────────
    case "dispute_submitted":
      return `Submitted a ${fmtFieldName(m.dispute_type || "dispute")}`;
    case "dispute_acknowledged":
      return `Acknowledged a dispute (was "${m.previous_status || "submitted"}")`;
    case "dispute_resolved":
      return `Resolved a ${fmtFieldName(m.dispute_type || "dispute")} as "${m.decision || "—"}"`;

    // ── Callback requests ─────────────────────────────────────
    case "callback_requested":
      return `Beneficiary requested a callback from ${who}`;
    case "callback_request_handled":
      return `Marked a callback request as handled`;
    case "callback_request_updated":
      return `Updated a callback request (status: ${fmtFieldName(m.from_status || "—")} → ${fmtFieldName(m.to_status || "—")})`;

    // ── System ──────────────────────────────────────────────
    case "data_export":
      return `Exported ${m.row_count ?? "an unknown number of"} record(s) as ${String(m.format || "CSV").toUpperCase()}`;
    case "report_generated":
      return `Generated a report`;
    case "breach_incident_report_generated":
      return `Generated a data breach incident report — an estimated ${m.estimated_subjects ?? "unknown number of"} subject(s) affected`;

    // ── Verifications ──────────────────────────────────────────
    case "verification_performed":
      return `Validated ID ${m.id_number || "—"} — result: ${fmtResult(m.result) || "—"}`;
    case "verification_manual":
      return `Manually entered and validated ID ${m.id_number || "—"} — result: ${fmtResult(m.result) || "—"}`;
    case "verification_action_taken":
      return `Cashier action recorded: ${fmtFieldName(m.cashier_action || "—")}`;

    // ── Staff ──────────────────────────────────────────────
    case "staff_created":
      return `Created a staff account for ${m.full_name || m.email || "—"} (${fmtFieldName(m.role || "staff")})`;
    case "staff_updated":
      return `Updated staff account fields: ${fmtList(m.changes)}`;
    case "staff_activated":
      return `Activated staff account (${m.email || "—"})`;
    case "staff_deactivated":
      return `Deactivated staff account (${m.email || "—"})`;
    case "staff_password_reset":
      return `Reset a staff account's password`;

    // ── SLA scheduler (system-triggered) ────────────────────
    case "sla_ack_escalation":
      return `System escalated a dispute that wasn't acknowledged within ${m.sla_hours ?? 24} hours`;
    case "sla_resolve_escalation":
      return `System escalated a dispute that wasn't resolved within ${m.sla_hours ?? 72} hours`;

    default: {
      // Generic fallback for any action we don't explicitly handle yet —
      // picks out the first couple of readable metadata fields.
      const entries = Object.entries(m || {}).filter(
        ([, v]) => v !== null && v !== undefined && v !== "",
      );
      if (entries.length === 0) return "No additional details.";
      return entries
        .slice(0, 2)
        .map(
          ([k, v]) =>
            `${fmtFieldName(k)}: ${Array.isArray(v) ? fmtList(v) : String(v)}`,
        )
        .join(" · ");
    }
  }
}

/**
 * Formats raw metadata into an array of {label, value} pairs for display
 * in the detail drawer — handles nested objects, arrays, booleans, and
 * null/empty values gracefully.
 */
export function formatMetadataEntries(metadata) {
  if (!metadata || typeof metadata !== "object") return [];

  const format = (value) => {
    if (value === null || value === undefined || value === "") return "—";
    if (typeof value === "boolean") return value ? "Yes" : "No";
    if (Array.isArray(value)) return fmtList(value);
    if (typeof value === "object") {
      return Object.entries(value)
        .map(([k, v]) => `${fmtFieldName(k)}: ${format(v)}`)
        .join("; ");
    }
    return String(value);
  };

  return Object.entries(metadata).map(([key, value]) => ({
    label: fmtFieldName(key),
    value: format(value),
  }));
}
