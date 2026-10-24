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

const ExcelJS = require("exceljs");
const jwt = require("jsonwebtoken");
const pool = require("../src/config/database");
const router = require("../src/routes/verification");

const ESTABLISHMENT_ID = "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d";
const ESTABLISHMENT_USER_ID = "11111111-2222-4333-8444-555555555555";
const ESTABLISHMENT_SECRET = "test-establishment-secret";
process.env.JWT_SECRET_ESTABLISHMENT = ESTABLISHMENT_SECRET;

function stepUpToken(overrides = {}, secret = ESTABLISHMENT_SECRET) {
  return jwt.sign(
    {
      id: ESTABLISHMENT_ID,
      establishment_user_id: ESTABLISHMENT_USER_ID,
      step_up: true,
      ...overrides,
    },
    secret,
    { expiresIn: "5m" },
  );
}

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
    if (outcome.error) throw outcome.error;
    if (outcome.finished) return;
  }
}

function mockRes() {
  const res = { headers: {}, statusCode: 200, body: undefined };
  res.setHeader = (key, value) => {
    res.headers[key.toLowerCase()] = value;
    return res;
  };
  res.status = (code) => {
    res.statusCode = code;
    return res;
  };
  res.json = (body) => {
    res.body = body;
    return res;
  };
  res.send = (body) => {
    res.body = body;
    return res;
  };
  return res;
}

function scanRow(overrides = {}) {
  return {
    reference_no: "REF-0001",
    id_number_scanned: "ABC123456",
    beneficiary_type_detected: "senior",
    result: "manual_review",
    ocr_confidence_score: 88,
    manually_entered: false,
    verified_at: new Date("2026-05-10T02:30:00Z"),
    beneficiary_name: "Juan Dela Cruz",
    ...overrides,
  };
}

function req(query, headers = { "x-step-up-token": stepUpToken() }) {
  return {
    query,
    headers,
    establishment: {
      id: ESTABLISHMENT_ID,
      establishment_user_id: ESTABLISHMENT_USER_ID,
      role: "establishment_super_user",
    },
  };
}

function auditInsertCalls() {
  return pool.query.mock.calls.filter(([sql]) => /INSERT INTO audit_logs/.test(sql));
}

function historyQueryCalls() {
  return pool.query.mock.calls.filter(([sql]) => /FROM verification_logs/.test(sql));
}

describe("GET /verification/history/export", () => {
  const stack = routeStack("get", "/history/export");

  beforeEach(() => {
    pool.query.mockReset();
    pool.query.mockImplementation(async (sql) => {
      if (/INSERT INTO audit_logs/.test(sql)) return { rows: [] };
      if (/FROM verification_logs/.test(sql)) return { rows: [scanRow()] };
      throw new Error(`Unexpected query: ${sql}`);
    });
  });

  test("requires a valid step-up token before exporting", async () => {
    const cases = [
      { headers: {} },
      { headers: { "x-step-up-token": stepUpToken({}, "wrong-secret") } },
      { headers: { "x-step-up-token": stepUpToken({ step_up: false }) } },
      { headers: { "x-step-up-token": stepUpToken({ establishment_user_id: "someone-else" }) } },
      { headers: { "x-step-up-token": stepUpToken({ id: "other-establishment" }) } },
    ];
    for (const { headers } of cases) {
      const res = mockRes();
      await runRoute(stack, req({ format: "xlsx" }, headers), res);
      expect(res.statusCode).toBe(401);
    }
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("refuses regular users even with a valid step-up token", async () => {
    const res = mockRes();
    const regularReq = req({ format: "xlsx" });
    regularReq.establishment.role = "establishment_regular_user";
    await runRoute(stack, regularReq, res);
    expect(res.statusCode).toBe(403);
    expect(res.body.message).toMatch(/Super User/);
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("rejects an unknown format without querying", async () => {
    const res = mockRes();
    await runRoute(stack, req({ format: "csv" }), res);
    expect(res.statusCode).toBe(400);
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("rejects a malformed date without querying", async () => {
    const res = mockRes();
    await runRoute(stack, req({ format: "xlsx", start_date: "05/01/2026" }), res);
    expect(res.statusCode).toBe(400);
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("builds an Excel file with masked IDs and logs the export", async () => {
    const res = mockRes();
    await runRoute(
      stack,
      req({ format: "xlsx", start_date: "2026-05-01", end_date: "2026-05-31", result: "valid" }),
      res,
    );

    expect(res.statusCode).toBe(200);
    expect(res.headers["content-type"]).toBe(
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    );
    expect(res.headers["content-disposition"]).toMatch(/^attachment; filename="scan-history-\d{4}-\d{2}-\d{2}\.xlsx"$/);

    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(res.body);
    const sheet = workbook.getWorksheet("Scan History");
    expect(sheet.getRow(1).getCell(1).value).toBe("Reference No");
    const dataRow = sheet.getRow(2);
    expect(dataRow.getCell(1).value).toBe("REF-0001");
    expect(dataRow.getCell(3).value).not.toContain("ABC123456");
    expect(dataRow.getCell(6).value).toBe("MANUAL REVIEW");

    const historyCall = historyQueryCalls()[0];
    expect(historyCall[1]).toEqual(
      expect.arrayContaining([ESTABLISHMENT_ID, "2026-05-01", "2026-05-31", "valid"]),
    );

    const audit = auditInsertCalls();
    expect(audit).toHaveLength(1);
    expect(audit[0][1][0]).toBe(ESTABLISHMENT_ID);
    const metadata = JSON.parse(audit[0][1][1]);
    expect(metadata).toMatchObject({
      format: "xlsx",
      result_filter: "valid",
      start_date: "2026-05-01",
      end_date: "2026-05-31",
      row_count: 1,
      establishment_user_id: ESTABLISHMENT_USER_ID,
    });
  });

  test("builds a PDF export", async () => {
    const res = mockRes();
    await runRoute(stack, req({ format: "pdf" }), res);

    expect(res.statusCode).toBe(200);
    expect(res.headers["content-type"]).toBe("application/pdf");
    expect(Buffer.isBuffer(res.body)).toBe(true);
    expect(res.body.subarray(0, 5).toString()).toBe("%PDF-");
    expect(auditInsertCalls()[0][1][1]).toContain('"format":"pdf"');
  });

  test("refuses ranges above the row cap", async () => {
    pool.query.mockImplementation(async (sql) => {
      if (/FROM verification_logs/.test(sql)) {
        return { rows: Array.from({ length: 5001 }, () => scanRow()) };
      }
      return { rows: [] };
    });
    const res = mockRes();
    await runRoute(stack, req({ format: "xlsx" }), res);

    expect(res.statusCode).toBe(400);
    expect(res.body.message).toMatch(/more than 5000 scans/);
    expect(auditInsertCalls()).toHaveLength(0);
  });
});

describe("GET /verification/history filters", () => {
  const stack = routeStack("get", "/history");

  beforeEach(() => {
    pool.query.mockReset();
  });

  test("still rejects an unknown result filter", async () => {
    const res = mockRes();
    await runRoute(stack, req({ result: "bogus" }), res);
    expect(res.statusCode).toBe(400);
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("passes the date and result filters to the query", async () => {
    pool.query.mockImplementation(async (sql) => {
      if (/COUNT/.test(sql)) return { rows: [{ count: "0" }] };
      return { rows: [] };
    });
    const res = mockRes();
    await runRoute(
      stack,
      req({ start_date: "2026-05-01", end_date: "2026-05-31", result: "invalid" }),
      res,
    );

    expect(res.statusCode).toBe(200);
    const [, params] = historyQueryCalls()[0];
    expect(params).toEqual(
      expect.arrayContaining([ESTABLISHMENT_ID, "2026-05-01", "2026-05-31", "invalid", 20, 0]),
    );
  });
});
