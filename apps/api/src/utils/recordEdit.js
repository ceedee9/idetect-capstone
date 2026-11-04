// Helpers for the "record edited" notice sent to the ID owner (change matrix A-07).
// The notice names which kinds of details changed, never their values.

const OWNER_VISIBLE_FIELDS = {
  full_name: "name",
  birthdate: "birth date",
  issuing_office: "issuing office",
  registered_mobile: "contact number",
  contact_number: "contact number",
  disability_type: "disability type",
  address: "address",
  email: "email",
};

// Staff-only fields are still audited but never notified.
const TRACKED_FIELDS = [...Object.keys(OWNER_VISIBLE_FIELDS), "notes"];

const REASON_MAX_LENGTH = 500;
const SMS_REASON_MAX_LENGTH = 80;

function normalize(value) {
  if (value === null || value === undefined) return null;
  if (value instanceof Date) return value.getTime();
  const text = String(value).trim();
  return text === "" ? null : text;
}

function changedFields(before, after) {
  return TRACKED_FIELDS.filter(
    (field) => normalize(before[field]) !== normalize(after[field]),
  );
}

function ownerVisibleLabels(changed) {
  const labels = changed
    .filter((field) => field in OWNER_VISIBLE_FIELDS)
    .map((field) => OWNER_VISIBLE_FIELDS[field]);
  return [...new Set(labels)];
}

function buildEditNotice({ beneficiaryType, labels, reason }) {
  const office = beneficiaryType === "senior_citizen" ? "Senior Citizen" : "PWD";
  const title = "Your Record Was Updated";
  const cleanReason = String(reason).trim().replace(/[.\s]+$/, "");
  const changed = labels.join(", ");
  const body =
    `Your ${office} record was updated (${changed}). Reason: ${cleanReason}. ` +
    "If you did not expect this change, contact your LGU office or file a dispute in the app.";

  const shortReason =
    cleanReason.length > SMS_REASON_MAX_LENGTH
      ? `${cleanReason.slice(0, SMS_REASON_MAX_LENGTH - 3)}...`
      : cleanReason;
  const smsBody =
    `${title}: your ${office} record was updated (${changed}). ` +
    `Reason: ${shortReason}. Contact your LGU office if unexpected.`;

  return { title, body, smsBody };
}

module.exports = {
  REASON_MAX_LENGTH,
  changedFields,
  ownerVisibleLabels,
  buildEditNotice,
};
