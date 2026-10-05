const { resolvePeriod, csvLine } = require("../src/services/auditReports");

describe("resolvePeriod", () => {
  const now = new Date("2026-05-15T00:00:00Z");

  test("year, half, quarter, month", () => {
    expect(resolvePeriod({ period: "year", year: "2025" })).toMatchObject({
      start: "2025-01-01",
      end: "2025-12-31",
    });
    expect(resolvePeriod({ period: "half", year: "2026", half: "2" })).toMatchObject({
      start: "2026-07-01",
      end: "2026-12-31",
    });
    expect(resolvePeriod({ period: "quarter", year: "2026", quarter: "2" })).toMatchObject({
      start: "2026-04-01",
      end: "2026-06-30",
    });
    expect(resolvePeriod({ period: "month", year: "2024", month: "2" })).toMatchObject({
      start: "2024-02-01",
      end: "2024-02-29",
    });
  });

  test("defaults to the current month", () => {
    expect(resolvePeriod({}, now)).toMatchObject({
      start: "2026-05-01",
      end: "2026-05-31",
    });
  });

  test("custom range and invalid input", () => {
    expect(
      resolvePeriod({ period: "custom", start_date: "2026-01-05", end_date: "2026-01-09" }),
    ).toMatchObject({ start: "2026-01-05", end: "2026-01-09" });
    expect(resolvePeriod({ period: "custom", start_date: "2026-02-01", end_date: "2026-01-01" }).error).toBeTruthy();
    expect(resolvePeriod({ period: "half", half: "3" }).error).toBeTruthy();
    expect(resolvePeriod({ period: "decade" }).error).toBeTruthy();
    expect(resolvePeriod({ period: "year", year: "abc" }).error).toBeTruthy();
  });
});

describe("csvLine", () => {
  test("escapes quotes, commas and formula prefixes", () => {
    expect(csvLine(["a,b", 'x"y', "=1+1", 3, null, { k: 1 }])).toBe(
      `"a,b","x""y",'=1+1,3,,"{""k"":1}"`,
    );
  });
});
