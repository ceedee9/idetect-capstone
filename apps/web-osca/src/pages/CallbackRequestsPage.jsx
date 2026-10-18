import { useEffect, useState } from "react";
import { PhoneCall, Clock, CheckCircle2, Info } from "lucide-react";
import { callbackRequestsAPI } from "../services/api";
import { fmtDateTime, fmtRelative } from "../utils/date";

const STATUS_TABS = [
  { value: "open", label: "Open" },
  { value: "handled", label: "Handled" },
  { value: "", label: "All" },
];

const REASON_LABELS = {
  transaction_question: "Question about a transaction",
  record_correction: "Correction to a record",
  other: "Other",
};

const TYPE_LABELS = { senior_citizen: "Senior Citizen", pwd: "PWD" };

function StatusBadge({ status }) {
  const isOpen = status === "open";
  return (
    <span
      className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold border ${
        isOpen
          ? "bg-blue-50 text-blue-700 border-blue-100"
          : "bg-green-50 text-green-700 border-green-100"
      }`}
    >
      {isOpen ? (
        <Clock className="w-3.5 h-3.5" />
      ) : (
        <CheckCircle2 className="w-3.5 h-3.5" />
      )}
      {isOpen ? "Open" : "Handled"}
    </span>
  );
}

export default function CallbackRequestsPage() {
  const [statusFilter, setStatusFilter] = useState("open");
  const [page, setPage] = useState(1);
  const [rows, setRows] = useState([]);
  const [pages, setPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let active = true;
    const params = { page, limit: 20 };
    if (statusFilter) params.status = statusFilter;

    callbackRequestsAPI
      .list(params)
      .then((res) => {
        if (!active) return;
        setRows(res.data.data ?? []);
        setPages(res.data.pagination?.pages ?? 1);
        setTotal(res.data.pagination?.total ?? 0);
        setError(null);
      })
      .catch((err) => {
        if (active)
          setError(
            err.response?.data?.error || "Failed to load callback requests.",
          );
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
    };
  }, [statusFilter, page]);

  function changeFilter(value) {
    setLoading(true);
    setStatusFilter(value);
    setPage(1);
  }

  function changePage(value) {
    setLoading(true);
    setPage(value);
  }

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 flex items-center gap-2">
            <PhoneCall className="w-6 h-6 text-accent-600" />
            Callback Requests
          </h1>
          <p className="text-sm text-slate-500 mt-1">
            Beneficiaries asking BPLO to contact an establishment they
            transacted with.
          </p>
        </div>
        <div className="inline-flex rounded-lg border border-slate-200 bg-white p-1">
          {STATUS_TABS.map((tab) => (
            <button
              key={tab.value || "all"}
              type="button"
              onClick={() => changeFilter(tab.value)}
              className={`px-3 py-1.5 text-sm font-medium rounded-md ${
                statusFilter === tab.value
                  ? "bg-accent-600 text-white"
                  : "text-slate-600 hover:bg-slate-50"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      <div className="flex items-start gap-2 rounded-lg border border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-600">
        <Info className="w-4 h-4 mt-0.5 shrink-0 text-slate-500" />
        View only. BPLO contacts the establishment and replies to these
        requests.
      </div>

      {error && (
        <div
          role="alert"
          className="rounded-lg border border-danger-100 bg-danger-50 px-4 py-3 text-sm text-danger-700"
        >
          {error}
        </div>
      )}

      {loading ? (
        <div className="py-12 text-center text-sm text-slate-500">Loading…</div>
      ) : rows.length === 0 ? (
        <div className="rounded-xl border border-dashed border-slate-300 bg-white py-12 text-center text-sm text-slate-500">
          No callback requests here.
        </div>
      ) : (
        <ul className="space-y-3">
          {rows.map((r) => (
            <li
              key={r.id}
              className="min-w-0 bg-white rounded-xl border border-slate-200 p-4"
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-mono text-xs text-slate-500">
                      {r.reference}
                    </span>
                    <span className="font-semibold text-slate-900 truncate">
                      {r.beneficiary_name}
                    </span>
                    <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium border bg-slate-50 text-slate-600 border-slate-200">
                      {TYPE_LABELS[r.beneficiary_type] ?? r.beneficiary_type}
                    </span>
                  </div>
                  <p className="mt-1 text-sm text-slate-700 truncate">
                    {r.establishment_name}
                  </p>
                  <p className="text-xs text-slate-500">
                    {REASON_LABELS[r.reason] ?? r.reason}
                  </p>
                  {r.staff_note && (
                    <p className="mt-2 rounded-md bg-slate-50 px-3 py-2 text-sm text-slate-700">
                      <span className="font-medium">BPLO note:</span>{" "}
                      {r.staff_note}
                    </p>
                  )}
                </div>
                <div className="flex shrink-0 flex-col items-end gap-1">
                  <StatusBadge status={r.status} />
                  <span
                    className="text-xs text-slate-500"
                    title={fmtDateTime(r.created_at)}
                  >
                    {fmtRelative(r.created_at)}
                  </span>
                </div>
              </div>
            </li>
          ))}
        </ul>
      )}

      {pages > 1 && (
        <div className="flex flex-wrap items-center justify-between gap-3 text-sm text-slate-600">
          <span>
            {total} request{total === 1 ? "" : "s"}
          </span>
          <div className="flex items-center gap-2">
            <button
              type="button"
              disabled={page <= 1}
              onClick={() => changePage(page - 1)}
              className="px-3 py-1.5 rounded-md border border-slate-200 bg-white disabled:opacity-40"
            >
              Previous
            </button>
            <span>
              Page {page} of {pages}
            </span>
            <button
              type="button"
              disabled={page >= pages}
              onClick={() => changePage(page + 1)}
              className="px-3 py-1.5 rounded-md border border-slate-200 bg-white disabled:opacity-40"
            >
              Next
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
