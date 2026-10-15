const jwt = require("jsonwebtoken");
const {
  requireStepUp,
  requireStepUpForDownload,
} = require("../src/middleware/stepUp");

process.env.JWT_SECRET_STAFF = "test-secret";

function run(mw, req) {
  const res = {
    statusCode: 200,
    status(c) { this.statusCode = c; return this; },
    json(b) { this.body = b; return this; },
  };
  const next = jest.fn();
  mw({ query: {}, headers: {}, user: { id: "u1" }, ...req }, res, next);
  return { res, next };
}

const proof = (extra = {}) =>
  jwt.sign({ id: "u1", step_up: true, ...extra }, "test-secret", { expiresIn: "5m" });

test("rejects a missing step-up token", () => {
  const { res, next } = run(requireStepUp, {});
  expect(res.statusCode).toBe(401);
  expect(next).not.toHaveBeenCalled();
});

test("rejects a token issued to another user", () => {
  const { res } = run(requireStepUp, { headers: { "x-step-up-token": proof({ id: "u2" }) } });
  expect(res.statusCode).toBe(401);
});

test("accepts a valid token", () => {
  const { next } = run(requireStepUp, { headers: { "x-step-up-token": proof() } });
  expect(next).toHaveBeenCalled();
});

test("downloads need proof but json previews do not", () => {
  expect(run(requireStepUpForDownload, { query: {} }).res.statusCode).toBe(401);
  expect(run(requireStepUpForDownload, { query: { format: "csv" } }).res.statusCode).toBe(401);
  expect(run(requireStepUpForDownload, { query: { format: "json" } }).next).toHaveBeenCalled();
});
