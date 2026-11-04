const { detectOutsideValenzuela, classifyIssuingCity } = require("../src/utils/issuingLgu");

describe("detectOutsideValenzuela", () => {
  test("flags a card that names another city", () => {
    const text = "REPUBLIC OF THE PHILIPPINES\nCITY OF MALABON\nSENIOR CITIZEN ID\nJUAN DELA CRUZ";
    expect(detectOutsideValenzuela(text)).toBe(true);
  });

  test("flags a municipality name, case-insensitively", () => {
    expect(detectOutsideValenzuela("municipality of Bocaue\nID 123")).toBe(true);
  });

  test("does not flag a Valenzuela card", () => {
    const text = "CITY OF VALENZUELA\nOFFICE OF SENIOR CITIZENS AFFAIRS";
    expect(detectOutsideValenzuela(text)).toBe(false);
  });

  test("a Valenzuela mention wins over another city name", () => {
    const text = "VALENZUELA CITY\nCITY OF MANILA";
    expect(detectOutsideValenzuela(text)).toBe(false);
  });

  test("tolerates a common OCR misread of Valenzuela", () => {
    const text = "CITY OF VALENZUEIA\nCITY OF MANILA";
    expect(detectOutsideValenzuela(text)).toBe(false);
  });

  test("does not flag text without an issuing city", () => {
    expect(detectOutsideValenzuela("OFFICE OF SENIOR CITIZENS AFFAIRS\nJUAN DELA CRUZ")).toBe(false);
  });

  test("does not flag the Office of the City Mayor wording", () => {
    expect(detectOutsideValenzuela("OFFICE OF THE CITY MAYOR\nSENIOR CITIZEN")).toBe(false);
  });

  test("flags the City Government wording used on some cards", () => {
    expect(detectOutsideValenzuela("CITY GOVERNMENT OF MALABON\nSENIOR CITIZEN ID")).toBe(true);
  });

  test("flags Tagalog wording (Lungsod ng / Bayan ng)", () => {
    expect(detectOutsideValenzuela("LUNGSOD NG MALABON\nID 123")).toBe(true);
    expect(detectOutsideValenzuela("BAYAN NG BULACAN\nID 123")).toBe(true);
  });

  test("matches multi-word city names", () => {
    expect(detectOutsideValenzuela("CITY OF SAN JOSE DEL MONTE\nID 123")).toBe(true);
  });

  test("does not flag a name without a government keyword", () => {
    expect(detectOutsideValenzuela("MALABON\nJUAN DELA CRUZ")).toBe(false);
    expect(detectOutsideValenzuela("ANGELES\nLOPEZ\nID 123")).toBe(false);
  });

  test("does not flag a city named only lower in the card (outside the header)", () => {
    const lines = Array.from({ length: 10 }, (_, i) => `LINE ${i + 1}`);
    lines[9] = "CITY OF MALABON";
    expect(detectOutsideValenzuela(lines.join("\n"))).toBe(false);
  });

  test("a Valenzuela header wins even if another city is printed in the header", () => {
    expect(detectOutsideValenzuela("CITY GOVERNMENT OF VALENZUELA\nCITY OF MALABON")).toBe(false);
  });

  test("classifyIssuingCity reports valenzuela, other, or unknown", () => {
    expect(classifyIssuingCity("CITY GOVERNMENT OF VALENZUELA")).toBe("valenzuela");
    expect(classifyIssuingCity("CITY OF MALABON")).toBe("other");
    expect(classifyIssuingCity("OFFICE OF SENIOR CITIZENS AFFAIRS")).toBe("unknown");
    expect(classifyIssuingCity("")).toBe("unknown");
  });

  test("matches a city name with one misread letter", () => {
    expect(detectOutsideValenzuela("CITY OF MALABQN\nID 123")).toBe(true);
    expect(detectOutsideValenzuela("CITY GOVERNMENT OF MALABQN\nID 123")).toBe(true);
    expect(detectOutsideValenzuela("LUNGSOD NG MALABQN\nID 123")).toBe(true);
  });

  test("matches a longer city name with two misread letters", () => {
    expect(detectOutsideValenzuela("CITY OF SAN JOSE DEL M0NTE\nID 123")).toBe(true);
    expect(detectOutsideValenzuela("CITY OF SAN JOSE DEL M0N7E\nID 123")).toBe(true);
  });

  test("does not match a short city name with a misread letter", () => {
    expect(classifyIssuingCity("CITY OF PILER\nID 123")).toBe("unknown");
  });

  test("does not match a name with too many misread letters", () => {
    expect(classifyIssuingCity("CITY OF MALAB\nID 123")).toBe("unknown");
    expect(classifyIssuingCity("CITY OF MALAXQN\nID 123")).toBe("unknown");
  });

  test("a misread Valenzuela after the keyword still counts as Valenzuela", () => {
    expect(classifyIssuingCity("CITY OF VALEN2UELA\nCITY OF MALABON")).toBe("valenzuela");
  });

  test("handles empty or missing text", () => {

    expect(detectOutsideValenzuela("")).toBe(false);
    expect(detectOutsideValenzuela("   ")).toBe(false);
    expect(detectOutsideValenzuela(null)).toBe(false);
    expect(detectOutsideValenzuela(undefined)).toBe(false);
  });
});
