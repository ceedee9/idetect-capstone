// Single source of truth for status/tone colors used across StatusBadge,
// StatCard, and the chart components. Tailwind classes drive badges and UI
// chrome; hex values drive SVG/recharts fills, which can't resolve Tailwind
// classes. Keep these two in sync — if you change a Tailwind shade, update
// the matching hex here too.
export const STATUS_TONES = {
  success: {
    label: "Approved",
    tw: "text-success-700 bg-success-50 ring-success-100",
    hex: "#3b6d11",
  },
  warn: {
    label: "Pending",
    tw: "text-warn-700 bg-warn-50 ring-warn-100",
    hex: "#a5680b",
  },
  danger: {
    label: "Suspended",
    tw: "text-danger-700 bg-danger-50 ring-danger-100",
    hex: "#a32d2d",
  },
  slate: {
    label: "Inactive",
    tw: "text-slate-600 bg-slate-50 ring-slate-200",
    hex: "#5f5e5a",
  },
  gov: {
    label: "Gov",
    tw: "text-gov-700 bg-gov-50 ring-gov-100",
    hex: "#16233F",
  },
};
