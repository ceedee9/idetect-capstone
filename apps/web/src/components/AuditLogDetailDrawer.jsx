// src/components/AuditLogDetailDrawer.jsx
// Right-side slide-over panel showing full details for a single audit log
// entry. Opens when a row is clicked in AuditLogsPage; closes on backdrop
// click, the X button, or Escape.

import { useEffect } from "react";
import { X, Calendar, User, Building2, Tag } from "lucide-react";
import { fmtDateTime } from "../utils/date";
import {
  humanizeAuditLog,
  formatMetadataEntries,
  actionLabel,
  formatAffectedRecord,
} from "../utils/auditLog";

export default function AuditLogDetailDrawer({ log, onClose }) {
  const isOpen = !!log;

  // Close on Escape key
  useEffect(() => {
    if (!isOpen) return;
    function handleKey(e) {
      if (e.key === "Escape") onClose();
    }
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [isOpen, onClose]);

  const entries = isOpen ? formatMetadataEntries(log.metadata) : [];

  return (
    <>
      {/* Backdrop */}
      <div
        onClick={onClose}
        className={`fixed inset-0 bg-slate-900/30 z-40 transition-opacity duration-200 ${
          isOpen
            ? "opacity-100 pointer-events-auto"
            : "opacity-0 pointer-events-none"
        }`}
      />

      {/* Panel */}
      <div
        className={`fixed top-0 right-0 h-full w-full sm:w-[420px] bg-white z-50 shadow-2xl
          transition-transform duration-200 ease-out flex flex-col
          ${isOpen ? "translate-x-0" : "translate-x-full"}`}
      >
        {isOpen && (
          <>
            {/* Header */}
            <div className="flex items-start justify-between px-5 py-4 border-b border-slate-100">
              <div>
                <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-1">
                  Audit Log Entry
                </p>
                <h2 className="font-heading font-bold text-lg text-slate-900">
                  {actionLabel(log.action)}
                </h2>
              </div>
              <button
                onClick={onClose}
                className="p-1.5 rounded-lg hover:bg-slate-100 transition-colors"
                aria-label="Close"
              >
                <X className="w-4 h-4 text-slate-500" />
              </button>
            </div>

            {/* Body */}
            <div className="flex-1 overflow-y-auto px-5 py-4 space-y-5">
              {/* Plain-language summary */}
              <div className="bg-slate-50 rounded-xl p-4 text-sm text-slate-700 leading-relaxed">
                {humanizeAuditLog(log)}
              </div>

              {/* Metadata rows: date / user / establishment / target */}
              <div className="space-y-3">
                <div className="flex items-start gap-2.5 text-sm">
                  <Calendar className="w-4 h-4 text-slate-400 mt-0.5 flex-shrink-0" />
                  <div>
                    <p className="text-xs text-slate-400 font-medium">Date</p>
                    <p className="text-slate-700">
                      {fmtDateTime(log.created_at)}
                    </p>
                  </div>
                </div>

                <div className="flex items-start gap-2.5 text-sm">
                  <User className="w-4 h-4 text-slate-400 mt-0.5 flex-shrink-0" />
                  <div>
                    <p className="text-xs text-slate-400 font-medium">User</p>
                    <p className="text-slate-700">
                      {log.user_name || "System"}
                    </p>
                  </div>
                </div>

                {log.establishment_name && (
                  <div className="flex items-start gap-2.5 text-sm">
                    <Building2 className="w-4 h-4 text-slate-400 mt-0.5 flex-shrink-0" />
                    <div>
                      <p className="text-xs text-slate-400 font-medium">
                        Establishment
                      </p>
                      <p className="text-slate-700">{log.establishment_name}</p>
                    </div>
                  </div>
                )}

                {formatAffectedRecord(log) && (
                  <div className="flex items-start gap-2.5 text-sm">
                    <Tag className="w-4 h-4 text-slate-400 mt-0.5 flex-shrink-0" />
                    <div>
                      <p className="text-xs text-slate-400 font-medium">
                        Affected record
                      </p>
                      <p className="text-slate-700 text-xs">
                        {formatAffectedRecord(log)}
                      </p>
                    </div>
                  </div>
                )}
              </div>

              {/* Full metadata breakdown */}
              {entries.length > 0 && (
                <div>
                  <p className="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-2">
                    Full Details
                  </p>
                  <div className="border border-slate-100 rounded-xl overflow-hidden divide-y divide-slate-100">
                    {entries.map(({ label, value }) => (
                      <div
                        key={label}
                        className="flex items-start gap-3 px-3.5 py-2.5 text-sm"
                      >
                        <span className="text-slate-400 w-2/5 flex-shrink-0">
                          {label}
                        </span>
                        <span className="text-slate-700 break-words">
                          {value}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </>
        )}
      </div>
    </>
  );
}
