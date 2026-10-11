const jwt = require("jsonwebtoken");

jest.mock("../src/config/database", () => ({ query: jest.fn() }));
jest.mock("../src/services/smsService", () => ({
  sendOtp: jest.fn(),
  sendSms: jest.fn(),
}));

const pool = require("../src/config/database");
const router = require("../src/routes/auth");

const handler = router.stack.find(
  (layer) =>
    layer.route?.path === "/establishment/logout" &&
    layer.route.methods.post,
).route.stack[0].handle;

function run(req = {}) {
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
    (error) => {
      throw error;
    },
  ).then(() => res);
}

describe("POST /auth/establishment/logout", () => {
  beforeEach(() => {
    process.env.JWT_SECRET_ESTABLISHMENT = "test-secret";
    pool.query.mockReset().mockResolvedValue({});
  });

  const token = () =>
    jwt.sign({ id: "establishment-1", type: "establishment" }, "test-secret");

  test("records a manual logout", async () => {
    const res = await run({
      headers: { authorization: `Bearer ${token()}` },
    });

    expect(res.statusCode).toBe(204);
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toContain("'logout'");
    expect(params[0]).toBe("establishment-1");
    expect(JSON.parse(params[1]).reason).toBe("manual");
  });

  test("records an idle timeout", async () => {
    await run({
      headers: { authorization: `Bearer ${token()}` },
      body: { reason: "idle_timeout" },
    });

    expect(JSON.parse(pool.query.mock.calls[0][1][1]).reason).toBe(
      "idle_timeout",
    );
  });

  test("rejects missing or invalid tokens without writing", async () => {
    expect((await run()).statusCode).toBe(401);
    expect(
      (await run({ headers: { authorization: "Bearer invalid" } })).statusCode,
    ).toBe(401);
    expect(pool.query).not.toHaveBeenCalled();
  });
});
