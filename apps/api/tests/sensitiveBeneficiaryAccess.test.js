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

describe("sensitive beneficiary access", () => {
  beforeEach(() => jest.clearAllMocks());

  test("returns the full ID only through the protected reveal endpoint and audits it", async () => {
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
      .mockResolvedValueOnce({ rows: [] });

    const routeLayer = beneficiariesRouter.stack.find(
      (layer) => layer.route?.path?.endsWith("/sensitive"),
    );
    const handler = routeLayer.route.stack[0].handle;
    const response = { json: jest.fn() };
    await handler(
      {
        params: { id: "00000000-0000-0000-0000-000000000001" },
        user: { id: "staff-id", role: "osca_admin" },
      },
      response,
      jest.fn(),
    );

    expect(response.json).toHaveBeenCalledWith({ id_number: "123456789" });
    expect(pool.query).toHaveBeenLastCalledWith(
      expect.stringContaining("sensitive_data_revealed"),
      expect.arrayContaining(["staff-id"]),
    );
  });
});
