jest.mock("../src/config/database", () => ({
  query: jest.fn(),
}));
jest.mock("../src/middleware/auth", () => ({
  authenticate: (req, res, next) => next(),
  requireRole: () => (req, res, next) => next(),
}));
jest.mock("../src/services/smsService", () => ({
  sendSms: jest.fn().mockResolvedValue({ success: true }),
}));
jest.mock("../src/services/fcmService", () => ({
  sendPushNotification: jest.fn().mockResolvedValue({ invalidToken: false }),
}));

const pool = require("../src/config/database");
const { sendSms } = require("../src/services/smsService");
const { sendPushNotification } = require("../src/services/fcmService");
const router = require("../src/routes/beneficiaries");
const {
  changedFields,
  ownerVisibleLabels,
  buildEditNotice,
} = require("../src/utils/recordEdit");

const BENEFICIARY_ID = "00000000-0000-0000-0000-000000000001";
const putRoute = router.stack.find(
  (layer) => layer.route?.methods.put && layer.route.path.startsWith("/:id"),
).route;
const handler = putRoute.stack.at(-1).handle;
const validators = putRoute.stack.slice(0, -1).map((layer) => layer.handle);

function mockRes() {
  const res = { statusCode: 200, body: undefined };
  res.status = (code) => {
    res.statusCode = code;
    return res;
  };
  res.json = (body) => {
    res.body = body;
    return res;
  };
  return res;
}

async function runPut(body) {
  const req = {
    params: { id: BENEFICIARY_ID },
    user: { id: "staff-id", role: "osca_admin" },
    body,
    headers: {},
  };
  for (const validate of validators) {
    await new Promise((resolve) => validate(req, {}, resolve));
  }
  const res = mockRes();
  const next = jest.fn();
  await handler(req, res, next);
  return { res, next };
}

const before = {
  id: BENEFICIARY_ID,
  id_number: "123456789",
  full_name: "Juan Dela Cruz",
  birthdate: new Date("1950-01-01T00:00:00Z"),
  issuing_office: "OSCA Valenzuela",
  registered_mobile: "09171234567",
  contact_number: "09171234567",
  disability_type: null,
  address: "Old address",
  email: null,
  notes: null,
  beneficiary_type: "senior_citizen",
};

function mockDb(afterRow) {
  pool.query.mockImplementation(async (sql) => {
    if (sql.includes("SELECT * FROM beneficiaries")) return { rows: [before] };
    if (sql.includes("UPDATE beneficiaries")) return { rows: [afterRow] };
    if (sql.includes("FROM beneficiary_accounts"))
      return { rows: [{ id: "account-1", device_token: "device-token" }] };
    return { rows: [] };
  });
}

const queriesMatching = (text) =>
  pool.query.mock.calls.filter(([sql]) => sql.includes(text));

describe("PUT /beneficiaries/:id record edit notice (A-07)", () => {
  beforeEach(() => jest.clearAllMocks());

  test("rejects an edit without a reason", async () => {
    const { res } = await runPut({ full_name: "Juan D. Cruz" });

    expect(res.statusCode).toBe(400);
    expect(res.body.errors[0].msg).toBe("A reason for the edit is required.");
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("rejects a blank or over-long reason", async () => {
    const blank = await runPut({ full_name: "Juan D. Cruz", reason: "   " });
    const long = await runPut({
      full_name: "Juan D. Cruz",
      reason: "x".repeat(501),
    });

    expect(blank.res.statusCode).toBe(400);
    expect(long.res.statusCode).toBe(400);
    expect(pool.query).not.toHaveBeenCalled();
  });

  test("notifies the ID owner and stores the reason in the audit log", async () => {
    mockDb({ ...before, address: "New address" });

    const { res } = await runPut({
      address: "New address",
      reason: "Moved to a new barangay",
    });

    expect(res.statusCode).toBe(200);
    expect(res.body.owner_notified).toBe(true);

    const pushRow = queriesMatching("INSERT INTO notifications").find(([, p]) =>
      p.includes("Your Record Was Updated"),
    );
    expect(pushRow).toBeDefined();
    const body = pushRow[1][2];
    expect(body).toContain("address");
    expect(body).toContain("Reason: Moved to a new barangay.");
    expect(body).not.toContain("New address");
    expect(body).not.toContain("Old address");

    expect(sendPushNotification).toHaveBeenCalledTimes(1);
    expect(sendSms).toHaveBeenCalledWith(
      "09171234567",
      expect.stringContaining("Moved to a new barangay"),
    );

    const [, auditParams] = queriesMatching("INSERT INTO audit_logs")[0];
    const metadata = JSON.parse(auditParams[2]);
    expect(metadata.reason).toBe("Moved to a new barangay");
    expect(metadata.changed_fields).toEqual(["address"]);
    expect(metadata.owner_notice).toEqual({
      notified: true,
      accounts: 1,
      sms: true,
    });
  });

  test("sends the SMS to the number on file before the edit", async () => {
    mockDb({
      ...before,
      registered_mobile: "09990000000",
      contact_number: "09990000000",
    });

    await runPut({
      registered_mobile: "09990000000",
      contact_number: "09990000000",
      reason: "Updated contact number",
    });

    expect(sendSms).toHaveBeenCalledWith("09171234567", expect.any(String));
  });

  test("records the reason but does not notify for staff-only notes", async () => {
    mockDb({ ...before, notes: "Internal remark" });

    const { res } = await runPut({
      notes: "Internal remark",
      reason: "Added a staff note",
    });

    expect(res.body.owner_notified).toBe(false);
    expect(queriesMatching("INSERT INTO notifications")).toHaveLength(0);
    expect(sendSms).not.toHaveBeenCalled();
    const metadata = JSON.parse(
      queriesMatching("INSERT INTO audit_logs")[0][1][2],
    );
    expect(metadata.reason).toBe("Added a staff note");
  });

  test("does nothing when no field actually changed", async () => {
    mockDb({ ...before });

    const { res } = await runPut({
      full_name: "Juan Dela Cruz",
      reason: "Checked the record",
    });

    expect(res.body.unchanged).toBe(true);
    expect(queriesMatching("INSERT INTO")).toHaveLength(0);
    expect(sendSms).not.toHaveBeenCalled();
  });

  test("still saves the edit when the notice fails", async () => {
    const afterRow = { ...before, address: "New address" };
    pool.query.mockImplementation(async (sql) => {
      if (sql.includes("SELECT * FROM beneficiaries")) return { rows: [before] };
      if (sql.includes("UPDATE beneficiaries")) return { rows: [afterRow] };
      if (sql.includes("FROM beneficiary_accounts"))
        throw new Error("db down");
      return { rows: [] };
    });
    jest.spyOn(console, "error").mockImplementation(() => {});

    const { res, next } = await runPut({
      address: "New address",
      reason: "Moved",
    });

    expect(next).not.toHaveBeenCalled();
    expect(res.statusCode).toBe(200);
    expect(res.body.owner_notified).toBe(false);
    const metadata = JSON.parse(
      queriesMatching("INSERT INTO audit_logs")[0][1][2],
    );
    expect(metadata.owner_notice.error).toBe(true);
    console.error.mockRestore();
  });
});

describe("record edit helpers", () => {
  test("changedFields ignores formatting-only differences", () => {
    expect(
      changedFields(
        { full_name: "Ana ", email: null, birthdate: new Date("1950-01-01") },
        { full_name: "Ana", email: "", birthdate: new Date("1950-01-01") },
      ),
    ).toEqual([]);
  });

  test("ownerVisibleLabels merges the two contact number columns and hides notes", () => {
    expect(
      ownerVisibleLabels(["registered_mobile", "contact_number", "notes"]),
    ).toEqual(["contact number"]);
  });

  test("buildEditNotice shortens the reason in the SMS only", () => {
    const reason = "r".repeat(200);
    const notice = buildEditNotice({
      beneficiaryType: "pwd",
      labels: ["name"],
      reason,
    });

    expect(notice.body).toContain(reason);
    expect(notice.body).toContain("PWD record");
    expect(notice.smsBody.length).toBeLessThan(200);
  });
});
