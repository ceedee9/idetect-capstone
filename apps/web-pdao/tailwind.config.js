/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        // Valenzuela City / government palette
        gov: {
          50: "#eef4ff",
          100: "#dce9ff",
          200: "#b2d0ff",
          300: "#7aadff",
          400: "#3a82ff",
          500: "#1a5cff",
          600: "#0038f5",
          700: "#002ee0",
          800: "#0127b5",
          900: "#06228e",
          950: "#051554",
        },
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
        // PDAO-specific accent (used sparingly for portal identity)
        pdao: {
          50: "#f0fdfa",
          100: "#ccfbf1",
          200: "#99f6e4",
          300: "#5eead4",
          400: "#2dd4bf",
          500: "#14b8a6",
          600: "#0d9488",
          700: "#0f766e",
          800: "#115e59",
          900: "#134e4a",
        },
        danger: {
          50: "#fff1f2",
          100: "#ffe4e6",
          400: "#f87171",
          500: "#ef4444",
          600: "#dc2626",
          700: "#b91c1c",
        },
        success: { 50: "#f0fdf4", 500: "#22c55e", 700: "#15803d" },
        warn: { 50: "#fffbeb", 100: "#fef3c7", 500: "#f59e0b", 700: "#b45309" },
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
