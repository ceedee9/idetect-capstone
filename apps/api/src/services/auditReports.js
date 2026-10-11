// Helpers for filtered audit-log reports (period resolution, categories, CSV).

const REPORT_TYPES = {
  summary: { label: "Activity summary", actions: null },
  staff: { label: "Staff activity", actions: null },
  security: {
    label: "Security and access",
    actions: [
      "login",
      "logout",
      "password_changed",
      "otp_requested",
      "otp_verified",
    ],
  },
  exports: {
    label: "Data export log",
    actions: [
      "data_export",
      "report_generated",
      "breach_incident_report_generated",
    ],
  },
};

const PERIODS = ["month", "quarter", "half", "year", "custom"];
const DETAIL_LIMIT = 50000;

const pad = (n) => String(n).padStart(2, "0");
const ymd = (y, m, d) => `${y}-${pad(m)}-${pad(d)}`;
const lastDay = (y, m) => new Date(Date.UTC(y, m, 0)).getUTCDate();

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

function isValidDate(value) {
  if (!DATE_RE.test(value)) return false;
  const date = new Date(`${value}T00:00:00Z`);
  return (
    !Number.isNaN(date.getTime()) &&
    date.toISOString().slice(0, 10) === value
  );
}

// Returns { start, end, label } (inclusive dates) or { error }.
function resolvePeriod(q, now = new Date()) {
  const period = q.period || "month";
  if (!PERIODS.includes(period)) return { error: "Invalid period" };

  if (period === "custom") {
    if (!isValidDate(q.start_date || "") || !isValidDate(q.end_date || "")) {
      return { error: "Custom period needs start_date and end_date" };
    }
    if (q.start_date > q.end_date) {
      return { error: "start_date must not be after end_date" };
    }
    return {
      start: q.start_date,
      end: q.end_date,
      label: `${q.start_date} to ${q.end_date}`,
    };
  }

  const year = q.year === undefined ? now.getUTCFullYear() : Number(q.year);
  if (!Number.isInteger(year) || year < 2000 || year > 2100) {
    return { error: "Invalid year" };
  }

  if (period === "year") {
    return { start: ymd(year, 1, 1), end: ymd(year, 12, 31), label: `${year}` };
  }

  const bounds = { month: [1, 12], quarter: [1, 4], half: [1, 2] }[period];
  const defaults = {
    month: now.getUTCMonth() + 1,
    quarter: Math.floor(now.getUTCMonth() / 3) + 1,
    half: now.getUTCMonth() < 6 ? 1 : 2,
  };
  const n = q[period] === undefined ? defaults[period] : Number(q[period]);
  if (!Number.isInteger(n) || n < bounds[0] || n > bounds[1]) {
    return { error: `Invalid ${period}` };
  }

  if (period === "month") {
    return {
      start: ymd(year, n, 1),
      end: ymd(year, n, lastDay(year, n)),
      label: `${year}-${pad(n)}`,
    };
  }
  const span = period === "quarter" ? 3 : 6;
  const first = (n - 1) * span + 1;
  const last = first + span - 1;
  return {
    start: ymd(year, first, 1),
    end: ymd(year, last, lastDay(year, last)),
    label: `${year} ${period === "quarter" ? "Q" : "H"}${n}`,
  };
}

function csvCell(v) {
  if (v === null || v === undefined) return "";
  let s = typeof v === "object" ? JSON.stringify(v) : String(v);
  // Prevent spreadsheet formula injection.
  if (/^[=+\-@\t\r]/.test(s) && typeof v === "string") s = `'${s}`;
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

function csvLine(cells) {
  return cells.map(csvCell).join(",");
}

module.exports = {
  REPORT_TYPES,
  PERIODS,
  DETAIL_LIMIT,
  resolvePeriod,
  csvCell,
  csvLine,
};
