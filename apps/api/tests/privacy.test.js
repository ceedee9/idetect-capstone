const {
  getAgeBand,
  maskBeneficiary,
  maskIdNumber,
} = require("../src/utils/privacy");

describe("privacy serializers", () => {
  test("masks identifiers while preserving only the final two characters", () => {
    expect(maskIdNumber("123456789")).toBe("*******89");
    expect(maskIdNumber("AB")).toBe("**AB");
    expect(maskIdNumber(null)).toBe(null);
  });

  test("returns age bands rather than exact age or birth date", () => {
    expect(getAgeBand("1960-10-14", new Date("2026-10-14T00:00:00Z"))).toBe(
      "60_69",
    );
    expect(getAgeBand("2008-10-15", new Date("2026-10-14T00:00:00Z"))).toBe(
      "under_18",
    );
    expect(getAgeBand("not-a-date")).toBe(null);
  });

  test("removes birth dates from beneficiary response objects", () => {
    expect(
      maskBeneficiary({
        id_number: "123456789",
        birthdate: "1960-10-14",
        full_name: "Example",
      }),
    ).toEqual({
      id_number: "*******89",
      age_band: expect.any(String),
      full_name: "Example",
    });
  });
});
