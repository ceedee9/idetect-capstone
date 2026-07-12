"use client";

import * as React from "react";
import * as RechartsPrimitive from "recharts";

// ── shadcn/ui chart foundation, adapted to plain JSX (no TypeScript) ────────
// Source pattern: shadcn/ui's official chart component (Recharts v3).
// Colors are driven by a per-chart `config` object mapping each data key to
// a `color` (or `theme: { light, dark }`), rendered as CSS custom properties
// scoped to the chart's own id — e.g. var(--color-total). This replaces the
// pattern in EstablishmentTrendChart.jsx where the stroke hex was hardcoded
// and had already drifted out of sync with tailwind.config.js once this
// session (osca/pdao sparkline colors). One config object per chart is now
// the single source of truth for that chart's colors.

const THEMES = { light: "", dark: ".dark" };

const ChartContext = React.createContext(null);

function useChart() {
  const context = React.useContext(ChartContext);
  if (!context) {
    throw new Error("Chart components must be used within a <ChartContainer />");
  }
  return context;
}

function ChartContainer({
  id,
  className = "",
  children,
  config,
  ...props
}) {
  const uniqueId = React.useId();
  const chartId = `chart-${id || uniqueId.replace(/:/g, "")}`;

  return (
    <ChartContext.Provider value={{ config }}>
      <div
        data-slot="chart"
        data-chart={chartId}
        className={`flex aspect-video justify-center text-xs [&_.recharts-cartesian-axis-tick_text]:fill-slate-400 [&_.recharts-cartesian-grid_line]:stroke-slate-100 [&_.recharts-dot]:stroke-transparent [&_.recharts-layer]:outline-none [&_.recharts-sector]:outline-none [&_.recharts-surface]:outline-none ${className}`}
        {...props}
      >
        <ChartStyle id={chartId} config={config} />
        <RechartsPrimitive.ResponsiveContainer>
          {children}
        </RechartsPrimitive.ResponsiveContainer>
      </div>
    </ChartContext.Provider>
  );
}

function ChartStyle({ id, config }) {
  const colorConfig = Object.entries(config).filter(
    ([, cfg]) => cfg.color || cfg.theme,
  );
  if (!colorConfig.length) return null;

  return (
    <style
      dangerouslySetInnerHTML={{
        __html: Object.entries(THEMES)
          .map(
            ([theme, prefix]) => `
${prefix} [data-chart=${id}] {
${colorConfig
  .map(([key, cfg]) => {
    const color = cfg.theme?.[theme] || cfg.color;
    return color ? `  --color-${key}: ${color};` : null;
  })
  .filter(Boolean)
  .join("\n")}
}
`,
          )
          .join("\n"),
      }}
    />
  );
}

const ChartTooltip = RechartsPrimitive.Tooltip;

function ChartTooltipContent({
  active,
  payload,
  className = "",
  indicator = "dot",
  hideLabel = false,
  hideIndicator = false,
  label,
  labelFormatter,
  formatter,
}) {
  const { config } = useChart();

  if (!active || !payload?.length) return null;

  return (
    <div
      className={`grid min-w-[10rem] items-start gap-1.5 rounded-xl border border-slate-100 bg-white px-3 py-2 text-xs shadow-card ${className}`}
    >
      {!hideLabel && label != null && (
        <div className="font-semibold text-slate-700">
          {labelFormatter ? labelFormatter(label, payload) : label}
        </div>
      )}
      <div className="grid gap-1.5">
        {payload.map((item, i) => {
          const key = item.dataKey || item.name;
          const cfg = config[key];
          const color = item.color || cfg?.color;
          return (
            <div key={i} className="flex w-full items-center gap-2">
              {!hideIndicator && (
                <span
                  className="h-2.5 w-2.5 shrink-0 rounded-[2px]"
                  style={{ background: color }}
                />
              )}
              <span className="text-slate-500">{cfg?.label || key}</span>
              <span className="ml-auto font-mono font-semibold tabular-nums text-slate-900">
                {formatter ? formatter(item.value, item) : item.value}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

const ChartLegend = RechartsPrimitive.Legend;

function ChartLegendContent({ payload, className = "" }) {
  const { config } = useChart();
  if (!payload?.length) return null;

  return (
    <div className={`flex items-center justify-center gap-4 pt-3 ${className}`}>
      {payload.map((item) => {
        const key = item.dataKey || item.value;
        const cfg = config[key];
        return (
          <div key={key} className="flex items-center gap-1.5">
            <span
              className="h-2 w-2 shrink-0 rounded-[2px]"
              style={{ background: item.color }}
            />
            <span className="text-xs text-slate-500">{cfg?.label || key}</span>
          </div>
        );
      })}
    </div>
  );
}

export {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  ChartLegend,
  ChartLegendContent,
  ChartStyle,
};
