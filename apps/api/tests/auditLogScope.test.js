const {
  ESTABLISHMENT_AUDIT_ACTIONS,
  appendAuditScope,
} = require("../src/services/auditLogScope");

describe("audit log scope for callback requests", () => {
  test("callback_requested is an establishment audit action", () => {
    expect(ESTABLISHMENT_AUDIT_ACTIONS).toContain("callback_requested");
  });

  test("BPLO scope passes the callback action to the unattributed-row rule", () => {
    const params = [];
    const { query } = appendAuditScope("SELECT 1 WHERE 1=1", params, 1, "bplo_admin");

    expect(params).toContainEqual(ESTABLISHMENT_AUDIT_ACTIONS);
    expect(query).toMatch(/u\.id IS NULL/);
  });
});
