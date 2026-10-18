import { useState, useRef } from "react";
import {
  X,
  Upload,
  Download,
  FileSpreadsheet,
  AlertCircle,
  CheckCircle2,
  Loader2,
  ChevronRight,
  Building2,
  ShieldCheck,
  Copy,
} from "lucide-react";
import { parseEstablishmentImportFile } from "../utils/establishmentImport";
import { establishmentsAPI } from "../services/api";

// ── Template CSV download ──────────────────────────────────────
function downloadTemplate() {
  const csv = [
    "business_name,business_permit_no,owner_name,address,contact_number,email,business_permit_expiry,contact_person",
    "Juan's Restaurant,VP-2026-00001,Juan Dela Cruz,123 Maysan Road Valenzuela City,09171234567,juan@restaurant.com,2027-01-01,",
    "Maria's Catering,VP-2026-00002,Maria Santos,456 Gen. T. de Leon Valenzuela City,09281234567,,,Maria Santos",
  ].join("\n");
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "bplo-establishments-template.csv";
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export default function BulkImportEstablishmentsModal({ onClose, onSuccess }) {
  const fileInputRef = useRef(null);

  const [step, setStep] = useState("upload"); // upload | preview | done
  const [file, setFile] = useState(null);
  const [analyzing, setAnalyzing] = useState(false);
  const [preview, setPreview] = useState(null); // { records, errors, totalRows }
  const [analyzeError, setAnalyzeError] = useState("");

  const [importing, setImporting] = useState(false);
  const [importResult, setImportResult] = useState(null); // { summary, credentialToken, invalidRows }
  const [importError, setImportError] = useState("");
  const [downloadingCreds, setDownloadingCreds] = useState(false);

  // ── File selection ─────────────────────────────────────────
  function handleFileChange(e) {
    const f = e.target.files[0];
    if (!f) return;
    setFile(f);
    setPreview(null);
    setAnalyzeError("");
    setStep("upload");
  }

  function handleDrop(e) {
    e.preventDefault();
    const f = e.dataTransfer.files[0];
    if (!f) return;
    setFile(f);
    setPreview(null);
    setAnalyzeError("");
    setStep("upload");
  }

  // ── Analyze ────────────────────────────────────────────────
  async function handleAnalyze() {
    if (!file) {
      setAnalyzeError("Please select a CSV or Excel file first.");
      return;
    }
    setAnalyzing(true);
    setAnalyzeError("");
    try {
      const result = await parseEstablishmentImportFile(file);
      setPreview(result);
      if (!result.records.length) {
        setAnalyzeError(
          "No valid records found. Check column headers and required fields.",
        );
      } else {
        setStep("preview");
      }
    } catch (err) {
      setAnalyzeError(err?.message || "Failed to read file.");
    } finally {
      setAnalyzing(false);
    }
  }

  // ── Import ─────────────────────────────────────────────────
  async function handleImport() {
    if (!preview?.records?.length) return;
    setImporting(true);
    setImportError("");
    try {
      const res = await establishmentsAPI.importBulk(preview.records);
      setImportResult(res.data);
      setStep("done");
      onSuccess?.();
    } catch (err) {
      const msg =
        err.response?.data?.message || "Bulk import failed. Please try again.";
      setImportError(msg);
    } finally {
      setImporting(false);
    }
  }

  // ── One-time credential download ───────────────────────────
  async function handleDownloadCredentials() {
    if (!importResult?.credentialToken) return;
    setDownloadingCreds(true);
    try {
      const res = await establishmentsAPI.downloadCredentials(
        importResult.credentialToken,
      );
      const url = URL.createObjectURL(res.data);
      const a = document.createElement("a");
      a.href = url;
      a.download = `idetect-credentials-${new Date().toISOString().slice(0, 10)}.csv`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
      // Mark token as consumed so the button disables
      setImportResult((prev) => ({ ...prev, credentialToken: null }));
    } catch {
      alert("Credential download failed or link already used.");
    } finally {
      setDownloadingCreds(false);
    }
  }

  // ── Render ─────────────────────────────────────────────────
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-3xl max-h-[90vh] flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 bg-gov-50 rounded-xl flex items-center justify-center">
              <FileSpreadsheet className="w-5 h-5 text-gov-600" />
            </div>
            <div>
              <h2 className="font-heading font-bold text-gray-900 text-lg leading-tight">
                Bulk Import Establishments
              </h2>
              <p className="text-xs text-gray-500">
                Upload a CSV or Excel file — passwords are auto-generated
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        {/* Body */}
        <div className="flex-1 overflow-y-auto px-6 py-5 space-y-5">
          {/* ── Step indicator ── */}
          <div className="flex items-center gap-2 text-xs">
            {[
              { key: "upload", label: "1. Upload" },
              { key: "preview", label: "2. Preview" },
              { key: "done", label: "3. Done" },
            ].map(({ key, label }, i) => (
              <span key={key} className="flex items-center gap-2">
                {i > 0 && <ChevronRight className="w-3 h-3 text-gray-300" />}
                <span
                  className={`font-medium ${
                    step === key
                      ? "text-gov-600"
                      : step === "done" || (step === "preview" && i === 0)
                        ? "text-gray-400 line-through"
                        : "text-gray-400"
                  }`}
                >
                  {label}
                </span>
              </span>
            ))}
          </div>

          {/* ── STEP: Upload ── */}
          {step === "upload" && (
            <>
              {/* Info box */}
              <div className="p-4 bg-blue-50 border border-blue-100 rounded-xl text-sm text-blue-800 space-y-1.5">
                <p className="font-semibold flex items-center gap-1.5">
                  <ShieldCheck className="w-4 h-4" /> How credentials are
                  generated
                </p>
                <ul className="list-disc list-inside space-y-0.5 text-blue-700">
                  <li>
                    <strong>Password</strong> — 12-character random password
                    auto-generated for every row
                  </li>
                  <li>
                    <strong>Email (optional column)</strong> — if blank, a login
                    email is auto-generated from the permit number
                  </li>
                  <li>
                    After import, download the credentials CSV and distribute to
                    each establishment
                  </li>
                </ul>
              </div>

              {/* Drop zone */}
              <div
                className="border-2 border-dashed border-gray-200 rounded-xl p-8 text-center cursor-pointer hover:border-gov-400 hover:bg-gov-50 transition-colors"
                onClick={() => fileInputRef.current?.click()}
                onDrop={handleDrop}
                onDragOver={(e) => e.preventDefault()}
              >
                <Upload className="w-10 h-10 text-gray-300 mx-auto mb-3" />
                <p className="font-medium text-gray-700 text-sm">
                  {file ? (
                    <span className="text-gov-700">{file.name}</span>
                  ) : (
                    "Click to select or drag & drop a file"
                  )}
                </p>
                <p className="text-xs text-gray-400 mt-1">
                  Accepts .csv, .xlsx, .xls
                </p>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept=".csv,.xlsx,.xls"
                  className="hidden"
                  onChange={handleFileChange}
                />
              </div>

              {analyzeError && (
                <div className="flex items-start gap-2 text-sm text-danger-700 bg-danger-50 border border-danger-100 rounded-lg px-4 py-3">
                  <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5" />
                  {analyzeError}
                </div>
              )}

              {/* Template download */}
              <button
                type="button"
                onClick={downloadTemplate}
                className="text-sm text-gov-600 hover:text-gov-700 flex items-center gap-1.5 font-medium"
              >
                <Download className="w-4 h-4" />
                Download CSV template
              </button>

              {/* Required columns */}
              <div className="text-xs text-gray-500 bg-gray-50 rounded-lg p-3 space-y-1">
                <p className="font-medium text-gray-700">Required columns:</p>
                <p>
                  <code className="bg-gray-200 px-1 rounded">
                    business_name
                  </code>{" "}
                  <code className="bg-gray-200 px-1 rounded">
                    business_permit_no
                  </code>{" "}
                  <code className="bg-gray-200 px-1 rounded">owner_name</code>{" "}
                  <code className="bg-gray-200 px-1 rounded">address</code>{" "}
                  <code className="bg-gray-200 px-1 rounded">
                    contact_number
                  </code>
                </p>
                <p className="font-medium text-gray-700 pt-1">
                  Optional columns:
                </p>
                <p>
                  <code className="bg-gray-200 px-1 rounded">email</code>{" "}
                  <code className="bg-gray-200 px-1 rounded">
                    business_permit_expiry
                  </code>{" "}
                  <code className="bg-gray-200 px-1 rounded">
                    contact_person
                  </code>
                </p>
              </div>
            </>
          )}

          {/* ── STEP: Preview ── */}
          {step === "preview" && preview && (
            <>
              {/* Summary cards */}
              <div className="grid grid-cols-3 gap-3">
                {[
                  {
                    label: "Valid Records",
                    value: preview.records.length,
                    color: "text-success-700 bg-success-50",
                  },
                  {
                    label: "Skipped Rows",
                    value: preview.errors.length,
                    color:
                      preview.errors.length > 0
                        ? "text-warning-700 bg-warning-50"
                        : "text-gray-500 bg-gray-50",
                  },
                  {
                    label: "Total Rows",
                    value: preview.totalRows,
                    color: "text-gray-700 bg-gray-50",
                  },
                ].map(({ label, value, color }) => (
                  <div
                    key={label}
                    className={`rounded-xl p-3 text-center ${color}`}
                  >
                    <p className="text-2xl font-bold">{value}</p>
                    <p className="text-xs font-medium mt-0.5">{label}</p>
                  </div>
                ))}
              </div>

              {/* Errors */}
              {preview.errors.length > 0 && (
                <div className="bg-warning-50 border border-warning-100 rounded-xl p-4 space-y-2">
                  <p className="text-sm font-semibold text-warning-800 flex items-center gap-1.5">
                    <AlertCircle className="w-4 h-4" />
                    {preview.errors.length} row(s) will be skipped
                  </p>
                  <div className="max-h-28 overflow-y-auto space-y-1">
                    {preview.errors.map((e, i) => (
                      <p key={i} className="text-xs text-warning-700">
                        Row {e.row}: {e.error}
                      </p>
                    ))}
                  </div>
                </div>
              )}

              {/* Preview table */}
              <div className="overflow-x-auto rounded-xl border border-gray-100">
                <table className="w-full text-xs">
                  <thead className="bg-gray-50 text-gray-600">
                    <tr>
                      {[
                        "Business Name",
                        "Permit No",
                        "Owner",
                        "Contact",
                        "Email (if provided)",
                        "Expiry",
                      ].map((h) => (
                        <th
                          key={h}
                          className="px-3 py-2 text-left font-semibold whitespace-nowrap"
                        >
                          {h}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-50">
                    {preview.records.slice(0, 20).map((r, i) => (
                      <tr key={i} className="hover:bg-gray-50">
                        <td className="px-3 py-2 font-medium text-gray-900 max-w-[160px] truncate">
                          {r.business_name}
                        </td>
                        <td className="px-3 py-2 text-gray-600 font-mono">
                          {r.business_permit_no}
                        </td>
                        <td className="px-3 py-2 text-gray-600">
                          {r.owner_name}
                        </td>
                        <td className="px-3 py-2 text-gray-600">
                          {r.contact_number}
                        </td>
                        <td className="px-3 py-2 text-gray-500 italic">
                          {r.email || (
                            <span className="text-blue-500 not-italic">
                              auto-generated
                            </span>
                          )}
                        </td>
                        <td className="px-3 py-2 text-gray-500">
                          {r.business_permit_expiry || "—"}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
                {preview.records.length > 20 && (
                  <p className="px-3 py-2 text-xs text-gray-400 bg-gray-50 border-t">
                    …and {preview.records.length - 20} more rows not shown
                  </p>
                )}
              </div>

              {importError && (
                <div className="flex items-start gap-2 text-sm text-danger-700 bg-danger-50 border border-danger-100 rounded-lg px-4 py-3">
                  <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5" />
                  {importError}
                </div>
              )}
            </>
          )}

          {/* ── STEP: Done ── */}
          {step === "done" && importResult && (
            <>
              <div className="flex items-center gap-3 p-4 bg-success-50 border border-success-200 rounded-xl">
                <CheckCircle2 className="w-6 h-6 text-success-600 flex-shrink-0" />
                <div>
                  <p className="font-semibold text-success-800 text-sm">
                    {importResult.message}
                  </p>
                  <p className="text-xs text-success-700 mt-0.5">
                    {importResult.summary.inserted} created ·{" "}
                    {importResult.summary.duplicates} duplicates skipped ·{" "}
                    {importResult.summary.invalid} invalid rows
                  </p>
                </div>
              </div>

              {/* Credential download */}
              {importResult.credentialToken && (
                <div className="space-y-3">
                  <div className="flex items-center justify-between">
                    <p className="text-sm font-semibold text-gray-900 flex items-center gap-1.5">
                      <Building2 className="w-4 h-4 text-gov-600" />
                      Generated Credentials
                    </p>
                    <button
                      onClick={handleDownloadCredentials}
                      disabled={downloadingCreds}
                      className="btn-primary text-xs py-1.5 px-3"
                    >
                      {downloadingCreds ? (
                        <Loader2 className="w-3.5 h-3.5 animate-spin" />
                      ) : (
                        <Download className="w-3.5 h-3.5" />
                      )}
                      Download CSV
                    </button>
                  </div>

                  <div className="p-3 bg-amber-50 border border-amber-200 rounded-lg text-xs text-amber-800 flex items-start gap-2">
                    <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5" />
                    <p>
                      <strong>
                        Download now — this link expires in 15 minutes.
                      </strong>{" "}
                      Credentials can only be downloaded once. Distribute them
                      to each establishment so they can log in to the Client
                      Portal.
                    </p>
                  </div>
                </div>
              )}

              {!importResult.credentialToken &&
                importResult.summary?.inserted > 0 && (
                  <div className="p-3 bg-gray-50 border border-gray-200 rounded-lg text-xs text-gray-600">
                    Credential download link was already used or has expired.
                  </div>
                )}

              {/* Import errors from API */}
              {importResult.invalidRows?.length > 0 && (
                <div className="bg-warning-50 border border-warning-100 rounded-xl p-4 space-y-2">
                  <p className="text-sm font-semibold text-warning-800">
                    {importResult.invalidRows.length} row(s) were skipped
                    server-side
                  </p>
                  <div className="max-h-28 overflow-y-auto space-y-1">
                    {importResult.invalidRows.map((e, i) => (
                      <p key={i} className="text-xs text-warning-700">
                        Row {e.row}: {e.error}
                      </p>
                    ))}
                  </div>
                </div>
              )}
            </>
          )}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between px-6 py-4 border-t bg-gray-50 rounded-b-2xl">
          {step === "upload" && (
            <>
              <button
                type="button"
                onClick={onClose}
                className="btn-secondary text-sm"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleAnalyze}
                disabled={!file || analyzing}
                className="btn-primary text-sm"
              >
                {analyzing ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <ChevronRight className="w-4 h-4" />
                )}
                Analyze File
              </button>
            </>
          )}

          {step === "preview" && (
            <>
              <button
                type="button"
                onClick={() => {
                  setStep("upload");
                  setPreview(null);
                }}
                className="btn-secondary text-sm"
              >
                ← Back
              </button>
              <button
                type="button"
                onClick={handleImport}
                disabled={importing || !preview?.records?.length}
                className="btn-primary text-sm"
              >
                {importing ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <Upload className="w-4 h-4" />
                )}
                Import {preview?.records?.length ?? 0} Establishment
                {preview?.records?.length !== 1 ? "s" : ""}
              </button>
            </>
          )}

          {step === "done" && (
            <>
              <button
                type="button"
                onClick={() => {
                  setStep("upload");
                  setFile(null);
                  setPreview(null);
                  setImportResult(null);
                }}
                className="btn-secondary text-sm"
              >
                Import Another File
              </button>
              <button
                type="button"
                onClick={onClose}
                className="btn-primary text-sm"
              >
                Done
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
