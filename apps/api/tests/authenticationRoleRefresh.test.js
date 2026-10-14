const mockQuery = jest.fn();

jest.mock("../src/config/database", () => ({
  query: (...args) => mockQuery(...args),
}));
jest.mock("jsonwebtoken", () => ({
  verify: jest.fn(() => ({
    id: "user-1",
    role: "bplo_admin",
    full_name: "Old Name",
  })),
}));

const { authenticate } = require("../src/middleware/auth");

test("uses the current database role instead of a stale JWT role", async () => {
  mockQuery.mockResolvedValueOnce({
    rows: [{
      id: "user-1",
      is_active: true,
      role: "bplo_super_admin",
      full_name: "Current Name",
    }],
  });
  const req = { headers: { authorization: "Bearer token" } };
  const res = {
    statusCode: 200,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json() {
      return this;
    },
  };
  const next = jest.fn();

  await authenticate(req, res, next);

  expect(next).toHaveBeenCalledWith();
  expect(req.user.role).toBe("bplo_super_admin");
  expect(req.user.portalRole).toBe("bplo_admin");
  expect(req.user.full_name).toBe("Current Name");
});

test("deactivated accounts are rejected even with a valid token", async () => {
  mockQuery.mockResolvedValueOnce({
    rows: [{ id: "user-1", is_active: false, role: "bplo_admin" }],
  });
  const req = { headers: { authorization: "Bearer token" } };
  const res = {
    statusCode: 200,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json() {
      return this;
    },
  };

  await authenticate(req, res, jest.fn());

  expect(res.statusCode).toBe(401);
});
