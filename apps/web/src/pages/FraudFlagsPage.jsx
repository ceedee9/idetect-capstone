import { useState, useEffect, useMemo, useRef } from "react";
import { Link } from "react-router-dom";
import { createPortal } from "react-dom";
import {
  Flag,
  AlertTriangle,
  CheckCircle2,
  XCircle,
  Store,
  User,
  AlertCircle,
  RefreshCw,
  MessageSquare,
  X,
  Eye,
  RotateCcw,
  Trash2,
  Keyboard,
  Maximize2,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";
import {
  fraudFlagsAPI,
  getStaffToken,
  staffAlertsAPI,
} from "../services/api";
import ConfirmModal from "../components/ConfirmModal";
import { fmtDateTime, fmtRelative } from "../utils/date";

// Fetches a protected image URL using the staff JWT and returns a blob URL
// safe to use in <img src>. Revokes the blob URL on cleanup.
function useAuthImage(url) {
  const [blobUrl, setBlobUrl] = useState(null);
  useEffect(() => {
    if (!url) {
      setBlobUrl(null);
      return;
    }
    let cancelled = false;
    const token = getStaffToken();
    fetch(url, token ? { headers: { Authorization: `Bearer ${token}` } } : {})
      .then((r) => {
        if (!r.ok) throw new Error("Failed to load image");
        return r.blob();
      })
      .then((blob) => {
        if (!cancelled) setBlobUrl(URL.createObjectURL(blob));
      })
      .catch(() => {
        if (!cancelled) setBlobUrl(null);
      });
    return () => {
      cancelled = true;
    };
  }, [url]);
  // Revoke previous blob URL when url changes or component unmounts
  useEffect(() => {
    return () => {
      if (blobUrl) URL.revokeObjectURL(blobUrl);
    };
  }, [blobUrl]);
  return blobUrl;
}

import { useState as useLocalState } from "react";

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
      setError(
        err.response?.data?.error ||
          err.response?.data?.message ||
          "Failed to load fraud flags.",
      );
    } finally {
      setLoading(false);
    }
  };

  useState(() => {
    fetch();
  }, []);
  // Trigger on mount via effect
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
      "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-tableHeader text-gov-700 border border-slate-200",
    confirmed:
      "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-danger-50 text-danger-700 border border-danger-100",
    dismissed:
      "inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-100 text-slate-500",
  };
  return <span className={map[status] ?? map.dismissed}>{status ?? "—"}</span>;
}

function OutcomeBadge({ outcome }) {
  const value = outcome?.toLowerCase();
  const tone =
    value === "valid"
      ? "text-semantic-success-700 bg-semantic-success-50 border-semantic-success-200"
      : value === "invalid"
        ? "text-semantic-danger-700 bg-semantic-danger-50 border-semantic-danger-200"
        : "text-semantic-warning-700 bg-semantic-warning-50 border-semantic-warning-200";

  return (
    <span
      className={`inline-flex items-center px-2.5 py-1 rounded-registry-lg border text-xs font-semibold capitalize ${tone}`}
    >
      {outcome ?? "Unknown"}
    </span>
  );
}

function confidenceTone(score) {
  if (score >= 80) {
    return {
      bar: "bg-semantic-success-500",
      text: "text-semantic-success-700",
    };
  }
  if (score >= 50) {
    return {
      bar: "bg-slate-500",
      text: "text-slate-700",
    };
  }
  return {
    bar: "bg-semantic-danger-500",
    text: "text-semantic-danger-700",
  };
}

export default function FraudFlagsPage() {
  const { data: flags, loading, error, refetch } = useFraudFlags();
  const [statusFilter, setStatusFilter] = useState("");
  const [modal, setModal] = useState(null); // { flag, action: 'confirm'|'dismiss'|'restore' }
  const [notes, setNotes] = useState("");
  const [actionLoading, setActionLoading] = useState(false);
  const [actionError, setActionError] = useState("");
  const [toast, setToast] = useState(null);
  const [selectedFlag, setSelectedFlag] = useState(null);
  const [lightboxOpen, setLightboxOpen] = useState(false);
  const [confirmArmed, setConfirmArmed] = useState(false);
  const detailScrollRef = useRef(null);

  // Staff alerts (auto-suspend notifications)
  const [alerts, setAlerts] = useState([]);
  useEffect(() => {
    staffAlertsAPI
      .list()
      .then((res) => setAlerts(res.data?.alerts ?? []))
      .catch(() => {});
  }, []);

  useEffect(() => {
    if (!lightboxOpen) return;
    const handleKeyDown = (event) => {
      if (event.key === "Escape") setLightboxOpen(false);
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [lightboxOpen]);

  async function handleMarkAllRead() {
    await staffAlertsAPI.markAllRead().catch(() => {});
    setAlerts((prev) => prev.map((a) => ({ ...a, is_read: true })));
  }

  // Fetches the flag image via the authenticated /api/uploads/* route.
  // Must be called unconditionally (hooks rule) — returns null when no flag selected.
  const flagImageUrl = useAuthImage(selectedFlag?.image_path ?? null);

  const filtered = useMemo(
    () => flags.filter((f) => !statusFilter || f.status === statusFilter),
    [flags, statusFilter],
  );

  const pendingQueue = useMemo(
    () => flags.filter((flag) => flag.status === "pending"),
    [flags],
  );
  const selectedQueueIndex = selectedFlag
    ? pendingQueue.findIndex((flag) => flag.id === selectedFlag.id)
    : -1;

  function selectFlag(flag) {
    setConfirmArmed(false);
    setSelectedFlag(flag);
  }

  useEffect(() => {
    if (selectedFlag) {
      detailScrollRef.current?.scrollTo({ top: 0, behavior: "auto" });
    }
  }, [selectedFlag?.id]);

  function moveInQueue(direction) {
    if (selectedQueueIndex < 0 || pendingQueue.length < 2) return;
    const nextIndex = selectedQueueIndex + direction;
    if (nextIndex < 0 || nextIndex >= pendingQueue.length) return;
    selectFlag(pendingQueue[nextIndex]);
  }

  useEffect(() => {
    if (!selectedFlag || lightboxOpen) return;
    const handleKeyDown = (event) => {
      if (event.key === "ArrowLeft") {
        event.preventDefault();
        moveInQueue(-1);
      }
      if (event.key === "ArrowRight") {
        event.preventDefault();
        moveInQueue(1);
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [selectedFlag, lightboxOpen, selectedQueueIndex, pendingQueue]);

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
      if (modal.action === "restore") {
        await fraudFlagsAPI.restore(modal.flag.id, notes);
        showToast(
          "Beneficiary restored to active. ID verifications will now return VALID.",
        );
      } else if (modal.action === "delete") {
        await fraudFlagsAPI.delete(modal.flag.id);
        setSelectedFlag(null);
        setLightboxOpen(false);
        showToast("Dismissed fraud flag permanently deleted.");
      } else {
        await fraudFlagsAPI.review(modal.flag.id, modal.action, notes);
        showToast(
          `Flag ${modal.action === "confirm" ? "confirmed — ID blocked as fraudulent" : "dismissed"} successfully.`,
        );
      }
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
    <div className="px-6 lg:px-8 py-8 max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="font-heading font-bold text-2xl text-slate-900">
            Fraud Flags
          </h1>
          <p className="text-slate-500 text-sm mt-0.5 font-medium">
            Suspicious ID reports submitted by registered establishments
          </p>
        </div>
        <button
          onClick={refetch}
          disabled={loading}
          className="btn-secondary self-start"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? "animate-spin" : ""}`} />
          Refresh
        </button>
      </div>

      {error && (
        <div className="flex items-center gap-2.5 px-4 py-3 bg-danger-50 border border-danger-100 rounded-xl text-danger-700 text-sm">
          <AlertCircle className="w-4 h-4 flex-shrink-0" />
          {error}
        </div>
      )}

      {/* Staff alerts — auto-suspend notifications */}
      {alerts.filter((a) => !a.is_read).length > 0 && (
        <div className="space-y-2">
          {alerts
            .filter((a) => !a.is_read)
            .map((alert) => (
              <div
                key={alert.id}
                className="flex items-start gap-3 px-4 py-3 bg-slate-50 border border-slate-200 rounded-registry-lg text-sm text-slate-700"
              >
                <AlertTriangle className="w-4 h-4 flex-shrink-0 mt-0.5 text-slate-500" />
                <div className="flex-1">
                  <p className="font-semibold">{alert.title}</p>
                  <p className="text-slate-600 mt-0.5">{alert.body}</p>
                  <p className="text-slate-500 text-xs mt-1">
                    {fmtRelative(alert.created_at)}
                  </p>
                </div>
              </div>
            ))}
          <button
            onClick={handleMarkAllRead}
            className="text-xs text-slate-600 underline hover:text-slate-800"
          >
            Mark all read
          </button>
        </div>
      )}

      {/* Summary cards */}
      <div className="grid grid-cols-3 gap-4">
        {[
          {
            label: "Pending Review",
            value: counts.pending,
            color: "bg-tableHeader text-gov-700 border border-slate-200",
          },
          {
            label: "Confirmed",
            value: counts.confirmed,
            color: "bg-danger-50 text-danger-700 border border-danger-100",
          },
          {
            label: "Dismissed",
            value: counts.dismissed,
            color: "bg-slate-50 text-slate-500 border border-slate-100",
          },
        ].map(({ label, value, color }) => (
          <div
            key={label}
            className={`rounded-registry-lg border p-4 ${color}`}
          >
            <p className="text-xs font-bold uppercase tracking-wider opacity-70">
              {label}
            </p>
            <p className="font-heading font-bold text-2xl mt-1">
              {loading ? "—" : value}
            </p>
          </div>
        ))}
      </div>

      {/* Status tabs */}
      <div className="flex items-center gap-1 border-b border-slate-200 w-fit">
        {STATUS_TABS.map((tab) => (
          <button
            key={tab.value}
            onClick={() => setStatusFilter(tab.value)}
            className={`px-4 py-2 border-b-2 text-sm font-semibold transition-colors duration-150 flex items-center gap-1.5
              ${statusFilter === tab.value ? "border-gov-600 text-gov-700" : "border-transparent text-slate-500 hover:text-slate-800"}`}
          >
            {tab.label}
            {counts[tab.value] > 0 && (
              <span
                className={`font-mono text-[10px] px-1.5 py-0.5 rounded-registry font-bold
                ${statusFilter === tab.value ? "bg-gov-100 text-gov-700" : "bg-slate-100 text-slate-500"}`}
              >
                {counts[tab.value]}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* Flags list */}
      <div className="space-y-3">
        {loading ? (
          [...Array(4)].map((_, i) => (
            <div key={i} className="card">
              <div className="skeleton h-20 w-full rounded-xl" />
            </div>
          ))
        ) : filtered.length === 0 ? (
          <div className="card text-center py-14">
            <Flag className="w-10 h-10 text-slate-200 mx-auto mb-3" />
            <p className="text-sm font-semibold text-slate-500">
              No fraud flags found
            </p>
            <p className="text-xs text-slate-400 mt-1">
              {statusFilter
                ? "No flags with this status."
                : "No fraud flags have been submitted yet."}
            </p>
          </div>
        ) : (
          filtered.map((flag) => (
            <div
              key={flag.id}
              onClick={() => selectFlag(flag)}
              className="card hover:shadow-card-md transition-shadow duration-200 cursor-pointer"
            >
              <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
                {/* Left: flag details */}
                <div className="flex items-start gap-4 flex-1 min-w-0">
                  <div
                    className={`w-10 h-10 rounded-2xl flex items-center justify-center flex-shrink-0
                    ${flag.status === "pending" ? "bg-tableHeader" : flag.status === "confirmed" ? "bg-semantic-danger-50" : "bg-slate-100"}`}
                  >
                    <AlertTriangle
                      className={`w-5 h-5 ${
                        flag.status === "pending"
                          ? "text-gov-600"
                          : flag.status === "confirmed"
                            ? "text-danger-600"
                            : "text-slate-400"
                      }`}
                    />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap mb-1">
                      <FlagStatusBadge status={flag.status} />
                      {flag.manually_entered && (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 bg-semantic-warning-50 border border-semantic-warning-200 rounded-registry text-[10px] font-semibold text-semantic-warning-700">
                          <Keyboard className="w-2.5 h-2.5" />
                          Manual Entry
                        </span>
                      )}
                    </div>

                    {/* Reference number and age */}
                    <p className="flex items-baseline gap-2 font-mono text-sm font-bold text-slate-900">
                      {flag.reference_no}
                      <span className="font-sans text-xs font-medium text-slate-400">
                        {fmtRelative(flag.created_at)}
                      </span>
                    </p>

                    {/* Establishment */}
                    <div className="flex items-center gap-1.5 mt-1.5 text-xs text-slate-500 font-medium">
                      <Store className="w-3.5 h-3.5 text-slate-400" />
                      <span>
                        Flagged by:{" "}
                        {flag.establishment?.business_name ??
                          `Establishment #${flag.establishment_id}`}
                      </span>
                    </div>

                    {/* Beneficiary link if resolved */}
                    {flag.beneficiary && (
                      <div className="flex items-center gap-1.5 mt-1 text-xs font-medium">
                        <User className="w-3.5 h-3.5 text-gov-500" />
                        <Link
                          to={`/beneficiaries/${flag.beneficiary.id}`}
                          className="text-gov-600 hover:underline"
                        >
                          {flag.beneficiary.first_name}{" "}
                          {flag.beneficiary.last_name}
                        </Link>
                      </div>
                    )}

                    {/* Notes */}
                    {flag.notes && (
                      <div className="flex items-start gap-1.5 mt-2 text-xs text-slate-500">
                        <MessageSquare className="w-3.5 h-3.5 text-slate-400 flex-shrink-0 mt-0.5" />
                        <span className="italic">"{flag.notes}"</span>
                      </div>
                    )}

                    {/* Review notes */}
                    {flag.review_notes && (
                      <div className="mt-2 px-3 py-2 bg-slate-50 rounded-xl text-xs text-slate-600">
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
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-danger-50 text-danger-700 text-xs font-semibold rounded-xl hover:bg-danger-100 transition-colors"
                    >
                      <CheckCircle2 className="w-3.5 h-3.5" />
                      Confirm Fraud
                    </button>
                    <button
                      onClick={() => setModal({ flag, action: "dismiss" })}
                      className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-slate-100 text-slate-600 text-xs font-semibold rounded-xl hover:bg-slate-200 transition-colors"
                    >
                      <XCircle className="w-3.5 h-3.5" />
                      Dismiss
                    </button>
                  </div>
                )}
                {flag.status !== "pending" && (
                  <div className="flex flex-col items-end gap-2 flex-shrink-0">
                    <div className="text-xs text-slate-400 font-medium">
                      Reviewed {fmtDateTime(flag.reviewed_at)}
                    </div>
                    {flag.status === "confirmed" && (
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          setModal({ flag, action: "restore" });
                        }}
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-emerald-50 text-emerald-700 text-xs font-semibold rounded-xl hover:bg-emerald-100 transition-colors"
                      >
                        <RotateCcw className="w-3.5 h-3.5" />
                        Restore to Active
                      </button>
                    )}
                  </div>
                )}
                <Eye className="w-4 h-4 text-slate-300 flex-shrink-0 self-center" />
              </div>
            </div>
          ))
        )}
      </div>

      {/* REQ-2.6.2: Flag Detail Drawer */}
      {selectedFlag && (
        createPortal(
        <div className="fixed inset-0 z-[60] flex items-center justify-center bg-slate-950/35 p-4 sm:p-6">
          <div
            className="absolute inset-0"
            onClick={() => {
              setLightboxOpen(false);
              setSelectedFlag(null);
            }}
          />
          <div className="relative z-10 flex h-[min(760px,calc(100vh-2rem))] min-h-0 w-full max-w-3xl flex-col overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-2xl">
            {/* Drawer Header */}
            <div className="relative flex flex-shrink-0 items-center justify-between px-6 py-4 border-b border-slate-100">
              <div className="flex items-center gap-3">
                <FlagStatusBadge status={selectedFlag.status} />
                <div>
                  <p className="text-xs text-slate-400 uppercase tracking-wide font-semibold">
                    Reference
                  </p>
                  <span className="font-mono font-bold text-slate-900 text-sm">
                    {selectedFlag.reference_no}
                  </span>
                </div>
              </div>
              <div className="flex items-center gap-3">
                {selectedQueueIndex >= 0 && (
                  <div className="flex items-center gap-1.5">
                    <button
                      type="button"
                      onClick={() => moveInQueue(-1)}
                      disabled={selectedQueueIndex === 0}
                      className="inline-flex items-center justify-center rounded-registry border border-slate-200 p-1.5 text-slate-500 hover:bg-slate-100 disabled:cursor-not-allowed disabled:opacity-30"
                      aria-label="Previous pending fraud flag"
                    >
                      <ChevronLeft className="h-4 w-4" />
                    </button>
                    <span className="whitespace-nowrap font-mono text-[10px] font-semibold tabular-nums text-slate-500">
                      {selectedQueueIndex + 1} of {pendingQueue.length} pending
                    </span>
                    <button
                      type="button"
                      onClick={() => moveInQueue(1)}
                      disabled={selectedQueueIndex === pendingQueue.length - 1}
                      className="inline-flex items-center justify-center rounded-registry border border-slate-200 p-1.5 text-slate-500 hover:bg-slate-100 disabled:cursor-not-allowed disabled:opacity-30"
                      aria-label="Next pending fraud flag"
                    >
                      <ChevronRight className="h-4 w-4" />
                    </button>
                  </div>
                )}
                <button
                  onClick={() => {
                    setLightboxOpen(false);
                    setSelectedFlag(null);
                    setConfirmArmed(false);
                  }}
                  className="inline-flex items-center justify-center rounded-registry-lg border border-slate-200 bg-white p-2 hover:bg-slate-100 focus:outline-none focus:ring-2 focus:ring-gov-200"
                  aria-label="Close fraud flag details"
                  title="Close"
                >
                  <X className="w-5 h-5 text-slate-500" />
                </button>
              </div>
            </div>

            <div
              ref={detailScrollRef}
              className="min-h-0 min-w-0 flex-1 space-y-5 overflow-x-hidden overflow-y-auto px-5 py-5 sm:px-8 sm:py-6"
            >
              {/* Tier 1: evidence */}
              <section>
                <div className="flex items-center justify-between mb-2">
                  <h3 className="text-xs font-bold text-slate-400 uppercase tracking-wider">
                    Evidence
                  </h3>
                  {selectedFlag.image_path && (
                    <span className="text-[10px] font-semibold text-slate-400 uppercase tracking-wider">
                      Click image to inspect
                    </span>
                  )}
                </div>
                {selectedFlag.image_path ? (
                  <button
                    type="button"
                    onClick={() => setLightboxOpen(true)}
                    className="group relative block w-full overflow-hidden rounded-registry-lg border border-slate-200 bg-slate-50 focus:outline-none focus:ring-2 focus:ring-gov-300"
                    aria-label="Expand captured ID image"
                  >
                    <img
                      src={flagImageUrl ?? ""}
                      alt="Captured ID"
                      className="block max-h-[16rem] w-full bg-slate-100 object-contain sm:max-h-[20rem]"
                    />
                    <span className="absolute right-3 top-3 inline-flex items-center gap-1.5 rounded-registry-lg bg-slate-900/75 px-2.5 py-1.5 text-xs font-semibold text-white opacity-90 transition-opacity group-hover:bg-slate-900">
                      <Maximize2 className="w-3.5 h-3.5" />
                      Expand
                    </span>
                  </button>
                ) : (
                  <div className="w-full h-40 rounded-registry-lg border border-dashed border-slate-200 flex items-center justify-center text-slate-400 text-xs gap-2">
                    <Eye className="w-4 h-4" /> No image captured
                  </div>
                )}
              </section>

              {/* Tier 2: verdict */}
              <section className="border-y border-slate-200 py-4">
                <div className="flex items-center justify-between gap-4">
                  <div>
                    <p className="text-[10px] font-bold uppercase tracking-wider text-slate-400">
                      Outcome
                    </p>
                    <div className="mt-1">
                      <OutcomeBadge
                        outcome={selectedFlag.verification_outcome}
                      />
                    </div>
                    <div className="mt-3">
                      <p className="text-[10px] font-bold uppercase tracking-wider text-slate-400">
                        ID number
                      </p>
                      <p className="mt-1 font-mono text-sm font-semibold text-slate-900">
                        {selectedFlag.id_number_flagged ??
                          selectedFlag.beneficiary?.id_number ??
                          "Unknown ID"}
                      </p>
                    </div>
                  </div>
                  <div className="min-w-0 flex-1 max-w-[16rem]">
                    <div className="flex items-center justify-between mb-1.5">
                      <p className="text-[10px] font-bold uppercase tracking-wider text-slate-400">
                        Extraction quality
                      </p>
                      {selectedFlag.ocr_confidence_score != null && (
                        <span
                          className={`font-mono text-sm font-semibold tabular-nums ${confidenceTone(selectedFlag.ocr_confidence_score).text}`}
                        >
                          {selectedFlag.ocr_confidence_score}%
                        </span>
                      )}
                    </div>
                    <div className="h-2 w-full overflow-hidden rounded-full bg-slate-100">
                      <div
                        className={`h-full rounded-full transition-all ${confidenceTone(selectedFlag.ocr_confidence_score ?? 0).bar}`}
                        style={{
                          width: `${Math.min(Math.max(selectedFlag.ocr_confidence_score ?? 0, 0), 100)}%`,
                        }}
                      />
                    </div>
                  </div>
                </div>
                {selectedFlag.manually_entered && (
                  <p className="mt-3 text-xs font-semibold text-slate-600">
                    ID number was manually entered rather than scanned.
                  </p>
                )}
              </section>

              {/* Tier 3: supporting context */}
              <section className="space-y-4">
                {selectedFlag.notes && (
                  <blockquote className="min-w-0 break-words border-l-2 border-slate-400 bg-slate-50 px-4 py-3 text-sm leading-relaxed text-slate-700">
                    <p className="text-[10px] font-bold uppercase tracking-wider text-slate-500 mb-1">
                      Flagged reason
                    </p>
                    <p className="italic">“{selectedFlag.notes}”</p>
                  </blockquote>
                )}
                <div className="grid min-w-0 grid-cols-1 gap-2 text-xs text-slate-500 sm:grid-cols-3">
                  <div>
                    <p className="uppercase tracking-wider text-[10px] text-slate-400">
                      Establishment
                    </p>
                    <p className="mt-1 font-medium text-slate-700 truncate">
                      {selectedFlag.establishment?.business_name ?? "—"}
                    </p>
                  </div>
                  <div>
                    <p className="uppercase tracking-wider text-[10px] text-slate-400">
                      Transaction time
                    </p>
                    <p className="mt-1 font-mono text-[11px] text-slate-700 tabular-nums">
                      {fmtDateTime(
                        selectedFlag.transaction_timestamp ??
                          selectedFlag.flagged_at,
                      )}
                    </p>
                  </div>
                  <div>
                    <p className="uppercase tracking-wider text-[10px] text-slate-400">
                      Transaction ref.
                    </p>
                    <p className="mt-1 font-mono text-[11px] text-slate-700 tabular-nums truncate">
                      {selectedFlag.verification_reference_no ?? "—"}
                    </p>
                  </div>
                  <div>
                    <p className="uppercase tracking-wider text-[10px] text-slate-400">
                      Reference code
                    </p>
                    <p className="mt-1 font-mono text-[11px] text-slate-700 tabular-nums truncate">
                      {selectedFlag.reference_no}
                    </p>
                  </div>
                </div>
              </section>

              {/* OCR Extracted Data */}
              {selectedFlag.ocr_data_available && (
                <details className="group border-t border-slate-200 pt-3">
                  <summary className="cursor-pointer list-none text-xs font-semibold text-slate-500 hover:text-slate-700">
                    <span className="flex items-center justify-between">
                      OCR extracted data
                      <span className="text-[10px] uppercase tracking-wider text-slate-400 group-open:hidden">
                        Show
                      </span>
                      <span className="hidden text-[10px] uppercase tracking-wider text-slate-400 group-open:inline">
                        Hide
                      </span>
                    </span>
                  </summary>
                  <p className="mt-2 bg-slate-50 border border-slate-200 rounded-registry-lg p-3 text-xs text-slate-600">
                    OCR data is retained for restricted review and is not
                    displayed in the ordinary fraud-flag view.
                  </p>
                </details>
              )}

              {/* Supplementary notice */}
              {selectedFlag.is_supplementary && (
                <div className="bg-slate-50 border border-slate-200 rounded-registry-lg px-4 py-3 text-xs text-slate-600 font-medium">
                  This is a supplementary report linked to an existing active
                  investigation.
                </div>
              )}

              {/* Review notes */}
              {selectedFlag.review_notes && (
                <details className="group border-t border-slate-200 pt-3">
                  <summary className="cursor-pointer list-none text-xs font-semibold text-slate-500 hover:text-slate-700">
                    <span className="flex items-center justify-between">
                      Review notes
                      <span className="text-[10px] uppercase tracking-wider text-slate-400 group-open:hidden">
                        Show
                      </span>
                      <span className="hidden text-[10px] uppercase tracking-wider text-slate-400 group-open:inline">
                        Hide
                      </span>
                    </span>
                  </summary>
                  <p className="mt-2 text-sm text-slate-700 bg-slate-50 border border-slate-200 rounded-registry-lg px-4 py-3">
                    {selectedFlag.review_notes}
                  </p>
                </details>
              )}
            </div>

            {/* Drawer Footer Actions */}
            {selectedFlag.status === "pending" && (
              <div className="flex flex-shrink-0 justify-center gap-3 border-t border-slate-200 bg-white px-5 py-4 sm:px-8">
                <button
                  onClick={() => {
                    if (confirmArmed) {
                      setModal({ flag: selectedFlag, action: "confirm" });
                      setConfirmArmed(false);
                    } else {
                      setConfirmArmed(true);
                    }
                  }}
                  className={`inline-flex min-w-0 flex-1 items-center justify-center gap-1.5 rounded-registry-lg px-4 py-2.5 text-sm font-semibold transition-colors ${confirmArmed ? "bg-danger-700 text-white ring-2 ring-danger-200" : "bg-semantic-danger-600 text-white hover:bg-semantic-danger-700"}`}
                >
                  <CheckCircle2 className="w-4 h-4" />
                  {confirmArmed ? "Click again to confirm" : "Confirm Fraud"}
                </button>
                <button
                  onClick={() => {
                    setConfirmArmed(false);
                    setModal({ flag: selectedFlag, action: "dismiss" });
                  }}
                  className="inline-flex min-w-0 flex-1 items-center justify-center gap-1.5 rounded-registry-lg border border-slate-300 bg-white px-4 py-2.5 text-sm font-semibold text-slate-700 transition-colors hover:bg-slate-100"
                >
                  <XCircle className="w-4 h-4" /> Dismiss
                </button>
              </div>
            )}
            {selectedFlag.status === "confirmed" && (
              <div className="px-6 py-4 border-t border-slate-100">
                <button
                  onClick={() =>
                    setModal({ flag: selectedFlag, action: "restore" })
                  }
                  className="w-full inline-flex items-center justify-center gap-2 px-4 py-2.5 bg-emerald-600 text-white text-sm font-semibold rounded-xl hover:bg-emerald-700 transition-colors"
                >
                  <RotateCcw className="w-4 h-4" /> Restore to Active (Dispute
                  Resolved)
                </button>
              </div>
            )}
            {selectedFlag.status === "dismissed" && (
              <div className="flex flex-shrink-0 justify-end border-t border-slate-200 bg-white px-5 py-4 sm:px-8">
                <button
                  onClick={() =>
                    setModal({ flag: selectedFlag, action: "delete" })
                  }
                  className="inline-flex items-center justify-center gap-2 rounded-registry-lg border border-danger-200 bg-danger-50 px-4 py-2.5 text-sm font-semibold text-danger-700 transition-colors hover:bg-danger-100"
                >
                  <Trash2 className="h-4 w-4" />
                  Delete permanently
                </button>
              </div>
            )}
          </div>
        </div>,
        document.body,
        )
      )}

      {lightboxOpen && selectedFlag && flagImageUrl && (
        <div
          className="fixed inset-0 z-[80] flex items-center justify-center bg-slate-950/90 p-4 sm:p-8"
          onClick={() => setLightboxOpen(false)}
          role="dialog"
          aria-modal="true"
          aria-label="Expanded captured ID image"
        >
          <button
            type="button"
            onClick={() => setLightboxOpen(false)}
            className="absolute right-4 top-4 inline-flex items-center justify-center rounded-registry-lg border border-white/20 bg-white/10 p-2 text-white hover:bg-white/20 focus:outline-none focus:ring-2 focus:ring-white/50"
            aria-label="Close expanded image"
          >
            <X className="h-5 w-5" />
          </button>
          <img
            src={flagImageUrl}
            alt="Expanded captured ID"
            className="max-h-full max-w-full object-contain"
            onClick={(event) => event.stopPropagation()}
          />
        </div>
      )}

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
        description={`Confirm this report as legitimate fraud? The beneficiary's ID will be immediately blocked — future verifications will return INVALID.`}
        confirmLabel="Confirm Fraud"
        variant="danger"
        loading={actionLoading}
      >
        <div className="mt-1">
          <label className="label text-xs">Review notes (optional)</label>
          <input
            type="text"
            className="input text-sm"
            placeholder="e.g. ID visually altered, duplicate registration found…"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
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
          <label className="label text-xs">Review notes (optional)</label>
          <input
            type="text"
            className="input text-sm"
            placeholder="e.g. ID verified as authentic, false report…"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
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

      {/* Restore modal */}
      <ConfirmModal
        open={modal?.action === "delete"}
        onClose={() => {
          setModal(null);
          setActionError("");
        }}
        onConfirm={handleAction}
        title="Permanently Delete Fraud Flag?"
        description="This will permanently remove the dismissed fraud flag, its review details, and its list entry. This action cannot be undone. The deletion will remain recorded in the audit log."
        confirmLabel="Delete Permanently"
        variant="danger"
        loading={actionLoading}
      >
        {actionError && (
          <p className="text-sm text-danger-600 flex items-center gap-1.5 mt-3">
            <AlertCircle className="w-4 h-4" />
            {actionError}
          </p>
        )}
      </ConfirmModal>

      <ConfirmModal
        open={modal?.action === "restore"}
        onClose={() => {
          setModal(null);
          setActionError("");
          setNotes("");
        }}
        onConfirm={handleAction}
        title="Restore Beneficiary to Active"
        description="A successful dispute has been filed? This will restore the beneficiary's ID to active status — future verifications will return VALID again."
        confirmLabel="Restore to Active"
        variant="primary"
        loading={actionLoading}
      >
        <div className="mt-1">
          <label className="label text-xs">
            Dispute resolution notes (optional)
          </label>
          <input
            type="text"
            className="input text-sm"
            placeholder="e.g. Identity confirmed via in-person interview, dispute resolved…"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
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
          className="fixed bottom-6 right-6 z-50 px-4 py-3 rounded-2xl shadow-card-lg text-sm font-semibold
          flex items-center gap-2 bg-gov-700 text-white"
          style={{ animation: "slideUp 0.2s ease-out" }}
        >
          <CheckCircle2 className="w-4 h-4" />
          {toast}
        </div>
      )}
    </div>
  );
}
