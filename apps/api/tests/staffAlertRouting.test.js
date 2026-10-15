jest.mock("../src/config/database", () => ({ query: jest.fn() }));

const {
  getDisputeAlertRoles,
  getDisputeAlertRoute,
} = require("../src/services/staffAlerts");

describe("dispute alert routing", () => {
  test("business refusals alert BPLO and the beneficiary's own office", () => {
    expect(getDisputeAlertRoles("business_refusal", "senior_citizen")).toEqual([
      "bplo_admin",
      "osca_admin",
    ]);
    expect(getDisputeAlertRoles("business_refusal", "pwd")).toEqual([
      "bplo_admin",
      "pdao_admin",
    ]);
  });

  test("other disputes alert only the beneficiary's own office", () => {
    expect(getDisputeAlertRoles("wrong_denial", "senior_citizen")).toEqual([
      "osca_admin",
    ]);
    expect(getDisputeAlertRoles("unauthorized_use", "pwd")).toEqual([
      "pdao_admin",
    ]);
  });

  test("BPLO alerts open the refusal queue; offices open disputes", () => {
    expect(getDisputeAlertRoute("bplo_admin")).toBe("/business-refusals");
    expect(getDisputeAlertRoute("osca_admin")).toBe("/disputes");
    expect(getDisputeAlertRoute("pdao_admin")).toBe("/disputes");
  });
});
