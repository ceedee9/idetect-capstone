jest.mock("../src/config/database", () => ({
  query: jest.fn(),
}));

jest.mock("../src/middleware/auth", () => ({
  authenticate: (req, res, next) => {
    req.user = { id: "staff-id", role: "osca_admin" };
    next();
  },
  requireRole: () => (req, res, next) => next(),
}));

const pool = require("../src/config/database");
const beneficiariesRouter = require("../src/routes/beneficiaries");
const jwt = require("jsonwebtoken");

describe("sensitive beneficiary access", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    process.env.JWT_SECRET_STAFF = "test-secret";
  });

  const stepUpToken = () =>
    jwt.sign({ id: "staff-id", step_up: true }, "test-secret", {
      expiresIn: "5m",
    });

  test("returns the full ID only through the protected reveal endpoint", async () => {
    pool.query
      .mockResolvedValueOnce({
        rows: [
          {
            id: "00000000-0000-0000-0000-000000000001",
            id_number: "123456789",
            beneficiary_type: "senior_citizen",
          },
        ],
      })

    const routeLayer = beneficiariesRouter.stack.find(
      (layer) => layer.route?.path?.endsWith("/sensitive"),
    );
    const handler = routeLayer.route.stack.at(-1).handle;
    const response = { json: jest.fn() };
    await handler(
      {
        params: { id: "00000000-0000-0000-0000-000000000001" },
        user: { id: "staff-id", role: "osca_admin" },
        headers: { "x-step-up-token": stepUpToken() },
      },
      response,
      jest.fn(),
    );

    expect(response.json).toHaveBeenCalledWith({ id_number: "123456789" });
    expect(pool.query).toHaveBeenCalledTimes(1);
  });

  test("returns plain DOB with a masked ID and audits the acknowledged detail view", async () => {
    pool.query
      .mockResolvedValueOnce({
        rows: [
          {
            id: "00000000-0000-0000-0000-000000000001",
            id_number: "123456789",
            birthdate: "1940-01-02",
            beneficiary_type: "senior_citizen",
            full_name: "Test Person",
          },
        ],
      })
      .mockResolvedValueOnce({ rows: [] });

    const routeLayer = beneficiariesRouter.stack.find(
      (layer) => layer.route?.path?.endsWith("/sensitive-detail"),
    );
    const handler = routeLayer.route.stack.at(-1).handle;
    const response = { json: jest.fn() };
    await handler(
      {
        params: { id: "00000000-0000-0000-0000-000000000001" },
        user: { id: "staff-id", role: "osca_admin" },
        headers: { "x-step-up-token": stepUpToken() },
      },
      response,
      jest.fn(),
    );

    expect(response.json).toHaveBeenCalledWith(
      expect.objectContaining({
        id_number: "*******89",
        birthdate: "1940-01-02",
      }),
    );
    expect(pool.query).toHaveBeenLastCalledWith(
      expect.stringContaining("sensitive_data_revealed"),
      expect.arrayContaining(["staff-id"]),
    );
  });
});
