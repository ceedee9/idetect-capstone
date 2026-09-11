/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        paper: "#FAF8F5",

        // Portal identity tokens — structural chrome only.
        portal: {
          bplo: "#1F4370",
          osca: "#28665F",
          pdao: "#534AB7",
        },

        // Semantic tokens — status meaning only, shared by every portal.
        semantic: {
          success: {
            50: "#EDF7F0",
            100: "#D7EBDD",
            200: "#B2D5BD",
            500: "#2F8F5B",
            600: "#267747",
            700: "#1F6039",
            800: "#17482B",
          },
          warning: {
            50: "#FFF7E8",
            100: "#FDEBC2",
            200: "#F9D48A",
            500: "#D88A16",
            600: "#B9700D",
            700: "#92560A",
            800: "#6E3F08",
          },
          danger: {
            50: "#FFF1F0",
            100: "#FBD9D6",
            200: "#F5AAA4",
            500: "#D94A42",
            600: "#B83B35",
            700: "#922F2A",
            800: "#6E2421",
          },
          neutral: {
            50: "#F4F3F1",
            100: "#E8E6E2",
            200: "#D5D2CC",
            500: "#77736D",
            600: "#625E58",
            700: "#4B4843",
          },
        },

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
        // OSCA portal identity — calm teal/eucalyptus
        osca: {
          50: "#E8F3F1",
          100: "#CBE5E0",
          200: "#A4D0C8",
          300: "#76B5AA",
          400: "#4A968B",
          500: "#317D73",
          600: "#28665F",
          700: "#20534F",
          800: "#183F3C",
          900: "#102D2B",
        },
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

        // Shared civic chrome — Valenzuela City seal colors, CONFIRMED
        // (Philippine Blue / Red / Golden Yellow, per official seal legend).
        // Used sparingly (thin stripe + seal badge) to avoid visually
        // colliding with BPLO's navy and OSCA's gold portal accents.
        civicBlue: {
          50: "#e6ecf7",
          100: "#c0d0ec",
          200: "#8fa9dd",
          300: "#5680cb",
          400: "#265cb8",
          500: "#0f47ac",
          600: "#0038A8", // Philippine Blue — anchor value, verified
          700: "#002d87",
          800: "#00225f",
          900: "#001739",
        },
        civicRed: {
          50: "#fbe9eb",
          100: "#f4c1c8",
          200: "#e893a0",
          300: "#dc616f",
          400: "#d33646",
          500: "#d3202f",
          600: "#CE1126", // Philippine Red — anchor value, verified
          700: "#a80d1e",
          800: "#820a17",
          900: "#5c060f",
        },
        civicGold: {
          50: "#fef9e7",
          100: "#fcedb8",
          200: "#fbe089",
          300: "#fcd450", // close to anchor, kept for a mid-light stop
          400: "#FCD116", // Golden Yellow — anchor value, verified
          500: "#e0b800",
          600: "#b89600",
          700: "#8f7400",
          800: "#665300",
          900: "#3d3200",
        },

        danger: {
          50: "#FFF1F0",
          100: "#FBD9D6",
          400: "#E8756D",
          500: "#D94A42",
          600: "#B83B35",
          700: "#922F2A",
          800: "#6E2421",
        },
        success: {
          50: "#EDF7F0",
          100: "#D7EBDD",
          500: "#2F8F5B",
          600: "#267747",
          700: "#1F6039",
          800: "#17482B",
        },
        warn: {
          50: "#FFF7E8",
          100: "#FDEBC2",
          500: "#D88A16",
          600: "#B9700D",
          700: "#92560A",
          800: "#6E3F08",
        },
        warning: {
          50: "#FFF7E8",
          100: "#FDEBC2",
          500: "#D88A16",
          600: "#B9700D",
          700: "#92560A",
          800: "#6E3F08",
        },
      },
      fontFamily: {
        display: ['"Source Serif 4"', "Georgia", "serif"],
        sans: ['"Inter"', "ui-sans-serif", "sans-serif"],
        mono: ['"IBM Plex Mono"', "ui-monospace", "monospace"],
        heading: ['"Source Serif 4"', "Georgia", "serif"],
        body: ['"Inter"', "ui-sans-serif", "sans-serif"],
      },
      fontSize: {
        xs: ["0.75rem", { lineHeight: "1rem", letterSpacing: "0.01em" }],
        sm: ["0.875rem", { lineHeight: "1.25rem", letterSpacing: "0" }],
        base: ["1rem", { lineHeight: "1.5rem", letterSpacing: "0" }],
        lg: ["1.125rem", { lineHeight: "1.75rem", letterSpacing: "0" }],
        xl: ["1.25rem", { lineHeight: "1.75rem", letterSpacing: "0" }],
        "2xl": ["1.5rem", { lineHeight: "2rem", letterSpacing: "0" }],
        "3xl": ["1.875rem", { lineHeight: "2.25rem", letterSpacing: "0" }],
        "4xl": ["2.25rem", { lineHeight: "2.5rem", letterSpacing: "0" }],
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
