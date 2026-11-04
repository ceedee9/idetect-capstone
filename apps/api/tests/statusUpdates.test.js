jest.mock("../src/config/database", () => ({
  query: jest.fn(),
  connect: jest.fn(),
}));
jest.mock("../src/middleware/auth", () => ({
  authenticate: (req, res, next) => next(),
  authenticateBeneficiary: (req, res, next) => next(),
  authenticateEstablishment: (req, res, next) => next(),
  requireRole: () => (req, res, next) => next(),
}));
jest.mock("../src/services/smsService");
jest.mock("../src/services/fcmService", () => ({
  sendPushNotification: jest.fn().mockResolvedValue({ invalidToken: false }),
}));
jest.mock("../src/services/storageService", () => ({
  uploadIdCaptureBase64: jest.fn(),
  buildAbsoluteApiUploadUrl: jest.fn(),
}));

const crypto = require("crypto");
const pool = require("../src/config/database");
const router = require("../src/routes/verification");

// The route handler is the last layer, after auth and the rate limiter.
const handler = router.stack
  .find((layer) => layer.route?.path === "/status-updates")
  .route.stack.at(-1).handle;

function mockRes() {
  const res = { statusCode: 200, body: undefined };
  res.status = (code) => {
    res.statusCode = code;
    return res;
  };
  res.json = (body) => {
    res.body = body;
    return res;
  };
  return res;
}

const sha = (value) => crypto.createHash("sha256").update(value).digest("hex");

describe("GET /verification/status-updates", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.useFakeTimers().setSystemTime(new Date("2026-01-01T00:00:10.000Z"));
  });
  afterEach(() => jest.useRealTimers());

  test("returns hashed IDs and pulls the cursor back by 5 seconds", async () => {
    const since = new Date("2026-01-01T00:00:00.000Z").getTime();
    pool.query.mockResolvedValue({
      rows: [
        {
          id_number: "12-3456",
          status: "revoked",
          updated_at: "2026-01-01T00:00:05.000Z",
        },
      ],
    });
    const res = mockRes();

    await handler({ query: { since: String(since) } }, res, jest.fn());

    expect(res.body.updates[0].id_number).toBe(sha("123456"));
    expect(res.body.has_more).toBe(false);
    expect(res.body.next_since).toBe(Date.now() - 5000);
  });

  test("never moves the cursor behind the one the device sent", async () => {
    pool.query.mockResolvedValue({ rows: [] });
    const since = Date.now() - 1000;
    const res = mockRes();

    await handler({ query: { since: String(since) } }, res, jest.fn());

    expect(res.body.next_since).toBe(since);
  });

  test("blocked_only=true filters to revoked and suspended rows", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await handler(
      { query: { since: "0", blocked_only: "true" } },
      mockRes(),
      jest.fn(),
    );

    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toContain("IN ('revoked', 'suspended')");
    expect(params[2]).toBe(true);
  });

  test("without blocked_only every status is returned", async () => {
    pool.query.mockResolvedValue({ rows: [] });

    await handler({ query: { since: "0" } }, mockRes(), jest.fn());

    expect(pool.query.mock.calls[0][1][2]).toBe(false);
  });

  test("a full page keeps the cursor at the last row", async () => {
    const rows = Array.from({ length: 1000 }, (_, i) => ({
      id_number: `ID${i}`,
      status: "revoked",
      updated_at: "2026-01-01T00:00:07.000Z",
    }));
    pool.query.mockResolvedValue({ rows });
    const res = mockRes();

    await handler({ query: { since: "0" } }, res, jest.fn());

    expect(res.body.has_more).toBe(true);
    expect(res.body.next_since).toBe(
      new Date("2026-01-01T00:00:07.000Z").getTime(),
    );
  });
});
