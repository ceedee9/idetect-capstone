import { useState, useMemo } from "react";
import {
  Flag,
  AlertTriangle,
  CheckCircle2,
  XCircle,
  Clock,
  Store,
  User,
  AlertCircle,
  RefreshCw,
  MessageSquare,
} from "lucide-react";
import { fraudFlagsAPI } from "../services/api";
import ConfirmModal from "../components/ConfirmModal";
import { fmtDateTime, fmtRelative } from "../utils/date";

function useFraudFlags() {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetch = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await fraudFlagsAPI.list();
      const raw = res.data?.fraud_flags ?? res.data?.flags ?? res.data;
      setData(
        Array.isArray(raw)
          ? raw
          : (Object.values(raw).find((v) => Array.isArray(v)) ?? []),
      );
    } catch (err) {
      setError(err.response?.data?.message || "Failed to load fraud flags.");
    } finally {
      setLoading(false);
    }
  };

  const [init, setInit] = useState(false);
  if (!init) {
    setInit(true);
    fetch();
  }

  return { data, loading, error, refetch: fetch };
}

const STATUS_TABS = [
  { value: "", label: "All" },
  { value: "pending", label: "Pending" },
  { value: "confirmed", label: "Confirmed" },
  { value: "dismissed", label: "Dismissed" },
];

function FlagStatusBadge({ status }) {
  const map = {
    pending:
      "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-yellow-50 text-yellow-700 border border-yellow-200",
    confirmed:
      "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-red-50 text-red-700 border border-red-200",
    dismissed:
      "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-100 text-slate-500",
  };
  const icons = {
    pending: <Clock className="w-3.5 h-3.5" />,
    confirmed: <CheckCircle2 className="w-3.5 h-3.5" />,
    dismissed: <XCircle className="w-3.5 h-3.5" />,
  };
  return (
    <span className={map[status] ?? map.dismissed}>
      {icons[status]} {status ?? "—"}
    </span>
  );
}

export default function FraudFlagsPage() {
  const { data: flags, loading, error, refetch } = useFraudFlags();
  const [statusFilter, setStatusFilter] = useState("");
  const [modal, setModal] = useState(null);
  const [notes, setNotes] = useState("");
  const [actionLoading, setActionLoading] = useState(false);
  const [actionError, setActionError] = useState("");
  const [toast, setToast] = useState(null);

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
    if (!modal) return;
    setActionLoading(true);
    setActionError("");
    try {
      await fraudFlagsAPI.review(modal.flag.id, modal.action, notes);
      showToast(
        `Flag ${modal.action === "confirm" ? "confirmed" : "dismissed"} successfully.`,
      );
      setModal(null);
      setNotes("");
      await refetch();
    } catch (err) {
      setActionError(err.response?.data?.message || "Action failed.");
    } finally {
      setActionLoading(false);
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="p-2.5 bg-red-100 rounded-xl">
            <Flag className="w-6 h-6 text-red-600" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-slate-800">Fraud Flags</h1>
            <p className="text-sm text-slate-500">
              Suspicious ID reports across all registered establishments
            </p>
          </div>
        </div>
        <button
          onClick={refetch}
          disabled={loading}
          className="flex items-center gap-2 px-4 py-2 text-sm font-medium text-slate-600 bg-white border border-slate-200 rounded-lg hover:bg-slate-50"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? "animate-spin" : ""}`} />{" "}
          Refresh
        </button>
      </div>

      {error && (
        <div className="p-4 bg-red-50 text-red-700 rounded-lg border border-red-100">
          <AlertCircle className="w-5 h-5 inline mr-2" />
          {error}
        </div>
      )}

      {/* Summary cards */}
      <div className="grid grid-cols-3 gap-4">
        {[
          {
            label: "Pending Review",
            value: counts.pending,
            color: "bg-yellow-50 text-yellow-700 border border-yellow-100",
          },
          {
            label: "Confirmed",
            value: counts.confirmed,
            color: "bg-red-50 text-red-700 border border-red-100",
          },
          {
            label: "Dismissed",
            value: counts.dismissed,
            color: "bg-slate-50 text-slate-500 border border-slate-100",
          },
        ].map(({ label, value, color }) => (
          <div key={label} className={`rounded-xl p-4 ${color}`}>
            <p className="text-xs font-bold uppercase tracking-wider opacity-70">
              {label}
            </p>
            <p className="font-bold text-2xl mt-1">{loading ? "—" : value}</p>
          </div>
        ))}
      </div>

      {/* Status tabs */}
      <div className="flex gap-1 p-1 bg-slate-100 rounded-lg w-fit">
        {STATUS_TABS.map((tab) => (
          <button
            key={tab.value}
            onClick={() => setStatusFilter(tab.value)}
            className={`px-3 py-1.5 text-sm font-medium rounded-md transition-colors ${
              statusFilter === tab.value
                ? "bg-white text-slate-800 shadow-sm"
                : "text-slate-500 hover:text-slate-700"
            }`}
          >
            {tab.label}{" "}
            <span className="ml-1 text-xs opacity-60">
              ({counts[tab.value] ?? 0})
            </span>
          </button>
        ))}
      </div>

      {/* Flags list */}
      <div className="space-y-3">
        {loading ? (
          <div className="text-center py-12 text-slate-400">
            Loading fraud flags…
          </div>
        ) : filtered.length === 0 ? (
          <div className="text-center py-12 text-slate-400">
            <Flag className="w-10 h-10 mx-auto mb-2 opacity-40" />
            No fraud flags found.
          </div>
        ) : (
          filtered.map((flag) => (
            <div
              key={flag.id}
              className="bg-white rounded-xl border border-slate-200 p-5 hover:shadow-sm transition-shadow"
            >
              <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
                {/* Left: details */}
                <div className="flex items-start gap-4 flex-1 min-w-0">
                  <div
                    className={`w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 ${
                      flag.status === "pending"
                        ? "bg-yellow-50"
                        : flag.status === "confirmed"
                          ? "bg-red-50"
                          : "bg-slate-100"
                    }`}
                  >
                    <AlertTriangle
                      className={`w-5 h-5 ${
                        flag.status === "pending"
                          ? "text-yellow-600"
                          : flag.status === "confirmed"
                            ? "text-red-600"
                            : "text-slate-400"
                      }`}
                    />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap mb-1">
                      <FlagStatusBadge status={flag.status} />
                      <span className="text-xs text-slate-400 font-medium">
                        {fmtRelative(flag.created_at)}
                      </span>
                    </div>

                    <p className="font-mono text-sm font-bold text-slate-900">
                      {flag.id_number_scanned ??
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
                      <div className="flex items-center gap-1.5 mt-1 text-xs font-medium text-blue-600">
                        <User className="w-3.5 h-3.5" />
                        <span>{flag.beneficiary.full_name}</span>
                        <span className="text-slate-400">
                          ({flag.beneficiary_type})
                        </span>
                      </div>
                    )}

                    {flag.notes && (
                      <div className="flex items-start gap-1.5 mt-2 text-xs text-slate-500">
                        <MessageSquare className="w-3.5 h-3.5 text-slate-400 flex-shrink-0 mt-0.5" />
                        <span className="italic">"{flag.notes}"</span>
                      </div>
                    )}

                    {flag.review_notes && (
                      <div className="mt-2 px-3 py-2 bg-slate-50 rounded-lg text-xs text-slate-600">
                        <span className="font-semibold">Review note:</span>{" "}
                        {flag.review_notes}
                      </div>
                    )}
                  </div>
                </div>

                {/* Right: actions */}
                {flag.status === "pending" && (
                  <div className="flex items-center gap-2 flex-shrink-0 sm:flex-col sm:items-end">
                    <button
                      onClick={() => setModal({ flag, action: "confirm" })}
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-red-50 text-red-700 text-xs font-semibold rounded-lg hover:bg-red-100 transition-colors"
                    >
                      <CheckCircle2 className="w-3.5 h-3.5" />
                      Confirm Fraud
                    </button>
                    <button
                      onClick={() => setModal({ flag, action: "dismiss" })}
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-slate-100 text-slate-600 text-xs font-semibold rounded-lg hover:bg-slate-200 transition-colors"
                    >
                      <XCircle className="w-3.5 h-3.5" />
                      Dismiss
                    </button>
                  </div>
                )}
                {flag.status !== "pending" && (
                  <div className="text-xs text-slate-400 font-medium flex-shrink-0">
                    Reviewed {fmtDateTime(flag.reviewed_at)}
                  </div>
                )}
              </div>
            </div>
          ))
        )}
      </div>

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
        description="Confirm this report as legitimate fraud? The beneficiary's status may need to be suspended separately."
        confirmLabel="Confirm Fraud"
        variant="danger"
        loading={actionLoading}
      >
        <div className="mt-1">
          <label className="block text-xs font-medium text-slate-600 mb-1">
            Review notes (optional)
          </label>
          <input
            type="text"
            className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="e.g. ID visually altered, duplicate registration…"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            disabled={actionLoading}
          />
        </div>
        {actionError && (
          <p className="text-sm text-red-600 mt-3">
            <AlertCircle className="w-4 h-4 inline mr-1" />
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
          <label className="block text-xs font-medium text-slate-600 mb-1">
            Review notes (optional)
          </label>
          <input
            type="text"
            className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="e.g. ID verified as authentic, false report…"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            disabled={actionLoading}
          />
        </div>
        {actionError && (
          <p className="text-sm text-red-600 mt-3">
            <AlertCircle className="w-4 h-4 inline mr-1" />
            {actionError}
          </p>
        )}
      </ConfirmModal>

      {/* Toast */}
      {toast && (
        <div className="fixed bottom-6 right-6 bg-slate-800 text-white px-5 py-3 rounded-lg shadow-lg text-sm z-50">
          <CheckCircle2 className="w-4 h-4 inline mr-2" />
          {toast}
        </div>
      )}
    </div>
  );
}
