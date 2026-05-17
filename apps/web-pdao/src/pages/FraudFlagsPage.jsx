import { useState, useEffect, useMemo } from "react";
import { Link } from "react-router-dom";
import {
  Flag,
  AlertTriangle,
  CheckCircle2,
  XCircle,
  Store,
  User,
  AlertCircle,
  RefreshCw,
  MessageSquare,
  X,
  Eye,
  RotateCcw,
  Keyboard,
} from "lucide-react";
import { fraudFlagsAPI, staffAlertsAPI } from "../services/api";
import ConfirmModal from "../components/ConfirmModal";
import { fmtDateTime, fmtRelative } from "../utils/date";

// Fetches a protected image URL using the staff JWT and returns a blob URL
// safe to use in <img src>. Revokes the blob URL on cleanup.
function useAuthImage(url) {
  const [blobUrl, setBlobUrl] = useState(null);
  useEffect(() => {
    if (!url) {
      setBlobUrl(null);
      return;
    }
    let cancelled = false;
    const token = localStorage.getItem("pdao_token");
    fetch(url, token ? { headers: { Authorization: `Bearer ${token}` } } : {})
      .then((r) => {
        if (!r.ok) throw new Error("Failed to load image");
        return r.blob();
      })
      .then((blob) => {
        if (!cancelled) setBlobUrl(URL.createObjectURL(blob));
      })
      .catch(() => {
        if (!cancelled) setBlobUrl(null);
      });
    return () => {
      cancelled = true;
    };
  }, [url]);
  useEffect(() => {
    return () => {
      if (blobUrl) URL.revokeObjectURL(blobUrl);
    };
  }, [blobUrl]);
  return blobUrl;
}

function extractFlags(data) {
  if (!data) return [];
  if (Array.isArray(data)) return data;
  for (const key of ["fraud_flags", "flags", "data", "rows", "results"]) {
    if (Array.isArray(data[key])) return data[key];
  }
  const first = Object.values(data).find((v) => Array.isArray(v));
  return first ?? [];
}

function FlagStatusBadge({ status }) {
  const map = {
    pending:
      "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-warn-50 text-warn-700 border border-warn-100",
    confirmed:
      "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-danger-50 text-danger-700 border border-danger-100",
    dismissed:
      "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-100 text-slate-500",
  };
  return <span className={map[status] ?? map.dismissed}>{status ?? "—"}</span>;
}

const STATUS_TABS = [
  { value: "", label: "All" },
  { value: "pending", label: "Pending" },
  { value: "confirmed", label: "Confirmed" },
  { value: "dismissed", label: "Dismissed" },
];

export default function FraudFlagsPage() {
  const [flags, setFlags] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [statusFilter, setStatusFilter] = useState("");
  const [modal, setModal] = useState(null);
  const [notes, setNotes] = useState("");
  const [actionLoading, setActionLoading] = useState(false);
  const [actionError, setActionError] = useState("");
  const [toast, setToast] = useState(null);
  const [selectedFlag, setSelectedFlag] = useState(null);

  // Fetches the flag image via the authenticated /api/uploads/* route.
  const flagImageUrl = useAuthImage(selectedFlag?.image_path ?? null);

  async function loadFlags() {
    setLoading(true);
    setError(null);
    try {
      const res = await fraudFlagsAPI.list();
      setFlags(extractFlags(res.data));
    } catch (err) {
      setError(
        err.response?.data?.error ||
          err.response?.data?.message ||
          "Failed to load fraud flags.",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    loadFlags();
  }, []);

  // Staff alerts (auto-suspend notifications)
  const [alerts, setAlerts] = useState([]);
  useEffect(() => {
    staffAlertsAPI
      .list()
      .then((res) => setAlerts(res.data?.alerts ?? []))
      .catch(() => {});
  }, []);

  async function handleMarkAllRead() {
    await staffAlertsAPI.markAllRead().catch(() => {});
    setAlerts((prev) => prev.map((a) => ({ ...a, is_read: true })));
  }

  const filtered = useMemo(
    () => flags.filter((f) => !statusFilter || f.status === statusFilter),
    [flags, statusFilter],
  );

  const counts = useMemo(() => {
    const t = { "": flags.length, pending: 0, confirmed: 0, dismissed: 0 };
    flags.forEach((f) => {
      if (t[f.status] !== undefined) t[f.status]++;
    });
    return t;
  }, [flags]);

  function showToast(msg) {
    setToast(msg);
    setTimeout(() => setToast(null), 3500);
  }

  async function handleAction() {
    setActionLoading(true);
    setActionError("");
    try {
      if (modal.action === "restore") {
        await fraudFlagsAPI.restore(modal.flag.id, notes);
        showToast(
          "Beneficiary restored to active. ID verifications will now return VALID.",
        );
      } else {
        await fraudFlagsAPI.review(modal.flag.id, modal.action, notes);
        showToast(
          `Flag ${modal.action === "confirm" ? "confirmed — ID blocked as fraudulent" : "dismissed"} successfully.`,
        );
      }
      setModal(null);
      setNotes("");
      await loadFlags();
    } catch (err) {
      setActionError(err.response?.data?.message || "Action failed.");
    } finally {
      setActionLoading(false);
    }
  }

  return (
    <div className="px-6 lg:px-8 py-8 max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="font-heading font-bold text-2xl text-slate-900">
            Fraud Flags
          </h1>
          <p className="text-slate-500 text-sm mt-0.5 font-medium">
            Suspicious PWD ID reports from registered establishments
          </p>
        </div>
        <button
          onClick={loadFlags}
          disabled={loading}
          className="btn-secondary self-start"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? "animate-spin" : ""}`} />
          Refresh
        </button>
      </div>

      {error && (
        <div className="flex items-center gap-2.5 px-4 py-3 bg-danger-50 border border-danger-100 rounded-xl text-danger-700 text-sm">
          <AlertCircle className="w-4 h-4 flex-shrink-0" />
          {error}
        </div>
      )}

      {/* Staff alerts — auto-suspend notifications */}
      {alerts.filter((a) => !a.is_read).length > 0 && (
        <div className="space-y-2">
          {alerts
            .filter((a) => !a.is_read)
            .map((alert) => (
              <div
                key={alert.id}
                className="flex items-start gap-3 px-4 py-3 bg-amber-50 border border-amber-200 rounded-xl text-sm text-amber-800"
              >
                <AlertTriangle className="w-4 h-4 flex-shrink-0 mt-0.5 text-amber-600" />
                <div className="flex-1">
                  <p className="font-semibold">{alert.title}</p>
                  <p className="text-amber-700 mt-0.5">{alert.body}</p>
                  <p className="text-amber-500 text-xs mt-1">
                    {fmtRelative(alert.created_at)}
                  </p>
                </div>
              </div>
            ))}
          <button
            onClick={handleMarkAllRead}
            className="text-xs text-amber-700 underline hover:text-amber-900"
          >
            Mark all read
          </button>
        </div>
      )}

      {/* Summary cards */}
      <div className="grid grid-cols-3 gap-4">
        {[
          {
            label: "Pending Review",
            value: counts.pending,
            cls: "bg-warn-50 text-warn-700 border border-warn-100",
          },
          {
            label: "Confirmed",
            value: counts.confirmed,
            cls: "bg-danger-50 text-danger-700 border border-danger-100",
          },
          {
            label: "Dismissed",
            value: counts.dismissed,
            cls: "bg-slate-50 text-slate-500 border border-slate-100",
          },
        ].map(({ label, value, cls }) => (
          <div key={label} className={`rounded-2xl p-4 ${cls}`}>
            <p className="text-xs font-bold uppercase tracking-wider opacity-70">
              {label}
            </p>
            <p className="font-heading font-bold text-2xl mt-1">
              {loading ? "—" : value}
            </p>
          </div>
        ))}
      </div>

      {/* Status tabs */}
      <div className="flex items-center gap-1 bg-slate-100 p-1 rounded-2xl w-fit">
        {STATUS_TABS.map((tab) => (
          <button
            key={tab.value}
            onClick={() => setStatusFilter(tab.value)}
            className={`px-4 py-1.5 rounded-xl text-sm font-semibold transition-all duration-150 flex items-center gap-1.5
              ${statusFilter === tab.value ? "bg-white text-slate-900 shadow-card" : "text-slate-500 hover:text-slate-800"}`}
          >
            {tab.label}
            {counts[tab.value] > 0 && (
              <span
                className={`text-xs px-1.5 py-0.5 rounded-full font-bold
                ${statusFilter === tab.value ? "bg-gov-100 text-gov-700" : "bg-slate-200 text-slate-500"}`}
              >
                {counts[tab.value]}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Flags list */}
      <div className="space-y-3">
        {loading ? (
          [...Array(4)].map((_, i) => (
            <div key={i} className="card">
              <div className="skeleton h-20 w-full rounded-xl" />
            </div>
          ))
        ) : filtered.length === 0 ? (
          <div className="card text-center py-14">
            <Flag className="w-10 h-10 text-slate-200 mx-auto mb-3" />
            <p className="text-sm font-semibold text-slate-500">
              No fraud flags found
            </p>
            <p className="text-xs text-slate-400 mt-1">
              {statusFilter
                ? "No flags with this status."
                : "No fraud flags have been submitted yet."}
            </p>
          </div>
        ) : (
          filtered.map((flag) => (
            <div
              key={flag.id}
              onClick={() => setSelectedFlag(flag)}
              className="card hover:shadow-card-md transition-shadow duration-200 cursor-pointer"
            >
              <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
                <div className="flex items-start gap-4 flex-1 min-w-0">
                  <div
                    className={`w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0
                    ${flag.status === "pending" ? "bg-warn-50" : flag.status === "confirmed" ? "bg-danger-50" : "bg-slate-100"}`}
                  >
                    <AlertTriangle
                      className={`w-5 h-5 ${flag.status === "pending" ? "text-warn-600" : flag.status === "confirmed" ? "text-danger-600" : "text-slate-400"}`}
                    />
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap mb-1">
                      <FlagStatusBadge status={flag.status} />
                      {flag.manually_entered && (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-yellow-50 border border-yellow-200 rounded-full text-[10px] font-semibold text-yellow-700">
                          <Keyboard className="w-2.5 h-2.5" />
                          Manual Entry
                        </span>
                      )}
                      <span className="text-xs text-slate-400 font-medium">
                        {fmtRelative(flag.created_at)}
                      </span>
                    </div>
                    <p className="font-mono text-sm font-bold text-slate-900">
                      {flag.id_number_flagged ??
                        flag.beneficiary?.id_number ??
                        "Unknown ID"}
                    </p>
                    <div className="flex items-center gap-1.5 mt-1.5 text-xs text-slate-500 font-medium">
                      <Store className="w-3.5 h-3.5 text-slate-400" />
                      <span>
                        Flagged by:{" "}
                        {flag.establishment?.business_name ??
                          `Establishment #${flag.establishment_id}`}
                      </span>
                    </div>
                    {flag.beneficiary && (
                      <div className="flex items-center gap-1.5 mt-1 text-xs font-medium">
                        <User className="w-3.5 h-3.5 text-gov-500" />
                        <Link
                          to={`/beneficiaries/${flag.beneficiary.id}`}
                          className="text-gov-600 hover:underline"
                        >
                          {flag.beneficiary.first_name}{" "}
                          {flag.beneficiary.last_name}
                        </Link>
                      </div>
                    )}
                    {flag.notes && (
                      <div className="flex items-start gap-1.5 mt-2 text-xs text-slate-500">
                        <MessageSquare className="w-3.5 h-3.5 text-slate-400 flex-shrink-0 mt-0.5" />
                        <span className="italic">"{flag.notes}"</span>
                      </div>
                    )}
                    {flag.review_notes && (
                      <div className="mt-2 px-3 py-2 bg-slate-50 rounded-xl text-xs text-slate-600">
                        <span className="font-semibold">Review note:</span>{" "}
                        {flag.review_notes}
                      </div>
                    )}
                  </div>
                </div>

                {flag.status === "pending" ? (
                  <div className="flex items-center gap-2 flex-shrink-0 sm:flex-col sm:items-end">
                    <button
                      onClick={() => setModal({ flag, action: "confirm" })}
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-danger-50 text-danger-700 text-xs font-semibold rounded-xl hover:bg-danger-100 transition-colors"
                    >
                      <CheckCircle2 className="w-3.5 h-3.5" />
                      Confirm Fraud
                    </button>
                    <button
                      onClick={() => setModal({ flag, action: "dismiss" })}
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-slate-100 text-slate-600 text-xs font-semibold rounded-xl hover:bg-slate-200 transition-colors"
                    >
                      <XCircle className="w-3.5 h-3.5" />
                      Dismiss
                    </button>
                  </div>
                ) : (
                  <div className="flex flex-col items-end gap-2 flex-shrink-0">
                    <div className="text-xs text-slate-400 font-medium">
                      Reviewed {fmtDateTime(flag.reviewed_at)}
                    </div>
                    {flag.status === "confirmed" && (
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          setModal({ flag, action: "restore" });
                        }}
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-emerald-50 text-emerald-700 text-xs font-semibold rounded-xl hover:bg-emerald-100 transition-colors"
                      >
                        <RotateCcw className="w-3.5 h-3.5" />
                        Restore to Active
                      </button>
                    )}
                  </div>
                )}
                <Eye className="w-4 h-4 text-slate-300 flex-shrink-0 self-center" />
              </div>
            </div>
          ))
        )}
      </div>

      {/* REQ-2.6.2: Flag Detail Drawer */}
      {selectedFlag && (
        <div className="fixed inset-0 z-40 flex justify-end">
          <div
            className="flex-1 bg-black/30"
            onClick={() => setSelectedFlag(null)}
          />
          <div className="w-full max-w-lg bg-white shadow-2xl flex flex-col overflow-hidden">
            {/* Drawer Header */}
            <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100">
              <div className="flex items-center gap-3">
                <FlagStatusBadge status={selectedFlag.status} />
                <div>
                  <p className="text-xs text-slate-400 uppercase tracking-wide font-semibold">
                    Reference
                  </p>
                  <span className="font-mono font-bold text-slate-900 text-sm">
                    {selectedFlag.id
                      .replace(/-/g, "")
                      .slice(0, 12)
                      .toUpperCase()}
                  </span>
                </div>
              </div>
              <button
                onClick={() => setSelectedFlag(null)}
                className="p-1.5 rounded-xl hover:bg-slate-100"
              >
                <X className="w-5 h-5 text-slate-500" />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto p-6 space-y-5">
              {/* Captured ID Image */}
              <section>
                <h3 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">
                  Captured ID Image
                </h3>
                {selectedFlag.image_path ? (
                  <img
                    src={flagImageUrl ?? ""}
                    alt="Captured ID"
                    className="w-full rounded-xl border border-slate-200 object-contain max-h-52"
                  />
                ) : (
                  <div className="w-full h-28 rounded-xl border-2 border-dashed border-slate-200 flex items-center justify-center text-slate-400 text-xs gap-2">
                    <Eye className="w-4 h-4" /> No image captured
                  </div>
                )}
              </section>

              {/* Verification Outcome & Timestamp */}
              <section>
                <h3 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">
                  Verification Details
                </h3>
                <div className="bg-slate-50 rounded-xl p-4 space-y-2.5 text-sm">
                  <div className="flex justify-between">
                    <span className="text-slate-500">Outcome</span>
                    <span className="font-semibold capitalize">
                      {selectedFlag.verification_outcome ?? "—"}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500">Transaction Time</span>
                    <span className="font-semibold">
                      {fmtDateTime(
                        selectedFlag.transaction_timestamp ??
                          selectedFlag.flagged_at,
                      )}
                    </span>
                  </div>
                  {selectedFlag.ocr_confidence_score != null && (
                    <div className="flex justify-between">
                      <span className="text-slate-500">OCR Confidence</span>
                      <span className="font-semibold">
                        {selectedFlag.ocr_confidence_score}%
                      </span>
                    </div>
                  )}
                  {selectedFlag.manually_entered && (
                    <p className="text-xs text-warn-600 font-semibold pt-1">
                      ⚠ ID number was manually entered (not scanned)
                    </p>
                  )}
                </div>
              </section>

              {/* OCR Extracted Data */}
              {selectedFlag.ocr_raw_text && (
                <section>
                  <h3 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">
                    OCR Extracted Data
                  </h3>
                  <pre className="bg-slate-50 border border-slate-200 rounded-xl p-4 text-xs text-slate-600 whitespace-pre-wrap font-mono max-h-40 overflow-y-auto">
                    {selectedFlag.ocr_raw_text}
                  </pre>
                </section>
              )}

              {/* Establishment Identifier */}
              <section>
                <h3 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">
                  Establishment
                </h3>
                <div className="bg-slate-50 rounded-xl p-4 space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-slate-500">Name</span>
                    <span className="font-semibold">
                      {selectedFlag.establishment?.business_name ?? "—"}
                    </span>
                  </div>
                  <div className="flex justify-between gap-4">
                    <span className="text-slate-500 flex-shrink-0">ID</span>
                    <span className="font-mono text-xs text-slate-500 truncate">
                      {selectedFlag.establishment_id}
                    </span>
                  </div>
                </div>
              </section>

              {/* Reason for Flagging */}
              {selectedFlag.notes && (
                <section>
                  <h3 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">
                    Reason for Flagging
                  </h3>
                  <p className="text-sm text-slate-700 bg-warn-50 border border-warn-100 rounded-xl px-4 py-3 italic">
                    "{selectedFlag.notes}"
                  </p>
                </section>
              )}

              {/* Supplementary notice */}
              {selectedFlag.is_supplementary && (
                <div className="bg-blue-50 border border-blue-100 rounded-xl px-4 py-3 text-xs text-blue-700 font-medium">
                  ℹ This is a supplementary report linked to an existing active
                  investigation.
                </div>
              )}

              {/* Review notes */}
              {selectedFlag.review_notes && (
                <section>
                  <h3 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">
                    Review Notes
                  </h3>
                  <p className="text-sm text-slate-700 bg-slate-50 rounded-xl px-4 py-3">
                    {selectedFlag.review_notes}
                  </p>
                </section>
              )}
            </div>

            {/* Drawer Footer Actions */}
            {selectedFlag.status === "pending" && (
              <div className="px-6 py-4 border-t border-slate-100 flex gap-3">
                <button
                  onClick={() =>
                    setModal({ flag: selectedFlag, action: "confirm" })
                  }
                  className="flex-1 inline-flex items-center justify-center gap-1.5 px-4 py-2.5 bg-danger-600 text-white text-sm font-semibold rounded-xl hover:bg-danger-700 transition-colors"
                >
                  <CheckCircle2 className="w-4 h-4" /> Confirm Fraud
                </button>
                <button
                  onClick={() =>
                    setModal({ flag: selectedFlag, action: "dismiss" })
                  }
                  className="flex-1 inline-flex items-center justify-center gap-1.5 px-4 py-2.5 bg-slate-100 text-slate-700 text-sm font-semibold rounded-xl hover:bg-slate-200 transition-colors"
                >
                  <XCircle className="w-4 h-4" /> Dismiss
                </button>
              </div>
            )}
            {selectedFlag.status === "confirmed" && (
              <div className="px-6 py-4 border-t border-slate-100">
                <button
                  onClick={() =>
                    setModal({ flag: selectedFlag, action: "restore" })
                  }
                  className="w-full inline-flex items-center justify-center gap-2 px-4 py-2.5 bg-emerald-600 text-white text-sm font-semibold rounded-xl hover:bg-emerald-700 transition-colors"
                >
                  <RotateCcw className="w-4 h-4" /> Restore to Active (Dispute
                  Resolved)
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Confirm fraud modal */}
      <ConfirmModal
        open={modal?.action === "confirm"}
        onClose={() => {
          setModal(null);
          setActionError("");
          setNotes("");
        }}
        onConfirm={handleAction}
        title="Confirm Fraud Flag"
        description="Mark this report as confirmed fraud? The beneficiary's ID will be immediately blocked — future verifications will return INVALID."
        confirmLabel="Confirm Fraud"
        variant="danger"
        loading={actionLoading}
      >
        <div className="mt-1">
          <label className="label text-xs">Review notes (optional)</label>
          <input
            type="text"
            className="input text-sm"
            placeholder="e.g. ID visually altered, unregistered ID number…"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            disabled={actionLoading}
          />
        </div>
        {actionError && (
          <p className="text-sm text-danger-600 flex items-center gap-1.5 mt-3">
            <AlertCircle className="w-4 h-4" />
            {actionError}
          </p>
        )}
      </ConfirmModal>

      {/* Dismiss modal */}
      <ConfirmModal
        open={modal?.action === "dismiss"}
        onClose={() => {
          setModal(null);
          setActionError("");
          setNotes("");
        }}
        onConfirm={handleAction}
        title="Dismiss Flag"
        description="Mark this fraud flag as dismissed? This indicates the report was investigated and found to be unfounded."
        confirmLabel="Dismiss"
        variant="primary"
        loading={actionLoading}
      >
        <div className="mt-1">
          <label className="label text-xs">Review notes (optional)</label>
          <input
            type="text"
            className="input text-sm"
            placeholder="e.g. PWD ID verified as authentic, false report…"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            disabled={actionLoading}
          />
        </div>
        {actionError && (
          <p className="text-sm text-danger-600 flex items-center gap-1.5 mt-3">
            <AlertCircle className="w-4 h-4" />
            {actionError}
          </p>
        )}
      </ConfirmModal>

      {/* Restore modal */}
      <ConfirmModal
        open={modal?.action === "restore"}
        onClose={() => {
          setModal(null);
          setActionError("");
          setNotes("");
        }}
        onConfirm={handleAction}
        title="Restore Beneficiary to Active"
        description="A successful dispute has been filed? This will restore the beneficiary's ID to active status — future verifications will return VALID again."
        confirmLabel="Restore to Active"
        variant="primary"
        loading={actionLoading}
      >
        <div className="mt-1">
          <label className="label text-xs">
            Dispute resolution notes (optional)
          </label>
          <input
            type="text"
            className="input text-sm"
            placeholder="e.g. Identity confirmed via in-person interview, dispute resolved…"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            disabled={actionLoading}
          />
        </div>
        {actionError && (
          <p className="text-sm text-danger-600 flex items-center gap-1.5 mt-3">
            <AlertCircle className="w-4 h-4" />
            {actionError}
          </p>
        )}
      </ConfirmModal>

      {/* Toast */}
      {toast && (
        <div
          className="fixed bottom-6 right-6 z-50 px-4 py-3 rounded-2xl shadow-card-lg text-sm font-semibold flex items-center gap-2 bg-gov-700 text-white"
          style={{ animation: "slideUp 0.2s ease-out" }}
        >
          <CheckCircle2 className="w-4 h-4" />
          {toast}
        </div>
      )}
    </div>
  );
}
