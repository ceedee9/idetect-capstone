import { useState, useMemo, useEffect } from "react";
import { Link, useSearchParams } from "react-router-dom";
import {
  Search,
  Users,
  ArrowRight,
  UserCheck,
  UserX,
  RefreshCw,
  AlertCircle,
  Plus,
  CheckCircle2,
  Accessibility,
  Filter,
  Clock,
  ShieldAlert,
} from "lucide-react";
import { useBeneficiaries } from "../hooks/useBeneficiaries";
import { beneficiariesAPI } from "../services/api";
import { useAuth } from "../context/AuthContext";
import StatusBadge from "../components/StatusBadge";
import ConfirmModal from "../components/ConfirmModal";
import EmptyState from "../components/EmptyState";
import { fmtDate, calcAge } from "../utils/date";
import { PDAO_DISABILITY_FILTER_OPTIONS } from "../constants/disabilityTypes";

const STATUS_TABS = [
  { value: "", label: "All" },
  { value: "active", label: "Active" },
  { value: "suspended", label: "Suspended" },
  { value: "expired", label: "Expired" },
  { value: "revoked", label: "Revoked" },
];

export default function BeneficiariesPage() {
  const { user } = useAuth();
  const isPDAO = user?.portalRole === "pdao_admin";

  const [searchParams, setSearchParams] = useSearchParams();
  const [search, setSearch] = useState("");
  const [disabilityFilter, setDisabilityFilter] = useState("");
  const [modal, setModal] = useState(null); // { beneficiary, action: 'activate'|'suspend' }
  const [actionLoading, setActionLoading] = useState(false);
  const [actionError, setActionError] = useState("");
  const [toast, setToast] = useState(null);
  const [expiringSoon, setExpiringSoon] = useState([]);
  const [autoSuspended, setAutoSuspended] = useState([]);

  useEffect(() => {
    beneficiariesAPI
      .expiringSoon(30)
      .then((r) => setExpiringSoon(r.data?.beneficiaries ?? []))
      .catch(() => {});
    beneficiariesAPI
      .recentlyAutoSuspended(24)
      .then((r) => setAutoSuspended(r.data?.data ?? []))
      .catch(() => {});
  }, []);

  const statusFilter = searchParams.get("status") ?? "";
  const { data: beneficiaries, loading, error, refetch } = useBeneficiaries();

  function setStatusFilter(val) {
    val ? setSearchParams({ status: val }) : setSearchParams({});
  }

  const filtered = useMemo(
    () =>
      beneficiaries.filter((b) => {
        const matchStatus = !statusFilter || b.status === statusFilter;
        const matchDisability =
          !disabilityFilter ||
          b.disability_type?.toLowerCase() === disabilityFilter;
        const q = search.toLowerCase();
        const matchSearch =
          !q ||
          [
            b.first_name,
            b.last_name,
            b.middle_name,
            b.full_name,
            b.id_number,
            b.reference_no,
            b.address,
          ].some((f) => f?.toLowerCase().includes(q));
        return matchStatus && (isPDAO ? matchDisability : true) && matchSearch;
      }),
    [beneficiaries, statusFilter, disabilityFilter, search, isPDAO],
  );

  const counts = useMemo(() => {
    const t = { "": 0 };
    STATUS_TABS.forEach((s) => {
      if (s.value) t[s.value] = 0;
    });
    beneficiaries.forEach((b) => {
      t[""]++;
      if (t[b.status] !== undefined) t[b.status]++;
    });
    return t;
  }, [beneficiaries]);

  function showToast(msg) {
    setToast(msg);
    setTimeout(() => setToast(null), 3500);
  }

  async function handleAction() {
    if (!modal) return;
    setActionLoading(true);
    setActionError("");
    const newStatus = modal.action === "activate" ? "active" : "suspended";
    try {
      await beneficiariesAPI.updateStatus(modal.beneficiary.id, newStatus);
      showToast(
        `${modal.beneficiary.first_name} ${modal.beneficiary.last_name} marked as ${newStatus}.`,
      );
      setModal(null);
      await refetch();
    } catch (err) {
      setActionError(err.response?.data?.message || "Action failed.");
    } finally {
      setActionLoading(false);
    }
  }

  // Role-aware labels
  const title = isPDAO ? "PWD Records" : "Senior Citizens";
  const subtitle = isPDAO
    ? "Beneficiary registry — RA 10754"
    : "Beneficiary registry — RA 9994";
  const entityLabel = isPDAO ? "PWD Beneficiary" : "Senior Citizen";
  const discountLabel = isPDAO ? "PWD discounts" : "senior citizen benefits";

  return (
    <div className="px-6 lg:px-8 py-8 max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="font-heading font-bold text-2xl text-slate-900">
            {title}
          </h1>
          <p className="text-slate-500 text-sm mt-0.5 font-medium">
            {subtitle}
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
          <Link to="/beneficiaries/add" className="btn-primary">
            <Plus className="w-4 h-4" />
            Add Record
          </Link>
        </div>
      </div>

      {error && (
        <div className="flex items-center gap-2.5 px-4 py-3 bg-danger-50 border border-danger-100 rounded-xl text-danger-700 text-sm">
          <AlertCircle className="w-4 h-4 flex-shrink-0" />
          {error}
        </div>
      )}

      {/* Auto-Suspended Alert Banner */}
      {autoSuspended.length > 0 && (
        <div className="bg-red-50 border border-red-200 rounded-xl p-4">
          <div className="flex items-center gap-2 mb-3">
            <ShieldAlert className="w-4 h-4 text-red-600" />
            <span className="text-sm font-bold text-red-800">
              {autoSuspended.length} ID{autoSuspended.length > 1 ? "s" : ""}{" "}
              auto-suspended in the last 24h — requires review
            </span>
          </div>
          <div className="flex flex-wrap gap-2">
            {autoSuspended.map((b) => (
              <Link
                key={b.id}
                to={`/beneficiaries/${b.id}`}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-white border border-red-200 rounded-lg text-xs font-medium text-red-900 hover:bg-red-100 transition-colors"
              >
                <ShieldAlert className="w-3 h-3 text-red-600" />
                <span>{b.full_name}</span>
                <span className="text-red-500 font-bold">
                  {b.distinct_flaggers} flags
                </span>
              </Link>
            ))}
          </div>
        </div>
      )}

      {/* Expiring Soon Banner */}
      {expiringSoon.length > 0 && (
        <div className="bg-amber-50 border border-amber-200 rounded-xl p-4">
          <div className="flex items-center gap-2 mb-3">
            <Clock className="w-4 h-4 text-amber-600" />
            <span className="text-sm font-bold text-amber-800">
              {expiringSoon.length} ID{expiringSoon.length > 1 ? "s" : ""}{" "}
              expiring within 30 days
            </span>
          </div>
          <div className="flex flex-wrap gap-2">
            {expiringSoon.slice(0, 8).map((b) => {
              const days = Math.ceil(
                (new Date(b.validity_end) - new Date()) / 86400000,
              );
              return (
                <Link
                  key={b.id}
                  to={`/beneficiaries/${b.id}`}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-white border border-amber-200 rounded-lg text-xs font-medium text-amber-900 hover:bg-amber-100 transition-colors"
                >
                  <span>{b.full_name}</span>
                  <span
                    className={`font-bold ${days <= 7 ? "text-red-600" : "text-amber-600"}`}
                  >
                    {days}d
                  </span>
                </Link>
              );
            })}
            {expiringSoon.length > 8 && (
              <span className="text-xs text-amber-600 self-center">
                +{expiringSoon.length - 8} more
              </span>
            )}
          </div>
        </div>
      )}

      {/* Search + Filters */}
      <div className="flex flex-col sm:flex-row gap-3">
        <div className="relative flex-1">
          <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            type="search"
            placeholder="Search by name, reference no. or ID number…"
            className="input-search"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        {isPDAO && (
          <div className="relative">
            <Filter className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400 pointer-events-none" />
            <select
              className="input pl-9 pr-8 appearance-none cursor-pointer min-w-[160px]"
              value={disabilityFilter}
              onChange={(e) => setDisabilityFilter(e.target.value)}
            >
              {PDAO_DISABILITY_FILTER_OPTIONS.map((t) => (
                <option key={t.value} value={t.value}>
                  {t.label}
                </option>
              ))}
            </select>
          </div>
        )}
      </div>

      {/* Status tabs */}
      <div className="flex items-center gap-1 border-b border-slate-200 w-fit overflow-x-auto">
        {STATUS_TABS.map((tab) => (
          <button
            key={tab.value}
            onClick={() => setStatusFilter(tab.value)}
            className={`px-4 py-2 border-b-2 text-sm font-semibold transition-colors duration-150 flex items-center gap-1.5 whitespace-nowrap
              ${statusFilter === tab.value ? `${isPDAO ? "border-pdao-600 text-pdao-700" : "border-osca-600 text-osca-700"}` : "border-transparent text-slate-500 hover:text-slate-800"}`}
          >
            {tab.label}
            {counts[tab.value] !== undefined && (
              <span
                className={`font-mono text-[10px] px-1.5 py-0.5 rounded-registry font-bold
                ${statusFilter === tab.value ? (isPDAO ? "bg-pdao-100 text-pdao-700" : "bg-osca-100 text-osca-700") : "bg-slate-100 text-slate-500"}`}
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
                {[
                  ["Beneficiary", ""],
                  ["ID Number", ""],
                  ...(isPDAO
                    ? [["Disability Type", "hidden lg:table-cell"]]
                    : []),
                  ["Age / DOB", "hidden lg:table-cell"],
                  ["Status", ""],
                  ["Actions", "text-right"],
                ].map(([h, cls]) => (
                  <th
                    key={h}
                    className={`text-left text-xs font-bold text-slate-400 uppercase tracking-wider px-5 py-2.5 ${cls}`}
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200">
              {loading ? (
                [...Array(6)].map((_, i) => (
                  <tr key={i}>
                    {[...Array(isPDAO ? 6 : 5)].map((_, j) => (
                      <td key={j} className="px-5 py-2.5">
                        <div className="skeleton h-4 w-full max-w-[120px]" />
                      </td>
                    ))}
                  </tr>
                ))
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={isPDAO ? 6 : 5}>
                    <EmptyState
                      icon={Accessibility}
                      tone={isPDAO ? "pdao" : "osca"}
                      title="No records found"
                      description={
                        search || (isPDAO && disabilityFilter)
                          ? "Try adjusting your filters."
                          : "No beneficiaries match this status."
                      }
                      action={
                        !search && !(isPDAO && disabilityFilter)
                          ? {
                              to: "/beneficiaries/add",
                              label: `Add a ${entityLabel.toLowerCase()}`,
                            }
                          : undefined
                      }
                    />
                  </td>
                </tr>
              ) : (
                filtered.map((b) => {
                  const age = calcAge(b.date_of_birth);
                  const fallbackName = b.full_name || "Unknown beneficiary";
                  const displayName =
                    b.last_name || b.first_name
                      ? `${b.last_name || ""}${b.last_name && b.first_name ? "," : ""} ${b.first_name || ""}${b.middle_name ? ` ${b.middle_name[0]}.` : ""}`.trim()
                      : fallbackName;
                  const initials =
                    [b.first_name?.[0], b.last_name?.[0]]
                      .filter(Boolean)
                      .join("") ||
                    fallbackName
                      .split(/\s+/)
                      .map((x) => x[0])
                      .filter(Boolean)
                      .slice(0, 2)
                      .join("")
                      .toUpperCase();
                  return (
                    <tr key={b.id} className="transition-colors">
                      {/* Name */}
                      <td className="px-5 py-2.5">
                        <div className="flex items-center gap-3">
                          <div className="w-9 h-9 bg-gov-100 rounded-full flex items-center justify-center flex-shrink-0">
                            <span className="text-xs font-bold text-gov-700">
                              {initials || "?"}
                            </span>
                          </div>
                          <div>
                            <p className="font-semibold text-slate-900">
                              {displayName}
                            </p>
                            <p className="font-mono text-[11px] text-slate-400">
                              {b.reference_no}
                            </p>
                            <p className="font-mono text-xs text-slate-400 font-medium mt-0.5 lg:hidden">
                              {b.id_number}
                            </p>
                          </div>
                        </div>
                      </td>
                      {/* ID */}
                      <td className="px-5 py-2.5">
                        <span className="font-mono text-xs text-slate-600 bg-slate-100 px-2 py-1 rounded-lg">
                          {b.id_number}
                        </span>
                      </td>
                      {/* Disability type — PDAO only */}
                      {isPDAO && (
                        <td className="px-5 py-2.5 hidden lg:table-cell">
                          {b.disability_type ? (
                            <span className="dtype-tag capitalize">
                              {b.disability_type}
                            </span>
                          ) : (
                            <span className="text-slate-400 text-xs">—</span>
                          )}
                        </td>
                      )}
                      {/* Age */}
                      <td className="px-5 py-2.5 hidden lg:table-cell">
                        <p className="text-slate-700 font-medium">
                          {age ? `${age} yrs` : "—"}
                        </p>
                        <p className="font-mono text-xs text-slate-400">
                          {fmtDate(b.date_of_birth)}
                        </p>
                      </td>
                      {/* Status */}
                      <td className="px-5 py-2.5">
                        <StatusBadge status={b.status} />
                      </td>
                      {/* Actions */}
                      <td className="px-5 py-2.5 text-right">
                        <div className="flex items-center justify-end gap-2">
                          {b.status === "suspended" && (
                            <button
                              onClick={() =>
                                setModal({ beneficiary: b, action: "activate" })
                              }
                              className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-gov-50 text-gov-700 text-xs font-semibold rounded-xl hover:bg-gov-100 transition-colors"
                            >
                              <UserCheck className="w-3.5 h-3.5" />
                              Activate
                            </button>
                          )}
                          {b.status === "active" && (
                            <button
                              onClick={() =>
                                setModal({ beneficiary: b, action: "suspend" })
                              }
                              className="btn-action-danger"
                            >
                              <UserX className="w-3.5 h-3.5" />
                              Suspend
                            </button>
                          )}
                          <Link
                            to={`/beneficiaries/${b.id}`}
                            className="btn-row-view"
                          >
                            View <ArrowRight className="w-3.5 h-3.5" />
                          </Link>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
        {!loading && filtered.length > 0 && (
          <div className="px-5 py-3 border-t border-slate-50 bg-slate-50/40">
            <p className="text-xs text-slate-400 font-medium">
              Showing {filtered.length} of {beneficiaries.length} record
              {beneficiaries.length !== 1 ? "s" : ""}
              {isPDAO &&
                disabilityFilter &&
                ` · ${disabilityFilter} disability`}
            </p>
          </div>
        )}
      </div>

      {/* Activate modal */}
      <ConfirmModal
        open={modal?.action === "activate"}
        onClose={() => {
          setModal(null);
          setActionError("");
        }}
        onConfirm={handleAction}
        title={`Activate ${entityLabel}`}
        description={`Restore active status for ${modal?.beneficiary?.first_name} ${modal?.beneficiary?.last_name}? They will be eligible for ${discountLabel} again.`}
        confirmLabel="Activate"
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

      {/* Suspend modal */}
      <ConfirmModal
        open={modal?.action === "suspend"}
        onClose={() => {
          setModal(null);
          setActionError("");
        }}
        onConfirm={handleAction}
        title={`Suspend ${entityLabel}`}
        description={`Suspend ${modal?.beneficiary?.first_name} ${modal?.beneficiary?.last_name}? Their ID will return SUSPICIOUS on establishment scans until reinstated.`}
        confirmLabel="Suspend"
        variant="warn"
        loading={actionLoading}
      >
        {actionError && (
          <p className="text-sm text-danger-600 flex items-center gap-1.5">
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
