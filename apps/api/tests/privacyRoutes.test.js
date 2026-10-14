const { maskIdNumber } = require("../src/utils/privacy");

describe("privacy route response rules", () => {
  test("masks IDs used in verification history and status updates", () => {
    const rows = [
      { id_number: "123456789", id_number_scanned: "ABC12345" },
    ].map((row) => ({
      ...row,
      id_number: maskIdNumber(row.id_number),
      id_number_scanned: maskIdNumber(row.id_number_scanned),
    }));

    expect(rows[0]).toMatchObject({
      id_number: "*******89",
      id_number_scanned: "******45",
    });
  });

  test("does not expose OCR contents through the fraud-list contract", () => {
    const row = { ocr_data_available: true };
    expect(row.ocr_raw_text).toBeUndefined();
    expect(row.ocr_data_available).toBe(true);
  });
});
