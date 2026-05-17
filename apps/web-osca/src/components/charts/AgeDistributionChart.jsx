import { useMemo } from "react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Cell,
  ResponsiveContainer,
} from "recharts";
import { calcAge } from "../../utils/date";

// Lighter → darker shades of osca green for age brackets (youngest → oldest)
const BRACKET_COLORS = ["#34d399", "#059669", "#047857", "#064e3b"];

function CustomTooltip({ active, payload, label }) {
  if (!active || !payload?.length) return null;
  return (
    <div className="bg-white border border-slate-200 rounded-xl shadow-card px-3 py-2 text-xs">
      <p className="font-semibold text-slate-500 mb-0.5">{label} yrs old</p>
      <p className="text-slate-900 font-bold">
        {payload[0].value} beneficiaries
      </p>
    </div>
  );
}

export default function AgeDistributionChart({ beneficiaries }) {
  const data = useMemo(() => {
    const brackets = { "60–69": 0, "70–79": 0, "80–89": 0, "90+": 0 };
    beneficiaries.forEach((b) => {
      const age = calcAge(b.date_of_birth);
      if (age == null) return;
      if (age >= 90) brackets["90+"]++;
      else if (age >= 80) brackets["80–89"]++;
      else if (age >= 70) brackets["70–79"]++;
      else if (age >= 60) brackets["60–69"]++;
    });
    return Object.entries(brackets).map(([name, value]) => ({ name, value }));
  }, [beneficiaries]);

  const hasData = data.some((d) => d.value > 0);

  if (!hasData) {
    return (
      <div className="flex items-center justify-center h-36 text-sm text-slate-400">
        No age data available
      </div>
    );
  }

  return (
    <div className="h-36">
      <ResponsiveContainer width="100%" height="100%">
        <BarChart
          data={data}
          layout="vertical"
          margin={{ top: 0, right: 28, left: 0, bottom: 0 }}
        >
          <CartesianGrid stroke="#f1f5f9" horizontal={false} />
          <XAxis
            type="number"
            tick={{ fontSize: 11, fill: "#94a3b8", fontFamily: "DM Sans" }}
            axisLine={false}
            tickLine={false}
            allowDecimals={false}
          />
          <YAxis
            type="category"
            dataKey="name"
            tick={{ fontSize: 11, fill: "#64748b", fontFamily: "DM Sans" }}
            axisLine={false}
            tickLine={false}
            width={46}
          />
          <Tooltip content={<CustomTooltip />} cursor={{ fill: "#f8fafc" }} />
          <Bar dataKey="value" radius={[0, 4, 4, 0]} maxBarSize={18}>
            {data.map((_, i) => (
              <Cell key={i} fill={BRACKET_COLORS[i]} />
            ))}
          </Bar>
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}
