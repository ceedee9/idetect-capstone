const jwt = require("jsonwebtoken");

jest.mock("../src/config/database", () => ({ query: jest.fn() }));
jest.mock("../src/services/smsService", () => ({
  sendOtp: jest.fn(),
  sendSms: jest.fn(),
}));

const pool = require("../src/config/database");
const router = require("../src/routes/auth");

const handler = router.stack.find(
  (layer) => layer.route?.path === "/staff/refresh" && layer.route.methods.post,
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
    { headers: {}, ...req },
    res,
    (error) => {
      throw error;
    },
  ).then(() => res);
}

describe("POST /auth/staff/refresh absolute session lifetime", () => {
  beforeEach(() => {
    process.env.JWT_SECRET_STAFF = "test-secret";
    process.env.JWT_EXPIRES_IN = "8h";
    pool.query.mockReset().mockResolvedValue({
      rows: [
        {
          id: "user-1",
          email: "staff@example.com",
          role: "bplo_admin",
          full_name: "Staff User",
          is_active: true,
        },
      ],
    });
  });

  test("preserves the original session start when refreshing", async () => {
    const sessionStartedAt = Math.floor(Date.now() / 1000) - 60;
    const token = jwt.sign(
      {
        id: "user-1",
        email: "staff@example.com",
        role: "bplo_admin",
        session_started_at: sessionStartedAt,
      },
      "test-secret",
    );

    const res = await run({
      headers: { authorization: `Bearer ${token}` },
    });

    expect(res.statusCode).toBeNull();
    const refreshed = jwt.verify(res.body.token, "test-secret");
    expect(refreshed.session_started_at).toBe(sessionStartedAt);
  });

  test("rejects refresh after eight hours from the original login", async () => {
    const sessionStartedAt =
      Math.floor(Date.now() / 1000) - 8 * 60 * 60 - 1;
    const token = jwt.sign(
      { id: "user-1", session_started_at: sessionStartedAt },
      "test-secret",
    );

    const res = await run({
      headers: { authorization: `Bearer ${token}` },
    });

    expect(res.statusCode).toBe(401);
    expect(res.body).toEqual({ error: "Session lifetime exceeded" });
    expect(pool.query).not.toHaveBeenCalled();
  });
});
