// ── Shared civic chrome (Option A: subtle accent) ────────────────────────────
// Valenzuela City seal colors (Philippine Blue / Red / Golden Yellow), used
// only as a thin identifying stripe + small seal badge — never as a filled
// surface — so it doesn't visually collide with BPLO's navy or OSCA's gold
// portal accent colors. See tailwind.config.js `civicBlue`/`civicRed`/`civicGold`
// for the full ramps these reference.

export function CivicStripe({ className = "" }) {
  return (
    <div
      aria-hidden="true"
      className={`h-[2px] w-full shrink-0 opacity-70 ${className}`}
      style={{
        background:
          "linear-gradient(90deg, #0038A8 0%, #0038A8 33%, #CE1126 33%, #CE1126 66%, #FCD116 66%, #FCD116 100%)",
      }}
    />
  );
}

// Small seal/stamp badge — reuses the same dashed-ring + glyph motif as
// StatusBadge/the donut chart, but in civic gold, to mark something as
// "verified by the city" rather than a record status.
export function CivicSealBadge({ label = "Verified · Valenzuela City" }) {
  return (
    <div className="flex items-center gap-2">
      <svg width="20" height="20" viewBox="0 0 20 20" aria-hidden="true">
        <circle
          cx="10"
          cy="10"
          r="9"
          fill="none"
          stroke="#b89600"
          strokeWidth="1"
          strokeDasharray="2.2 2"
        />
        <circle
          cx="10"
          cy="10"
          r="6"
          fill="none"
          stroke="#8f7400"
          strokeWidth="1"
        />
        <path
          d="M6.5 10.2l2.3 2.3 4.7-4.7"
          fill="none"
          stroke="#8f7400"
          strokeWidth="1.4"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
      <span className="text-xs font-semibold" style={{ color: "#665300" }}>
        {label}
      </span>
    </div>
  );
}
