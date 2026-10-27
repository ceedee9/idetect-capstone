// Mirrors apps/api/src/utils/passwordPolicy.js. Keep the two files in sync.

export const PASSWORD_MIN_LENGTH = 8;
export const PASSWORD_MAX_LENGTH = 128;

export const PASSWORD_RULES = [
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

export function getFailedPasswordRules(password) {
  return PASSWORD_RULES.filter((rule) => !rule.test(password));
}

export function isPasswordValid(password) {
  return getFailedPasswordRules(password).length === 0;
}
