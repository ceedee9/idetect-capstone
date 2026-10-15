import { useEffect, useState } from "react";
import { History, ChevronLeft, ChevronRight } from "lucide-react";
import { auditLogsAPI } from "../services/api";
import { fmtDateTime } from "../utils/date";
import { actionLabel, humanizeAuditLog } from "../utils/auditLog";

const PAGE_SIZE = 10;

/**
 * Read-only history of audit events for one record (e.g. a beneficiary or
 * establishment). Uses the audit-log list endpoint, which is admin-only;
 * the panel renders nothing for users without access.
 */
export default function RecordHistoryPanel({ targetTable, targetId }) {
  const [logs, setLogs] = useState([]);
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [hidden, setHidden] = useState(false);

  useEffect(() => {
    if (!targetId) return;
    let cancelled = false;
    setLoading(true);
    auditLogsAPI
      .list({
        target_table: targetTable,
        target_id: targetId,
        page,
        limit: PAGE_SIZE,
      })
      .then((res) => {
        if (cancelled) return;
        setLogs(res.data?.data ?? []);
        setPages(res.data?.pagination?.pages ?? 1);
        setTotal(res.data?.pagination?.total ?? 0);
      })
      .catch((err) => {
        if (cancelled) return;
        if (err.response?.status === 403) {
          setHidden(true);
        } else {
          setLogs([]);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [targetTable, targetId, page]);

  if (hidden) return null;

  return (
    <div className="card">
      <div className="flex items-center justify-between mb-4">
        <h3 className="font-heading font-semibold text-slate-900 text-sm flex items-center gap-2">
          <History className="w-4 h-4 text-slate-400" />
          Record History
        </h3>
        {total > 0 && (
          <span className="text-xs text-slate-500">{total} events</span>
        )}
      </div>

      {loading && logs.length === 0 ? (
        <p className="text-sm text-slate-500">Loading history…</p>
      ) : logs.length === 0 ? (
        <p className="text-sm text-slate-500">No recorded events yet.</p>
      ) : (
        <ul className="divide-y divide-slate-100">
          {logs.map((log) => (
            <li key={log.id} className="py-3 first:pt-0 last:pb-0">
              <div className="flex items-start justify-between gap-3">
                <p className="text-sm text-slate-800 min-w-0 break-words">
                  {humanizeAuditLog(log)}
                </p>
                <span className="shrink-0 text-[11px] font-medium text-slate-500 bg-slate-100 rounded px-1.5 py-0.5">
                  {actionLabel(log.action)}
                </span>
              </div>
              <p className="text-xs text-slate-500 mt-1">
                {fmtDateTime(log.created_at)}
              </p>
            </li>
          ))}
        </ul>
      )}

      {pages > 1 && (
        <div className="flex items-center justify-between mt-4 pt-3 border-t border-slate-100">
          <button
            type="button"
            className="btn-secondary text-xs px-2 py-1"
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            disabled={page <= 1 || loading}
          >
            <ChevronLeft className="w-3.5 h-3.5 inline" /> Prev
          </button>
          <span className="text-xs text-slate-500">
            Page {page} of {pages}
          </span>
          <button
            type="button"
            className="btn-secondary text-xs px-2 py-1"
            onClick={() => setPage((p) => Math.min(pages, p + 1))}
            disabled={page >= pages || loading}
          >
            Next <ChevronRight className="w-3.5 h-3.5 inline" />
          </button>
        </div>
      )}
    </div>
  );
}
