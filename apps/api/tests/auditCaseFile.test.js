const mockQuery = jest.fn();
jest.mock("../src/config/database", () => ({ query: (...a) => mockQuery(...a) }));
jest.mock("../src/middleware/auth", () => ({
  authenticate: jest.fn(),
  requireRole: jest.fn(() => jest.fn()),
}));

const router = require("../src/routes/auditLogs");
const layer = router.stack.find((l) => l.route && l.route.path === "/case");
const handler = layer.route.stack[layer.route.stack.length - 1].handle;

function run(ref) {
  const res = {
    statusCode: 200,
    headers: {},
    setHeader(k, v) { this.headers[k] = v; },
    status(c) { this.statusCode = c; return this; },
    json(b) { this.body = b; return this; },
    send(t) { this.text = t; return this; },
  };
  const req = { query: { ref }, user: { id: "u1", role: "bplo_admin", full_name: "Admin" } };
  return handler(req, res, (e) => { throw e; }).then(() => res);
}

beforeEach(() => mockQuery.mockReset());

test("rejects a malformed reference number", async () => {
  const res = await run("hello");
  expect(res.statusCode).toBe(400);
  expect(mockQuery).not.toHaveBeenCalled();
});

test("returns 404 when the reference does not exist", async () => {
  mockQuery.mockResolvedValueOnce({ rows: [] });
  const res = await run("DSP-2026-000999");
  expect(res.statusCode).toBe(404);
});

test("builds a masked case file and audits the download", async () => {
  mockQuery
    .mockResolvedValueOnce({ rows: [{ id: "f1", reference_no: "FLG-2026-000001", flag_status: "pending", beneficiary_type: "pwd", id_number_flagged: "12345678", verification_log_id: null, establishment_id: "e1" }] })
    .mockResolvedValueOnce({ rows: [{ created_at: "2026-01-01T00:00:00Z", action: "flag_created", metadata: {} }] })
    .mockResolvedValueOnce({ rows: [] });
  const res = await run("flg-2026-000001");
  expect(res.statusCode).toBe(200);
  expect(res.text).toContain("FLG-2026-000001");
  expect(res.text).toContain("******78");
  expect(res.text).not.toContain("12345678");
  expect(mockQuery.mock.calls[2][1][1]).toContain("case_file");
});
