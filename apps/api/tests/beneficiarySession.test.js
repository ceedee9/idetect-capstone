const jwt = require("jsonwebtoken");

jest.mock("../src/config/database", () => ({ query: jest.fn() }));

const pool = require("../src/config/database");
const { authenticateBeneficiary } = require("../src/middleware/auth");

const SECRET = "test-beneficiary-secret";

function run(authHeader) {
  const res = {
    statusCode: 200,
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
  const req = { headers: authHeader ? { authorization: authHeader } : {} };
  let nextCalled = false;
  let nextErr = null;
  return authenticateBeneficiary(req, res, (err) => {
    nextCalled = true;
    nextErr = err || null;
  }).then(() => ({ req, res, nextCalled, nextErr }));
}

const tokenWith = (payload) =>
  `Bearer ${jwt.sign({ id: "acct-1", type: "beneficiary", ...payload }, SECRET)}`;

describe("authenticateBeneficiary session check", () => {
  beforeEach(() => {
    process.env.JWT_SECRET_BENEFICIARY = SECRET;
    pool.query.mockReset();
  });

  test("accepts a token whose session_version matches the account", async () => {
    pool.query.mockResolvedValue({
      rows: [{ is_active: true, session_version: 3 }],
    });
    const out = await run(tokenWith({ sv: 3 }));
    expect(out.nextCalled).toBe(true);
    expect(out.req.beneficiary.id).toBe("acct-1");
    expect(out.req.beneficiary.accountId).toBe("acct-1");
  });

  test("rejects a token issued before another phone logged in", async () => {
    pool.query.mockResolvedValue({
      rows: [{ is_active: true, session_version: 4 }],
    });
    const out = await run(tokenWith({ sv: 3 }));
    expect(out.nextCalled).toBe(false);
    expect(out.res.statusCode).toBe(401);
    expect(out.res.body.code).toBe("SESSION_ENDED");
  });

  test("rejects a legacy token that has no session version", async () => {
    pool.query.mockResolvedValue({
      rows: [{ is_active: true, session_version: 0 }],
    });
    const out = await run(tokenWith({}));
    expect(out.res.statusCode).toBe(401);
    expect(out.res.body.code).toBe("SESSION_ENDED");
  });

  test("rejects an inactive account even when the version matches", async () => {
    pool.query.mockResolvedValue({
      rows: [{ is_active: false, session_version: 3 }],
    });
    const out = await run(tokenWith({ sv: 3 }));
    expect(out.res.statusCode).toBe(401);
    expect(out.res.body.code).toBe("SESSION_ENDED");
  });

  test("rejects when the account no longer exists", async () => {
    pool.query.mockResolvedValue({ rows: [] });
    const out = await run(tokenWith({ sv: 0 }));
    expect(out.res.statusCode).toBe(401);
    expect(out.res.body.code).toBe("SESSION_ENDED");
  });

  test("rejects a token signed with the wrong secret without querying", async () => {
    const forged = `Bearer ${jwt.sign({ id: "acct-1", sv: 0 }, "other")}`;
    const out = await run(forged);
    expect(out.res.statusCode).toBe(403);
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("returns 401 when no token is sent", async () => {
    const out = await run(undefined);
    expect(out.res.statusCode).toBe(401);
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("passes database errors to next()", async () => {
    const dbError = new Error("db down");
    pool.query.mockRejectedValue(dbError);
    const out = await run(tokenWith({ sv: 0 }));
    expect(out.nextCalled).toBe(true);
    expect(out.nextErr).toBe(dbError);
  });
});
