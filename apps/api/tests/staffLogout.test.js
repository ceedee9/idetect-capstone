const jwt = require("jsonwebtoken");

jest.mock("../src/config/database", () => ({ query: jest.fn() }));
jest.mock("../src/services/smsService", () => ({
  sendOtp: jest.fn(),
  sendSms: jest.fn(),
}));

const pool = require("../src/config/database");
const router = require("../src/routes/auth");

const handler = router.stack.find(
  (l) => l.route?.path === "/staff/logout" && l.route.methods.post,
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
    end() {
      return this;
    },
  };
  return handler(
    { ip: "127.0.0.1", body: {}, headers: {}, ...req },
    res,
    (e) => {
      throw e;
    },
  ).then(() => res);
}

describe("POST /auth/staff/logout", () => {
  beforeEach(() => {
    process.env.JWT_SECRET_STAFF = "test-secret";
    pool.query.mockReset().mockResolvedValue({});
  });

  const token = () =>
    jwt.sign({ id: "user-1", email: "a@b.ph" }, "test-secret");

  test("records a logout with the given reason", async () => {
    const res = await run({
      headers: { authorization: `Bearer ${token()}` },
      body: { reason: "idle_timeout" },
    });
    expect(res.statusCode).toBe(204);
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toContain("'logout'");
    expect(params[0]).toBe("user-1");
    expect(JSON.parse(params[1]).reason).toBe("idle_timeout");
  });

  test("falls back to manual for an unknown reason", async () => {
    await run({
      headers: { authorization: `Bearer ${token()}` },
      body: { reason: "anything" },
    });
    expect(JSON.parse(pool.query.mock.calls[0][1][1]).reason).toBe("manual");
  });

  test("rejects a missing or invalid token without writing", async () => {
    expect((await run({})).statusCode).toBe(401);
    const bad = await run({ headers: { authorization: "Bearer nope" } });
    expect(bad.statusCode).toBe(401);
    expect(pool.query).not.toHaveBeenCalled();
  });
});
