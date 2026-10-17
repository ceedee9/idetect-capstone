jest.mock("../src/config/database", () => ({
  query: jest.fn(),
  connect: jest.fn(),
}));
jest.mock("../src/middleware/auth", () => ({
  authenticate: (req, res, next) => next(),
  requireRole: () => (req, res, next) => next(),
}));
jest.mock("../src/middleware/stepUp", () => ({
  requireStepUp: (req, res, next) => next(),
  requireStepUpForDownload: (req, res, next) => next(),
}));

const pool = require("../src/config/database");
const router = require("../src/routes/auditLogs");

function routeStack(method, path) {
  return router.stack
    .find((layer) => layer.route?.path === path && layer.route.methods[method])
    .route.stack.map((layer) => layer.handle);
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

const bploSuperAdmin = { id: "sa-1", role: "bplo_super_admin" };
const pdaoSuperAdmin = { id: "sa-2", role: "pdao_super_admin" };

describe("audit-log retention archive", () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    pool.query.mockReset();
    client = {
      query: jest.fn().mockResolvedValue({ rows: [] }),
      release: jest.fn(),
    };
    pool.connect.mockResolvedValue(client);
  });

  test("only agency super admins pass the retention role gate", () => {
    const [gate] = routeStack("post", "/archive");

    const denied = makeRes();
    const deniedNext = jest.fn();
    gate({ user: { id: "a-1", role: "osca_admin" } }, denied, deniedNext);
    expect(denied.statusCode).toBe(403);
    expect(deniedNext).not.toHaveBeenCalled();

    const next = jest.fn();
    gate({ user: bploSuperAdmin }, makeRes(), next);
    expect(next).toHaveBeenCalled();
  });

  test("archive requires an explicit acknowledgement", async () => {
    const handler = routeStack("post", "/archive").at(-1);
    const res = makeRes();

    await handler({ user: bploSuperAdmin, body: {}, ip: "::1", get: () => null }, res, jest.fn());

    expect(res.statusCode).toBe(400);
    expect(pool.connect).not.toHaveBeenCalled();
  });

  test("archive is scoped to the agency and writes an audit entry", async () => {
    client.query.mockImplementation(async (sql) =>
      sql.includes("archived_count")
        ? { rows: [{ archived_count: 3 }] }
        : { rows: [] },
    );
    const handler = routeStack("post", "/archive").at(-1);
    const res = makeRes();
    const next = jest.fn();

    await handler(
      { user: pdaoSuperAdmin, body: { acknowledged: true }, ip: "::1", get: () => "jest" },
      res,
      next,
    );

    expect(next).not.toHaveBeenCalled();
    expect(res.body).toEqual({ archived_count: 3, retention_years: 5 });

    const statements = client.query.mock.calls.map((call) => call[0]);
    expect(statements[0]).toBe("BEGIN");
    expect(statements[1]).toContain("idetect.audit_archive");
    expect(statements.at(-1)).toBe("COMMIT");

    const archiveCall = client.query.mock.calls.find((call) =>
      call[0].includes("DELETE FROM audit_logs"),
    );
    expect(archiveCall[0]).toContain("INTERVAL '5 years'");
    expect(archiveCall[1]).toEqual(
      expect.arrayContaining(["pdao_admin", "pdao_super_admin", "pwd"]),
    );
    expect(archiveCall[1].at(-1)).toBe("sa-2");

    expect(statements.some((sql) => sql.includes("'audit_logs_archived'"))).toBe(true);
    expect(client.release).toHaveBeenCalled();
  });

  test("a failed archive rolls back and writes no audit entry", async () => {
    client.query.mockImplementation(async (sql) => {
      if (sql.includes("archived_count")) throw new Error("boom");
      return { rows: [] };
    });
    const handler = routeStack("post", "/archive").at(-1);
    const next = jest.fn();

    await handler(
      { user: bploSuperAdmin, body: { acknowledged: true }, ip: "::1", get: () => null },
      makeRes(),
      next,
    );

    const statements = client.query.mock.calls.map((call) => call[0]);
    expect(statements).toContain("ROLLBACK");
    expect(statements).not.toContain("COMMIT");
    expect(statements.some((sql) => sql.includes("'audit_logs_archived'"))).toBe(false);
    expect(next).toHaveBeenCalledWith(expect.any(Error));
    expect(client.release).toHaveBeenCalled();
  });

  test("retention preview counts eligible and archived logs for the agency", async () => {
    pool.query
      .mockResolvedValueOnce({
        rows: [{ eligible_count: 7, oldest_created_at: "2019-01-01", cutoff: "2021-01-01" }],
      })
      .mockResolvedValueOnce({ rows: [{ archived_count: 2 }] });
    const handler = routeStack("get", "/retention").at(-1);
    const res = makeRes();

    await handler({ user: bploSuperAdmin }, res, jest.fn());

    expect(res.body).toMatchObject({
      retention_years: 5,
      eligible_count: 7,
      archived_count: 2,
    });
    const [sql, params] = pool.query.mock.calls[0];
    expect(sql).toContain("INTERVAL '5 years'");
    expect(params).toEqual(expect.arrayContaining(["bplo_admin", "bplo_super_admin"]));
  });
});
