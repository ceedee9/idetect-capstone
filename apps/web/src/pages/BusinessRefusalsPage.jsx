import { useState, useMemo } from "react";
import {
  Scale,
  AlertCircle,
  RefreshCw,
  MessageSquare,
  User,
  Store,
} from "lucide-react";
import { disputesAPI } from "../services/api";
import ConfirmModal from "../components/ConfirmModal";
import StatusBadge from "../components/StatusBadge";
import EmptyState from "../components/EmptyState";
import { fmtDateTime, fmtRelative } from "../utils/date";

function useDisputes() {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const fetch = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await disputesAPI.list();
      const raw = res.data?.data ?? res.data;
      setData(Array.isArray(raw) ? raw : []);
    } catch (err) {
      setError(err.response?.data?.message || "Failed to load disputes.");
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
  { value: "submitted", label: "New" },
  { value: "acknowledged", label: "Acknowledged" },
  { value: "resolved", label: "Resolved" },
  { value: "rejected", label: "Rejected" },
];

export default function BusinessRefusalsPage() {
  const { data: disputes, loading, error, refetch } = useDisputes();
  const [statusFilter, setStatusFilter] = useState("");
  const [selected, setSelected] = useState(null);
  const [modal, setModal] = useState(null);
  const [staffResponse, setStaffResponse] = useState("");
  const [actionLoading, setActionLoading] = useState(false);
  const [actionError, setActionError] = useState("");
  const [toast, setToast] = useState(null);

  const filtered = useMemo(
    () => disputes.filter((d) => !statusFilter || d.status === statusFilter),
    [disputes, statusFilter],
  );

  const counts = useMemo(() => {
    const t = { "": disputes.length };
    STATUS_TABS.forEach((tab) => {
      if (tab.value) t[tab.value] = 0;
    });
    disputes.forEach((d) => {
      if (t[d.status] !== undefined) t[d.status]++;
    });
    return t;
  }, [disputes]);

  function showToast(msg) {
    setToast(msg);
    setTimeout(() => setToast(null), 3500);
  }

  async function handleAction() {
    if (!modal) return;
    setActionLoading(true);
    setActionError("");
    try {
      if (modal.action === "acknowledge") {
        await disputesAPI.acknowledge(modal.dispute.id);
        showToast("Report acknowledged.");
      } else {
        const decision = modal.action === "resolve" ? "resolved" : "rejected";
        await disputesAPI.resolve(modal.dispute.id, decision, staffResponse);
        showToast(`Report ${decision}.`);
      }
      setModal(null);
      setStaffResponse("");
      setSelected(null);
      refetch();
    } catch (err) {
      setActionError(
        err.response?.data?.message ||
          err.response?.data?.error ||
          "Action failed.",
      );
    } finally {
      setActionLoading(false);
    }
  }

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-6 sm:py-8 space-y-6 max-w-7xl mx-auto">
      <div className="flex flex-col sm:flex-row sm:items-start justify-between gap-4">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold leading-tight text-slate-800">
            Business Refusal Reports
          </h1>
          <p className="text-sm text-slate-500 mt-1 leading-relaxed max-w-2xl">
            Beneficiary reports of establishments refusing valid discounts (DOJ
            Opinion compliance)
          </p>
        </div>
        <button
          onClick={refetch}
          disabled={loading}
          className="flex shrink-0 items-center gap-2 px-4 py-2 text-sm font-medium text-slate-600 bg-white border border-slate-200 rounded-lg hover:bg-slate-50 self-start"
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

      <div className="flex gap-1 border-b border-slate-200 w-fit overflow-x-auto">
        {STATUS_TABS.map((tab) => (
          <button
            key={tab.value}
            onClick={() => setStatusFilter(tab.value)}
            className={`px-3 py-2 border-b-2 text-sm font-medium transition-colors ${
              statusFilter === tab.value
                ? "border-gov-600 text-gov-700"
                : "border-transparent text-slate-500 hover:text-slate-700"
            }`}
          >
            {tab.label}{" "}
            <span className="ml-1 font-mono text-[10px] px-1.5 py-0.5 rounded-registry bg-slate-100 text-slate-500">
              ({counts[tab.value] ?? 0})
            </span>
          </button>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
        <div className="lg:col-span-2 space-y-2">
          {loading && !disputes.length ? (
            <div className="text-center py-12 text-slate-400">
              Loading reports…
            </div>
          ) : filtered.length === 0 ? (
            <div className="bg-white border border-slate-200 rounded-registry-lg">
              <EmptyState
                icon={Scale}
                tone="gov"
                title="No refusal reports found"
                description="New reports will appear here when submitted by beneficiaries."
              />
            </div>
          ) : (
            filtered.map((d) => (
              <button
                key={d.id}
                onClick={() => setSelected(d)}
                className={`w-full text-left p-4 rounded-xl border transition-all ${
                  selected?.id === d.id
                    ? "bg-orange-50 border-orange-200 shadow-sm"
                    : "bg-white border-slate-200 hover:border-slate-300"
                }`}
              >
                <div className="flex items-start justify-between mb-2">
                  <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium border bg-orange-50 text-orange-700 border-orange-100">
                    Business Refusal
                  </span>
                  <StatusBadge status={d.status} />
                </div>
                <p className="text-sm font-medium text-slate-800 truncate">
                  <User className="w-3.5 h-3.5 inline mr-1" />
                  {d.beneficiary_name || d.beneficiary_id_number || "Unknown"}
                </p>
                <p className="text-xs text-slate-500 mt-1 truncate">
                  {d.establishment_name && (
                    <>
                      <Store className="w-3 h-3 inline mr-1" />
                      {d.establishment_name} ·{" "}
                    </>
                  )}
                  {fmtRelative(d.submitted_at)}
                </p>
              </button>
            ))
          )}
        </div>

        <div className="lg:col-span-3">
          {selected ? (
            <div className="bg-white rounded-xl border border-slate-200 p-6 space-y-5 sticky top-6">
              <div className="flex items-start justify-between">
                <div>
                  <p className="text-xs text-slate-400 font-mono">
                    Ref: {selected.id.slice(0, 8).toUpperCase()}
                  </p>
                  <h2 className="text-lg font-bold text-slate-800 mt-1">
                    Business Refusal Report
                  </h2>
                </div>
                <StatusBadge status={selected.status} />
              </div>

              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <p className="text-slate-400 text-xs mb-1">Beneficiary</p>
                  <p className="font-medium">
                    {selected.beneficiary_name || selected.beneficiary_id_number || "—"}
                  </p>
                  {selected.beneficiary_name ? (
                    <p className="text-xs text-slate-500">
                      {selected.beneficiary_id_number}
                    </p>
                  ) : (
                    <p className="text-xs text-slate-500">
                      Name withheld. Full identity is held by OSCA/PDAO.
                    </p>
                  )}
                </div>
                <div>
                  <p className="text-slate-400 text-xs mb-1">Establishment</p>
                  <p className="font-medium text-orange-700">
                    {selected.establishment_name || "N/A"}
                  </p>
                </div>
                <div>
                  <p className="text-slate-400 text-xs mb-1">Submitted</p>
                  <p className="font-medium">
                    {fmtDateTime(selected.submitted_at)}
                  </p>
                </div>
                <div>
                  <p className="text-slate-400 text-xs mb-1">
                    Verification Result
                  </p>
                  <p className="font-medium text-green-700">
                    {selected.verification_result || "VALID"}
                  </p>
                </div>
              </div>

              <div className="p-3 bg-orange-50 rounded-lg border border-orange-100">
                <p className="text-xs text-orange-600 font-semibold mb-1">
                  Potential DOJ Opinion Non-Compliance
                </p>
                <p className="text-sm text-orange-800">
                  This beneficiary reports that the establishment refused to
                  honor a valid discount despite system approval.
                </p>
              </div>

              <div>
                <p className="text-xs text-slate-400 mb-1 flex items-center gap-1">
                  <MessageSquare className="w-3.5 h-3.5" /> Beneficiary
                  Statement
                </p>
                <div className="p-3 bg-slate-50 rounded-lg text-sm text-slate-700 whitespace-pre-wrap">
                  {selected.explanation}
                </div>
              </div>

              {selected.staff_response && (
                <div>
                  <p className="text-xs text-slate-400 mb-1">BPLO Response</p>
                  <div className="p-3 bg-green-50 rounded-lg text-sm text-green-800 whitespace-pre-wrap">
                    {selected.staff_response}
                  </div>
                  {selected.handled_by_email && (
                    <p className="text-xs text-slate-400 mt-1">
                      Handled by: {selected.handled_by_email}
                    </p>
                  )}
                </div>
              )}

              <div className="flex gap-3 pt-2 border-t border-slate-100">
                {selected.status === "submitted" && (
                  <button
                    onClick={() =>
                      setModal({ dispute: selected, action: "acknowledge" })
                    }
                    className="flex-1 py-2.5 text-sm font-semibold text-white bg-blue-600 rounded-lg hover:bg-blue-700 transition-colors"
                  >
                    Acknowledge Report
                  </button>
                )}
                {["acknowledged", "under_review"].includes(selected.status) && (
                  <>
                    <button
                      onClick={() => {
                        setStaffResponse("");
                        setModal({ dispute: selected, action: "resolve" });
                      }}
                      className="flex-1 py-2.5 text-sm font-semibold text-white bg-green-600 rounded-lg hover:bg-green-700 transition-colors"
                    >
                      Resolve
                    </button>
                    <button
                      onClick={() => {
                        setStaffResponse("");
                        setModal({ dispute: selected, action: "reject" });
                      }}
                      className="flex-1 py-2.5 text-sm font-semibold text-white bg-red-600 rounded-lg hover:bg-red-700 transition-colors"
                    >
                      Dismiss
                    </button>
                  </>
                )}
              </div>
            </div>
          ) : (
            <div className="bg-white rounded-xl border border-slate-200 p-12 text-center text-slate-400">
              <Scale className="w-12 h-12 mx-auto mb-3 opacity-30" />
              <p className="text-sm">Select a report to view details</p>
            </div>
          )}
        </div>
      </div>

      {modal && (
        <ConfirmModal
          title={
            modal.action === "acknowledge"
              ? "Acknowledge Report"
              : modal.action === "resolve"
                ? "Resolve Report"
                : "Dismiss Report"
          }
          description={
            modal.action === "acknowledge"
              ? `Acknowledge business refusal report for ${modal.dispute.establishment_name || "this establishment"}?`
              : `${modal.action === "resolve" ? "Resolve" : "Dismiss"} this report? Please provide your response.`
          }
          confirmLabel={
            modal.action === "acknowledge"
              ? "Acknowledge"
              : modal.action === "resolve"
                ? "Resolve"
                : "Dismiss"
          }
          variant={modal.action === "reject" ? "danger" : "primary"}
          loading={actionLoading}
          onConfirm={handleAction}
          onClose={() => {
            setModal(null);
            setStaffResponse("");
            setActionError("");
          }}
        >
          {modal.action !== "acknowledge" && (
            <div className="mt-4">
              <label className="block text-sm font-medium text-slate-700 mb-1">
                BPLO Response *
              </label>
              <textarea
                value={staffResponse}
                onChange={(e) => setStaffResponse(e.target.value)}
                rows={4}
                placeholder="Document your findings and actions taken..."
                className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>
          )}
          {actionError && (
            <p className="text-sm text-red-600 mt-2">{actionError}</p>
          )}
        </ConfirmModal>
      )}

      {toast && (
        <div className="fixed bottom-6 right-6 bg-slate-800 text-white px-5 py-3 rounded-lg shadow-lg text-sm z-50">
          <CheckCircle2 className="w-4 h-4 inline mr-2" />
          {toast}
        </div>
      )}
    </div>
  );
}
