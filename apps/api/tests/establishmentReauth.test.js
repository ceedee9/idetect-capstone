const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");

jest.mock("../src/config/database", () => ({ query: jest.fn() }));
jest.mock("../src/services/smsService", () => ({
  sendOtp: jest.fn(),
  sendSms: jest.fn(),
}));

const pool = require("../src/config/database");
const router = require("../src/routes/auth");

const SECRET = "test-establishment-secret";
const ESTABLISHMENT_ID = "est-1";
const USER_ID = "user-1";

const handler = router.stack.find(
  (layer) => layer.route?.path === "/establishment/reauth",
).route.stack[0].handle;

function run(req) {
  const res = {
    statusCode: null,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
  return handler(
    { headers: {}, body: {}, ...req },
    res,
    (error) => {
      throw error;
    },
  ).then(() => res);
}

function bearer() {
  const token = jwt.sign(
    { id: ESTABLISHMENT_ID, establishment_user_id: USER_ID, type: "establishment" },
    SECRET,
  );
  return `Bearer ${token}`;
}

describe("POST /auth/establishment/reauth", () => {
  beforeEach(async () => {
    process.env.JWT_SECRET_ESTABLISHMENT = SECRET;
    pool.query.mockReset();
    pool.query.mockResolvedValue({
      rows: [
        {
          id: ESTABLISHMENT_ID,
          status: "approved",
          password_hash: null,
          establishment_user_id: USER_ID,
          user_password_hash: await bcrypt.hash("correct-password", 4),
          user_account_status: "active",
        },
      ],
    });
  });

  test("returns a short-lived step-up token for the current password", async () => {
    const res = await run({
      headers: { authorization: bearer() },
      body: { password: "correct-password" },
    });

    expect(res.statusCode).toBeNull();
    expect(res.body.expires_in).toBe(300);
    expect(jwt.verify(res.body.step_up_token, SECRET)).toEqual(
      expect.objectContaining({
        id: ESTABLISHMENT_ID,
        establishment_user_id: USER_ID,
        step_up: true,
      }),
    );
  });

  test("rejects an incorrect current password", async () => {
    const res = await run({
      headers: { authorization: bearer() },
      body: { password: "wrong-password" },
    });

    expect(res.statusCode).toBe(401);
    expect(res.body).toEqual({ error: "Current password is incorrect" });
    expect(res.body.step_up_token).toBeUndefined();
  });

  test("requires a bearer token and a password", async () => {
    const res = await run({ headers: {}, body: { password: "correct-password" } });
    expect(res.statusCode).toBe(401);
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("refuses when the establishment is not approved", async () => {
    pool.query.mockResolvedValue({
      rows: [{ id: ESTABLISHMENT_ID, status: "pending" }],
    });
    const res = await run({
      headers: { authorization: bearer() },
      body: { password: "correct-password" },
    });
    expect(res.statusCode).toBe(403);
  });

  test("refuses when the user account is locked", async () => {
    pool.query.mockResolvedValue({
      rows: [
        {
          id: ESTABLISHMENT_ID,
          status: "approved",
          establishment_user_id: USER_ID,
          user_password_hash: await bcrypt.hash("correct-password", 4),
          user_account_status: "locked",
        },
      ],
    });
    const res = await run({
      headers: { authorization: bearer() },
      body: { password: "correct-password" },
    });
    expect(res.statusCode).toBe(403);
    expect(res.body.step_up_token).toBeUndefined();
  });
});
