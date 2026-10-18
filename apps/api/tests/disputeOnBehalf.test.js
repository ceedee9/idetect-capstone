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
jest.mock("../src/services/fcmService", () => ({ sendPushNotification: jest.fn() }));
jest.mock("../src/services/smsService", () => ({ sendSms: jest.fn() }));
jest.mock("../src/services/storageService", () => ({
  uploadDisputeDocument: jest.fn(),
  buildAbsoluteApiUploadUrl: jest.fn(),
}));

const pool = require("../src/config/database");
const router = require("../src/routes/disputes");

function routeStack(method, path) {
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

const validBody = {
  id_number: "ID-123",
  birthdate: "1960-05-04",
  dispute_type: "wrong_denial",
  explanation: "I was denied even though my card is valid.",
  request_channel: "in_person",
};

function makeReq(body = validBody) {
  return {
    body,
    establishment: { id: "est-1", establishment_user_id: "user-1" },
  };
}

describe("establishment-filed disputes on behalf of a beneficiary", () => {
  const stack = routeStack("post", "/on-behalf");

  beforeEach(() => {
    jest.clearAllMocks();
    pool.query.mockReset();
  });

  test("rejects business_refusal, which an establishment cannot file", async () => {
    const res = makeRes();
    await runRoute(stack, makeReq({ ...validBody, dispute_type: "business_refusal" }), res);

    expect(res.statusCode).toBe(400);
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("requires a request channel", async () => {
    const res = makeRes();
    const { request_channel, ...withoutChannel } = validBody;
    await runRoute(stack, makeReq(withoutChannel), res);

    expect(res.statusCode).toBe(400);
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("fails when the ID number and birthdate do not match", async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const res = makeRes();
    const outcome = await runRoute(stack, makeReq(), res);

    expect(outcome.error.statusCode).toBe(404);
    expect(pool.query).toHaveBeenCalledTimes(1);
  });

  test("creates an inactive placeholder account for a beneficiary without the app", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ id: "b-1", account_id: null }] })
      .mockResolvedValueOnce({ rows: [{ id: "acc-new" }] })
      .mockResolvedValueOnce({
        rows: [{ id: "d-1", reference_no: "DSP-2026-000001", dispute_type: "wrong_denial", status: "submitted" }],
      })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{ device_token: null, registered_mobile: null }] })
      .mockResolvedValueOnce({ rows: [] });

    const res = makeRes();
    await runRoute(stack, makeReq(), res);

    expect(res.statusCode).toBe(201);
    expect(pool.query.mock.calls[1][0]).toMatch(/INSERT INTO beneficiary_accounts/);
    expect(pool.query.mock.calls[1][0]).toMatch(/is_active[\s\S]*FALSE/);

    const [disputeSql, disputeParams] = pool.query.mock.calls[2];
    expect(disputeSql).toMatch(/filed_on_behalf/);
    expect(disputeSql).toMatch(/TRUE/);
    expect(disputeParams).toEqual([
      "acc-new",
      "wrong_denial",
      "I was denied even though my card is valid.",
      "est-1",
      "user-1",
      "in_person",
    ]);
  });

  test("reuses an existing beneficiary account instead of creating one", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ id: "b-1", account_id: "acc-existing" }] })
      .mockResolvedValueOnce({
        rows: [{ id: "d-2", reference_no: "DSP-2026-000002", dispute_type: "wrong_denial", status: "submitted" }],
      })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{ device_token: null, registered_mobile: null }] })
      .mockResolvedValueOnce({ rows: [] });

    const res = makeRes();
    await runRoute(stack, makeReq(), res);

    expect(res.statusCode).toBe(201);
    expect(pool.query).toHaveBeenCalledTimes(5);
    expect(pool.query.mock.calls[1][1][0]).toBe("acc-existing");
  });

  test("writes a general beneficiary notice tied to the dispute", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ id: "b-1", account_id: "acc-existing" }] })
      .mockResolvedValueOnce({
        rows: [{ id: "d-4", reference_no: "DSP-2026-000004", dispute_type: "wrong_denial", status: "submitted" }],
      })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{ device_token: null, registered_mobile: null }] })
      .mockResolvedValueOnce({ rows: [] });

    const res = makeRes();
    await runRoute(stack, makeReq(), res);

    const [notifSql, notifParams] = pool.query.mock.calls[2];
    expect(notifSql).toMatch(/INSERT INTO notifications/);
    expect(notifSql).toMatch(/'general'/);
    expect(notifParams[0]).toBe("acc-existing");
    expect(notifParams[1]).toMatch(/^Dispute Filed For You/);
    expect(notifParams[1]).toMatch(/Reklamo/);
    expect(notifParams[2]).toMatch(/DSP-2026-000004/);
    expect(notifParams[3]).toBe("d-4");
  });

  test("writes an audit row that records the request channel", async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ id: "b-1", account_id: "acc-existing" }] })
      .mockResolvedValueOnce({ rows: [{ id: "d-3", reference_no: "DSP-2026-000003", dispute_type: "other", status: "submitted" }] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{ device_token: null, registered_mobile: null }] })
      .mockResolvedValueOnce({ rows: [] });

    const res = makeRes();
    await runRoute(stack, makeReq({ ...validBody, dispute_type: "other", request_channel: "phone" }), res);

    const [auditSql, auditParams] = pool.query.mock.calls[4];
    expect(auditSql).toMatch(/INSERT INTO audit_logs/);
    expect(auditSql).toMatch(/'dispute_submitted'/);
    expect(auditParams[0]).toBe("est-1");
    expect(JSON.parse(auditParams[2])).toMatchObject({
      filed_on_behalf: true,
      request_channel: "phone",
      dispute_type: "other",
    });
  });
});
