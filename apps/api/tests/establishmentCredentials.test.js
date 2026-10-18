process.env.JWT_SECRET_STAFF = "test-secret";

jest.mock("../src/config/database", () => ({
  query: jest.fn(),
  connect: jest.fn(),
}));
jest.mock("../src/middleware/auth", () => ({
  authenticate: (req, res, next) => {
    req.user = { id: "bplo-1", role: "bplo_admin" };
    next();
  },
  authenticateBeneficiary: (req, res, next) => next(),
  authenticateEstablishment: (req, res, next) => next(),
  requireRole: () => (req, res, next) => next(),
}));
jest.mock("../src/services/smsService", () => ({ sendSms: jest.fn() }));
jest.mock("../src/services/emailService", () => ({
  sendEstablishmentSetupLink: jest.fn(),
}));

const jwt = require("jsonwebtoken");
const pool = require("../src/config/database");
const router = require("../src/routes/establishments");

const TOKEN = "11111111-2222-3333-4444-555555555555";
const CREDENTIALS = [
  {
    business_name: "Acme Store",
    business_permit_no: "P-1",
    email: "acme@example.com",
    password: "Secret-One-1",
    email_auto_generated: true,
  },
  {
    business_name: "Beta Shop",
    business_permit_no: "P-2",
    email: "beta@example.com",
    password: "Secret-Two-2",
    email_auto_generated: false,
  },
];

function routeStack() {
  return router.stack
    .find((layer) => layer.route?.path === "/bulk-credentials/:token" && layer.route.methods.get)
    .route.stack.map((layer) => layer.handle);
}

async function runRoute(stack, req, res) {
  for (const handler of stack) {
    const outcome = await new Promise((resolve) => {
      let settled = false;
      const done = (value) => {
        if (!settled) {
          settled = true;
          resolve(value);
        }
      };
      const next = (err) => done(err ? { error: err } : { next: true });
      Promise.resolve(handler(req, res, next)).then(
        () => done({ finished: true }),
        (err) => done({ error: err }),
      );
    });
    if (outcome.error || outcome.finished) return outcome;
  }
  return { finished: true };
}

function makeRes() {
  return {
    statusCode: 200,
    body: null,
    headers: {},
    sent: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(value) {
      this.body = value;
      return this;
    },
    setHeader(name, value) {
      this.headers[name] = value;
    },
    send(value) {
      this.sent = value;
      return this;
    },
  };
}

function stepUpHeader() {
  const proof = jwt.sign({ id: "bplo-1", step_up: true }, "test-secret", { expiresIn: "5m" });
  return { "x-step-up-token": proof };
}

function seedToken() {
  router.credentialTokenStore.set(TOKEN, {
    credentials: CREDENTIALS,
    expiresAt: Date.now() + 15 * 60 * 1000,
  });
}

beforeEach(() => {
  jest.clearAllMocks();
  router.credentialTokenStore.clear();
});

test("rejects the download without a step-up token and keeps the token", async () => {
  seedToken();
  const res = makeRes();
  await runRoute(routeStack(), { params: { token: TOKEN }, headers: {}, query: {} }, res);

  expect(res.statusCode).toBe(401);
  expect(pool.query).not.toHaveBeenCalled();
  expect(router.credentialTokenStore.has(TOKEN)).toBe(true);
});

test("writes the audit row before returning the CSV and consumes the token", async () => {
  seedToken();
  pool.query.mockResolvedValue({ rows: [] });
  const res = makeRes();
  await runRoute(routeStack(), { params: { token: TOKEN }, headers: stepUpHeader(), query: {} }, res);

  expect(pool.query).toHaveBeenCalledTimes(1);
  const [sql, params] = pool.query.mock.calls[0];
  expect(sql).toMatch(/INSERT INTO audit_logs/);
  expect(sql).toMatch(/'credentials_downloaded'/);
  expect(params[0]).toBe("bplo-1");
  expect(JSON.parse(params[1])).toEqual({ count: 2 });
  expect(params[1]).not.toMatch(/Secret/);

  expect(res.statusCode).toBe(200);
  expect(res.sent).toMatch(/Secret-One-1/);
  expect(router.credentialTokenStore.has(TOKEN)).toBe(false);
});

test("keeps the token when the audit write fails so the officer can retry", async () => {
  seedToken();
  const dbError = new Error("audit write failed");
  pool.query.mockRejectedValue(dbError);
  const res = makeRes();
  const outcome = await runRoute(
    routeStack(),
    { params: { token: TOKEN }, headers: stepUpHeader(), query: {} },
    res,
  );

  expect(outcome.error).toBe(dbError);
  expect(res.sent).toBeNull();
  expect(router.credentialTokenStore.has(TOKEN)).toBe(true);
});

test("a used token cannot be downloaded again", async () => {
  pool.query.mockResolvedValue({ rows: [] });
  seedToken();
  await runRoute(
    routeStack(),
    { params: { token: TOKEN }, headers: stepUpHeader(), query: {} },
    makeRes(),
  );

  const res = makeRes();
  await runRoute(routeStack(), { params: { token: TOKEN }, headers: stepUpHeader(), query: {} }, res);
  expect(res.statusCode).toBe(404);
});
