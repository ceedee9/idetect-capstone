import { useState } from "react";
import { X, Download, Eye, AlertCircle, Check } from "lucide-react";
import { auditLogsAPI } from "../services/api";

const TYPES = [
  { value: "summary", label: "Activity summary", hint: "Counts of every action, grouped by month, action or user." },
  { value: "staff", label: "Staff activity", hint: "Everything staff did (filter by role)." },
  { value: "security", label: "Security and access", hint: "Logins, logouts, password changes and OTP events." },
  { value: "exports", label: "Data export log", hint: "Who exported or generated reports, and when." },
];

const PERIODS = [
  { value: "month", label: "Month" },
  { value: "quarter", label: "Quarter" },
  { value: "half", label: "Half year" },
  { value: "year", label: "Full year" },
  { value: "custom", label: "Custom range" },
];

const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

export default function AuditReportModal({ onClose }) {
  const [tab, setTab] = useState("period");
  const [refNo, setRefNo] = useState("");
  const [casePreview, setCasePreview] = useState(null);
  const [caseBusy, setCaseBusy] = useState(false);
  const [caseError, setCaseError] = useState("");

  async function runCase(download) {
    setCaseBusy(true);
    setCaseError("");
    try {
      const ref = refNo.trim().toUpperCase();
      const res = await auditLogsAPI.caseFile(ref, download);
      if (download) {
        downloadBlob(new Blob([res.data], { type: "text/csv" }), `case-${ref}.csv`);
      } else {
        setCasePreview(res.data);
      }
    } catch (e) {
      setCasePreview(null);
      setCaseError(
        e.response?.status === 404
          ? "No record found for that reference number."
          : "Enter a valid reference number, e.g. DSP-2026-000123.",
      );
    } finally {
      setCaseBusy(false);
    }
  }

  const tabBtn = (v, text) => (
    <button
      type="button"
      onClick={() => setTab(v)}
      className={`px-4 py-2 text-sm font-semibold border-b-2 ${tab === v ? "border-primary-500 text-primary-700" : "border-transparent text-slate-500"}`}
    >
      {text}
    </button>
  );

  const now = new Date();
  const [type, setType] = useState("summary");
  const [period, setPeriod] = useState("month");
  const [year, setYear] = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [quarter, setQuarter] = useState(Math.floor(now.getMonth() / 3) + 1);
  const [half, setHalf] = useState(now.getMonth() < 6 ? 1 : 2);
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [mode, setMode] = useState("summary");
  const [groupBy, setGroupBy] = useState("month");
  const [role, setRole] = useState("");
  const [preview, setPreview] = useState(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const effectiveMode = type === "summary" ? "summary" : mode;

  function buildParams(extra = {}) {
    const p = { type, period, mode: effectiveMode, ...extra };
    if (period === "custom") {
      p.start_date = startDate;
      p.end_date = endDate;
    } else {
      p.year = year;
      if (period === "month") p.month = month;
      if (period === "quarter") p.quarter = quarter;
      if (period === "half") p.half = half;
    }
    if (effectiveMode === "summary") p.group_by = groupBy;
    if (role) p.role = role;
    return p;
  }

  async function run(download) {
    if (period === "custom" && (!startDate || !endDate)) {
      setError("Choose a start and end date.");
      return;
    }
    setBusy(true);
    setError("");
    try {
      if (download) {
        const res = await auditLogsAPI.report(buildParams({ format: "csv" }), true);
        downloadBlob(new Blob([res.data], { type: "text/csv" }), `audit-${type}-${effectiveMode}-${new Date().toISOString().slice(0, 10)}.csv`);
      } else {
        const res = await auditLogsAPI.report(buildParams({ format: "json" }), false);
        setPreview(res.data);
      }
    } catch {
      setError("Could not generate the report. Check the filters and try again.");
    } finally {
      setBusy(false);
    }
  }

  const label = "block text-xs font-semibold text-slate-600 mb-1";
  const input = "w-full border border-slate-200 rounded-lg px-3 py-2 text-sm bg-white";

  return (
    <div className="fixed inset-0 z-50 bg-black/40 p-4">
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-white rounded-2xl shadow-xl w-full max-w-3xl max-h-[calc(100vh-2rem)] flex flex-col overflow-hidden">
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100">
          <h2 className="font-heading font-bold text-lg text-slate-900">Generate audit report</h2>
          <button onClick={onClose} aria-label="Close" className="text-slate-400 hover:text-slate-700">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="flex gap-1 px-6 border-b border-slate-100">
          {tabBtn("period", "Period reports")}
          {tabBtn("case", "Case file")}
        </div>

        {tab === "case" && (
          <>
            <div className="p-6 space-y-4 overflow-y-auto">
              <div>
                <label className="block text-xs font-semibold text-slate-600 mb-1">Reference number</label>
                <input
                  className="w-full border border-slate-200 rounded-lg px-3 py-2 text-sm bg-white"
                  placeholder="DSP-2026-000123, FLG-, VER-, EST- or BEN-"
                  value={refNo}
                  onChange={(e) => setRefNo(e.target.value)}
                />
                <p className="text-xs text-slate-500 mt-1">
                  Bundles the record, the related scan, flags and disputes, and the full audit timeline. ID numbers are masked.
                </p>
              </div>
              {caseError && (
                <div className="flex items-center gap-2 px-3 py-2 bg-danger-50 border border-danger-100 rounded-lg text-danger-700 text-sm">
                  <AlertCircle className="w-4 h-4" /> {caseError}
                </div>
              )}
              {casePreview && (
                <div className="space-y-3 max-h-72 overflow-auto">
                  {casePreview.sections.map((s) => (
                    <div key={s.title} className="border border-slate-200 rounded-xl overflow-hidden">
                      <div className="px-3 py-1.5 bg-slate-50 text-xs font-semibold text-slate-700">
                        {s.title} ({s.rows.length})
                      </div>
                      <div className="overflow-auto">
                        <table className="w-full text-xs">
                          <thead>
                            <tr>{s.columns.map((c) => <th key={c} className="text-left px-3 py-1 text-slate-600">{c}</th>)}</tr>
                          </thead>
                          <tbody>
                            {s.rows.slice(0, 50).map((r, i) => (
                              <tr key={i} className="border-t border-slate-100">
                                {r.map((c, j) => (
                                  <td key={j} className="px-3 py-1 text-slate-700 max-w-[14rem] truncate">
                                    {c !== null && typeof c === "object" ? JSON.stringify(c) : String(c ?? "")}
                                  </td>
                                ))}
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
            <div className="flex justify-end gap-2 px-6 py-4 border-t border-slate-100">
              <button className="btn-secondary" disabled={caseBusy || !refNo.trim()} onClick={() => runCase(false)}>
                <Eye className="w-4 h-4" /> Preview
              </button>
              <button className="btn-primary" disabled={caseBusy || !refNo.trim()} onClick={() => runCase(true)}>
                <Download className="w-4 h-4" /> Download case file
              </button>
            </div>
          </>
        )}

        {tab === "period" && (
          <>
        <div className="p-6 space-y-5 overflow-y-auto">
          <div>
            <span className={label}>Report type</span>
            <div className="grid sm:grid-cols-2 gap-2">
              {TYPES.map((t) => (
                <button
                  key={t.value}
                  type="button"
                  aria-pressed={type === t.value}
                  onClick={() => { setType(t.value); setPreview(null); }}
                  className={`relative text-left rounded-xl border-2 px-3 py-2.5 transition-colors ${
                    type === t.value
                      ? "border-primary-600 bg-primary-50 ring-2 ring-primary-100"
                      : "border-slate-200 hover:border-primary-300 hover:bg-slate-50"
                  }`}
                >
                  {type === t.value && (
                    <span className="absolute top-2 right-2 flex items-center justify-center w-5 h-5 rounded-full bg-primary-600 text-white">
                      <Check className="w-3.5 h-3.5" strokeWidth={3} />
                    </span>
                  )}
                  <div className="text-sm font-semibold text-slate-900">{t.label}</div>
                  <div className={`text-xs ${type === t.value ? "text-primary-800" : "text-slate-500"}`}>{t.hint}</div>
                </button>
              ))}
            </div>
          </div>

          <div className="grid sm:grid-cols-4 gap-3">
            <div>
              <label className={label}>Period</label>
              <select className={input} value={period} onChange={(e) => setPeriod(e.target.value)}>
                {PERIODS.map((p) => <option key={p.value} value={p.value}>{p.label}</option>)}
              </select>
            </div>
            {period !== "custom" && (
              <div>
                <label className={label}>Year</label>
                <input type="number" className={input} value={year} min="2000" max="2100" onChange={(e) => setYear(e.target.value)} />
              </div>
            )}
            {period === "month" && (
              <div>
                <label className={label}>Month</label>
                <select className={input} value={month} onChange={(e) => setMonth(e.target.value)}>
                  {MONTHS.map((m, i) => <option key={m} value={i + 1}>{m}</option>)}
                </select>
              </div>
            )}
            {period === "quarter" && (
              <div>
                <label className={label}>Quarter</label>
                <select className={input} value={quarter} onChange={(e) => setQuarter(e.target.value)}>
                  {[1, 2, 3, 4].map((n) => <option key={n} value={n}>Q{n}</option>)}
                </select>
              </div>
            )}
            {period === "half" && (
              <div>
                <label className={label}>Half</label>
                <select className={input} value={half} onChange={(e) => setHalf(e.target.value)}>
                  <option value={1}>H1 (Jan–Jun)</option>
                  <option value={2}>H2 (Jul–Dec)</option>
                </select>
              </div>
            )}
            {period === "custom" && (
              <>
                <div>
                  <label className={label}>From</label>
                  <input type="date" className={input} value={startDate} onChange={(e) => setStartDate(e.target.value)} />
                </div>
                <div>
                  <label className={label}>To</label>
                  <input type="date" className={input} value={endDate} onChange={(e) => setEndDate(e.target.value)} />
                </div>
              </>
            )}
          </div>

          <div className="grid sm:grid-cols-3 gap-3">
            {type !== "summary" && (
              <div>
                <label className={label}>Output</label>
                <select className={input} value={mode} onChange={(e) => setMode(e.target.value)}>
                  <option value="summary">Summary (counts)</option>
                  <option value="detail">Detailed (every record)</option>
                </select>
              </div>
            )}
            {effectiveMode === "summary" && (
              <div>
                <label className={label}>Group by</label>
                <select className={input} value={groupBy} onChange={(e) => setGroupBy(e.target.value)}>
                  <option value="month">Month</option>
                  <option value="action">Action</option>
                  <option value="user">Staff member</option>
                </select>
              </div>
            )}
            <div>
              <label className={label}>Office / role</label>
              <select className={input} value={role} onChange={(e) => setRole(e.target.value)}>
                <option value="">All</option>
                <option value="bplo_super_admin">BPLO Super Admin</option>
                <option value="osca_super_admin">OSCA Super Admin</option>
                <option value="pdao_super_admin">PDAO Super Admin</option>
                <option value="osca_admin">OSCA</option>
                <option value="pdao_admin">PDAO</option>
                <option value="bplo_admin">BPLO</option>
              </select>
            </div>
          </div>

          {error && (
            <div className="flex items-center gap-2 px-3 py-2 bg-danger-50 border border-danger-100 rounded-lg text-danger-700 text-sm">
              <AlertCircle className="w-4 h-4" /> {error}
            </div>
          )}

          {preview && (
            <div className="border border-slate-200 rounded-xl overflow-hidden">
              <div className="px-3 py-2 bg-slate-50 text-xs text-slate-600 flex justify-between">
                <span>{preview.meta.report} · {preview.meta.start_date} to {preview.meta.end_date}</span>
                <span>{preview.meta.total} records{preview.meta.mode === "detail" && preview.meta.total > preview.rows.length ? ` (showing ${preview.rows.length})` : ""}</span>
              </div>
              <div className="max-h-64 overflow-auto">
                <table className="w-full text-xs">
                  <thead className="sticky top-0 bg-white">
                    <tr>{preview.columns.map((c) => <th key={c} className="text-left px-3 py-1.5 font-semibold text-slate-600">{c}</th>)}</tr>
                  </thead>
                  <tbody>
                    {preview.rows.map((r, i) => (
                      <tr key={i} className="border-t border-slate-100">
                        {r.map((c, j) => (
                          <td key={j} className="px-3 py-1.5 text-slate-700 max-w-[14rem] truncate">
                            {c !== null && typeof c === "object" ? JSON.stringify(c) : String(c ?? "")}
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>

        <div className="flex justify-end gap-2 px-6 py-4 border-t border-slate-100">
          <button className="btn-secondary" disabled={busy} onClick={() => run(false)}>
            <Eye className="w-4 h-4" /> Preview
          </button>
          <button className="btn-primary" disabled={busy} onClick={() => run(true)}>
            <Download className="w-4 h-4" /> Download CSV
          </button>
        </div>
          </>
        )}
      </div>
    </div>
  );
}
