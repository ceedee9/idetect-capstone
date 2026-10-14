jest.mock("../src/config/database", () => ({ query: jest.fn() }));
jest.mock("../src/middleware/auth", () => ({
  authenticate: (req, res, next) => next(),
  requireRole: () => (req, res, next) => next(),
}));

const pool = require("../src/config/database");
const router = require("../src/routes/auditLogs");

const listHandler = router.stack.find(
  (layer) => layer.route?.path === "/" && layer.route.methods.get,
).route.stack.at(-1).handle;

function run(role) {
  const res = {
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

  return listHandler(
    {
      user: { id: "staff-1", role },
      query: { page: "1", limit: "30" },
    },
    res,
    (error) => {
      throw error;
    },
  ).then(() => res);
}

describe("audit log establishment scope", () => {
  beforeEach(() => {
    pool.query
      .mockReset()
      .mockResolvedValueOnce({ rows: [{ count: "1" }] })
      .mockResolvedValueOnce({ rows: [] });
  });

  test("includes establishment-originated PWD audit events for PDAO", async () => {
    await run("pdao_admin");

    const [query, params] = pool.query.mock.calls[0];
    expect(query).toContain("al.metadata->>'beneficiary_type'");
    expect(query).toContain("u.id IS NULL");
    expect(params).toEqual([
      "pdao_admin",
      "pwd",
      ["verification_performed", "verification_action_taken", "flag_created"],
      30,
      0,
    ]);
  });

  test("uses senior-citizen scope for OSCA", async () => {
    await run("osca_admin");

    expect(pool.query.mock.calls[0][1]).toEqual([
      "osca_admin",
      "senior_citizen",
      ["verification_performed", "verification_action_taken", "flag_created"],
      30,
      0,
    ]);
  });
});
