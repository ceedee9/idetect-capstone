// Palette per accent. `stroke` is a plain hex because SVG polylines can't
// resolve Tailwind classes — pick these to roughly match each token's
// 600/700 shade in your Tailwind config; adjust if they drift.
const PALETTE = {
  gov: {
    bar: "bg-gov-600",
    iconBg: "bg-gov-50",
    iconBorder: "border-gov-200",
    iconText: "text-gov-700",
    stroke: "#16233F",
  },
  osca: {
    bar: "bg-osca-600",
    iconBg: "bg-osca-50",
    iconBorder: "border-osca-200",
    iconText: "text-osca-700",
    stroke: "#6B4E0F",
  },
  pdao: {
    bar: "bg-pdao-600",
    iconBg: "bg-pdao-50",
    iconBorder: "border-pdao-200",
    iconText: "text-pdao-700",
    stroke: "#443C9E",
  },
  warm: {
    bar: "bg-accent-600",
    iconBg: "bg-accent-50",
    iconBorder: "border-accent-200",
    iconText: "text-accent-700",
    stroke: "#c2790a",
  },
  green: {
    bar: "bg-success-600",
    iconBg: "bg-success-50",
    iconBorder: "border-success-200",
    iconText: "text-success-700",
    stroke: "#3b6d11",
  },
  red: {
    bar: "bg-danger-600",
    iconBg: "bg-danger-50",
    iconBorder: "border-danger-200",
    iconText: "text-danger-700",
    stroke: "#a32d2d",
  },
  slate: {
    bar: "bg-slate-400",
    iconBg: "bg-slate-100",
    iconBorder: "border-slate-200",
    iconText: "text-slate-600",
    stroke: "#5f5e5a",
  },
};

function toSparklinePoints(values) {
  const max = Math.max(...values);
  const min = Math.min(...values);
  const range = max - min || 1;
  return values
    .map((v, i) => {
      const x = (i / (values.length - 1)) * 100;
      const y = 22 - ((v - min) / range) * 20;
      return `${x},${y}`;
    })
    .join(" ");
}

export default function StatCard({
  label,
  value,
  icon: Icon,
  color = "gov",
  sub,
  trend, // optional: number[] — e.g. last 7-14 days, renders a sparkline
  loading,
}) {
  const c = PALETTE[color] ?? PALETTE.gov;

  if (loading) {
    return (
      <div className="card relative overflow-hidden">
        <div className="skeleton h-3.5 w-24 mb-4" />
        <div className="skeleton h-9 w-16 mb-2" />
        <div className="skeleton h-3 w-20" />
      </div>
    );
  }

  const points = trend && trend.length > 1 ? toSparklinePoints(trend) : null;

  return (
    <div className="card relative overflow-hidden hover:shadow-card-md transition-shadow duration-200">
      <span
        className={`absolute left-0 top-0 h-full w-[3px] ${c.bar}`}
        aria-hidden="true"
      />
      <div className="flex items-start justify-between pl-2">
        <div className="min-w-0">
          <p className="text-xs font-bold text-slate-400 uppercase tracking-wider">
            {label}
          </p>
          <p className="font-heading font-semibold text-3xl text-slate-900 mt-1.5 tabular-nums">
            {value ?? "—"}
          </p>
          {sub && (
            <p className="text-xs text-slate-400 mt-1 font-medium">{sub}</p>
          )}
        </div>
        {Icon && (
          <div
            className={`w-10 h-10 rounded-lg border flex items-center justify-center flex-shrink-0 ${c.iconBg} ${c.iconBorder}`}
          >
            <Icon className={`w-4.5 h-4.5 ${c.iconText}`} />
          </div>
        )}
      </div>
      {points && (
        <svg
          viewBox="0 0 100 24"
          className="w-full h-6 mt-3 pl-2"
          preserveAspectRatio="none"
          aria-hidden="true"
        >
          <polyline
            points={points}
            fill="none"
            stroke={c.stroke}
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      )}
    </div>
  );
}
