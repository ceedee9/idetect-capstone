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
import { fmtDateTime } from "../utils/date";

const ACTION_GROUPS = [
  { value: "", label: "All Actions" },
  {
    value: "auth",
    label: "Auth",
    actions: [
      "login",
      "logout",
      "password_changed",
      "otp_requested",
      "otp_verified",
    ],
  },
  {
    value: "beneficiary",
    label: "Beneficiary",
    actions: [
      "beneficiary_created",
      "beneficiary_updated",
      "beneficiary_status_changed",
    ],
  },
  {
    value: "establishment",
    label: "Establishment",
    actions: [
      "establishment_approved",
      "establishment_suspended",
      "establishment_revoked",
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
    actions: ["data_export", "report_generated"],
  },
  {
    value: "verification",
    label: "Verifications",
    actions: [
      "verification_performed",
      "verification_manual",
      "verification_action_taken",
    ],
  },
];

function actionLabel(action) {
  return (action ?? "")
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

function actionColor(action) {
  if (!action) return "bg-slate-100 text-slate-600";
  if (action === "verification_manual") return "bg-amber-100 text-amber-800";
  if (action.startsWith("flag_") || action.startsWith("dispute_"))
    return "bg-accent-50 text-accent-700";
  if (action.startsWith("beneficiary_")) return "bg-gov-50 text-gov-700";
  if (action.startsWith("establishment_"))
    return "bg-purple-50 text-purple-700";
  if (
    [
      "login",
      "logout",
      "password_changed",
      "otp_requested",
      "otp_verified",
    ].includes(action)
  )
    return "bg-blue-50 text-blue-700";
  return "bg-slate-100 text-slate-600";
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
      setError(err.response?.data?.message || "Failed to load audit logs.");
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

  async function handleExport() {
    setExporting(true);
    try {
      const params = {};
      if (search) params.search = search;
      if (startDate) params.start_date = startDate;
      if (endDate) params.end_date = endDate;
      if (activeActions.length === 1) params.action = activeActions[0];
      const res = await auditLogsAPI.exportCsv(params);
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
      {/* Header */}
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
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
            <input
              type="text"
              placeholder="Search by user, action, or details…"
              className="input pl-9 text-sm w-full"
              value={search}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
            />
          </div>
          {/* Date range */}
          <div className="flex items-center gap-2">
            <Calendar className="w-4 h-4 text-slate-400 flex-shrink-0" />
            <input
              type="date"
              className="input text-sm"
              value={startDate}
              onChange={(e) => {
                setStartDate(e.target.value);
                setPage(1);
              }}
            />
            <span className="text-slate-400 text-xs">to</span>
            <input
              type="date"
              className="input text-sm"
              value={endDate}
              onChange={(e) => {
                setEndDate(e.target.value);
                setPage(1);
              }}
            />
          </div>
        </div>

        {/* Action group tabs */}
        <div className="flex items-center gap-1 mt-3 flex-wrap">
          <Filter className="w-4 h-4 text-slate-400 mr-1" />
          {ACTION_GROUPS.map((grp) => (
            <button
              key={grp.value}
              onClick={() => {
                setActionGroup(grp.value);
                setPage(1);
              }}
              className={`px-3 py-1 rounded-xl text-xs font-semibold transition-all
                ${
                  actionGroup === grp.value
                    ? "bg-gov-100 text-gov-700 shadow-sm"
                    : "bg-slate-100 text-slate-500 hover:text-slate-700"
                }`}
            >
              {grp.label}
            </button>
          ))}
        </div>
      </div>

      {/* Table */}
      <div className="card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-100 bg-slate-50/60">
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
                  Establishment
                </th>
                <th className="text-left px-4 py-3 font-semibold text-slate-500 text-xs uppercase tracking-wider">
                  Target
                </th>
                <th className="text-left px-4 py-3 font-semibold text-slate-500 text-xs uppercase tracking-wider">
                  Details
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-50">
              {loading ? (
                [...Array(8)].map((_, i) => (
                  <tr key={i}>
                    {[...Array(6)].map((__, j) => (
                      <td key={j} className="px-4 py-3">
                        <div className="skeleton h-4 w-full rounded" />
                      </td>
                    ))}
                  </tr>
                ))
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={6} className="text-center py-14">
                    <ScrollText className="w-10 h-10 text-slate-200 mx-auto mb-3" />
                    <p className="text-sm font-semibold text-slate-500">
                      No audit logs found
                    </p>
                    <p className="text-xs text-slate-400 mt-1">
                      Try adjusting your filters or date range.
                    </p>
                  </td>
                </tr>
              ) : (
                filtered.map((log) => (
                  <tr
                    key={log.id}
                    className={`hover:bg-slate-50/50 transition-colors ${
                      log.action === "verification_manual" ? "bg-amber-50" : ""
                    }`}
                  >
                    <td className="px-4 py-3 text-xs text-slate-500 whitespace-nowrap">
                      {fmtDateTime(log.created_at)}
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold ${actionColor(log.action)}`}
                      >
                        {log.action === "verification_manual" && (
                          <Keyboard className="w-3 h-3" />
                        )}
                        {actionLabel(log.action)}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-xs font-medium text-slate-700">
                      {log.user_name || "—"}
                    </td>
                    <td className="px-4 py-3 text-xs text-slate-500">
                      {log.establishment_name || "—"}
                    </td>
                    <td className="px-4 py-3 text-xs text-slate-500 font-mono">
                      {log.target_table ? `${log.target_table}` : "—"}
                      {log.target_id ? (
                        <span className="text-slate-400 ml-1">
                          #{log.target_id.slice(0, 8)}
                        </span>
                      ) : (
                        ""
                      )}
                    </td>
                    <td className="px-4 py-3 text-xs text-slate-400 max-w-xs truncate">
                      {log.metadata
                        ? JSON.stringify(log.metadata).slice(0, 80)
                        : "—"}
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
    </div>
  );
}
