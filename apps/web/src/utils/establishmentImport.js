import * as XLSX from "xlsx";

// Column header aliases — flexible matching regardless of spacing/casing
const HEADER_ALIASES = {
  business_name: [
    "business_name",
    "business name",
    "name",
    "establishment_name",
    "establishment name",
  ],
  business_permit_no: [
    "business_permit_no",
    "business permit no",
    "permit_no",
    "permit no",
    "permit_number",
    "permit number",
    "business_permit",
    "business permit",
    "bp_no",
    "bp no",
  ],
  owner_name: [
    "owner_name",
    "owner name",
    "owner",
    "proprietor",
    "proprietor_name",
  ],
  address: ["address", "location", "business_address", "business address"],
  contact_number: [
    "contact_number",
    "contact number",
    "contact",
    "phone",
    "mobile",
    "telephone",
    "contact_phone",
  ],
  contact_person: [
    "contact_person",
    "contact person",
    "on-site contact",
    "onsite contact",
    "on site contact",
  ],
  email: [
    "email",
    "email_address",
    "email address",
    "staff_email",
    "login_email",
  ],
  business_permit_expiry: [
    "business_permit_expiry",
    "business permit expiry",
    "permit_expiry",
    "permit expiry",
    "expiry",
    "expiration",
    "expiry_date",
    "expiry date",
  ],
};

function normalizeHeader(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
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
  const src = keyMap[key];
  if (!src) return "";
  const val = row[src];
  return val === null || val === undefined ? "" : val;
}

function excelSerialToIso(serial) {
  const ms = Math.round((serial - 25569) * 86400 * 1000);
  const d = new Date(ms);
  if (isNaN(d.getTime())) return "";
  return d.toISOString().slice(0, 10);
}

function toIsoDate(value) {
  if (!value && value !== 0) return "";
  if (typeof value === "number") return excelSerialToIso(value);
  const raw = String(value).trim();
  if (!raw) return "";
  const direct = new Date(raw);
  if (!isNaN(direct.getTime())) return direct.toISOString().slice(0, 10);
  // MM/DD/YYYY or MM-DD-YYYY
  const mdy = raw.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$/);
  if (mdy) {
    let [, m, d, y] = mdy;
    if (y.length === 2) y = Number(y) > 50 ? `19${y}` : `20${y}`;
    const parsed = new Date(`${y}-${m.padStart(2, "0")}-${d.padStart(2, "0")}`);
    if (!isNaN(parsed.getTime())) return parsed.toISOString().slice(0, 10);
  }
  return "";
}

/**
 * Parse a .csv, .xlsx, or .xls file and return normalized establishment records.
 * @param {File} file
 * @returns {{ records, errors, totalRows }}
 */
export async function parseEstablishmentImportFile(file) {
  const buffer = await file.arrayBuffer();
  const wb = XLSX.read(buffer, { type: "array" });
  const sheetName = wb.SheetNames[0];
  const ws = wb.Sheets[sheetName];

  const rows = XLSX.utils.sheet_to_json(ws, { defval: "", raw: true });

  if (!rows.length) {
    return {
      records: [],
      errors: [{ row: 0, error: "File has no data rows." }],
      totalRows: 0,
    };
  }

  const keyMap = indexColumns(Object.keys(rows[0]));
  const errors = [];
  const records = [];

  rows.forEach((row, index) => {
    const rowNum = index + 2; // row 1 = header

    const business_name = String(cell(row, keyMap, "business_name")).trim();
    const business_permit_no = String(cell(row, keyMap, "business_permit_no"))
      .trim()
      .toUpperCase();
    const owner_name = String(cell(row, keyMap, "owner_name")).trim();
    const address = String(cell(row, keyMap, "address")).trim();
    const contact_number = String(cell(row, keyMap, "contact_number"))
      .replace(/[^\d+]/g, "")
      .trim();
    const contact_person = String(cell(row, keyMap, "contact_person") || "").trim();
    const email = String(cell(row, keyMap, "email"))
      .trim()
      .toLowerCase();
    const business_permit_expiry = toIsoDate(
      cell(row, keyMap, "business_permit_expiry"),
    );

    // Required field checks
    if (!business_name) {
      errors.push({ row: rowNum, error: "business_name is required" });
      return;
    }
    if (!business_permit_no) {
      errors.push({ row: rowNum, error: "business_permit_no is required" });
      return;
    }
    if (!owner_name) {
      errors.push({ row: rowNum, error: "owner_name is required" });
      return;
    }
    if (!address) {
      errors.push({ row: rowNum, error: "address is required" });
      return;
    }
    if (!contact_number) {
      errors.push({ row: rowNum, error: "contact_number is required" });
      return;
    }
    if (contact_person.length > 255) {
      errors.push({
        row: rowNum,
        error: "contact_person must be 255 characters or fewer",
      });
      return;
    }
    if (email && !/\S+@\S+\.\S+/.test(email)) {
      errors.push({ row: rowNum, error: "email format is invalid" });
      return;
    }

    records.push({
      business_name,
      business_permit_no,
      owner_name,
      address,
      contact_number,
      contact_person: contact_person || undefined,
      email: email || undefined, // omit so backend knows to auto-generate
      business_permit_expiry: business_permit_expiry || undefined,
    });
  });

  return { records, errors, totalRows: rows.length };
}
