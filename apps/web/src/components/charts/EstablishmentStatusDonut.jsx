import { useMemo } from "react";
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer } from "recharts";
import { STATUS_TONES } from "../constants/statusTheme"; // adjust path to wherever you place statusTheme.js

const STATUS_META = {
  Approved: STATUS_TONES.success,
  Pending: STATUS_TONES.warn,
  Suspended: STATUS_TONES.danger,
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

// Center checkmark — small enough to sit inside the ring without a second
// dashed border, since the donut segments already act as the seal's ring.
function CenterCheck() {
  return (
    <svg
      viewBox="0 0 20 20"
      className="w-4 h-4 text-success-600"
      aria-hidden="true"
    >
      <path
        d="M4.5 10.5l3.5 3.5L15.5 6"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function EmptySeal() {
  return (
    <svg
      viewBox="0 0 80 80"
      className="w-16 h-16 mx-auto mb-3 text-slate-300"
      aria-hidden="true"
    >
      <circle
        cx="40"
        cy="40"
        r="34"
        fill="none"
        stroke="currentColor"
        strokeWidth="1"
        strokeDasharray="2 4"
      />
      <circle
        cx="40"
        cy="40"
        r="24"
        fill="none"
        stroke="currentColor"
        strokeWidth="1"
      />
      <line
        x1="32"
        y1="40"
        x2="48"
        y2="40"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
      />
    </svg>
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
      <div className="flex flex-col items-center justify-center h-48 text-center px-6">
        <EmptySeal />
        <p className="text-sm font-semibold text-slate-600">
          No establishments yet
        </p>
        <p className="text-xs text-slate-400 mt-1 leading-relaxed">
          Approved, pending, and suspended counts will appear here once
          establishments are registered.
        </p>
      </div>
    );
  }

  const compliance = Math.round(((stats.approved ?? 0) / stats.total) * 100);

  return (
    <div className="space-y-3">
      <div className="relative h-48">
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={data}
              cx="50%"
              cy="50%"
              innerRadius={58}
              outerRadius={78}
              paddingAngle={3}
              cornerRadius={4}
              dataKey="value"
              strokeWidth={0}
            >
              {data.map((entry) => (
                <Cell key={entry.name} fill={STATUS_META[entry.name].hex} />
              ))}
            </Pie>
            <Tooltip content={<CustomTooltip />} />
          </PieChart>
        </ResponsiveContainer>

        {/* Center reading — the ring itself is the seal, this is just the face */}
        <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
          <CenterCheck />
          <p className="font-heading font-semibold text-2xl text-slate-900 leading-none mt-1 tabular-nums">
            {compliance}%
          </p>
          <p className="text-[10px] text-slate-400 font-semibold uppercase tracking-wider mt-0.5">
            Compliant
          </p>
          <p className="text-[10px] text-slate-300 mt-0.5">
            {stats.total} total
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
                style={{ backgroundColor: STATUS_META[d.name].hex }}
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
