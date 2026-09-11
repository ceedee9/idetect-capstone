// Single source of truth for status/tone colors used across StatusBadge,
// StatCard, and the chart components. Tailwind classes drive badges and UI
// chrome; hex values drive SVG/recharts fills, which can't resolve Tailwind
// classes. Keep these two in sync — if you change a Tailwind shade, update
// the matching hex here too.
export const STATUS_TONES = {
  success: {
    label: "Approved",
    tw: "text-semantic-success-700 bg-semantic-success-50 ring-semantic-success-100",
    hex: "#2F8F5B",
  },
  warn: {
    label: "Pending",
    tw: "text-semantic-warning-700 bg-semantic-warning-50 ring-semantic-warning-100",
    hex: "#92560A",
  },
  danger: {
    label: "Suspended",
    tw: "text-semantic-danger-700 bg-semantic-danger-50 ring-semantic-danger-100",
    hex: "#922F2A",
  },
  slate: {
    label: "Inactive",
    tw: "text-semantic-neutral-600 bg-semantic-neutral-50 ring-semantic-neutral-200",
    hex: "#625E58",
  },
  gov: {
    label: "Gov",
    tw: "text-gov-700 bg-gov-50 ring-gov-100",
    hex: "#16233F",
  },
};
