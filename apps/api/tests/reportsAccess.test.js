const express = require("express");

const mockState = { role: "bplo_admin" };

jest.mock("../src/config/database", () => ({
  query: jest.fn(async () => ({ rows: [] })),
}));
jest.mock("../src/middleware/auth", () => {
  const actual = jest.requireActual("../src/middleware/auth");
  return {
    ...actual,
    authenticate: (req, res, next) => {
      req.user = { id: "staff-1", role: mockState.role };
      next();
    },
  };
});
jest.mock("../src/middleware/stepUp", () => ({
  requireStepUp: (req, res, next) => next(),
}));

const pool = require("../src/config/database");
const reportsRouter = require("../src/routes/reports");

const ENDPOINTS = [
  "/api/reports/verifications/export",
  "/api/reports/fraud-flags/export",
  "/api/reports/disputes/export",
];

let server;
let baseUrl;

beforeAll(async () => {
  const app = express();
  app.use("/api/reports", reportsRouter);
  app.use((err, req, res, next) => {
    res.status(500).json({ error: err.message });
  });
  await new Promise((resolve) => {
    server = app.listen(0, resolve);
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

afterAll(async () => {
  await new Promise((resolve) => server.close(resolve));
});

beforeEach(() => {
  pool.query.mockClear();
});

describe.each(["bplo_admin", "bplo_super_admin"])(
  "BPLO role %s",
  (role) => {
    test.each(ENDPOINTS)("is refused access to %s", async (path) => {
      mockState.role = role;
      const res = await fetch(`${baseUrl}${path}`);
      expect(res.status).toBe(403);
      expect(pool.query).not.toHaveBeenCalled();
    });
  },
);

describe.each(["osca_admin", "pdao_admin"])("office role %s", (role) => {
  test.each(ENDPOINTS)("can download %s", async (path) => {
    mockState.role = role;
    const res = await fetch(`${baseUrl}${path}`);
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toContain("text/csv");
  });
});

test("OSCA fraud-flag export is limited to senior citizens", async () => {
  mockState.role = "osca_admin";
  await fetch(`${baseUrl}/api/reports/fraud-flags/export`);
  const [sql] = pool.query.mock.calls[0];
  expect(sql).toContain("ff.beneficiary_type = 'senior_citizen'");
});

test("PDAO verification export is limited to PWD", async () => {
  mockState.role = "pdao_admin";
  await fetch(`${baseUrl}/api/reports/verifications/export`);
  const [sql] = pool.query.mock.calls[0];
  expect(sql).toContain("vl.beneficiary_type_detected = 'pwd'");
});
