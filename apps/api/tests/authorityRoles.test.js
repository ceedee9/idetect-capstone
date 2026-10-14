jest.mock("../src/config/database", () => ({ query: jest.fn() }));

const {
  normalizeStaffRole,
  requireRole,
} = require("../src/middleware/auth");

function runRoleCheck(allowed, role) {
  const req = { user: { role } };
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
  let nextCalled = false;
  requireRole(allowed)(req, res, () => {
    nextCalled = true;
  });
  return { res, nextCalled };
}

describe("agency-scoped staff roles", () => {
  test.each([
    ["bplo_super_admin", "bplo_admin"],
    ["osca_super_admin", "osca_admin"],
    ["pdao_super_admin", "pdao_admin"],
  ])("normalizes %s to %s portal behavior", (role, portalRole) => {
    expect(normalizeStaffRole(role)).toBe(portalRole);
  });

  test("regular admins are accepted only for their own role", () => {
    expect(runRoleCheck("bplo_admin", "bplo_admin").nextCalled).toBe(true);
    expect(runRoleCheck("bplo_admin", "osca_admin").res.statusCode).toBe(403);
    expect(runRoleCheck("bplo_admin", "pdao_admin").res.statusCode).toBe(403);
  });

  test("matching agency Super Admin is accepted for an office route", () => {
    expect(runRoleCheck("bplo_admin", "bplo_super_admin").nextCalled).toBe(
      true,
    );
    expect(runRoleCheck("osca_admin", "bplo_super_admin").res.statusCode).toBe(
      403,
    );
    expect(runRoleCheck("pdao_admin", "bplo_super_admin").res.statusCode).toBe(
      403,
    );
  });

  test("legacy global Super Admin is never accepted", () => {
    const result = runRoleCheck(
      ["bplo_admin", "osca_admin", "pdao_admin"],
      "super_admin",
    );
    expect(result.nextCalled).toBe(false);
    expect(result.res.statusCode).toBe(403);
  });
});
