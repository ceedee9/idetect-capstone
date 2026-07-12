import { useMemo } from "react";
import { AreaChart, Area, XAxis, YAxis, CartesianGrid } from "recharts";
import {
  format,
  parseISO,
  isValid,
  subMonths,
  startOfMonth,
  endOfMonth,
} from "date-fns";
import { STATUS_TONES } from "../../constants/statusTheme";
import { ChartContainer, ChartTooltip, ChartTooltipContent } from "../ui/chart"; // adjust path if your ui/ folder lives elsewhere

const INK = STATUS_TONES.gov.hex; // #16233F — swap here to retint the whole chart

const chartConfig = {
  count: { label: "Registrations", color: INK },
};

function EmptyLedger() {
  return (
    <svg
      viewBox="0 0 80 56"
      className="w-16 h-11 mx-auto mb-3 text-slate-300"
      aria-hidden="true"
    >
      <rect
        x="6"
        y="6"
        width="68"
        height="44"
        rx="4"
        fill="none"
        stroke="currentColor"
        strokeWidth="1"
      />
      <line
        x1="14"
        y1="18"
        x2="66"
        y2="18"
        stroke="currentColor"
        strokeWidth="1"
        strokeDasharray="2 3"
      />
      <line
        x1="14"
        y1="28"
        x2="66"
        y2="28"
        stroke="currentColor"
        strokeWidth="1"
        strokeDasharray="2 3"
      />
      <line
        x1="14"
        y1="38"
        x2="46"
        y2="38"
        stroke="currentColor"
        strokeWidth="1"
        strokeDasharray="2 3"
      />
    </svg>
  );
}

export default function EstablishmentTrendChart({ establishments }) {
  const data = useMemo(() => {
    const now = new Date();
    return Array.from({ length: 6 }, (_, i) => {
      const monthDate = subMonths(now, 5 - i);
      const start = startOfMonth(monthDate);
      const end = endOfMonth(monthDate);
      const count = establishments.filter((e) => {
        const d =
          typeof e.created_at === "string"
            ? parseISO(e.created_at)
            : e.created_at;
        return isValid(d) && d >= start && d <= end;
      }).length;
      return { month: format(monthDate, "MMM"), count };
    });
  }, [establishments]);

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
      <div className="flex flex-col items-center justify-center h-48 text-center px-6">
        <EmptyLedger />
        <p className="text-sm font-semibold text-slate-600">
          No registrations yet
        </p>
        <p className="text-xs text-slate-400 mt-1 leading-relaxed">
          New establishments will show up here as they're registered, month by
          month.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {insight && (
        <p
          className="text-xs text-slate-500 font-medium border-l-2 pl-2"
          style={{ borderColor: INK }}
        >
          {insight}
        </p>
      )}
      <ChartContainer config={chartConfig} className="h-44 aspect-auto">
        <AreaChart
          data={data}
          margin={{ top: 4, right: 4, left: -28, bottom: 0 }}
        >
          <defs>
            <linearGradient id="inkFill" x1="0" y1="0" x2="0" y2="1">
              <stop
                offset="5%"
                stopColor="var(--color-count)"
                stopOpacity={0.16}
              />
              <stop
                offset="95%"
                stopColor="var(--color-count)"
                stopOpacity={0}
              />
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
          <ChartTooltip
            content={
              <ChartTooltipContent
                formatter={(value) => `${value} registered`}
              />
            }
            cursor={{
              stroke: INK,
              strokeWidth: 1,
              strokeDasharray: "4 2",
            }}
          />
          <Area
            type="monotone"
            dataKey="count"
            name="Registrations"
            stroke="var(--color-count)"
            strokeWidth={2}
            fill="url(#inkFill)"
            dot={{ fill: "var(--color-count)", strokeWidth: 0, r: 3 }}
            activeDot={{
              r: 5,
              fill: "var(--color-count)",
              strokeWidth: 2,
              stroke: "#fff",
            }}
          />
        </AreaChart>
      </ChartContainer>
    </div>
  );
}
