import { useEffect, useState } from "react";
import { PhoneCall, Clock, CheckCircle2, X } from "lucide-react";
import { callbackRequestsAPI } from "../services/api";
import { useAuth } from "../context/AuthContext";
import { fmtDateTime, fmtRelative } from "../utils/date";

const BPLO_ROLES = ["bplo_admin", "bplo_super_admin"];

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

const STAFF_NOTE_MAX = 300;

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

function TypeBadge({ type }) {
  return (
    <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium border bg-slate-50 text-slate-600 border-slate-200">
      {TYPE_LABELS[type] ?? type}
    </span>
  );
}

function CallbackRequestModal({ request, canEdit, onClose, onSaved }) {
  const [status, setStatus] = useState(request.status);
  const [staffNote, setStaffNote] = useState(request.staff_note ?? "");
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState(null);

  const trimmedNote = staffNote.trim();
  const changed =
    status !== request.status || trimmedNote !== (request.staff_note ?? "");

  async function save(e) {
    e.preventDefault();
    setSaving(true);
    setFormError(null);
    try {
      await callbackRequestsAPI.update(request.id, {
        status,
        staff_note: trimmedNote,
      });
      onSaved();
    } catch (err) {
      setFormError(
        err.response?.data?.error ||
          err.response?.data?.errors?.[0]?.msg ||
          "Could not save. Please try again.",
      );
      setSaving(false);
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 p-4"
      onClick={onClose}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="callback-modal-title"
        className="w-full max-w-lg max-h-[90vh] overflow-y-auto rounded-2xl bg-white shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between gap-4 border-b border-slate-100 px-6 py-4">
          <div className="min-w-0">
            <p className="font-mono text-xs text-slate-500">
              {request.reference}
            </p>
            <h2
              id="callback-modal-title"
              className="text-lg font-semibold text-slate-900 truncate"
            >
              {request.beneficiary_name}
            </h2>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close"
            className="p-1.5 rounded-md text-slate-400 hover:bg-slate-100"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="px-6 py-5 space-y-5">
          <dl className="grid grid-cols-2 gap-4 text-sm">
            <div className="col-span-2">
              <dt className="text-xs text-slate-500">Establishment</dt>
              <dd className="font-medium text-slate-900">
                {request.establishment_name}
              </dd>
            </div>
            <div>
              <dt className="text-xs text-slate-500">Beneficiary type</dt>
              <dd>
                <TypeBadge type={request.beneficiary_type} />
              </dd>
            </div>
            <div>
              <dt className="text-xs text-slate-500">Reason</dt>
              <dd className="text-slate-900">
                {REASON_LABELS[request.reason] ?? request.reason}
              </dd>
            </div>
            <div>
              <dt className="text-xs text-slate-500">Submitted</dt>
              <dd className="text-slate-900">
                {fmtDateTime(request.created_at)}
              </dd>
            </div>
            {request.handled_at && (
              <div>
                <dt className="text-xs text-slate-500">Handled</dt>
                <dd className="text-slate-900">
                  {fmtDateTime(request.handled_at)}
                  {request.handled_by_email
                    ? ` by ${request.handled_by_email}`
                    : ""}
                </dd>
              </div>
            )}
          </dl>

          <div className="rounded-lg bg-slate-50 px-4 py-3 text-sm">
            <p className="text-xs text-slate-500 mb-1">Beneficiary's note</p>
            <p className="text-slate-700 whitespace-pre-wrap">
              {request.note || "No note added."}
            </p>
          </div>

          {canEdit ? (
            <form onSubmit={save} className="space-y-5">
              <div>
                <label
                  htmlFor="callback-status"
                  className="block text-sm font-medium text-slate-700 mb-1"
                >
                  Status
                </label>
                <select
                  id="callback-status"
                  value={status}
                  onChange={(e) => setStatus(e.target.value)}
                  className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
                >
                  <option value="open">Open</option>
                  <option value="handled">Handled</option>
                </select>
              </div>

              <div>
                <div className="flex items-center justify-between mb-1">
                  <label
                    htmlFor="callback-note"
                    className="text-sm font-medium text-slate-700"
                  >
                    Note to beneficiary
                  </label>
                  <span className="text-xs text-slate-500">
                    {staffNote.length}/{STAFF_NOTE_MAX}
                  </span>
                </div>
                <textarea
                  id="callback-note"
                  rows={3}
                  maxLength={STAFF_NOTE_MAX}
                  value={staffNote}
                  onChange={(e) => setStaffNote(e.target.value)}
                  placeholder="e.g. Called the establishment on 18 Oct. They confirmed the record."
                  className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
                />
                <p className="mt-1 text-xs text-slate-500">
                  The beneficiary sees this in their app. Do not include contact
                  details.
                </p>
              </div>

              {formError && (
                <p role="alert" className="text-sm text-danger-700">
                  {formError}
                </p>
              )}

              <div className="flex justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={onClose}
                  className="px-4 py-2 text-sm rounded-lg border border-slate-200 text-slate-700 hover:bg-slate-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={!changed || saving}
                  className="px-4 py-2 text-sm rounded-lg bg-accent-600 text-white hover:bg-accent-700 disabled:opacity-40"
                >
                  {saving ? "Saving…" : "Save"}
                </button>
              </div>
            </form>
          ) : (
            <>
              <div className="rounded-lg border border-slate-200 px-4 py-3 text-sm space-y-2">
                <div className="flex items-center justify-between">
                  <span className="text-xs text-slate-500">Status</span>
                  <StatusBadge status={request.status} />
                </div>
                <div>
                  <p className="text-xs text-slate-500 mb-1">BPLO reply</p>
                  <p className="text-slate-700 whitespace-pre-wrap">
                    {request.staff_note || "No reply yet."}
                  </p>
                </div>
              </div>
              <div className="flex justify-end">
                <button
                  type="button"
                  onClick={onClose}
                  className="px-4 py-2 text-sm rounded-lg border border-slate-200 text-slate-700 hover:bg-slate-50"
                >
                  Close
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

export default function CallbackRequestsPage() {
  const { user } = useAuth();
  const canEdit = BPLO_ROLES.includes(user?.role);
  const [statusFilter, setStatusFilter] = useState("open");
  const [page, setPage] = useState(1);
  const [rows, setRows] = useState([]);
  const [pages, setPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [selected, setSelected] = useState(null);
  const [reloadKey, setReloadKey] = useState(0);

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
  }, [statusFilter, page, reloadKey]);

  function changeFilter(value) {
    setLoading(true);
    setStatusFilter(value);
    setPage(1);
  }

  function changePage(value) {
    setLoading(true);
    setPage(value);
  }

  function handleSaved() {
    setSelected(null);
    setLoading(true);
    setReloadKey((k) => k + 1);
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center gap-3">
        <div className="p-2.5 bg-accent-100 rounded-xl">
          <PhoneCall className="w-6 h-6 text-accent-600" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-slate-900">Callback Requests</h1>
          <p className="text-sm text-slate-500">
            {canEdit
              ? "Beneficiaries asking BPLO to contact an establishment they transacted with."
              : "Callback requests for your beneficiary type. View only."}
          </p>
        </div>
      </div>

      <div className="flex gap-1 p-1 bg-slate-100 rounded-lg w-fit">
        {STATUS_TABS.map((tab) => (
          <button
            key={tab.value || "all"}
            type="button"
            onClick={() => changeFilter(tab.value)}
            className={`px-3 py-1.5 text-sm font-medium rounded-md transition-colors ${
              statusFilter === tab.value
                ? "bg-white text-slate-800 shadow-sm"
                : "text-slate-500 hover:text-slate-700"
            }`}
          >
            {tab.label}
          </button>
        ))}
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
            <li key={r.id}>
              <button
                type="button"
                onClick={() => setSelected(r)}
                className="w-full min-w-0 text-left bg-white rounded-xl border border-slate-200 p-4 hover:border-accent-300 hover:shadow-sm transition"
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
                      <TypeBadge type={r.beneficiary_type} />
                    </div>
                    <p className="mt-1 text-sm text-slate-700 truncate">
                      {r.establishment_name}
                    </p>
                    <p className="text-xs text-slate-500">
                      {REASON_LABELS[r.reason] ?? r.reason}
                    </p>
                    {r.note && (
                      <p className="mt-2 text-sm text-slate-600 line-clamp-2">
                        “{r.note}”
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
              </button>
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

      {selected && (
        <CallbackRequestModal
          request={selected}
          canEdit={canEdit}
          onClose={() => setSelected(null)}
          onSaved={handleSaved}
        />
      )}
    </div>
  );
}
