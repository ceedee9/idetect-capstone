import { useMemo } from "react";
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer } from "recharts";

// Gov-blue for approved, amber for pending, danger for suspended
const STATUS_META = {
  Approved: { color: "#0038f5" }, // gov-600
  Pending: { color: "#b45309" }, // warn-700
  Suspended: { color: "#b91c1c" }, // danger-700
};

function CustomTooltip({ active, payload }) {
  if (!active || !payload?.length) return null;
  const { name, value } = payload[0];
  return (
    <div className="bg-white border border-slate-200 rounded-xl shadow-card px-3 py-2 text-xs">
      <p className="font-semibold text-slate-700">{name}</p>
      <p className="text-slate-900 font-bold mt-0.5">{value} establishments</p>
    </div>
  );
}

export default function EstablishmentStatusDonut({ stats }) {
  const data = useMemo(
    () =>
      [
        { name: "Approved", value: stats.approved ?? 0 },
        { name: "Pending", value: stats.pending ?? 0 },
        { name: "Suspended", value: stats.suspended ?? 0 },
      ].filter((d) => d.value > 0),
    [stats],
  );

  if (!stats.total || data.length === 0) {
    return (
      <div className="flex items-center justify-center h-48 text-sm text-slate-400">
        No establishment data yet
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <div className="relative h-48">
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={data}
              cx="50%"
              cy="50%"
              innerRadius={56}
              outerRadius={76}
              paddingAngle={3}
              dataKey="value"
              strokeWidth={0}
            >
              {data.map((entry) => (
                <Cell key={entry.name} fill={STATUS_META[entry.name].color} />
              ))}
            </Pie>
            <Tooltip content={<CustomTooltip />} />
          </PieChart>
        </ResponsiveContainer>

        {/* Center label */}
        <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
          <p className="font-heading font-bold text-2xl text-slate-900 leading-none">
            {stats.total}
          </p>
          <p className="text-[10px] text-slate-400 font-medium uppercase tracking-wider mt-0.5">
            Total
          </p>
        </div>
      </div>

      {/* Legend */}
      <div className="flex justify-center gap-4 flex-wrap">
        {data.map((d) => {
          const pct = Math.round((d.value / stats.total) * 100);
          return (
            <div key={d.name} className="flex items-center gap-1.5">
              <span
                className="w-2.5 h-2.5 rounded-full flex-shrink-0"
                style={{ backgroundColor: STATUS_META[d.name].color }}
              />
              <span className="text-xs text-slate-500 font-medium">
                {d.name}
              </span>
              <span className="text-xs font-bold text-slate-800">
                {d.value}
              </span>
              <span className="text-[10px] text-slate-400">({pct}%)</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
