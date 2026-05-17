import { useMemo } from "react";
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";
import {
  format,
  parseISO,
  isValid,
  subMonths,
  startOfMonth,
  endOfMonth,
} from "date-fns";

function CustomTooltip({ active, payload, label }) {
  if (!active || !payload?.length) return null;
  return (
    <div className="bg-white border border-slate-200 rounded-xl shadow-card px-3 py-2 text-xs">
      <p className="font-semibold text-slate-500 mb-0.5">{label}</p>
      <p className="text-slate-900 font-bold">{payload[0].value} registered</p>
    </div>
  );
}

export default function RegistrationTrendChart({ beneficiaries }) {
  const data = useMemo(() => {
    const now = new Date();
    return Array.from({ length: 6 }, (_, i) => {
      const monthDate = subMonths(now, 5 - i);
      const start = startOfMonth(monthDate);
      const end = endOfMonth(monthDate);
      const count = beneficiaries.filter((b) => {
        const d =
          typeof b.created_at === "string"
            ? parseISO(b.created_at)
            : b.created_at;
        return isValid(d) && d >= start && d <= end;
      }).length;
      return {
        month: format(monthDate, "MMM"),
        full: format(monthDate, "MMMM yyyy"),
        count,
      };
    });
  }, [beneficiaries]);

  // Insight sentence: compare this month vs last month
  const thisMonth = data[data.length - 1]?.count ?? 0;
  const lastMonth = data[data.length - 2]?.count ?? 0;
  const insight = (() => {
    if (thisMonth === 0 && lastMonth === 0) return null;
    if (lastMonth === 0) return `${thisMonth} registered this month.`;
    const diff = thisMonth - lastMonth;
    if (diff === 0)
      return `${thisMonth} registered this month — same as last month.`;
    const dir = diff > 0 ? "up" : "down";
    return `${thisMonth} registered this month — ${dir} ${Math.abs(diff)} from last month.`;
  })();

  const hasData = data.some((d) => d.count > 0);

  if (!hasData) {
    return (
      <div className="flex items-center justify-center h-48 text-sm text-slate-400">
        No registration data yet
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {/* Insight sentence */}
      {insight && (
        <p className="text-xs text-slate-500 font-medium border-l-2 border-osca-400 pl-2">
          {insight}
        </p>
      )}

      {/* Chart */}
      <div className="h-44">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart
            data={data}
            margin={{ top: 4, right: 4, left: -28, bottom: 0 }}
          >
            <defs>
              <linearGradient id="oscaFill" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#059669" stopOpacity={0.18} />
                <stop offset="95%" stopColor="#059669" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid stroke="#f1f5f9" vertical={false} />
            <XAxis
              dataKey="month"
              tick={{ fontSize: 11, fill: "#94a3b8", fontFamily: "DM Sans" }}
              axisLine={false}
              tickLine={false}
            />
            <YAxis
              tick={{ fontSize: 11, fill: "#94a3b8", fontFamily: "DM Sans" }}
              axisLine={false}
              tickLine={false}
              allowDecimals={false}
            />
            <Tooltip
              content={<CustomTooltip />}
              cursor={{
                stroke: "#059669",
                strokeWidth: 1,
                strokeDasharray: "4 2",
              }}
            />
            <Area
              type="monotone"
              dataKey="count"
              name="Registrations"
              stroke="#059669"
              strokeWidth={2}
              fill="url(#oscaFill)"
              dot={{ fill: "#059669", strokeWidth: 0, r: 3 }}
              activeDot={{
                r: 5,
                fill: "#059669",
                strokeWidth: 2,
                stroke: "#fff",
              }}
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
