// Seal mark: 16px stamp icon used inside status badges. Dashed outer ring +
// solid inner ring + a small glyph, echoing an official ink stamp rather than
// a generic colored dot. Uses currentColor so it inherits the badge's tone.
function SealMark({ variant }) {
  return (
    <svg
      viewBox="0 0 20 20"
      className="w-4 h-4 flex-shrink-0"
      aria-hidden="true"
    >
      <circle
        cx="10"
        cy="10"
        r="9"
        fill="none"
        stroke="currentColor"
        strokeWidth="1"
        strokeDasharray="1.4 2.2"
        opacity="0.55"
      />
      <circle
        cx="10"
        cy="10"
        r="6.3"
        fill="none"
        stroke="currentColor"
        strokeWidth="1"
      />
      {variant === "check" && (
        <path
          d="M6.6 10.2l2.1 2.1 4.2-4.5"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      )}
      {variant === "x" && (
        <path
          d="M7.4 7.4l5.2 5.2M12.6 7.4l-5.2 5.2"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinecap="round"
        />
      )}
      {variant === "dot" && (
        <circle cx="10" cy="10" r="1.8" fill="currentColor" />
      )}
      {variant === "dash" && (
        <line
          x1="7"
          y1="10"
          x2="13"
          y2="10"
          stroke="currentColor"
          strokeWidth="1.6"
          strokeLinecap="round"
        />
      )}
    </svg>
  );
}

const MAP = {
  active: { tone: "success", variant: "check", label: "Active" },
  approved: { tone: "success", variant: "check", label: "Approved" },
  inactive: { tone: "slate", variant: "dash", label: "Inactive" },
  expired: { tone: "slate", variant: "dash", label: "Expired" },
  suspended: { tone: "danger", variant: "x", label: "Suspended" },
  revoked: { tone: "danger", variant: "x", label: "Revoked" },
  pending: { tone: "warn", variant: "dot", label: "Pending" },
};

// If your Tailwind config doesn't have a 100-shade ring color for one of
// these tokens, swap that entry's ring-*-100 for ring-*-200 — same idea,
// just needs a shade that exists in your palette.
const TONE_CLS = {
  success:
    "text-semantic-success-700 bg-semantic-success-50 ring-semantic-success-100",
  warn: "text-semantic-warning-700 bg-semantic-warning-50 ring-semantic-warning-100",
  danger:
    "text-semantic-danger-700 bg-semantic-danger-50 ring-semantic-danger-100",
  slate:
    "text-semantic-neutral-600 bg-semantic-neutral-50 ring-semantic-neutral-200",
};

export default function StatusBadge({ status }) {
  const cfg = MAP[status?.toLowerCase()] ?? {
    tone: "slate",
    variant: "dash",
    label: status ?? "—",
  };
  const cls = TONE_CLS[cfg.tone];

  return (
    <span
      className={`inline-flex items-center gap-1.5 pl-1 pr-2.5 py-1 rounded-full ring-1 text-xs font-semibold ${cls}`}
    >
      <SealMark variant={cfg.variant} />
      {cfg.label}
    </span>
  );
}
