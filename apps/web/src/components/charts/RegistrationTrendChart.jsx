import { useMemo } from "react";
import { AreaChart, Area, XAxis, YAxis, CartesianGrid } from "recharts";
import { TrendingUp } from "lucide-react";
import { format } from "date-fns";
import { ChartContainer, ChartTooltip, ChartTooltipContent } from "../ui/chart";
import EmptyState from "../EmptyState";

// `data` is [{ month: "YYYY-MM", count }] from the dashboard stats API, oldest first.
// `tone` is a PORTAL_TONES hex so each portal keeps its own ink color.
export default function RegistrationTrendChart({ data = [], tone, noun }) {
  const chartConfig = useMemo(
    () => ({ count: { label: "Registrations", color: tone } }),
    [tone],
  );

  const rows = useMemo(
    () =>
      data.map((d) => {
        const [y, m] = d.month.split("-").map(Number);
        const date = new Date(y, m - 1, 1);
        // Show the year on January so a 12-month window stays readable.
        return {
          label: m === 1 ? format(date, "MMM yy") : format(date, "MMM"),
          count: d.count,
        };
      }),
    [data],
  );

  const thisMonth = rows[rows.length - 1]?.count ?? 0;
  const lastMonth = rows[rows.length - 2]?.count ?? 0;
  const insight = (() => {
    if (thisMonth === 0 && lastMonth === 0) return null;
    if (lastMonth === 0) return `${thisMonth} new this month.`;
    const diff = thisMonth - lastMonth;
    if (diff === 0) return `${thisMonth} new this month — same as last month.`;
    const dir = diff > 0 ? "up" : "down";
    return `${thisMonth} new this month — ${dir} ${Math.abs(diff)} from last month.`;
  })();

  const hasData = rows.some((d) => d.count > 0);

  if (!hasData) {
    return (
      <EmptyState
        icon={TrendingUp}
        tone="gov"
        title={`No ${noun} yet`}
        description={`New ${noun} will appear here month by month.`}
      />
    );
  }

  return (
    <div className="space-y-3">
      {insight && (
        <p
          className="text-xs text-slate-500 font-medium border-l-2 pl-2"
          style={{ borderColor: tone }}
        >
          {insight}
        </p>
      )}
      <ChartContainer
        config={chartConfig}
        className="w-full min-w-0 h-40 sm:h-44 aspect-auto"
      >
        <AreaChart data={rows} margin={{ top: 4, right: 4, left: -28, bottom: 0 }}>
          <defs>
            <linearGradient id="trendFill" x1="0" y1="0" x2="0" y2="1">
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
          <CartesianGrid stroke="#E8E6E2" strokeWidth={0.75} vertical={false} />
          <XAxis
            dataKey="label"
            tick={{
              fontSize: 10,
              fill: "#77736D",
              fontFamily: "IBM Plex Mono",
            }}
            axisLine={false}
            tickLine={false}
            interval="preserveStartEnd"
          />
          <YAxis
            tick={{
              fontSize: 10,
              fill: "#77736D",
              fontFamily: "IBM Plex Mono",
            }}
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
              stroke: tone,
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
            fill="url(#trendFill)"
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
