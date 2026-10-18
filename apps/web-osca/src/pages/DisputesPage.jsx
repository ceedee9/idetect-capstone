import { useState, useMemo } from "react";
import {
  Scale,
  Clock,
  CheckCircle2,
  XCircle,
  AlertCircle,
  Eye,
  RefreshCw,
  MessageSquare,
  User,
  Store,
  FileText,
} from "lucide-react";
import { disputesAPI } from "../services/api";
import ConfirmModal from "../components/ConfirmModal";
import { fmtDateTime, fmtRelative } from "../utils/date";
import { useAuth } from "../context/AuthContext";

// Open a protected document by fetching it with the staff JWT and creating
// a temporary blob URL. The blob URL is revoked after 60 s to free memory.
async function openAuthDocument(url) {
  try {
    const token = localStorage.getItem("osca_token");
    const res = await fetch(
      url,
      token ? { headers: { Authorization: `Bearer ${token}` } } : {},
    );
    if (!res.ok) throw new Error("Document not accessible");
    const blob = await res.blob();
    const blobUrl = URL.createObjectURL(blob);
    window.open(blobUrl, "_blank");
    setTimeout(() => URL.revokeObjectURL(blobUrl), 60_000);
  } catch {
    alert("Could not open document. Please try again.");
  }
}

// ── Data hook ─────────────────────────────────────────────────────────────────
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

// ── Constants ─────────────────────────────────────────────────────────────────
const STATUS_TABS = [
  { value: "", label: "All" },
  { value: "submitted", label: "New" },
  { value: "acknowledged", label: "Acknowledged" },
  { value: "under_review", label: "Under Review" },
  { value: "resolved", label: "Resolved" },
  { value: "rejected", label: "Rejected" },
];

const DISPUTE_TYPE_LABELS = {
  wrong_denial: "Wrong Denial",
  unauthorized_use: "Unauthorized Use",
  business_refusal: "Business Refusal",
  incorrect_db_info: "Incorrect DB Info",
};

// ── Status badge ──────────────────────────────────────────────────────────────
function StatusBadge({ status }) {
  const map = {
    submitted:
      "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-blue-50 text-blue-700 border border-blue-100",
    acknowledged:
      "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-accent-50 text-accent-700 border border-accent-100",
    under_review:
      "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-yellow-50 text-yellow-700 border border-yellow-100",
    resolved:
      "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-green-50 text-green-700 border border-green-100",
    rejected:
      "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-danger-50 text-danger-700 border border-danger-100",
  };
  const icons = {
    submitted: <Clock className="w-3.5 h-3.5" />,
    acknowledged: <Eye className="w-3.5 h-3.5" />,
    under_review: <AlertCircle className="w-3.5 h-3.5" />,
    resolved: <CheckCircle2 className="w-3.5 h-3.5" />,
    rejected: <XCircle className="w-3.5 h-3.5" />,
  };
  return (
    <span className={map[status] ?? map.submitted}>
      {icons[status]} {status?.replace("_", " ") ?? "—"}
    </span>
  );
}

function TypeBadge({ type }) {
  const map = {
    wrong_denial: "bg-purple-50 text-purple-700 border-purple-100",
    unauthorized_use: "bg-red-50 text-red-700 border-red-100",
    business_refusal: "bg-orange-50 text-orange-700 border-orange-100",
    incorrect_db_info: "bg-cyan-50 text-cyan-700 border-cyan-100",
  };
  return (
    <span
      className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium border ${map[type] ?? "bg-slate-50 text-slate-600"}`}
    >
      {DISPUTE_TYPE_LABELS[type] ?? type}
    </span>
  );
}

// ── SLA indicator ─────────────────────────────────────────────────────────────
function SlaIndicator({ dispute }) {
  if (dispute.status === "resolved" || dispute.status === "rejected")
    return null;
  const submitted = new Date(dispute.submitted_at);
  const now = new Date();
  const hoursElapsed = (now - submitted) / (1000 * 60 * 60);

  if (dispute.status === "submitted" && hoursElapsed > 24) {
    return (
      <span className="text-xs text-danger-600 font-semibold">
        ⚠ SLA Overdue (24h ack)
      </span>
    );
  }
  if (
    ["acknowledged", "under_review"].includes(dispute.status) &&
    hoursElapsed > 72
  ) {
    return (
      <span className="text-xs text-danger-600 font-semibold">
        ⚠ SLA Overdue (72h resolve)
      </span>
    );
  }
  return null;
}

// ── Main page ─────────────────────────────────────────────────────────────────
export default function DisputesPage() {
  const { data: disputes, loading, error, refetch } = useDisputes();
  const [statusFilter, setStatusFilter] = useState("");
  const [selected, setSelected] = useState(null);
  const [modal, setModal] = useState(null); // { dispute, action: 'acknowledge'|'resolve'|'reject' }
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

  const { user } = useAuth();

  async function handleClaim(claim) {
    try {
      if (claim) {
        await disputesAPI.claim(selected.id);
        showToast("Dispute claimed.");
      } else {
        await disputesAPI.release(selected.id);
        showToast("Dispute released.");
      }
      setSelected((prev) => ({
        ...prev,
        claimed_by_email: claim ? user?.email : null,
      }));
      refetch();
    } catch (err) {
      showToast(
        err.response?.data?.error ||
          err.response?.data?.message ||
          "Action failed.",
      );
    }
  }

  async function handleAction() {
    if (!modal) return;
    setActionLoading(true);
    setActionError("");
    try {
      if (modal.action === "acknowledge") {
        await disputesAPI.acknowledge(modal.dispute.id);
        showToast("Dispute acknowledged successfully.");
      } else {
        const decision = modal.action === "resolve" ? "resolved" : "rejected";
        await disputesAPI.resolve(modal.dispute.id, decision, staffResponse);
        showToast(`Dispute ${decision} successfully.`);
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

  // ── Render ────────────────────────────────────────────────────────────────
  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="p-2.5 bg-purple-100 rounded-xl">
            <Scale className="w-6 h-6 text-purple-600" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-slate-800">
              Dispute Resolution
            </h1>
            <p className="text-sm text-slate-500">
              Review and resolve beneficiary disputes (Senior Citizens)
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

      {/* Error */}
      {error && (
        <div className="p-4 bg-danger-50 text-danger-700 rounded-lg border border-danger-100">
          <AlertCircle className="w-5 h-5 inline mr-2" />
          {error}
        </div>
      )}

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

      {/* Two-column layout: list + detail */}
      <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
        {/* List */}
        <div className="lg:col-span-2 space-y-2">
          {loading && !disputes.length ? (
            <div className="text-center py-12 text-slate-400">
              Loading disputes…
            </div>
          ) : filtered.length === 0 ? (
            <div className="text-center py-12 text-slate-400">
              <Scale className="w-10 h-10 mx-auto mb-2 opacity-40" />
              No disputes found.
            </div>
          ) : (
            filtered.map((d) => (
              <button
                key={d.id}
                onClick={() => setSelected(d)}
                className={`w-full text-left p-4 rounded-xl border transition-all ${
                  selected?.id === d.id
                    ? "bg-purple-50 border-purple-200 shadow-sm"
                    : "bg-white border-slate-200 hover:border-slate-300"
                }`}
              >
                <div className="flex items-start justify-between mb-2">
                  <TypeBadge type={d.dispute_type} />
                  <StatusBadge status={d.status} />
                </div>
                <p className="text-sm font-medium text-slate-800 truncate">
                  <User className="w-3.5 h-3.5 inline mr-1" />
                  {d.beneficiary_name || "Unknown"}
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
                <SlaIndicator dispute={d} />
              </button>
            ))
          )}
        </div>

        {/* Detail panel */}
        <div className="lg:col-span-3">
          {selected ? (
            <div className="bg-white rounded-xl border border-slate-200 p-6 space-y-5 sticky top-6">
              <div className="flex items-start justify-between">
                <div>
                  <p className="text-xs text-slate-400 font-mono">
                    Ref: {selected.id.slice(0, 8).toUpperCase()}
                  </p>
                  <h2 className="text-lg font-bold text-slate-800 mt-1">
                    {DISPUTE_TYPE_LABELS[selected.dispute_type]}
                  </h2>
                </div>
                <StatusBadge status={selected.status} />
              </div>

              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <p className="text-slate-400 text-xs mb-1">Beneficiary</p>
                  <p className="font-medium">
                    {selected.beneficiary_name || "—"}
                  </p>
                  <p className="text-xs text-slate-500">
                    {selected.beneficiary_id_number}
                  </p>
                </div>
                <div>
                  <p className="text-slate-400 text-xs mb-1">Establishment</p>
                  <p className="font-medium">
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
                  <p className="font-medium">
                    {selected.verification_result || "N/A"}
                  </p>
                </div>
                {selected.acknowledged_at && (
                  <div>
                    <p className="text-slate-400 text-xs mb-1">Acknowledged</p>
                    <p className="font-medium">
                      {fmtDateTime(selected.acknowledged_at)}
                    </p>
                  </div>
                )}
                {selected.resolved_at && (
                  <div>
                    <p className="text-slate-400 text-xs mb-1">Resolved</p>
                    <p className="font-medium">
                      {fmtDateTime(selected.resolved_at)}
                    </p>
                  </div>
                )}
              </div>

              <SlaIndicator dispute={selected} />

              {/* Beneficiary explanation */}
              <div>
                <p className="text-xs text-slate-400 mb-1 flex items-center gap-1">
                  <MessageSquare className="w-3.5 h-3.5" /> Beneficiary
                  Explanation
                </p>
                <div className="p-3 bg-slate-50 rounded-lg text-sm text-slate-700 whitespace-pre-wrap">
                  {selected.explanation}
                </div>
              </div>

              {selected.supporting_doc_path && (
                <div>
                  <p className="text-xs text-slate-400 mb-1 flex items-center gap-1">
                    <FileText className="w-3.5 h-3.5" /> Supporting Document
                  </p>
                  <button
                    onClick={() =>
                      openAuthDocument(selected.supporting_doc_path)
                    }
                    className="text-sm text-blue-600 hover:underline"
                  >
                    View attached document
                  </button>
                </div>
              )}

              {/* Staff response */}
              {selected.staff_response && (
                <div>
                  <p className="text-xs text-slate-400 mb-1">Staff Response</p>
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

              {/* Claim */}
              <div className="flex items-center justify-between gap-3 p-3 bg-slate-50 rounded-lg">
                <div>
                  <p className="text-xs text-slate-400">Claimed by</p>
                  <p className="text-sm font-medium">
                    {selected.claimed_by_email || "Nobody yet"}
                  </p>
                </div>
                {["submitted", "acknowledged", "under_review"].includes(
                  selected.status,
                ) &&
                  (!selected.claimed_by_email ? (
                    <button
                      onClick={() => handleClaim(true)}
                      className="px-3 py-1.5 text-sm font-medium text-purple-700 bg-purple-100 rounded-lg hover:bg-purple-200"
                    >
                      Claim
                    </button>
                  ) : selected.claimed_by_email === user?.email ? (
                    <button
                      onClick={() => handleClaim(false)}
                      className="px-3 py-1.5 text-sm font-medium text-slate-600 bg-white border border-slate-200 rounded-lg hover:bg-slate-50"
                    >
                      Release
                    </button>
                  ) : null)}
              </div>
              {selected.beneficiary_acknowledged_at && (
                <p className="text-xs text-green-700">
                  Beneficiary acknowledged the response on{" "}
                  {fmtDateTime(selected.beneficiary_acknowledged_at)}
                </p>
              )}

              {/* Actions */}
              <div className="flex gap-3 pt-2 border-t border-slate-100">
                {selected.status === "submitted" && (
                  <button
                    onClick={() =>
                      setModal({ dispute: selected, action: "acknowledge" })
                    }
                    className="flex-1 py-2.5 text-sm font-semibold text-white bg-blue-600 rounded-lg hover:bg-blue-700 transition-colors"
                  >
                    Acknowledge
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
                      className="flex-1 py-2.5 text-sm font-semibold text-white bg-danger-600 rounded-lg hover:bg-danger-700 transition-colors"
                    >
                      Reject
                    </button>
                  </>
                )}
              </div>
            </div>
          ) : (
            <div className="bg-white rounded-xl border border-slate-200 p-12 text-center text-slate-400">
              <Scale className="w-12 h-12 mx-auto mb-3 opacity-30" />
              <p className="text-sm">Select a dispute to view details</p>
            </div>
          )}
        </div>
      </div>

      {/* Action modal */}
      {modal && (
        <ConfirmModal
          open={Boolean(modal)}
          title={
            modal.action === "acknowledge"
              ? "Acknowledge Dispute"
              : modal.action === "resolve"
                ? "Resolve Dispute"
                : "Reject Dispute"
          }
          description={
            modal.action === "acknowledge"
              ? `Acknowledge dispute from ${modal.dispute.beneficiary_name}? This confirms receipt within the 24h SLA.`
              : `${modal.action === "resolve" ? "Resolve" : "Reject"} this dispute? Please provide your response below.`
          }
          confirmLabel={
            modal.action === "acknowledge"
              ? "Acknowledge"
              : modal.action === "resolve"
                ? "Resolve"
                : "Reject"
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
                Staff Response *
              </label>
              <textarea
                value={staffResponse}
                onChange={(e) => setStaffResponse(e.target.value)}
                rows={4}
                placeholder="Provide explanation for the beneficiary..."
                className="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
              />
            </div>
          )}
          {actionError && (
            <p className="text-sm text-danger-600 mt-2">{actionError}</p>
          )}
        </ConfirmModal>
      )}

      {/* Toast */}
      {toast && (
        <div className="fixed bottom-6 right-6 bg-slate-800 text-white px-5 py-3 rounded-lg shadow-lg text-sm z-50 animate-fade-in">
          <CheckCircle2 className="w-4 h-4 inline mr-2" />
          {toast}
        </div>
      )}
    </div>
  );
}
