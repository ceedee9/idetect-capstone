/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        // Valenzuela City / government palette — BPLO portal identity
        // Ink navy (reworked from session: replaces the old bright blue #0038f5)
        gov: {
          50: "#eef1f6",
          100: "#d7dee9",
          200: "#b0bdd0",
          300: "#8697b3",
          400: "#5c7096",
          500: "#3c4f75",
          600: "#16233F", // anchor value from session log
          700: "#121d34",
          800: "#0e1628",
          900: "#0a101c",
          950: "#050810",
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
        osca: {
          50: "#faf5ea",
          100: "#f0e3c4",
          200: "#e0c788",
          300: "#cca94f",
          400: "#a3801f",
          500: "#8a6813",
          600: "#6B4E0F", // anchor value from session log
          700: "#573f0c",
          800: "#453209",
          900: "#352606",
        },
        // PDAO portal identity — advocacy violet
        // (reworked from session: replaces the old teal ramp)
        pdao: {
          50: "#f1effa",
          100: "#e0dcf3",
          200: "#c3bbe8",
          300: "#a294d9",
          400: "#7f6cc4",
          500: "#5f4dab",
          600: "#443C9E", // anchor value from session log
          700: "#37307f",
          800: "#2b2665",
          900: "#211d4d",
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
