const express = require("express");

jest.mock("../src/config/database", () => ({
  query: jest.fn(),
  connect: jest.fn(),
}));
jest.mock("../src/middleware/auth", () => ({
  authenticate: (req, res, next) => {
    req.user = { id: "staff-1", role: "bplo_super_admin" };
    next();
  },
  authenticateEstablishment: (req, res, next) => {
    req.establishment = {
      id: "est-1",
      establishment_user_id: "eu-1",
      role: "establishment_super_user",
    };
    next();
  },
  authenticateBeneficiary: (req, res, next) => next(),
  requireRole: () => (req, res, next) => next(),
}));
jest.mock("../src/services/smsService", () => ({
  sendOtp: jest.fn(),
  sendSms: jest.fn(),
}));
jest.mock("../src/services/emailService", () => ({
  sendEstablishmentSetupLink: jest.fn(),
  sendEstablishmentUserInvitation: jest.fn(),
}));

const {
  getFailedPasswordRules,
  PASSWORD_MAX_LENGTH,
} = require("../src/utils/passwordPolicy");

const ID = "11111111-2222-4333-8444-555555555555";
const WEAK = "password";
const STRONG = "Valid-Pass1";
const TOO_LONG = `Aa1!${"x".repeat(PASSWORD_MAX_LENGTH)}`;

// Every route that sets or changes a password. Paths match app.js mounts.
const CASES = [
  {
    name: "BPLO staff account creation",
    method: "POST",
    path: "/api/staff",
    field: "password",
    body: (password) => ({
      email: "new.staff@example.com",
      full_name: "New Staff",
      role: "bplo_admin",
      password,
    }),
  },
  {
    name: "BPLO staff password reset",
    method: "PATCH",
    path: `/api/staff/${ID}/reset-password`,
    field: "password",
    body: (password) => ({ password }),
  },
  {
    name: "BPLO staff change own password",
    method: "PATCH",
    path: "/api/staff/me/change-password",
    field: "new_password",
    body: (new_password) => ({ current_password: "OldPass1!", new_password }),
  },
  {
    name: "BPLO staff reset link",
    method: "POST",
    path: "/api/auth/staff/reset-password",
    field: "new_password",
    body: (new_password) => ({
      email: "staff@example.com",
      token: "token",
      new_password,
    }),
  },
  {
    name: "Establishment self-registration",
    method: "POST",
    path: "/api/establishments/register",
    field: "password",
    body: (password) => ({
      email: "biz@example.com",
      password,
      business_name: "Biz",
      business_permit_no: "P-1",
      owner_name: "Owner",
      address: "Address",
      contact_number: "09171234567",
    }),
  },
  {
    name: "BPLO admin reset of establishment password",
    method: "PATCH",
    path: `/api/establishments/${ID}/admin-reset-password`,
    field: "new_password",
    body: (new_password) => ({ new_password }),
  },
  {
    name: "Establishment user password reset",
    method: "PATCH",
    path: `/api/establishment-users/${ID}/reset-password`,
    field: "password",
    body: (password) => ({ password }),
  },
  {
    name: "Establishment OTP reset",
    method: "POST",
    path: "/api/auth/establishment/reset-password",
    field: "new_password",
    body: (new_password) => ({
      contact_number: "09171234567",
      otp: "123456",
      new_password,
    }),
  },
  {
    name: "Establishment change own password",
    method: "POST",
    path: "/api/auth/establishment/change-password",
    field: "new_password",
    body: (new_password) => ({ current_password: "OldPass1!", new_password }),
  },
  {
    name: "Establishment setup link",
    method: "POST",
    path: "/api/auth/establishment/setup-password",
    field: "new_password",
    body: (new_password) => ({
      email: "owner@example.com",
      token: "token",
      new_password,
    }),
  },
  {
    name: "Establishment invitation acceptance",
    method: "POST",
    path: "/api/auth/establishment/accept-invitation",
    field: "new_password",
    body: (new_password) => ({
      email: "owner@example.com",
      token: "token",
      new_password,
    }),
  },
];

let server;
let baseUrl;

beforeAll(async () => {
  const app = express();
  app.use(express.json());
  app.use("/api/auth", require("../src/routes/auth"));
  app.use("/api/establishments", require("../src/routes/establishments"));
  app.use(
    "/api/establishment-users",
    require("../src/routes/establishmentUsers"),
  );
  app.use("/api/staff", require("../src/routes/staff"));
  app.use((err, req, res, next) =>
    res.status(500).json({ error: "server error" }),
  );
  await new Promise((resolve) => {
    server = app.listen(0, "127.0.0.1", resolve);
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

afterAll(() => new Promise((resolve) => server.close(resolve)));

async function send(method, path, body) {
  const res = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer test-token",
    },
    body: JSON.stringify(body),
  });
  return { status: res.status, json: await res.json().catch(() => null) };
}

function fieldErrors(json, field) {
  return (json?.errors ?? [])
    .filter((e) => e.path === field)
    .map((e) => e.msg);
}

describe("password policy rules", () => {
  test.each([
    ["Sh1!", "At least 8 characters"],
    ["alllowercase1!", "One uppercase letter (A-Z)"],
    ["ALLUPPERCASE1!", "One lowercase letter (a-z)"],
    ["NoDigitsHere!", "One number (0-9)"],
    ["NoSpecial123", "One special character (e.g. ! @ # $ %)"],
  ])("rejects %s and names the missing rule", (password, missing) => {
    const failed = getFailedPasswordRules(password).map((r) => r.label);
    expect(failed).toEqual([missing]);
  });

  test("treats letters with diacritics as letters, not special characters", () => {
    expect(getFailedPasswordRules("Abcdefg1ñ").map((r) => r.key)).toEqual([
      "special",
    ]);
  });

  test("accepts a password that meets every rule", () => {
    expect(getFailedPasswordRules("Valid-Pass1")).toEqual([]);
  });

});

describe.each(CASES)("$name", ({ method, path, field, body }) => {
  test("rejects a weak password and lists the failed rules", async () => {
    const { status, json } = await send(method, path, body(WEAK));
    expect(status).toBe(400);
    const messages = fieldErrors(json, field);
    expect(messages).toHaveLength(1);
    expect(messages[0]).toContain("uppercase letter");
    expect(messages[0]).toContain("special character");
  });

  test("rejects a password over the maximum length", async () => {
    const { json } = await send(method, path, body(TOO_LONG));
    expect(fieldErrors(json, field)).toEqual([
      `Password must be at most ${PASSWORD_MAX_LENGTH} characters`,
    ]);
  });

  test("accepts a password that meets every rule", async () => {
    const { json } = await send(method, path, body(STRONG));
    expect(fieldErrors(json, field)).toEqual([]);
  });
});
