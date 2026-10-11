import { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import {
  ArrowLeft,
  User,
  Save,
  Upload,
  FileSpreadsheet,
  Download,
  AlertCircle,
  CheckCircle2,
  Loader2,
  Hash,
  MapPin,
  Phone,
  Calendar,
  Mail,
  FileText,
  Accessibility,
} from "lucide-react";
import { beneficiariesAPI } from "../services/api";
import { useAuth } from "../context/AuthContext";
import { parseBeneficiaryImportFile } from "../utils/beneficiaryImport";
import { PDAO_DISABILITY_OPTIONS } from "../constants/disabilityTypes";

const INITIAL = {
  id_number: "",
  first_name: "",
  middle_name: "",
  last_name: "",
  date_of_birth: "",
  disability_type: "",
  address: "",
  contact_number: "",
  email: "",
  notes: "",
};

function FormField({ icon: Icon, label, required, children }) {
  return (
    <div>
      <label className="label flex items-center gap-1.5">
        <Icon className="w-3.5 h-3.5 text-slate-400" />
        {label}
        {required && <span className="text-danger-500">*</span>}
      </label>
      {children}
    </div>
  );
}

export default function AddBeneficiaryPage() {
  const navigate = useNavigate();
  const { user } = useAuth();
  const isOsca = user?.portalRole === "osca_admin";
  const recordLabel = isOsca ? "Senior Citizens" : "PWD Records";
  const registryLabel = isOsca ? "OSCA" : "PDAO";
  const issuingOffice = isOsca ? "OSCA Valenzuela" : "PDAO Valenzuela";
  const idLabel = isOsca ? "OSCA ID Number" : "PWD ID Number";
  const idPlaceholder = isOsca ? "Enter OSCA ID number" : "Enter PWD ID number";
  const raText = isOsca ? "Republic Act 9994" : "Republic Act 10754";
  const beneficiaryTypeLabel = isOsca ? "Senior Citizen" : "PWD";
  const templateFilename = isOsca
    ? "osca-beneficiaries-template.csv"
    : "pdao-beneficiaries-template.csv";
  const [form, setForm] = useState(INITIAL);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);
  const [importFile, setImportFile] = useState(null);
  const [importLoading, setImportLoading] = useState(false);
  const [importError, setImportError] = useState("");
  const [importPreview, setImportPreview] = useState(null);
  const [importResult, setImportResult] = useState(null);
  const [importRowTotal, setImportRowTotal] = useState(0);

  function set(field) {
    return (e) => setForm((f) => ({ ...f, [field]: e.target.value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const beneficiaryType =
        user?.portalRole === "osca_admin" ? "senior_citizen" : "pwd";
      await beneficiariesAPI.create(form, beneficiaryType);
      setSuccess(true);
      setTimeout(() => navigate("/beneficiaries"), 1800);
    } catch (err) {
      const apiErrors = err.response?.data?.errors;
      const msg =
        err.response?.data?.message ||
        apiErrors
          ?.map((e) => `${e.path || e.param || "field"}: ${e.msg}`)
          .join(", ") ||
        "Failed to create beneficiary. Please check the form and try again.";
      setError(msg);
    } finally {
      setLoading(false);
    }
  }

  async function handleAnalyzeImport() {
    if (!importFile) {
      setImportError("Select a CSV or Excel file first.");
      return;
    }

    setImportLoading(true);
    setImportError("");
    setImportResult(null);

    try {
      const analyzed = await parseBeneficiaryImportFile(
        importFile,
        issuingOffice,
      );
      setImportPreview(analyzed);
      if (!analyzed.records.length) {
        setImportError(
          "No valid records found. Check the column names and values.",
        );
      }
    } catch (err) {
      setImportPreview(null);
      setImportError(err?.message || "Failed to analyze file.");
    } finally {
      setImportLoading(false);
    }
  }

  async function handleImportRecords() {
    if (!importPreview?.records?.length) {
      setImportError("Analyze a file with valid rows before importing.");
      return;
    }

    setImportLoading(true);
    setImportRowTotal(importPreview.records.length);
    setImportError("");

    try {
      const res = await beneficiariesAPI.importBulk(importPreview.records);
      setImportResult(res.data?.summary || null);
      setImportError("");
    } catch (err) {
      const msg =
        err.response?.data?.message ||
        "Bulk import failed. Please check your file and try again.";
      setImportError(msg);
    } finally {
      setImportLoading(false);
      setImportRowTotal(0);
    }
  }

  function downloadTemplate() {
    const sampleId = isOsca ? "SC-2026-0001" : "PWD-2026-0001";
    const sampleDate = isOsca ? "1950-01-15" : "1990-01-15";
    const csv = [
      "id_number,full_name,birthdate,issuing_office,validity_start,validity_end,registered_mobile",
      `${sampleId},JUAN DELA CRUZ,${sampleDate},${issuingOffice},2026-01-01,2027-01-01,09171234567`,
    ].join("\n");
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = templateFilename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  if (success)
    return (
      <div className="px-6 lg:px-8 py-8 max-w-2xl mx-auto">
        <div className="card text-center py-14">
          <div className="w-16 h-16 bg-gov-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <CheckCircle2 className="w-8 h-8 text-gov-600" />
          </div>
          <h2 className="font-heading font-bold text-xl text-slate-900">
            Beneficiary Registered!
          </h2>
          <p className="text-slate-500 text-sm mt-2 font-medium">
            {form.first_name} {form.last_name} has been added to the{" "}
            {registryLabel} registry.
          </p>
          <p className="text-slate-400 text-xs mt-1">
            Redirecting to beneficiary list…
          </p>
        </div>
      </div>
    );

  return (
    <div className="px-6 lg:px-8 py-8 max-w-2xl mx-auto space-y-6">
      {/* Breadcrumb */}
      <div className="flex items-center gap-2 text-sm text-slate-400">
        <Link
          to="/beneficiaries"
          className="hover:text-gov-600 flex items-center gap-1 font-semibold"
        >
          <ArrowLeft className="w-4 h-4" /> {recordLabel}
        </Link>
        <span>/</span>
        <span className="text-slate-900 font-semibold">Add Record</span>
      </div>

      {/* Header */}
      <div>
        <h1 className="font-heading font-bold text-2xl text-slate-900">
          Register {beneficiaryTypeLabel}
        </h1>
        <p className="text-slate-500 text-sm mt-1 font-medium">
          Add a new beneficiary to the {registryLabel} registry ({raText})
        </p>
      </div>

      {error && (
        <div className="flex items-start gap-2.5 px-4 py-3 bg-danger-50 border border-danger-100 rounded-xl text-danger-700 text-sm">
          <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5" />
          <span>{error}</span>
        </div>
      )}

      <div className="card space-y-4">
        <h2 className="font-heading font-semibold text-slate-900 text-sm border-b border-slate-50 pb-3">
          Bulk Import (CSV or Excel)
        </h2>
        <p className="text-xs text-slate-500 font-medium">
          Upload a .csv, .xlsx, or .xls file to analyze and import many
          beneficiaries at once.
        </p>
        <div className="grid sm:grid-cols-[1fr_auto_auto_auto] gap-3 items-center">
          <label className="input flex items-center gap-2 cursor-pointer">
            <FileSpreadsheet className="w-4 h-4 text-slate-400" />
            <span className="text-sm text-slate-600 truncate">
              {importFile ? importFile.name : "Choose file"}
            </span>
            <input
              type="file"
              accept=".csv,.xlsx,.xls"
              className="hidden"
              onChange={(e) => {
                setImportFile(e.target.files?.[0] || null);
                setImportPreview(null);
                setImportResult(null);
                setImportError("");
              }}
              disabled={importLoading}
            />
          </label>
          <button
            type="button"
            className="btn-secondary"
            onClick={handleAnalyzeImport}
            disabled={importLoading || !importFile}
          >
            {importLoading ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" /> Analyzing...
              </>
            ) : (
              <>
                <Upload className="w-4 h-4" /> Analyze
              </>
            )}
          </button>
          <button
            type="button"
            className="btn-secondary"
            onClick={downloadTemplate}
            disabled={importLoading}
          >
            <Download className="w-4 h-4" /> Template
          </button>
          <button
            type="button"
            className="btn-primary"
            onClick={handleImportRecords}
            disabled={importLoading || !importPreview?.records?.length}
          >
            {importLoading ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" /> Importing...
              </>
            ) : (
              <>Import Valid Rows</>
            )}
          </button>
        </div>

        {/* Bulk import progress bar */}
        {importLoading && importRowTotal > 0 && (
          <div className="rounded-xl bg-gov-50 border border-gov-100 px-4 py-3 space-y-2">
            <div className="flex items-center justify-between text-xs font-semibold text-gov-700">
              <span>Importing {importRowTotal.toLocaleString()} records…</span>
              <span className="text-gov-500">Please wait</span>
            </div>
            <div className="h-2 rounded-full bg-gov-100 overflow-hidden">
              <div
                className="h-full rounded-full bg-gov-500 animate-pulse"
                style={{ width: "100%" }}
              />
            </div>
            <p className="text-[11px] text-gov-500">
              Large imports may take up to{" "}
              {Math.ceil((importRowTotal / 500) * 2)}–
              {Math.ceil((importRowTotal / 500) * 4)} seconds.
            </p>
          </div>
        )}

        {importPreview && (
          <div className="text-xs text-slate-600 bg-slate-50 border border-slate-100 rounded-xl p-3 space-y-1">
            <p>
              Rows analyzed: <strong>{importPreview.totalRows}</strong>
            </p>
            <p>
              Valid rows: <strong>{importPreview.records.length}</strong>
            </p>
            <p>
              Invalid rows: <strong>{importPreview.errors.length}</strong>
            </p>
            {importPreview.errors.length > 0 && (
              <p className="text-danger-700">
                Sample issue: row {importPreview.errors[0].row} -{" "}
                {importPreview.errors[0].error}
              </p>
            )}
          </div>
        )}

        {importResult && (
          <div className="text-xs text-gov-700 bg-gov-50 border border-gov-100 rounded-xl p-3 space-y-1">
            <p>
              Inserted: <strong>{importResult.inserted}</strong>
            </p>
            <p>
              Duplicates skipped: <strong>{importResult.duplicates}</strong>
            </p>
            <p>
              Invalid skipped: <strong>{importResult.invalid}</strong>
            </p>
          </div>
        )}

        {importError && (
          <div className="flex items-start gap-2 text-sm text-danger-700 bg-danger-50 border border-danger-100 rounded-xl p-3">
            <AlertCircle className="w-4 h-4 mt-0.5" />
            <span>{importError}</span>
          </div>
        )}
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* ID */}
        <div className="card space-y-4">
          <h2 className="font-heading font-semibold text-slate-900 text-sm border-b border-slate-50 pb-3">
            ID Information
          </h2>
          <FormField icon={Hash} label={idLabel} required>
            <input
              type="text"
              className="input font-mono"
              required
              placeholder={idPlaceholder}
              value={form.id_number}
              onChange={set("id_number")}
              disabled={loading}
            />
          </FormField>
        </div>

        {/* Personal info */}
        <div className="card space-y-4">
          <h2 className="font-heading font-semibold text-slate-900 text-sm border-b border-slate-50 pb-3">
            Personal Information
          </h2>

          <div className="grid sm:grid-cols-2 gap-4">
            <FormField icon={User} label="First Name" required>
              <input
                type="text"
                className="input"
                required
                placeholder="Maria"
                value={form.first_name}
                onChange={set("first_name")}
                disabled={loading}
              />
            </FormField>
            <FormField icon={User} label="Middle Name">
              <input
                type="text"
                className="input"
                placeholder="Santos"
                value={form.middle_name}
                onChange={set("middle_name")}
                disabled={loading}
              />
            </FormField>
          </div>

          <FormField icon={User} label="Last Name" required>
            <input
              type="text"
              className="input"
              required
              placeholder="Reyes"
              value={form.last_name}
              onChange={set("last_name")}
              disabled={loading}
            />
          </FormField>

          <FormField icon={Calendar} label="Date of Birth" required>
            <input
              type="date"
              className="input"
              required
              max={
                isOsca
                  ? new Date(
                      new Date().setFullYear(new Date().getFullYear() - 60),
                    )
                      .toISOString()
                      .split("T")[0]
                  : new Date().toISOString().split("T")[0]
              }
              value={form.date_of_birth}
              onChange={set("date_of_birth")}
              disabled={loading}
            />
            {isOsca && (
              <p className="text-xs text-slate-400 mt-1.5 font-medium">
                Beneficiary must be 60 years old or older.
              </p>
            )}
          </FormField>
        </div>

        {/* Contact */}
        <div className="card space-y-4">
          <h2 className="font-heading font-semibold text-slate-900 text-sm border-b border-slate-50 pb-3">
            Contact Details
          </h2>

          <FormField icon={MapPin} label="Home Address" required>
            <textarea
              rows={2}
              className="input resize-none"
              required
              placeholder="House No., Street, Barangay, Valenzuela City"
              value={form.address}
              onChange={set("address")}
              disabled={loading}
            />
          </FormField>

          <div className="grid sm:grid-cols-2 gap-4">
            <FormField icon={Phone} label="Contact Number">
              <input
                type="tel"
                className="input"
                placeholder="09XX-XXX-XXXX"
                value={form.contact_number}
                onChange={set("contact_number")}
                disabled={loading}
              />
            </FormField>
            <FormField icon={Mail} label="Email Address">
              <input
                type="email"
                className="input"
                placeholder="optional@email.com"
                value={form.email}
                onChange={set("email")}
                disabled={loading}
              />
            </FormField>
          </div>
        </div>

        {/* Disability Classification (PDAO only) */}
        {!isOsca && (
          <div className="card space-y-4">
            <h2 className="font-heading font-semibold text-slate-900 text-sm border-b border-slate-50 pb-3">
              Disability Classification
            </h2>
            <FormField icon={Accessibility} label="Disability Type" required>
              <select
                className="input"
                required
                value={form.disability_type}
                onChange={set("disability_type")}
                disabled={loading}
              >
                {PDAO_DISABILITY_OPTIONS.map((opt) => (
                  <option key={opt.value} value={opt.value}>
                    {opt.label}
                  </option>
                ))}
              </select>
            </FormField>
          </div>
        )}

        {/* Notes */}
        <div className="card space-y-4">
          <h2 className="font-heading font-semibold text-slate-900 text-sm border-b border-slate-50 pb-3">
            Additional Notes
          </h2>
          <FormField icon={FileText} label="Notes (optional)">
            <textarea
              rows={3}
              className="input resize-none"
              placeholder="Any relevant information about this beneficiary…"
              value={form.notes}
              onChange={set("notes")}
              disabled={loading}
            />
          </FormField>
        </div>

        {/* Disclaimer */}
        <div className="flex items-start gap-3 p-4 bg-gov-50 border border-gov-100 rounded-2xl text-xs text-gov-700">
          <CheckCircle2 className="w-4 h-4 text-gov-600 flex-shrink-0 mt-0.5" />
          <p>
            By submitting this form, you confirm that the information provided
            is accurate and that this individual qualifies as a{" "}
            {beneficiaryTypeLabel} beneficiary under <strong>{raText}</strong>.
            The record will be immediately active in the iDetect verification
            system.
          </p>
        </div>

        {/* Submit */}
        <div className="flex items-center gap-3 justify-end">
          <Link to="/beneficiaries" className="btn-secondary">
            Cancel
          </Link>
          <button type="submit" disabled={loading} className="btn-primary px-6">
            {loading ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" /> Saving…
              </>
            ) : (
              <>
                <Save className="w-4 h-4" /> Register Beneficiary
              </>
            )}
          </button>
        </div>
      </form>
    </div>
  );
}
