jest.mock("../src/config/database", () => ({ query: jest.fn() }));
jest.mock("../src/middleware/auth", () => ({
  authenticate: jest.fn(),
  requireRole: jest.fn(() => jest.fn()),
}));
jest.mock("../src/services/smsService", () => ({ sendSms: jest.fn() }));
jest.mock("../src/services/emailService", () => ({
  sendEstablishmentSetupLink: jest.fn(),
}));

jest.useFakeTimers();

const pool = require("../src/config/database");
const router = require("../src/routes/establishments");
const suspensionRoute = router.stack.find(
  (layer) => layer.route?.path === "/:id/suspend",
).route.stack;
const [validateReason, suspend] = suspensionRoute;

function response() {
  return {
    statusCode: null,
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

async function run(reason) {
  const req = {
    body: { reason },
    params: { id: "establishment-1" },
    user: { id: "staff-1" },
  };
  const res = response();
  await validateReason.handle(req, res, jest.fn());
  await suspend.handle(req, res, (error) => {
    throw error;
  });
  return res;
}

describe("PATCH /establishments/:id/suspend", () => {
  beforeEach(() => {
    pool.query.mockReset().mockResolvedValue({ rows: [] });
  });

  afterAll(() => {
    jest.clearAllTimers();
    jest.useRealTimers();
  });

  test("rejects a suspension reason longer than 2,500 characters", async () => {
    const res = await run("x".repeat(2501));

    expect(res.statusCode).toBe(400);
    expect(res.body.errors[0].path).toBe("reason");
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("accepts a suspension reason of exactly 2,500 characters", async () => {
    const res = await run("x".repeat(2500));

    expect(res.body.message).toBe("Establishment suspended.");
    expect(pool.query).toHaveBeenCalledTimes(2);
    expect(pool.query.mock.calls[0][1][0]).toHaveLength(2500);
  });
});
