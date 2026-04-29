export default function StatCard({
  label,
  value,
  icon: Icon,
  color = "osca",
  sub,
  loading,
}) {
  const colors = {
    osca: "bg-osca-50 text-osca-700",
    teal: "bg-gov-50 text-gov-700",
    warm: "bg-accent-50 text-accent-700",
    green: "bg-success-50 text-success-700",
    red: "bg-danger-50 text-danger-700",
    slate: "bg-slate-100 text-slate-600",
  };
  if (loading)
    return (
      <div className="card">
        <div className="skeleton h-3.5 w-24 mb-4" />
        <div className="skeleton h-9 w-16 mb-2" />
        <div className="skeleton h-3 w-20" />
      </div>
    );
  return (
    <div className="card hover:shadow-card-md transition-shadow duration-200">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-xs font-bold text-slate-400 uppercase tracking-wider">
            {label}
          </p>
          <p className="font-heading font-bold text-3xl text-slate-900 mt-1.5">
            {value ?? "—"}
          </p>
          {sub && (
            <p className="text-xs text-slate-400 mt-1 font-medium">{sub}</p>
          )}
        </div>
        {Icon && (
          <div
            className={`w-11 h-11 rounded-2xl flex items-center justify-center ${colors[color]}`}
          >
            <Icon className="w-5 h-5" />
          </div>
        )}
      </div>
    </div>
  );
}
