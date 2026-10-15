import { useState, useEffect, useMemo, useCallback } from "react";
import {
  ScrollText,
  Search,
  Download,
  RefreshCw,
  AlertCircle,
  ChevronLeft,
  ChevronRight,
  Calendar,
  Filter,
  Keyboard,
} from "lucide-react";
import { auditLogsAPI } from "../services/api";
import { getStepUpToken } from "../utils/stepUp";
import { fmtDateTime } from "../utils/date";
import {
  humanizeAuditLog,
  actionLabel,
  formatAffectedRecord,
} from "../utils/auditLog";
import AuditLogDetailDrawer from "../components/AuditLogDetailDrawer";
import EmptyState from "../components/EmptyState";
import AuditReportModal from "../components/AuditReportModal";

const ACTION_GROUPS = [
  { value: "", label: "All Actions" },
  {
    value: "auth",
    label: "Auth",
    actions: [
      "login",
      "login_failed",
      "logout",
      "password_changed",
      "otp_requested",
      "otp_verified",
      "account_locked",
      "account_unlocked",
      "password_reset",
      "password_reset_by_admin",
    ],
  },
  {
    value: "beneficiary",
    label: "Beneficiary",
    actions: [
      "beneficiary_created",
      "beneficiary_updated",
      "beneficiary_status_changed",
      "beneficiary_deleted",
      "beneficiary_bulk_import",
      "beneficiary_renewed",
      "fraud_report_submitted",
    ],
  },
  {
    value: "establishment",
    label: "Establishment",
    actions: [
      "establishment_approved",
      "establishment_suspended",
      "establishment_revoked",
      "establishment_self_registered",
      "establishment_created",
      "establishment_bulk_import",
      "establishment_updated",
      "establishment_deleted",
    ],
  },
  {
    value: "fraud",
    label: "Fraud Flags",
    actions: [
      "flag_created",
      "flag_reviewed",
      "flag_confirmed",
      "flag_dismissed",
      "flag_restored",
      "unauthorized_use_reported",
    ],
  },
  {
    value: "dispute",
    label: "Disputes",
    actions: [
      "dispute_submitted",
      "dispute_acknowledged",
      "dispute_resolved",
      "dispute_rejected",
    ],
  },
  {
    value: "system",
    label: "System",
    actions: [
      "data_export",
      "report_generated",
      "breach_incident_report_generated",
    ],
  },
  {
    value: "verification",
    label: "Validations",
    actions: [
      "verification_performed",
      "verification_manual",
      "verification_action_taken",
      "seal_not_detected",
    ],
  },
  {
    value: "staff",
    label: "Staff",
    actions: [
      "staff_created",
      "staff_updated",
      "staff_activated",
      "staff_deactivated",
      "staff_password_reset",
      "staff_role_changed",
    ],
  },
];

// Full class strings are listed so Tailwind keeps them.
const ACTION_STYLES = {
  // Auth
  login: "bg-emerald-100 text-emerald-800",
  login_failed: "bg-red-100 text-red-800",
  logout: "bg-orange-100 text-orange-800",
  password_changed: "bg-sky-100 text-sky-800",
  otp_requested: "bg-cyan-100 text-cyan-800",
  otp_verified: "bg-teal-100 text-teal-800",
  account_locked: "bg-rose-100 text-rose-800",
  account_unlocked: "bg-lime-100 text-lime-800",
  password_reset: "bg-violet-100 text-violet-800",
  password_reset_by_admin: "bg-fuchsia-100 text-fuchsia-800",
  // Beneficiary
  beneficiary_created: "bg-blue-100 text-blue-800",
  beneficiary_updated: "bg-indigo-100 text-indigo-800",
  beneficiary_status_changed: "bg-yellow-100 text-yellow-800",
  beneficiary_deleted: "bg-red-100 text-red-800",
  beneficiary_bulk_import: "bg-slate-200 text-slate-800",
  beneficiary_renewed: "bg-green-100 text-green-800",
  fraud_report_submitted: "bg-pink-100 text-pink-800",
  // Establishment
  establishment_approved: "bg-green-200 text-green-900",
  establishment_suspended: "bg-amber-100 text-amber-800",
  establishment_revoked: "bg-red-200 text-red-900",
  establishment_self_registered: "bg-purple-100 text-purple-800",
  establishment_created: "bg-blue-200 text-blue-900",
  establishment_bulk_import: "bg-indigo-200 text-indigo-900",
  establishment_updated: "bg-violet-200 text-violet-900",
  establishment_deleted: "bg-rose-200 text-rose-900",
  // Fraud flags
  flag_created: "bg-orange-200 text-orange-900",
  flag_reviewed: "bg-yellow-200 text-yellow-900",
  flag_confirmed: "bg-red-600 text-white",
  flag_dismissed: "bg-stone-200 text-stone-800",
  flag_restored: "bg-lime-200 text-lime-900",
  unauthorized_use_reported: "bg-pink-200 text-pink-900",
  // Disputes
  dispute_submitted: "bg-sky-200 text-sky-900",
  dispute_acknowledged: "bg-cyan-200 text-cyan-900",
  dispute_resolved: "bg-emerald-200 text-emerald-900",
  dispute_rejected: "bg-rose-600 text-white",
  // System
  data_export: "bg-teal-200 text-teal-900",
  report_generated: "bg-fuchsia-200 text-fuchsia-900",
  breach_incident_report_generated: "bg-red-700 text-white",
  // Validations
  verification_performed: "bg-gov-50 text-gov-700",
  verification_manual: "bg-amber-100 text-amber-800",
  verification_action_taken: "bg-zinc-200 text-zinc-800",
  // Staff
  staff_created: "bg-green-100 text-green-800",
  staff_updated: "bg-slate-200 text-slate-800",
  staff_activated: "bg-lime-100 text-lime-800",
  staff_deactivated: "bg-stone-300 text-stone-800",
  staff_password_reset: "bg-fuchsia-100 text-fuchsia-800",
};

function actionColor(action) {
  return ACTION_STYLES[action] ?? "bg-slate-100 text-slate-600";
}

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

export default function AuditLogsPage() {
  const [logs, setLogs] = useState([]);
  const [pagination, setPagination] = useState({
    total: 0,
    page: 1,
    limit: 30,
    pages: 1,
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const [search, setSearch] = useState("");
  const [actionGroup, setActionGroup] = useState("");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [page, setPage] = useState(1);

  const [exporting, setExporting] = useState(false);
  const [showReport, setShowReport] = useState(false);
  const [selectedLog, setSelectedLog] = useState(null);

  const activeActions = useMemo(() => {
    const grp = ACTION_GROUPS.find((g) => g.value === actionGroup);
    return grp?.actions ?? [];
  }, [actionGroup]);

  const fetchLogs = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const params = { page, limit: 30 };
      if (search) params.search = search;
      if (startDate) params.start_date = startDate;
      if (endDate) params.end_date = endDate;
      if (activeActions.length === 1) params.action = activeActions[0];
      const res = await auditLogsAPI.list(params);
      setLogs(res.data?.data ?? []);
      setPagination(
        res.data?.pagination ?? { total: 0, page: 1, limit: 30, pages: 1 },
      );
    } catch (err) {
      setError(
        err.response?.data?.error ||
          err.response?.data?.message ||
          err.response?.data?.detail ||
          "Failed to load audit logs.",
      );
    } finally {
      setLoading(false);
    }
  }, [page, search, startDate, endDate, activeActions]);

  useEffect(() => {
    fetchLogs();
  }, [fetchLogs]);

  // Client-side group filter (API only supports single action filter)
  const filtered = useMemo(() => {
    if (!activeActions.length) return logs;
    return logs.filter((l) => activeActions.includes(l.action));
  }, [logs, activeActions]);

  const actionCounts = useMemo(() => {
    const counts = { "": logs.length };
    ACTION_GROUPS.forEach((group) => {
      if (group.value) {
        counts[group.value] = logs.filter((log) =>
          group.actions.includes(log.action),
        ).length;
      }
    });
    return counts;
  }, [logs]);

  async function handleExport() {
    setExporting(true);
    try {
      const params = {};
      if (search) params.search = search;
      if (startDate) params.start_date = startDate;
      if (endDate) params.end_date = endDate;
      if (activeActions.length === 1) params.action = activeActions[0];
      const token = await getStepUpToken("Confirm your password to export audit logs.");
      const res = await auditLogsAPI.exportCsv(params, token);
      downloadBlob(
        new Blob([res.data]),
        `audit-logs-${new Date().toISOString().slice(0, 10)}.csv`,
      );
    } catch {
      setError("Export failed.");
    } finally {
      setExporting(false);
    }
  }

  return (
    <div className="px-6 lg:px-8 py-8 max-w-7xl mx-auto space-y-6">
      {showReport && <AuditReportModal onClose={() => setShowReport(false)} />}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="font-heading font-bold text-2xl text-slate-900">
            Audit Logs
          </h1>
          <p className="text-slate-500 text-sm mt-0.5 font-medium">
            Track all system activity across users and establishments
          </p>
        </div>
        <div className="flex items-center gap-2 self-start">
          <button
            onClick={() => setShowReport(true)}
            className="btn-secondary"
          >
            <ScrollText className="w-4 h-4" />
            Reports
          </button>
          <button
            onClick={handleExport}
            disabled={exporting}
            className="btn-secondary"
          >
            <Download
              className={`w-4 h-4 ${exporting ? "animate-pulse" : ""}`}
            />
            Export CSV
          </button>
          <button
            onClick={() => {
              setPage(1);
              fetchLogs();
            }}
            disabled={loading}
            className="btn-secondary"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? "animate-spin" : ""}`} />
            Refresh
          </button>
        </div>
      </div>

      {error && (
        <div className="flex items-center gap-2.5 px-4 py-3 bg-danger-50 border border-danger-100 rounded-xl text-danger-700 text-sm">
          <AlertCircle className="w-4 h-4 flex-shrink-0" />
          {error}
        </div>
      )}

      {/* Filters */}
      <div className="card p-4">
        <div className="flex flex-col lg:flex-row gap-3">
          {/* Search */}
          <div className="relative flex-1">
            <Search
              className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500"
              strokeWidth={1.8}
              aria-hidden="true"
            />
            <input
              type="text"
              placeholder="Search by user, action, or details…"
              className="input-search text-sm w-full"
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
            />
          </div>
          {/* Date range */}
          <div className="flex items-center gap-2">
            <div className="relative">
              <Calendar
                className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-slate-500 pointer-events-none"
                strokeWidth={1.8}
                aria-hidden="true"
              />
              <input
                type="date"
                aria-label="Start date"
                className="input-date"
                value={startDate}
                onChange={(e) => {
                  setStartDate(e.target.value);
                  setPage(1);
                }}
              />
            </div>
            <span className="text-slate-400 text-xs">to</span>
            <div className="relative">
              <Calendar
                className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-slate-500 pointer-events-none"
                strokeWidth={1.8}
                aria-hidden="true"
              />
              <input
                type="date"
                aria-label="End date"
                className="input-date"
                value={endDate}
                onChange={(e) => {
                  setEndDate(e.target.value);
                  setPage(1);
                }}
              />
            </div>
          </div>
        </div>

        {/* Action group tabs */}
        <div className="flex items-center gap-x-1 gap-y-0 mt-3 border-b border-slate-200 flex-wrap">
          <Filter className="w-4 h-4 text-slate-400 mr-2 flex-shrink-0" />
          {ACTION_GROUPS.map((grp) => (
            <button
              key={grp.value}
              onClick={() => {
                setActionGroup(grp.value);
                setPage(1);
              }}
              className={`inline-flex items-center gap-2 whitespace-nowrap px-3 py-2 -mb-px border-b-2 text-xs font-semibold transition-colors
                ${
                  actionGroup === grp.value
                    ? "border-gov-600 text-gov-700"
                    : "border-transparent text-slate-500 hover:text-slate-700"
                }`}
            >
              {grp.label}
              <span
                className={`inline-flex items-center justify-center min-w-[1.5rem] h-5 px-1.5 font-mono text-[10px] leading-none tabular-nums rounded-full ${
                  actionGroup === grp.value
                    ? "bg-gov-100 text-gov-700"
                    : "bg-slate-100 text-slate-500"
                }`}
              >
                {actionCounts[grp.value] ?? 0}
              </span>
            </button>
          ))}
        </div>
      </div>

      {/* Table */}
      <div className="card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-200 bg-tableHeader">
                <th className="text-left px-4 py-3 font-semibold text-slate-500 text-xs uppercase tracking-wider">
                  Date
                </th>
                <th className="text-left px-4 py-3 font-semibold text-slate-500 text-xs uppercase tracking-wider">
                  Action
                </th>
                <th className="text-left px-4 py-3 font-semibold text-slate-500 text-xs uppercase tracking-wider">
                  User
                </th>
                <th className="text-left px-4 py-3 font-semibold text-slate-500 text-xs uppercase tracking-wider">
                  Affected record
                </th>
                <th className="text-left px-4 py-3 font-semibold text-slate-500 text-xs uppercase tracking-wider">
                  Details
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200">
              {loading ? (
                [...Array(8)].map((_, i) => (
                  <tr key={i}>
                    {[...Array(5)].map((__, j) => (
                      <td key={j} className="px-4 py-2.5">
                        <div className="skeleton h-4 w-full rounded" />
                      </td>
                    ))}
                  </tr>
                ))
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={5}>
                    <EmptyState
                      icon={ScrollText}
                      tone="gov"
                      title="No audit logs found"
                      description="Try adjusting your filters or date range."
                    />
                  </td>
                </tr>
              ) : (
                filtered.map((log) => (
                  <tr
                    key={log.id}
                    onClick={() => setSelectedLog(log)}
                    className={`transition-colors cursor-pointer ${
                      log.action === "verification_manual" ? "bg-amber-50" : ""
                    }`}
                  >
                    <td className="px-4 py-2.5 text-xs text-slate-500 whitespace-nowrap font-mono">
                      {fmtDateTime(log.created_at)}
                    </td>
                    <td className="px-4 py-2.5">
                      <span
                        className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold ${actionColor(log.action)}`}
                      >
                        {log.action === "verification_manual" && (
                          <Keyboard className="w-3 h-3" />
                        )}
                        {actionLabel(log.action)}
                      </span>
                    </td>
                    <td className="px-4 py-2.5 text-xs font-medium text-slate-700">
                      {log.user_name || "—"}
                    </td>
                    <td className="px-4 py-2.5 text-xs text-slate-600">
                      {formatAffectedRecord(log) || "—"}
                    </td>
                    <td className="px-4 py-2.5 text-xs text-slate-500 max-w-xs truncate">
                      {humanizeAuditLog(log)}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {!loading && pagination.pages > 1 && (
          <div className="flex items-center justify-between px-4 py-3 border-t border-slate-100 bg-slate-50/40">
            <p className="text-xs text-slate-500">
              Showing page{" "}
              <span className="font-semibold">{pagination.page}</span> of{" "}
              <span className="font-semibold">{pagination.pages}</span> (
              {pagination.total} total)
            </p>
            <div className="flex items-center gap-1">
              <button
                onClick={() => setPage((p) => Math.max(1, p - 1))}
                disabled={page <= 1}
                className="p-1.5 rounded-lg hover:bg-slate-100 disabled:opacity-30 transition-colors"
              >
                <ChevronLeft className="w-4 h-4" />
              </button>
              <button
                onClick={() =>
                  setPage((p) => Math.min(pagination.pages, p + 1))
                }
                disabled={page >= pagination.pages}
                className="p-1.5 rounded-lg hover:bg-slate-100 disabled:opacity-30 transition-colors"
              >
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}
      </div>

      <AuditLogDetailDrawer
        log={selectedLog}
        onClose={() => setSelectedLog(null)}
      />
    </div>
  );
}
