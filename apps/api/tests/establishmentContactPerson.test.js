process.env.JWT_SECRET_STAFF = "test-secret";

jest.mock("../src/config/database", () => ({
  query: jest.fn(),
  connect: jest.fn(),
}));
jest.mock("../src/middleware/auth", () => ({
  authenticate: (req, res, next) => {
    req.user = { id: "bplo-1", role: "bplo_admin" };
    next();
  },
  authenticateBeneficiary: (req, res, next) => next(),
  authenticateEstablishment: (req, res, next) => next(),
  requireRole: () => (req, res, next) => next(),
}));
jest.mock("../src/services/smsService", () => ({
  sendSms: jest.fn(() => Promise.resolve()),
}));
jest.mock("../src/services/emailService", () => ({
  sendEstablishmentSetupLink: jest.fn(() =>
    Promise.resolve({ success: true }),
  ),
}));

const pool = require("../src/config/database");
const router = require("../src/routes/establishments");

function findHandlers(path, method) {
  const layer = router.stack.find(
    (l) => l.route?.path === path && l.route.methods[method],
  );
  return layer.route.stack.map((l) => l.handle);
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
    if (outcome.error || outcome.finished) return outcome;
  }
  return { finished: true };
}

function makeRes() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
}

const CREATE_BODY = {
  email: "franchise@example.com",
  business_name: "Franchise Store",
  business_permit_no: "BP-900",
  owner_name: "Franchise Holdings Inc.",
  address: "Valenzuela City",
  contact_number: "09171234567",
};

describe("establishment contact person", () => {
  let clientQuery;

  beforeEach(() => {
    jest.clearAllMocks();
    clientQuery = jest.fn(async (sql) => {
      if (sql.includes("INSERT INTO establishments")) {
        return {
          rows: [
            {
              id: "est-1",
              email: "franchise@example.com",
              business_name: "Franchise Store",
              business_permit_no: "BP-900",
              status: "approved",
              created_at: new Date(),
            },
          ],
        };
      }
      return { rows: [] };
    });
    pool.connect.mockResolvedValue({
      query: clientQuery,
      release: jest.fn(),
    });
    pool.query.mockImplementation(async (sql) => {
      if (sql.includes("UPDATE establishments")) {
        return { rows: [{ id: "est-1", owner_name: "Franchise Holdings Inc." }] };
      }
      return { rows: [] };
    });
  });

  it("stores the contact person when creating an establishment", async () => {
    const res = makeRes();
    const req = {
      body: { ...CREATE_BODY, contact_person: "Maria Santos" },
      params: {},
      query: {},
      user: { id: "bplo-1", role: "bplo_admin" },
    };

    const outcome = await runRoute(findHandlers("/", "post"), req, res);
    expect(outcome.error).toBeUndefined();

    expect(res.statusCode).toBe(201);
    const insert = clientQuery.mock.calls.find(([sql]) =>
      sql.includes("INSERT INTO establishments"),
    );
    expect(insert[0]).toContain("contact_person");
    expect(insert[1][11]).toBe("Maria Santos");
    expect(insert[1][4]).toBe("Franchise Holdings Inc.");
  });

  it("stores null when no contact person is given", async () => {
    const res = makeRes();
    const req = {
      body: { ...CREATE_BODY },
      params: {},
      query: {},
      user: { id: "bplo-1", role: "bplo_admin" },
    };

    const outcome = await runRoute(findHandlers("/", "post"), req, res);
    expect(outcome.error).toBeUndefined();

    expect(res.statusCode).toBe(201);
    const insert = clientQuery.mock.calls.find(([sql]) =>
      sql.includes("INSERT INTO establishments"),
    );
    expect(insert[1][11]).toBeNull();
  });

  it("updates the contact person through the contact endpoint", async () => {
    const res = makeRes();
    const req = {
      body: { contact_person: "Juan Dela Cruz" },
      params: { id: "7b1d4f2e-0c3a-4e5b-9f6a-123456789abc" },
      query: {},
    };

    await runRoute(findHandlers("/:id/contact", "patch"), req, res);

    expect(res.statusCode).toBe(200);
    const update = pool.query.mock.calls.find(([sql]) =>
      sql.includes("UPDATE establishments"),
    );
    expect(update[0]).toContain("contact_person = $1");
    expect(update[1][0]).toBe("Juan Dela Cruz");
  });

  it("clears the contact person when an empty value is sent", async () => {
    const res = makeRes();
    const req = {
      body: { contact_person: "" },
      params: { id: "7b1d4f2e-0c3a-4e5b-9f6a-123456789abc" },
      query: {},
    };

    await runRoute(findHandlers("/:id/contact", "patch"), req, res);

    expect(res.statusCode).toBe(200);
    const update = pool.query.mock.calls.find(([sql]) =>
      sql.includes("UPDATE establishments"),
    );
    expect(update[1][0]).toBeNull();
  });
});
