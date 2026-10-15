const mockQuery = jest.fn();

jest.mock("../src/config/database", () => ({
  query: (...args) => mockQuery(...args),
}));
jest.mock("../src/middleware/auth", () => ({
  authenticate: jest.fn((req, res, next) => next()),
  requireRole: jest.fn(() => (req, res, next) => next()),
}));

const router = require("../src/routes/staff");

function route(path, method) {
  const layer = router.stack.find(
    (entry) => entry.route?.path === path && entry.route.methods[method],
  );
  if (!layer) throw new Error(`Route not found: ${method.toUpperCase()} ${path}`);
  return layer.route.stack;
}

function response() {
  return {
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
}

test.each(["bplo_admin", "osca_admin", "pdao_admin"])(
  "regular %s cannot create staff",
  async (role) => {
    const res = response();
    let nextCalled = false;
    await route("/", "post")[0].handle(
      { user: { role } },
      res,
      () => {
        nextCalled = true;
      },
    );

    expect(res.statusCode).toBe(403);
    expect(nextCalled).toBe(false);
  },
);

test.each([
  ["bplo_super_admin", "bplo_admin"],
  ["osca_super_admin", "osca_admin"],
  ["pdao_super_admin", "pdao_admin"],
])(
  "%s is allowed through the create-staff authorization guard",
  async (role) => {
    const res = response();
    let nextCalled = false;
    await route("/", "post")[0].handle(
      { user: { role } },
      res,
      () => {
        nextCalled = true;
      },
    );

    expect(res.statusCode).toBe(200);
    expect(nextCalled).toBe(true);
  },
);

test.each([
  ["bplo_admin", "bplo_admin"],
  ["osca_super_admin", "osca_admin"],
  ["pdao_super_admin", "pdao_admin"],
])(
  "%s can read alerts for %s",
  async (role, expectedTargetRole) => {
    const alertRouteIndex = router.stack.findIndex(
      (entry) => entry.route?.path === "/alerts" && entry.route.methods.get,
    );
    const staffIdRouteIndex = router.stack.findIndex(
      (entry) => entry.route?.path === "/:id" && entry.route.methods.get,
    );

    expect(alertRouteIndex).toBeGreaterThanOrEqual(0);
    expect(alertRouteIndex).toBeLessThan(staffIdRouteIndex);

    mockQuery.mockResolvedValueOnce({
      rows: [{ id: "alert-1", is_read: false }],
    });
    const res = response();
    const handlers = route("/alerts", "get");
    await handlers[handlers.length - 1].handle(
      { user: { role } },
      res,
      () => {},
    );

    expect(mockQuery).toHaveBeenCalledWith(
      expect.stringContaining("WHERE target_role = $1"),
      [expectedTargetRole],
    );
    expect(res.body).toEqual({
      alerts: [{ id: "alert-1", is_read: false }],
      unread_count: 1,
    });
    mockQuery.mockReset();
  },
);

test.each([
  ["bplo_super_admin", "bplo_admin"],
  ["osca_super_admin", "osca_admin"],
  ["pdao_super_admin", "pdao_admin"],
])(
  "%s scopes a staff UUID lookup to %s",
  async (role, expectedRole) => {
    mockQuery.mockResolvedValueOnce({ rows: [] });
    const res = response();
    const handlers = route("/:id", "get");
    const handler = handlers[handlers.length - 1].handle;

    await handler(
      {
        params: { id: "11111111-1111-1111-1111-111111111111" },
        user: { id: "admin-id", role },
      },
      res,
      () => {},
    );

    expect(mockQuery).toHaveBeenCalledWith(
      expect.stringContaining("AND role = $2"),
      ["11111111-1111-1111-1111-111111111111", expectedRole],
    );
    expect(res.statusCode).toBe(404);
    mockQuery.mockReset();
  },
);
