import * as XLSX from "xlsx";

const HEADER_ALIASES = {
  id_number: ["id_number", "id number", "idno", "id no", "osca_id", "osca id"],
  full_name: [
    "full_name",
    "full name",
    "name",
    "beneficiary_name",
    "beneficiary name",
  ],
  first_name: [
    "first_name",
    "first name",
    "firstname",
    "given_name",
    "given name",
  ],
  middle_name: ["middle_name", "middle name", "middlename"],
  last_name: ["last_name", "last name", "lastname", "surname"],
  birthdate: ["birthdate", "date_of_birth", "date of birth", "dob"],
  issuing_office: ["issuing_office", "issuing office", "office"],
  validity_start: [
    "validity_start",
    "validity start",
    "start_date",
    "start date",
  ],
  validity_end: [
    "validity_end",
    "validity end",
    "end_date",
    "end date",
    "expiry",
    "expiration",
  ],
  registered_mobile: [
    "registered_mobile",
    "registered mobile",
    "mobile",
    "mobile_number",
    "contact_number",
    "contact number",
    "phone",
  ],
};

function normalizeHeader(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

function excelSerialToIsoDate(serial) {
  const utc = Math.round((serial - 25569) * 86400 * 1000);
  const d = new Date(utc);
  if (Number.isNaN(d.getTime())) return "";
  return d.toISOString().slice(0, 10);
}

function toIsoDate(value) {
  if (!value && value !== 0) return "";

  if (typeof value === "number") {
    return excelSerialToIsoDate(value);
  }

  const raw = String(value).trim();
  if (!raw) return "";

  const direct = new Date(raw);
  if (!Number.isNaN(direct.getTime())) {
    return direct.toISOString().slice(0, 10);
  }

  const mdy = raw.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$/);
  if (mdy) {
    const month = mdy[1].padStart(2, "0");
    const day = mdy[2].padStart(2, "0");
    let year = mdy[3];
    if (year.length === 2) year = Number(year) > 50 ? `19${year}` : `20${year}`;
    return `${year}-${month}-${day}`;
  }

  return "";
}

function addOneYear(isoDate) {
  const d = new Date(isoDate);
  d.setFullYear(d.getFullYear() + 1);
  return d.toISOString().slice(0, 10);
}

function indexColumns(headers) {
  const map = {};
  const normalized = headers.map(normalizeHeader);

  Object.entries(HEADER_ALIASES).forEach(([target, aliases]) => {
    const aliasSet = new Set(aliases.map(normalizeHeader));
    const idx = normalized.findIndex((h) => aliasSet.has(h));
    if (idx >= 0) map[target] = headers[idx];
  });

  return map;
}

function cell(row, keyMap, key) {
  const sourceKey = keyMap[key];
  if (!sourceKey) return "";
  return row[sourceKey];
}

export async function parseBeneficiaryImportFile(file, defaultIssuingOffice) {
  const buffer = await file.arrayBuffer();
  const wb = XLSX.read(buffer, { type: "array" });
  const sheetName = wb.SheetNames[0];
  const ws = wb.Sheets[sheetName];

  const rows = XLSX.utils.sheet_to_json(ws, {
    defval: "",
    raw: true,
  });

  if (!rows.length) {
    return {
      records: [],
      errors: [{ row: 0, error: "File has no data rows." }],
      totalRows: 0,
    };
  }

  const keyMap = indexColumns(Object.keys(rows[0]));
  const today = new Date().toISOString().slice(0, 10);
  const errors = [];
  const records = [];

  rows.forEach((row, index) => {
    const rowNum = index + 2;

    const idNumber = String(cell(row, keyMap, "id_number") || "")
      .trim()
      .toUpperCase();
    const fullName = String(cell(row, keyMap, "full_name") || "").trim();
    const firstName = String(cell(row, keyMap, "first_name") || "").trim();
    const middleName = String(cell(row, keyMap, "middle_name") || "").trim();
    const lastName = String(cell(row, keyMap, "last_name") || "").trim();

    const computedName = [firstName, middleName, lastName]
      .filter(Boolean)
      .join(" ")
      .trim();
    const name = fullName || computedName;

    const birthdate = toIsoDate(cell(row, keyMap, "birthdate"));
    const validityStart =
      toIsoDate(cell(row, keyMap, "validity_start")) || today;
    const validityEnd =
      toIsoDate(cell(row, keyMap, "validity_end")) || addOneYear(validityStart);
    const issuingOffice =
      String(cell(row, keyMap, "issuing_office") || "").trim() ||
      defaultIssuingOffice;
    const mobile = String(cell(row, keyMap, "registered_mobile") || "")
      .replace(/[^\d+]/g, "")
      .trim();

    if (!idNumber) {
      errors.push({ row: rowNum, error: "id_number is required" });
      return;
    }
    if (!name) {
      errors.push({
        row: rowNum,
        error: "full_name or first/last name is required",
      });
      return;
    }
    if (!birthdate) {
      errors.push({
        row: rowNum,
        error: "birthdate is required and must be a valid date",
      });
      return;
    }

    records.push({
      id_number: idNumber,
      full_name: name,
      birthdate,
      issuing_office: issuingOffice,
      validity_start: validityStart,
      validity_end: validityEnd,
      registered_mobile: mobile || undefined,
    });
  });

  return {
    records,
    errors,
    totalRows: rows.length,
  };
}
