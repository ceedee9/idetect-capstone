// src/utils/passwordPolicy.js
// Password strength rules for the establishment setup-password and
// accept-invitation links. apps/web/src/utils/passwordPolicy.js mirrors
// these rules for live feedback; keep the two files in sync.

const PASSWORD_MIN_LENGTH = 8;
const PASSWORD_MAX_LENGTH = 128;

const PASSWORD_RULES = [
  {
    key: "length",
    label: `At least ${PASSWORD_MIN_LENGTH} characters`,
    test: (p) => p.length >= PASSWORD_MIN_LENGTH,
  },
  {
    key: "uppercase",
    label: "One uppercase letter (A-Z)",
    test: (p) => /[A-Z]/.test(p),
  },
  {
    key: "lowercase",
    label: "One lowercase letter (a-z)",
    test: (p) => /[a-z]/.test(p),
  },
  {
    key: "number",
    label: "One number (0-9)",
    test: (p) => /[0-9]/.test(p),
  },
  {
    // Anything that is not a letter, digit, or whitespace (e.g. ! @ # $ % ^ & * ? _ -).
    key: "special",
    label: "One special character (e.g. ! @ # $ %)",
    test: (p) => /[^\p{L}\p{N}\s]/u.test(p),
  },
];

function getFailedPasswordRules(password) {
  const value = String(password ?? "");
  return PASSWORD_RULES.filter((rule) => !rule.test(value));
}

// Custom express-validator check. Throwing makes the message appear in
// the 400 response's errors array.
function assertPasswordPolicy(password) {
  const failed = getFailedPasswordRules(password);
  if (failed.length) {
    throw new Error(
      `Password does not meet the requirements: ${failed
        .map((rule) => rule.label)
        .join("; ")}`,
    );
  }
  return true;
}

module.exports = {
  PASSWORD_MIN_LENGTH,
  PASSWORD_MAX_LENGTH,
  PASSWORD_RULES,
  getFailedPasswordRules,
  assertPasswordPolicy,
};
