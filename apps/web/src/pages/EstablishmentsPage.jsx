import { useState, useMemo } from "react";
import { Link, useSearchParams } from "react-router-dom";
import {
  Search,
  Filter,
  ArrowRight,
  CheckCircle2,
  Ban,
  Store,
  Loader2,
  RefreshCw,
  AlertCircle,
  Plus,
  FileSpreadsheet,
} from "lucide-react";
import { useEstablishments } from "../hooks/useEstablishments";
import { establishmentsAPI } from "../services/api";
import StatusBadge from "../components/StatusBadge";
import ConfirmModal from "../components/ConfirmModal";
import BulkImportEstablishmentsModal from "../components/BulkImportEstablishmentsModal";
import { fmtDate } from "../utils/date";

const STATUS_TABS = [
  { value: "", label: "All" },
  { value: "pending", label: "Pending" },
  { value: "approved", label: "Approved" },
  { value: "suspended", label: "Suspended" },
  { value: "revoked", label: "Revoked" },
];

export default function EstablishmentsPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const [search, setSearch] = useState("");
  const [actionTarget, setActionTarget] = useState(null); // { est, type: 'approve'|'suspend' }
  const [suspendReason, setSuspendReason] = useState("");
  const [actionLoading, setActionLoading] = useState(false);
  const [actionError, setActionError] = useState("");
  const [toast, setToast] = useState(null);
  const [showBulkImport, setShowBulkImport] = useState(false);

  const statusFilter = searchParams.get("status") ?? "";
  const { data: establishments, loading, error, refetch } = useEstablishments();

  function setStatusFilter(val) {
    if (val) setSearchParams({ status: val });
    else setSearchParams({});
  }

  const filtered = useMemo(() => {
    return establishments.filter((e) => {
      const matchStatus = !statusFilter || e.status === statusFilter;
      const matchSearch =
        !search ||
        [
          e.business_name,
          e.address,
          e.contact_email,
          e.contact_phone,
          e.business_type,
        ].some((f) => f?.toLowerCase().includes(search.toLowerCase()));
      return matchStatus && matchSearch;
    });
  }, [establishments, statusFilter, search]);

  function showToast(msg, type = "success") {
    setToast({ msg, type });
    setTimeout(() => setToast(null), 3500);
  }

  async function handleAction() {
    if (!actionTarget) return;
    setActionLoading(true);
    setActionError("");
    try {
      if (actionTarget.type === "approve") {
        await establishmentsAPI.approve(actionTarget.est.id);
        showToast(`"${actionTarget.est.business_name}" approved successfully.`);
      } else {
        await establishmentsAPI.suspend(
          actionTarget.est.id,
          suspendReason || "Suspended by BPLO admin.",
        );
        showToast(
          `"${actionTarget.est.business_name}" has been suspended.`,
          "warn",
        );
      }
      setActionTarget(null);
      setSuspendReason("");
      await refetch();
    } catch (err) {
      setActionError(
        err.response?.data?.message || "Action failed. Please try again.",
      );
    } finally {
      setActionLoading(false);
    }
  }

  const counts = useMemo(() => {
    const tally = {};
    STATUS_TABS.forEach((t) => {
      tally[t.value] = 0;
    });
    establishments.forEach((e) => {
      tally[""]++;
      if (tally[e.status] !== undefined) tally[e.status]++;
    });
    return tally;
  }, [establishments]);

  return (
    <div className="px-6 lg:px-8 py-8 max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="font-heading font-bold text-2xl text-gray-900">
            Establishments
          </h1>
          <p className="text-gray-500 text-sm mt-0.5">
            Manage registered food service businesses
          </p>
        </div>
        <div className="flex items-center gap-2 self-start">
          <button
            onClick={refetch}
            disabled={loading}
            className="btn-secondary"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? "animate-spin" : ""}`} />
            Refresh
          </button>
          <button
            onClick={() => setShowBulkImport(true)}
            className="btn-secondary"
          >
            <FileSpreadsheet className="w-4 h-4" />
            Bulk Import
          </button>
          <Link to="/establishments/create" className="btn-primary">
            <Plus className="w-4 h-4" />
            Create Establishment
          </Link>
        </div>
      </div>

      {/* Error */}
      {error && (
        <div className="flex items-center gap-2.5 px-4 py-3 bg-danger-50 border border-danger-100 rounded-lg text-danger-700 text-sm">
          <AlertCircle className="w-4 h-4 flex-shrink-0" />
          {error}
        </div>
      )}

      {/* Filters row */}
      <div className="flex flex-col sm:flex-row gap-3">
        {/* Search */}
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="search"
            placeholder="Search by name, address, contact…"
            className="input pl-9"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        {/* Status filter (mobile select) */}
        <div className="sm:hidden">
          <select
            className="input"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            {STATUS_TABS.map((t) => (
              <option key={t.value} value={t.value}>
                {t.label}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Status tabs (desktop) */}
      <div className="hidden sm:flex items-center gap-1 border-b border-slate-200 w-fit">
        {STATUS_TABS.map((tab) => (
          <button
            key={tab.value}
            onClick={() => setStatusFilter(tab.value)}
            className={`px-4 py-2 border-b-2 text-sm font-medium transition-colors duration-150 flex items-center gap-1.5 ${
              statusFilter === tab.value
                ? "border-gov-600 text-gov-700"
                : "border-transparent text-gray-600 hover:text-gray-900"
            }`}
          >
            {tab.label}
            {counts[tab.value] !== undefined && (
              <span
                className={`font-mono text-[10px] px-1.5 py-0.5 rounded-registry font-medium ${
                  statusFilter === tab.value
                    ? "bg-gov-100 text-gov-700"
                    : "bg-slate-100 text-gray-600"
                }`}
              >
                {counts[tab.value]}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Table */}
      <div className="card p-0 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-200 bg-tableHeader">
                <th className="text-left text-xs font-semibold text-gray-500 uppercase tracking-wider px-5 py-2.5">
                  Business
                </th>
                <th className="text-left text-xs font-semibold text-gray-500 uppercase tracking-wider px-4 py-2.5 hidden md:table-cell">
                  Type
                </th>
                <th className="text-left text-xs font-semibold text-gray-500 uppercase tracking-wider px-4 py-2.5 hidden lg:table-cell">
                  Contact
                </th>
                <th className="text-left text-xs font-semibold text-gray-500 uppercase tracking-wider px-4 py-2.5 hidden lg:table-cell">
                  Registered
                </th>
                <th className="text-left text-xs font-semibold text-gray-500 uppercase tracking-wider px-4 py-2.5">
                  Status
                </th>
                <th className="text-right text-xs font-semibold text-gray-500 uppercase tracking-wider px-5 py-2.5">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200">
              {loading ? (
                [...Array(6)].map((_, i) => (
                  <tr key={i}>
                    {[...Array(6)].map((_, j) => (
                      <td key={j} className="px-4 py-2.5">
                        <div className="skeleton h-4 w-full max-w-[120px]" />
                      </td>
                    ))}
                  </tr>
                ))
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={6} className="text-center py-14">
                    <Store className="w-10 h-10 text-gray-200 mx-auto mb-3" />
                    <p className="text-sm font-medium text-gray-500">
                      No establishments found
                    </p>
                    <p className="text-xs text-gray-400 mt-1">
                      {search
                        ? "Try a different search term."
                        : "No establishments match this filter."}
                    </p>
                  </td>
                </tr>
              ) : (
                filtered.map((est) => (
                  <tr key={est.id}>
                    {/* Business name */}
                    <td className="px-5 py-2.5">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 bg-gov-50 rounded-lg flex items-center justify-center flex-shrink-0">
                          <Store className="w-4 h-4 text-gov-500" />
                        </div>
                        <div>
                          <p className="font-medium text-gray-900">
                            {est.business_name}
                          </p>
                          <p className="text-xs text-gray-400 mt-0.5 hidden sm:block truncate max-w-[200px]">
                            {est.address}
                          </p>
                        </div>
                      </div>
                    </td>

                    {/* Type */}
                    <td className="px-4 py-2.5 hidden md:table-cell">
                      <span className="text-gray-600 capitalize">
                        {est.business_type?.replace(/_/g, " ") ?? "—"}
                      </span>
                    </td>

                    {/* Contact */}
                    <td className="px-4 py-2.5 hidden lg:table-cell">
                      <p className="font-mono text-xs text-gray-700">
                        {est.contact_email}
                      </p>
                      <p className="text-xs text-gray-400 mt-0.5">
                        {est.contact_phone}
                      </p>
                    </td>

                    {/* Registered */}
                    <td className="px-4 py-2.5 hidden lg:table-cell text-gray-600 font-mono text-xs">
                      {fmtDate(est.created_at)}
                    </td>

                    {/* Status */}
                    <td className="px-4 py-2.5">
                      <StatusBadge status={est.status} />
                    </td>

                    {/* Actions */}
                    <td className="px-5 py-2.5 text-right">
                      <div className="flex items-center justify-end gap-2">
                        {est.status === "pending" && (
                          <button
                            onClick={() =>
                              setActionTarget({ est, type: "approve" })
                            }
                            className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-success-50 text-success-700 text-xs font-medium rounded-lg hover:bg-success-100 transition-colors"
                          >
                            <CheckCircle2 className="w-3.5 h-3.5" />
                            Approve
                          </button>
                        )}
                        {est.status === "approved" && (
                          <button
                            onClick={() =>
                              setActionTarget({ est, type: "suspend" })
                            }
                            className="btn-action-danger"
                          >
                            <Ban className="w-3.5 h-3.5" />
                            Suspend
                          </button>
                        )}
                        <Link
                          to={`/establishments/${est.id}`}
                          className="btn-row-view"
                        >
                          View <ArrowRight className="w-3.5 h-3.5" />
                        </Link>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Footer count */}
        {!loading && filtered.length > 0 && (
          <div className="px-5 py-3 border-t border-gray-50 bg-gray-50/40">
            <p className="text-xs text-gray-400">
              Showing {filtered.length} of {establishments.length} establishment
              {establishments.length !== 1 ? "s" : ""}
            </p>
          </div>
        )}
      </div>

      {/* Bulk Import Modal */}
      {showBulkImport && (
        <BulkImportEstablishmentsModal
          onClose={() => setShowBulkImport(false)}
          onSuccess={refetch}
        />
      )}

      {/* Approve confirm */}
      <ConfirmModal
        open={actionTarget?.type === "approve"}
        onClose={() => {
          setActionTarget(null);
          setActionError("");
        }}
        onConfirm={handleAction}
        title="Approve Establishment"
        description={`Grant "${actionTarget?.est?.business_name}" access to the iDetect verification network? They will be able to scan Senior Citizen and PWD IDs immediately.`}
        confirmLabel="Approve"
        variant="primary"
        loading={actionLoading}
      >
        {actionError && (
          <p className="text-sm text-danger-600 flex items-center gap-1.5">
            <AlertCircle className="w-4 h-4" />
            {actionError}
          </p>
        )}
      </ConfirmModal>

      {/* Suspend confirm */}
      <ConfirmModal
        open={actionTarget?.type === "suspend"}
        onClose={() => {
          setActionTarget(null);
          setActionError("");
          setSuspendReason("");
        }}
        onConfirm={handleAction}
        title="Suspend Establishment"
        description={`Suspend "${actionTarget?.est?.business_name}"? They will lose access to iDetect scanning immediately.`}
        confirmLabel="Suspend"
        variant="danger"
        loading={actionLoading}
      >
        <div className="mt-1">
          <label className="label text-xs">
            Reason for suspension (optional)
          </label>
          <input
            type="text"
            className="input text-sm"
            placeholder="e.g. Expired business permit, non-compliance…"
            value={suspendReason}
            onChange={(e) => setSuspendReason(e.target.value)}
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
          className={`fixed bottom-6 right-6 z-50 px-4 py-3 rounded-xl shadow-lg text-sm font-medium
          flex items-center gap-2 animate-[slideUp_0.2s_ease-out]
          ${toast.type === "success" ? "bg-success-700 text-white" : "bg-warn-700 text-white"}`}
        >
          <CheckCircle2 className="w-4 h-4" />
          {toast.msg}
        </div>
      )}
    </div>
  );
}
