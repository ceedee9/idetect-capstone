/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        // Valenzuela City / government palette — BPLO portal identity
        // Ink navy (reworked from session: replaces the old bright blue #0038f5)
        gov: {
          50: "#EAF0FA",
          100: "#CBDAED",
          200: "#9FBADC",
          300: "#6F97C6",
          400: "#4874AC",
          500: "#2F5A8C",
          600: "#1F4370",
          700: "#16233F",
          800: "#101A2F",
          900: "#0A1220",
        },
        // Pre-existing amber/gold utility token — NOT part of the portal
        // identity system (not referenced in session log). Left untouched.
        accent: {
          50: "#fef9ec",
          100: "#fdf0c9",
          200: "#fbe28e",
          300: "#f9ce4d",
          400: "#f7ba1e",
          500: "#e69c06",
          600: "#cb7802",
          700: "#a85505",
          800: "#8a430b",
          900: "#73380f",
        },
        // OSCA portal identity — civic gold/mustard
        // (reworked from session: replaces the old green ramp)
        // Intentionally shifted away from `warn`'s hue to avoid collision.
        50: "#FBF3DE",
        100: "#F5E3AE",
        200: "#EACB6E",
        300: "#D9AE3E",
        400: "#BE9020",
        500: "#9F7817",
        600: "#8A6613",
        700: "#6B4E0F",
        800: "#4A3609",
        900: "#2E2205",
        // PDAO portal identity — advocacy violet
        // (reworked from session: replaces the old teal ramp)
        pdao: {
          50: "#EEEDFE",
          100: "#CECBF6",
          200: "#AFA9EC",
          300: "#9691E4",
          400: "#7F77DD",
          500: "#6860CB",
          600: "#534AB7",
          700: "#443C9E",
          800: "#3C3489",
          900: "#26215C",
        },
        // Shared civic chrome — NOT yet applied anywhere in components
        // (header/footer/login layer deferred per session notes).
        // Colors inferred from Valenzuela City seal heraldry —
        // UNVERIFIED against an actual brand guide, confirm before shipping.
        civic: {
          maroon: "#7A1F1A",
          gold: "#B8860B",
        },
        danger: {
          50: "#fff1f2",
          100: "#ffe4e6",
          400: "#f87171",
          500: "#ef4444",
          600: "#dc2626",
          700: "#b91c1c",
        },
        success: {
          50: "#f0fdf4",
          500: "#22c55e",
          700: "#15803d",
        },
        warn: {
          50: "#fffbeb",
          100: "#fef3c7",
          500: "#f59e0b",
          700: "#b45309",
        },
      },
      fontFamily: {
        heading: ['"Sora"', "sans-serif"],
        body: ['"DM Sans"', "sans-serif"],
        mono: ['"JetBrains Mono"', "monospace"],
      },
      boxShadow: {
        card: "0 2px 8px 0 rgba(0,0,0,0.06), 0 1px 2px 0 rgba(0,0,0,0.04)",
        "card-hover":
          "0 8px 24px 0 rgba(0,0,0,0.10), 0 2px 4px 0 rgba(0,0,0,0.06)",
        nav: "0 1px 0 0 rgba(0,0,0,0.08)",
        "card-md":
          "0 8px 24px 0 rgba(0,0,0,0.10), 0 2px 4px 0 rgba(0,0,0,0.06)",
        "card-lg":
          "0 8px 24px 0 rgba(0,0,0,0.10), 0 2px 4px 0 rgba(0,0,0,0.06)",
      },
    },
  },
  plugins: [],
};
