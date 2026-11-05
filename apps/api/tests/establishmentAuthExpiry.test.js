const jwt = require("jsonwebtoken");

jest.mock("../src/config/database", () => ({ query: jest.fn() }));

const pool = require("../src/config/database");
const { authenticateEstablishment } = require("../src/middleware/auth");

function run(token) {
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
  const req = { headers: token ? { authorization: ["Bearer", token].join(" ") } : {} };
  const next = jest.fn();
  return authenticateEstablishment(req, res, next).then(() => ({
    req,
    res,
    next,
  }));
}

describe("authenticateEstablishment session expiry", () => {
  beforeEach(() => {
    process.env.JWT_SECRET_ESTABLISHMENT = "test-secret";
    pool.query.mockReset();
  });

  test("returns 401 SESSION_EXPIRED for an expired token", async () => {
    const token = jwt.sign({ id: "est-1" }, "test-secret", { expiresIn: -10 });

    const { res, next } = await run(token);

    expect(res.statusCode).toBe(401);
    expect(res.body.code).toBe("SESSION_EXPIRED");
    expect(next).not.toHaveBeenCalled();
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("returns 401 SESSION_INVALID for a token signed with another secret", async () => {
    const token = jwt.sign({ id: "est-1" }, "other-secret");

    const { res } = await run(token);

    expect(res.statusCode).toBe(401);
    expect(res.body.code).toBe("SESSION_INVALID");
  });

  test("passes database failures to the error handler instead of reporting an expired session", async () => {
    const token = jwt.sign({ id: "est-1" }, "test-secret", { expiresIn: "1h" });
    const failure = new Error("db down");
    pool.query.mockRejectedValue(failure);

    const { res, next } = await run(token);

    expect(res.statusCode).toBeNull();
    expect(next).toHaveBeenCalledWith(failure);
  });

  test("accepts a valid token for an approved establishment", async () => {
    const token = jwt.sign({ id: "est-1" }, "test-secret", { expiresIn: "1h" });
    pool.query.mockResolvedValue({
      rows: [
        {
          establishment_id: "est-1",
          establishment_status: "approved",
          establishment_user_id: null,
          role: null,
          account_status: null,
          invitation_status: null,
          password_reset_required: false,
        },
      ],
    });

    const { res, next } = await run(token);

    expect(res.statusCode).toBeNull();
    expect(next).toHaveBeenCalledWith();
  });
});
