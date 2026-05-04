import { useState } from "react";
import { ShieldAlert, X, Download, Loader2 } from "lucide-react";
import { breachReportAPI } from "../services/api";

const DATA_CATEGORIES = [
  "Full names",
  "ID numbers",
  "Birthdates",
  "Registered mobile numbers",
  "Verification transaction records",
  "Fraud flag reports",
  "Audit log entries",
  "Authentication credentials (hashed)",
];

/**
 * REQ-2.17.6 – Breach incident report modal.
 * Allows an admin to fill in breach details and generate a formatted
 * NPC notification report (72-hour obligation under RA 10173).
 */
export default function BreachReportModal({ onClose }) {
  const [step, setStep] = useState("form"); // "form" | "result"
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [result, setResult] = useState(null);

  const [form, setForm] = useState({
    nature_of_breach: "",
    affected_categories: [],
    estimated_subjects: "",
    discovery_date: new Date().toISOString().slice(0, 16),
    notes: "",
  });

  function toggleCategory(cat) {
    setForm((f) => ({
      ...f,
      affected_categories: f.affected_categories.includes(cat)
        ? f.affected_categories.filter((c) => c !== cat)
        : [...f.affected_categories, cat],
    }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");

    if (!form.nature_of_breach.trim()) {
      setError("Please describe the nature of the breach.");
      return;
    }
    if (form.affected_categories.length === 0) {
      setError("Select at least one affected data category.");
      return;
    }
    if (!form.estimated_subjects || Number(form.estimated_subjects) < 0) {
      setError("Enter a valid estimated number of affected data subjects.");
      return;
    }

    setLoading(true);
    try {
      const res = await breachReportAPI.generate({
        ...form,
        estimated_subjects: Number(form.estimated_subjects),
      });
      setResult(res.data);
      setStep("result");
    } catch (err) {
      setError(
        err.response?.data?.message || "Failed to generate report. Please try again."
      );
    } finally {
      setLoading(false);
    }
  }

  function downloadReport() {
    const blob = new Blob([result.formatted_report], { type: "text/plain;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `breach-incident-report-${result.report_id.slice(0, 8)}.txt`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center gap-3 px-6 py-4 border-b border-slate-100 flex-shrink-0">
          <div className="w-9 h-9 rounded-xl bg-red-100 flex items-center justify-center">
            <ShieldAlert className="w-5 h-5 text-red-600" />
          </div>
          <div>
            <h2 className="text-base font-bold text-slate-900">
              Breach Incident Report
            </h2>
            <p className="text-xs text-slate-500">
              REQ-2.17.6 · RA 10173 · 72-hour NPC notification
            </p>
          </div>
          <button
            onClick={onClose}
            className="ml-auto text-slate-400 hover:text-slate-600 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="overflow-y-auto flex-1 px-6 py-5">
          {step === "form" ? (
            <form id="breach-form" onSubmit={handleSubmit} className="space-y-5">
              {/* Nature of breach */}
              <div>
                <label className="block text-sm font-semibold text-slate-700 mb-1.5">
                  Nature of the Breach <span className="text-red-500">*</span>
                </label>
                <textarea
                  rows={3}
                  value={form.nature_of_breach}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, nature_of_breach: e.target.value }))
                  }
                  placeholder="Describe what happened — e.g., unauthorized access to beneficiary records via compromised admin credentials..."
                  className="w-full px-3 py-2.5 rounded-xl border border-slate-200 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-red-400 resize-none"
                />
              </div>

              {/* Affected data categories */}
              <div>
                <label className="block text-sm font-semibold text-slate-700 mb-1.5">
                  Affected Data Categories <span className="text-red-500">*</span>
                </label>
                <div className="grid grid-cols-2 gap-2">
                  {DATA_CATEGORIES.map((cat) => (
                    <label
                      key={cat}
                      className="flex items-center gap-2 px-3 py-2 rounded-lg border border-slate-200 cursor-pointer hover:bg-slate-50 transition-colors"
                    >
                      <input
                        type="checkbox"
                        checked={form.affected_categories.includes(cat)}
                        onChange={() => toggleCategory(cat)}
                        className="accent-red-600"
                      />
                      <span className="text-xs text-slate-700">{cat}</span>
                    </label>
                  ))}
                </div>
              </div>

              {/* Estimated subjects + discovery date */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-1.5">
                    Estimated Affected Subjects <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="number"
                    min={0}
                    value={form.estimated_subjects}
                    onChange={(e) =>
                      setForm((f) => ({ ...f, estimated_subjects: e.target.value }))
                    }
                    placeholder="0"
                    className="w-full px-3 py-2.5 rounded-xl border border-slate-200 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-red-400"
                  />
                </div>
                <div>
                  <label className="block text-sm font-semibold text-slate-700 mb-1.5">
                    Date / Time Discovered <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="datetime-local"
                    value={form.discovery_date}
                    onChange={(e) =>
                      setForm((f) => ({ ...f, discovery_date: e.target.value }))
                    }
                    className="w-full px-3 py-2.5 rounded-xl border border-slate-200 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-red-400"
                  />
                </div>
              </div>

              {/* Notes */}
              <div>
                <label className="block text-sm font-semibold text-slate-700 mb-1.5">
                  Additional Notes (optional)
                </label>
                <textarea
                  rows={2}
                  value={form.notes}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, notes: e.target.value }))
                  }
                  placeholder="Any additional context, remediation steps taken, etc."
                  className="w-full px-3 py-2.5 rounded-xl border border-slate-200 text-sm text-slate-900 focus:outline-none focus:ring-2 focus:ring-red-400 resize-none"
                />
              </div>

              {error && (
                <p className="text-sm text-red-600 bg-red-50 px-3 py-2 rounded-lg">
                  {error}
                </p>
              )}
            </form>
          ) : (
            /* Result view */
            <div className="space-y-4">
              <div className="flex items-center gap-2 text-green-700 bg-green-50 px-4 py-3 rounded-xl">
                <ShieldAlert className="w-4 h-4 flex-shrink-0" />
                <span className="text-sm font-semibold">
                  Report generated and logged to audit trail. Report ID:{" "}
                  <code className="font-mono">{result.report_id.slice(0, 8).toUpperCase()}</code>
                </span>
              </div>
              <div className="bg-slate-50 rounded-xl p-4 border border-slate-200">
                <pre className="text-xs text-slate-700 whitespace-pre-wrap font-mono leading-relaxed">
                  {result.formatted_report}
                </pre>
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between gap-3 px-6 py-4 border-t border-slate-100 flex-shrink-0">
          {step === "result" ? (
            <>
              <p className="text-xs text-slate-500">
                Submit this report to NPC within 72 hours of discovery.
              </p>
              <div className="flex gap-2">
                <button
                  onClick={downloadReport}
                  className="flex items-center gap-1.5 px-4 py-2 rounded-xl bg-slate-100 text-slate-700 text-sm font-semibold hover:bg-slate-200 transition-colors"
                >
                  <Download className="w-4 h-4" />
                  Download
                </button>
                <button
                  onClick={onClose}
                  className="px-4 py-2 rounded-xl bg-red-600 text-white text-sm font-semibold hover:bg-red-700 transition-colors"
                >
                  Close
                </button>
              </div>
            </>
          ) : (
            <>
              <button
                onClick={onClose}
                className="px-4 py-2 rounded-xl border border-slate-200 text-sm font-semibold text-slate-600 hover:bg-slate-50 transition-colors"
              >
                Cancel
              </button>
              <button
                type="submit"
                form="breach-form"
                disabled={loading}
                className="flex items-center gap-2 px-5 py-2 rounded-xl bg-red-600 text-white text-sm font-semibold hover:bg-red-700 disabled:opacity-50 transition-colors"
              >
                {loading && <Loader2 className="w-4 h-4 animate-spin" />}
                Generate Report
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
