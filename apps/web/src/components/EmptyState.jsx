import { Link } from "react-router-dom";

const TONES = {
  gov: {
    surface: "bg-gov-50",
    icon: "text-gov-600",
    title: "text-gov-800",
    body: "text-slate-500",
    action: "text-gov-700 hover:text-gov-800",
  },
  osca: {
    surface: "bg-osca-50",
    icon: "text-osca-600",
    title: "text-osca-800",
    body: "text-slate-500",
    action: "text-osca-700 hover:text-osca-800",
  },
  pdao: {
    surface: "bg-pdao-50",
    icon: "text-pdao-600",
    title: "text-pdao-800",
    body: "text-slate-500",
    action: "text-pdao-700 hover:text-pdao-800",
  },
};

export default function EmptyState({
  icon: Icon,
  tone = "gov",
  title,
  description,
  action,
}) {
  const colors = TONES[tone] ?? TONES.gov;

  return (
    <div className="flex flex-col items-center justify-center text-center py-10 px-6">
      <div
        className={`w-10 h-10 ${colors.surface} ${colors.icon} rounded-registry-lg flex items-center justify-center mb-3`}
      >
        {Icon && (
          <Icon className="w-5 h-5" strokeWidth={1.8} aria-hidden="true" />
        )}
      </div>
      <p className={`text-sm font-semibold ${colors.title}`}>{title}</p>
      {description && (
        <p className={`text-xs mt-1 max-w-xs leading-relaxed ${colors.body}`}>
          {description}
        </p>
      )}
      {action && (
        <Link
          to={action.to}
          className={`mt-3 text-xs font-semibold underline underline-offset-2 ${colors.action}`}
        >
          {action.label}
        </Link>
      )}
    </div>
  );
}
