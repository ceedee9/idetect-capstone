let mockCurrentUser = null;

jest.mock("../src/config/database", () => ({
  query: jest.fn(),
  connect: jest.fn(),
}));
jest.mock("../src/middleware/auth", () => ({
  authenticate: (req, res, next) => {
    req.user = mockCurrentUser;
    next();
  },
  authenticateBeneficiary: (req, res, next) => next(),
  authenticateEstablishment: (req, res, next) => next(),
  requireRole: () => (req, res, next) => next(),
}));
jest.mock("../src/services/fcmService", () => ({ sendPushNotification: jest.fn() }));
jest.mock("../src/services/smsService", () => ({ sendSms: jest.fn() }));
jest.mock("../src/services/storageService", () => ({
  uploadDisputeDocument: jest.fn(),
  buildAbsoluteApiUploadUrl: jest.fn(),
}));

const pool = require("../src/config/database");
const router = require("../src/routes/disputes");

function routeStack(method, path) {
  return router.stack
    .find((layer) => layer.route?.path === path && layer.route.methods[method])
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
    if (outcome.error) return outcome;
    if (outcome.finished) return outcome;
  }
  return { finished: true };
}

function makeRes() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(value) {
      this.body = value;
      return this;
    },
  };
}

const listRow = {
  id: "dispute-1",
  dispute_type: "business_refusal",
  beneficiary_name: "Juan Dela Cruz",
  beneficiary_id_number: "SC-123456",
  beneficiary_type: "senior_citizen",
};

async function listDisputesAs(portalRole) {
  mockCurrentUser = { id: "user-1", portalRole };
  pool.query
    .mockResolvedValueOnce({ rows: [{ ...listRow }] })
    .mockResolvedValueOnce({ rows: [{ count: "1" }] });
  const res = makeRes();
  const outcome = await runRoute(routeStack("get", "/"), { query: {}, user: mockCurrentUser }, res);
  expect(outcome.error).toBeUndefined();
  return res.body;
}

beforeEach(() => {
  pool.query.mockReset();
});

describe("GET /api/disputes beneficiary privacy by role", () => {
  test("BPLO gets no beneficiary name and a masked ID", async () => {
    const body = await listDisputesAs("bplo_admin");

    expect(body.data[0].beneficiary_name).toBeNull();
    expect(body.data[0].beneficiary_id_number).toBe("*******56");
    expect(body.data[0].dispute_type).toBe("business_refusal");
  });

  test("OSCA keeps the full name and ID for its own dispute records", async () => {
    const body = await listDisputesAs("osca_admin");

    expect(body.data[0].beneficiary_name).toBe("Juan Dela Cruz");
    expect(body.data[0].beneficiary_id_number).toBe("SC-123456");
  });
});
