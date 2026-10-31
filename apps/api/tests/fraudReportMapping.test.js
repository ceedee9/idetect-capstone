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
jest.mock("../src/services/fcmService", () => ({
  sendPushNotification: jest.fn().mockResolvedValue({ invalidToken: false }),
}));
jest.mock("../src/services/staffAlerts", () => ({
  createStaffAlert: jest.fn().mockResolvedValue(null),
}));

const pool = require("../src/config/database");
const router = require("../src/routes/beneficiaryPortal");

const DISPUTE_ID = "3f2a1b4c-5d6e-4f70-8a9b-0c1d2e3f4a5b";

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

// Submits a fraud report and returns the dispute_type written to the
// disputes table (the third parameter of the INSERT).
async function submitReportAndGetDisputeType(reportType) {
  pool.query.mockReset();
  pool.query.mockResolvedValue({ rows: [{ id: DISPUTE_ID }] });

  const req = {
    body: {
      report_type: reportType,
      description: "A copy of my ID was used without my permission",
    },
    beneficiary: { id: "account-1", beneficiary_id: "beneficiary-1" },
  };
  const res = makeRes();
  const outcome = await runRoute(routeStack("post", "/fraud-report"), req, res);

  expect(outcome.error).toBeUndefined();
  expect(res.statusCode).toBe(201);
  const [, params] = pool.query.mock.calls[0];
  return params[2];
}

describe("POST /api/beneficiary-portal/fraud-report dispute type mapping", () => {
  test("Fake / Cloned ID reports are filed as 'other', not incorrect_db_info", async () => {
    expect(await submitReportAndGetDisputeType("fake_id")).toBe("other");
  });

  test("Other reports are filed as 'other', not incorrect_db_info", async () => {
    expect(await submitReportAndGetDisputeType("other")).toBe("other");
  });

  test("Unauthorized use and stolen ID reports remain 'unauthorized_use'", async () => {
    expect(await submitReportAndGetDisputeType("unauthorized_use")).toBe(
      "unauthorized_use",
    );
    expect(await submitReportAndGetDisputeType("stolen_id")).toBe(
      "unauthorized_use",
    );
  });
});
