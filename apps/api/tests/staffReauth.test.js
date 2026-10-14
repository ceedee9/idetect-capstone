const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");

jest.mock("../src/config/database", () => ({ query: jest.fn() }));
jest.mock("../src/services/smsService", () => ({
  sendOtp: jest.fn(),
  sendSms: jest.fn(),
}));

const pool = require("../src/config/database");
const router = require("../src/routes/auth");

const handler = router.stack.find(
  (layer) => layer.route?.path === "/staff/reauth",
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

describe("POST /auth/staff/reauth", () => {
  beforeEach(async () => {
    process.env.JWT_SECRET_STAFF = "test-secret";
    pool.query.mockReset();
    pool.query.mockResolvedValue({
      rows: [
        {
          id: "staff-id",
          password_hash: await bcrypt.hash("correct-password", 4),
          is_active: true,
        },
      ],
    });
  });

  test("returns a short-lived step-up token for the current password", async () => {
    const token = jwt.sign({ id: "staff-id" }, "test-secret");
    const res = await run({
      headers: { authorization: `Bearer ${token}` },
      body: { password: "correct-password" },
    });

    expect(res.statusCode).toBeNull();
    expect(res.body.expires_in).toBe(300);
    expect(jwt.verify(res.body.step_up_token, "test-secret")).toEqual(
      expect.objectContaining({ id: "staff-id", step_up: true }),
    );
  });

  test("rejects an incorrect current password", async () => {
    const token = jwt.sign({ id: "staff-id" }, "test-secret");
    const res = await run({
      headers: { authorization: `Bearer ${token}` },
      body: { password: "wrong-password" },
    });

    expect(res.statusCode).toBe(401);
    expect(res.body).toEqual({ error: "Current password is incorrect" });
  });
});
