import { useMemo } from "react";
import { BarChart, Bar, XAxis, YAxis, CartesianGrid } from "recharts";
import { BarChart3 } from "lucide-react";
import { ChartContainer, ChartTooltip, ChartTooltipContent } from "../ui/chart";
import EmptyState from "../EmptyState";

// `data` is [{ label, count }]. `horizontal` suits long category names.
export default function PortalBreakdownChart({
  data = [],
  tone,
  horizontal = false,
  emptyTitle,
  emptyDescription,
}) {
  const chartConfig = useMemo(
    () => ({ count: { label: "Records", color: tone } }),
    [tone],
  );

  const total = data.reduce((sum, d) => sum + d.count, 0);

  if (total === 0) {
    return (
      <EmptyState
        icon={BarChart3}
        tone="gov"
        title={emptyTitle}
        description={emptyDescription}
      />
    );
  }

  const tick = {
    fontSize: 10,
    fill: "#77736D",
    fontFamily: "IBM Plex Mono",
  };

  return (
    <ChartContainer
      config={chartConfig}
      className={`w-full min-w-0 aspect-auto ${horizontal ? "h-56" : "h-48 sm:h-52"}`}
    >
      <BarChart
        data={data}
        layout={horizontal ? "vertical" : "horizontal"}
        margin={{ top: 4, right: 8, left: horizontal ? 0 : -28, bottom: 0 }}
      >
        <CartesianGrid
          stroke="#E8E6E2"
          strokeWidth={0.75}
          horizontal={!horizontal}
          vertical={horizontal}
        />
        {horizontal ? (
          <>
            <XAxis type="number" tick={tick} axisLine={false} tickLine={false} allowDecimals={false} />
            <YAxis
              type="category"
              dataKey="label"
              tick={{ ...tick, fill: "#4B4740" }}
              axisLine={false}
              tickLine={false}
              width={110}
            />
          </>
        ) : (
          <>
            <XAxis dataKey="label" tick={tick} axisLine={false} tickLine={false} />
            <YAxis tick={tick} axisLine={false} tickLine={false} allowDecimals={false} />
          </>
        )}
        <ChartTooltip
          cursor={{ fill: tone, fillOpacity: 0.06 }}
          content={
            <ChartTooltipContent
              hideLabel={false}
              formatter={(value) => `${value} records`}
            />
          }
        />
        <Bar
          dataKey="count"
          name="Records"
          fill="var(--color-count)"
          radius={horizontal ? [0, 4, 4, 0] : [4, 4, 0, 0]}
          maxBarSize={horizontal ? 18 : 40}
        />
      </BarChart>
    </ChartContainer>
  );
}
