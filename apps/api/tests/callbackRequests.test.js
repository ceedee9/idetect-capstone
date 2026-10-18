jest.mock("../src/config/database", () => ({
  query: jest.fn(),
  connect: jest.fn(),
}));
jest.mock("../src/middleware/auth", () => ({
  authenticate: (req, res, next) => next(),
  authenticateBeneficiary: (req, res, next) => next(),
  authenticateEstablishment: (req, res, next) => next(),
  requireRole: () => (req, res, next) => next(),
}));
jest.mock("../src/services/fcmService", () => ({
  sendPushNotification: jest.fn().mockResolvedValue({ invalidToken: false }),
}));

const pool = require("../src/config/database");
const { sendPushNotification } = require("../src/services/fcmService");
const beneficiaryRouter = require("../src/routes/beneficiaryPortal");
const staffRouter = require("../src/routes/callbackRequests");

const ESTABLISHMENT_ID = "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d";
const REQUEST_ID = "f0e1d2c3-b4a5-4968-8776-655443322110";

function routeStack(router, method, path) {
  return router.stack
    .find((layer) => layer.route?.path === path && layer.route.methods[method])
    .route.stack.map((layer) => layer.handle);
}

// Runs validators and handler in order. Resolves with { error } when a
// handler calls next(err); otherwise resolves once the handler finishes.
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
    if (outcome.error) return outcome;
    if (outcome.finished) return outcome;
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
    json(value) {
      this.body = value;
      return this;
    },
  };
}

function beneficiaryReq(body) {
  return {
    body,
    query: {},
    beneficiary: { id: "acc-1", accountId: "acc-1", beneficiary_id: "ben-1" },
  };
}

const validRequest = {
  establishment_id: ESTABLISHMENT_ID,
  reason: "transaction_question",
  note: "Can you check the date of my last visit?",
};

describe("beneficiary callback requests", () => {
  const stack = routeStack(beneficiaryRouter, "post", "/callback-requests");

  beforeEach(() => {
    jest.clearAllMocks();
    pool.query.mockReset();
  });

  test("returns 404 for an establishment that is not approved or missing", async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const res = makeRes();
    await runRoute(stack, beneficiaryReq(validRequest), res);

    expect(res.statusCode).toBe(404);
    expect(pool.query).toHaveBeenCalledTimes(1);
  });

  test("refuses an establishment the beneficiary has never transacted with", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ id: ESTABLISHMENT_ID }] })
      .mockResolvedValueOnce({ rows: [] });

    const res = makeRes();
    await runRoute(stack, beneficiaryReq(validRequest), res);

    expect(res.statusCode).toBe(403);
    expect(pool.query).toHaveBeenCalledTimes(2);
  });

  test("creates the request, audits it without the note, and never returns a phone number", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ id: ESTABLISHMENT_ID }] })
      .mockResolvedValueOnce({ rows: [{ id: "vl-1" }] })
      .mockResolvedValueOnce({
        rows: [{ id: REQUEST_ID, created_at: new Date() }],
      })
      .mockResolvedValueOnce({ rows: [] });

    const res = makeRes();
    await runRoute(stack, beneficiaryReq(validRequest), res);

    expect(res.statusCode).toBe(201);
    expect(res.body.request_id).toBe(REQUEST_ID);
    expect(res.body.reference).toBe("F0E1D2C3");
    expect(JSON.stringify(res.body)).not.toMatch(/contact_number|phone/i);

    const auditCall = pool.query.mock.calls[3];
    expect(auditCall[0]).toMatch(/callback_requested/);
    expect(auditCall[1][2]).not.toContain("Can you check");
  });

  test("returns 409 when the beneficiary already has an open request for that establishment", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ id: ESTABLISHMENT_ID }] })
      .mockResolvedValueOnce({ rows: [{ id: "vl-1" }] })
      .mockRejectedValueOnce(Object.assign(new Error("duplicate"), { code: "23505" }));

    const res = makeRes();
    await runRoute(stack, beneficiaryReq(validRequest), res);

    expect(res.statusCode).toBe(409);
  });

  test("rejects a reason outside the short list", async () => {
    const res = makeRes();
    await runRoute(stack, beneficiaryReq({ ...validRequest, reason: "free_text" }), res);

    expect(res.statusCode).toBe(400);
    expect(pool.query).not.toHaveBeenCalled();
  });
});

describe("staff callback request queue", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    pool.query.mockReset();
  });

  test("PDAO sees only PWD requests", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ count: "0" }] })
      .mockResolvedValueOnce({ rows: [] });

    const req = {
      query: {},
      user: { id: "u-1", role: "pdao_admin", portalRole: "pdao_admin" },
    };
    const res = makeRes();
    await runRoute(routeStack(staffRouter, "get", "/"), req, res);

    expect(res.statusCode).toBe(200);
    expect(pool.query.mock.calls[0][0]).toMatch(/beneficiary_type = \$1/);
    expect(pool.query.mock.calls[0][1][0]).toBe("pwd");
  });

  test("BPLO sees every request with no type filter", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ count: "0" }] })
      .mockResolvedValueOnce({ rows: [] });

    const req = {
      query: {},
      user: { id: "u-2", role: "bplo_admin", portalRole: "bplo_admin" },
    };
    await runRoute(routeStack(staffRouter, "get", "/"), req, makeRes());

    expect(pool.query.mock.calls[0][0]).not.toMatch(/beneficiary_type = \$/);
  });
});

describe("staff reply to a callback request", () => {
  const stack = routeStack(staffRouter, "patch", "/:id");
  const openRow = {
    id: REQUEST_ID,
    status: "open",
    establishment_id: ESTABLISHMENT_ID,
    beneficiary_account_id: "acc-1",
    handled_by: null,
    handled_at: null,
    staff_note: null,
  };

  function staffReq(body) {
    return {
      params: { id: REQUEST_ID },
      body,
      user: { id: "bplo-1", role: "bplo_admin", portalRole: "bplo_admin" },
    };
  }

  beforeEach(() => {
    jest.clearAllMocks();
    pool.query.mockReset();
  });

  test("marking a request handled records who handled it, notifies, and audits", async () => {
    const handledRow = { ...openRow, status: "handled", handled_by: "bplo-1", handled_at: new Date() };
    pool.query
      .mockResolvedValueOnce({ rows: [openRow] })
      .mockResolvedValueOnce({ rows: [handledRow] })
      .mockResolvedValueOnce({ rows: [{ business_name: "Sari Store", device_token: null }] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] });

    const res = makeRes();
    await runRoute(stack, staffReq({ status: "handled", staff_note: "Store confirmed the visit date." }), res);

    expect(res.statusCode).toBe(200);
    expect(res.body.data.status).toBe("handled");

    const updateCall = pool.query.mock.calls[1];
    expect(updateCall[1]).toEqual([REQUEST_ID, "handled", "Store confirmed the visit date.", "bplo-1", expect.any(Date)]);

    expect(pool.query.mock.calls[3][0]).toMatch(/callback_request_handled/);
    expect(pool.query.mock.calls[4][0]).toMatch(/audit_logs/);
    expect(pool.query.mock.calls[4][1][2]).toBe("callback_request_handled");
    expect(sendPushNotification).not.toHaveBeenCalled();
  });

  test("a note-only update audits as callback_request_updated and does not notify", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [openRow] })
      .mockResolvedValueOnce({ rows: [{ ...openRow, staff_note: "Called, no answer." }] })
      .mockResolvedValueOnce({ rows: [] });

    const res = makeRes();
    await runRoute(stack, staffReq({ staff_note: "Called, no answer." }), res);

    expect(res.statusCode).toBe(200);
    expect(pool.query).toHaveBeenCalledTimes(3);
    expect(pool.query.mock.calls[2][1][2]).toBe("callback_request_updated");
  });

  test("rejects a staff note over 300 characters", async () => {
    const res = makeRes();
    await runRoute(stack, staffReq({ staff_note: "x".repeat(301) }), res);

    expect(res.statusCode).toBe(400);
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("rejects an empty update", async () => {
    const outcome = await runRoute(stack, staffReq({}), makeRes());

    expect(outcome.error.statusCode).toBe(400);
    expect(pool.query).not.toHaveBeenCalled();
  });
});
