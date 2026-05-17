import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";
import { format, parseISO, isValid } from "date-fns";

function CustomTooltip({ active, payload, label }) {
  if (!active || !payload?.length) return null;
  return (
    <div className="bg-white border border-slate-200 rounded-xl shadow-card px-3 py-2 text-xs">
      <p className="font-semibold text-slate-500 mb-0.5">{label}</p>
      <p className="text-slate-900 font-bold">{payload[0].value} scans</p>
    </div>
  );
}

/**
 * Upgrades the old div-based mini bar chart in Verification Activity.
 * @param {Array} data - Array of { date: string, count: number }
 */
export default function DailyVerificationChart({ data }) {
  if (!data?.length) return null;

  const chartData = data.map((d) => ({
    label: (() => {
      try {
        const dt = parseISO(d.date);
        return isValid(dt) ? format(dt, "d MMM") : d.date;
      } catch {
        return d.date;
      }
    })(),
    count: d.count,
  }));

  return (
    <div className="h-20">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart
          data={chartData}
          margin={{ top: 0, right: 0, left: -32, bottom: 0 }}
          barCategoryGap="20%"
        >
          <CartesianGrid stroke="#f1f5f9" vertical={false} />
          <XAxis
            dataKey="label"
            tick={{ fontSize: 9, fill: "#94a3b8", fontFamily: "DM Sans" }}
            axisLine={false}
            tickLine={false}
            interval="preserveStartEnd"
          />
          <YAxis hide allowDecimals={false} />
          <Tooltip content={<CustomTooltip />} cursor={{ fill: "#ecfdf5" }} />
          <Bar
            dataKey="count"
            fill="#34d399"
            radius={[3, 3, 0, 0]}
            maxBarSize={12}
          />
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
