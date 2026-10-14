import { useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import {
  Eye,
  EyeOff,
  AlertCircle,
  Loader2,
  Clock,
  WifiOff,
} from "lucide-react";
import { useAuth } from "../context/AuthContext";
import { authAPI } from "../services/api";
import { CivicStripe } from "../components/CivicChrome";

// Design tokens — mirrors civicBlue/danger/warn ramps in tailwind.config.js.
// Added pageBg / photoBox* / hairline for the ID-card login redesign.
// If the Tailwind ramps change, update this object too.
const C = {
  institutional: "#00225F",
  institutionalHover: "#001739",
  institutionalMuted: "#8FA9DD",
  danger50: "#fff1f2",
  danger100: "#ffe4e6",
  danger600: "#dc2626",
  warn50: "#fffbeb",
  warn100: "#fef3c7",
  warn700: "#92560A",
  pageBg: "#D7DFEC", // slate-blue neutral the ID card sits on
  photoBoxBg: "#E7EBF2",
  photoBoxBorder: "#C3CCDC",
  hairline: "#D8DCE3",
  fieldBg: "#F6F8FB",
};

const LOGO_SRC = "/IDETECT.png";
// Served from apps/web/public/photobox.png — reference it as a root-relative
// path here since that's how Vite serves files from /public.
const PHOTOBOX_SRC = "/photobox.png";

// Shared notice styling — left-border accent + mono uppercase label,
// same visual idiom as the fraud-flag detail panel's quoted-reason
// callout, so these read as part of the same system rather than
// generic rounded alert boxes.
const NOTICE_STYLES = {
  idle: {
    accent: "#92560A",
    bg: "#fffbeb",
    icon: Clock,
    label: "Session Expired",
  },
  credentials: {
    accent: "#dc2626",
    bg: "#fff1f2",
    icon: AlertCircle,
    label: "Sign-In Failed",
  },
  network: {
    accent: "#00225F",
    bg: "#EEF2FA",
    icon: WifiOff,
    label: "Connection Issue",
  },
};

function Notice({ type, message }) {
  const s = NOTICE_STYLES[type];
  const Icon = s.icon;
  return (
    <div
      className="flex items-start gap-3 pl-3 pr-4 py-3 mb-4"
      style={{ borderLeft: `3px solid ${s.accent}`, background: s.bg }}
    >
      <Icon
        className="w-4 h-4 flex-shrink-0 mt-0.5"
        style={{ color: s.accent }}
      />
      <div>
        <p
          className="font-mono text-[9px] tracking-widest uppercase"
          style={{ color: s.accent }}
        >
          {s.label}
        </p>
        <p className="text-xs mt-1 text-slate-700 leading-relaxed">{message}</p>
      </div>
    </div>
  );
}

// Purely decorative barcode flourish for the footer strip — no data encoded.
// Nods to the "scannable document" theme. Safe to delete if unwanted.
function IDBarcode() {
  const bars = [
    2, 1, 3, 1, 1, 2, 1, 4, 1, 2, 1, 1, 3, 1, 2, 1, 1, 2, 1, 3, 1, 1, 2, 1,
  ];
  let x = 0;
  return (
    <svg
      width="100%"
      height="22"
      viewBox="0 0 240 22"
      preserveAspectRatio="xMidYMid meet"
      aria-hidden="true"
    >
      {bars.map((w, i) => {
        const barWidth = w * 2;
        const el =
          i % 2 === 0 ? (
            <rect
              key={i}
              x={x}
              y="0"
              width={barWidth - 1}
              height="22"
              fill={C.institutional}
              opacity={0.55}
            />
          ) : null;
        x += barWidth;
        return el;
      })}
    </svg>
  );
}

function ForgotPasswordModal({ onClose }) {
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [sent, setSent] = useState(false);
  const [msg, setMsg] = useState("");

  async function handleSubmit(e) {
    e.preventDefault();
    setLoading(true);
    setMsg("");
    try {
      await authAPI.forgotPassword(email, window.location.origin);
      setSent(true);
    } catch {
      setMsg("Something went wrong. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center"
      style={{ background: "rgba(0,0,0,0.55)" }}
    >
      <div
        className="bg-white rounded-registry-lg shadow-xl p-6 w-full max-w-sm mx-4"
        style={{ border: "1px solid #e5e7eb" }}
      >
        <h3 className="font-bold text-lg text-gray-900 mb-1">Reset Password</h3>
        {sent ? (
          <>
            <p className="text-sm text-gray-600 mb-4">
              If an account exists for that email, a password reset link has
              been sent. Please check your inbox (and spam folder).
            </p>
            <button
              onClick={onClose}
              className="w-full rounded-registry-lg py-2.5 text-sm font-semibold text-white"
              style={{ background: C.institutional }}
            >
              Done
            </button>
          </>
        ) : (
          <>
            <p className="text-sm text-gray-500 mb-4">
              Enter your staff email address and we&apos;ll send you a link to
              reset your password.
            </p>
            {msg && (
              <div
                className="flex items-start gap-2 px-3 py-2 rounded-lg text-sm mb-3"
                style={{
                  background: C.danger50,
                  color: C.danger600,
                  border: `1px solid ${C.danger100}`,
                }}
              >
                <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5" />
                <span>{msg}</span>
              </div>
            )}
            <form onSubmit={handleSubmit} className="space-y-3">
              <input
                type="email"
                required
                placeholder="staff@example.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                disabled={loading}
                className="input"
              />
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={onClose}
                  disabled={loading}
                  className="flex-1 rounded-registry-lg py-2.5 text-sm font-medium text-slate-600 border border-slate-200 bg-paper"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={loading || !email}
                  className="flex-1 flex items-center justify-center gap-2 rounded-registry-lg py-2.5 text-sm font-semibold text-white"
                  style={{
                    background:
                      loading || !email
                        ? C.institutionalMuted
                        : C.institutional,
                    cursor: loading || !email ? "not-allowed" : "pointer",
                  }}
                >
                  {loading ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      Sending…
                    </>
                  ) : (
                    "Send Link"
                  )}
                </button>
              </div>
            </form>
          </>
        )}
      </div>
    </div>
  );
}

export default function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const idleExpired = searchParams.get("reason") === "idle";

  const [form, setForm] = useState({ email: "", password: "" });
  const [showPw, setShowPw] = useState(false);
  const [remember, setRemember] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  // 'credentials' (server responded, rejected) vs 'network' (no response at
  // all — request never completed, e.g. a timeout or the API still
  // cold-starting). These need different messages: a cold-start failure
  // was previously mislabeled as "Invalid email or password" because the
  // old logic only checked err.message for "Access denied" and otherwise
  // always assumed a credentials failure, even when err.response was
  // undefined (i.e. no response was ever received).
  const [errorType, setErrorType] = useState("credentials");
  const [showForgotPw, setShowForgotPw] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await login(form.email, form.password, remember);
      navigate("/");
    } catch (err) {
      if (!err.response) {
        // No response object at all — the request never completed. This
        // covers network drops, timeouts, and (most likely here) the API
        // still spinning up after a period of inactivity. Do NOT call
        // this a credentials error.
        setErrorType("network");
        setError(
          "Can't reach the server right now — this can happen briefly if the API is still starting up. Please wait a few seconds and try again.",
        );
      } else {
        setErrorType("credentials");
        const msg =
          err.response?.data?.error ||
          err.response?.data?.message ||
          (err.message?.includes("Access denied")
            ? err.message
            : "Invalid email or password.");
        setError(msg);
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <>
      <div className="min-h-screen flex flex-col">
        <CivicStripe />

        {/* Page surface the ID card sits on — Valenzuela City Hall photo,
            with a navy tint for brand-color consistency. Card is centered;
            a single consistent tint opacity is used across breakpoints
            since the centered card can sit across both the photo's washed
            and full-color zones, unlike the earlier left-aligned layout. */}
        <div className="flex-1 relative flex items-center justify-center px-4 py-10 overflow-hidden">
          <div
            className="absolute inset-0"
            style={{
              backgroundColor: C.pageBg,
              backgroundImage: "url('/CITY%20HALL%20BG.png')",
              backgroundSize: "cover",
              backgroundPosition: "center",
            }}
          />
          <div className="absolute inset-0 bg-[#00225F] opacity-45" />

          {/* ═══════════════════════════════════════
              THE ID CARD — login form fused into an
              actual ID layout: masthead, photo box,
              data fields, control-number footer.
          ═══════════════════════════════════════ */}
          <div
            className="relative z-10 w-full bg-white overflow-hidden"
            style={{
              maxWidth: 680,
              borderRadius: 18,
              boxShadow:
                "0 24px 60px -18px rgba(0,34,95,0.35), 0 4px 14px rgba(0,0,0,0.08)",
              border: "1px solid rgba(0,34,95,0.08)",
            }}
          >
            {/* ── Header band / masthead — issuer identity ── */}
            <div
              className="relative overflow-hidden px-6 pt-5 pb-4 flex items-center justify-between"
              style={{ backgroundColor: C.institutional }}
            >
              <svg
                className="absolute inset-0 h-full w-full opacity-10"
                viewBox="0 0 400 100"
                preserveAspectRatio="xMidYMid slice"
                aria-hidden="true"
              >
                <defs>
                  <pattern
                    id="guillocheHeader"
                    width="48"
                    height="48"
                    patternUnits="userSpaceOnUse"
                  >
                    <path
                      d="M-24 24C-6-8 18-8 36 24s42 32 60 0M-24 36C-6 4 18 4 36 36s42 32 60 0"
                      fill="none"
                      stroke="#8FA9DD"
                      strokeWidth="0.6"
                    />
                  </pattern>
                </defs>
                <rect width="400" height="100" fill="url(#guillocheHeader)" />
              </svg>
              <img
                src={LOGO_SRC}
                alt="iDetect"
                className="relative z-10 h-7 object-contain"
              />
              <span className="relative z-10 font-mono text-[9px] tracking-widest text-white/60 uppercase">
                Staff Access Card
              </span>
            </div>

            {/* ── Body ── */}
            <div className="px-6 pt-6 pb-5">
              {/* Photo box + title/office block */}
              <div className="flex gap-4 mb-5">
                <div
                  className="flex items-center justify-center flex-shrink-0"
                  style={{
                    width: 96,
                    height: 96,
                    borderRadius: 8,
                    background: C.photoBoxBg,
                    border: `1px solid ${C.photoBoxBorder}`,
                  }}
                >
                  <img
                    src={PHOTOBOX_SRC}
                    alt="iDetect"
                    className="w-full h-full object-contain p-4"
                  />
                </div>
                <div className="flex-1 pt-1">
                  <h1 className="font-display font-semibold text-2xl leading-tight text-slate-900">
                    Sign In
                  </h1>
                  <p className="font-mono text-[10px] tracking-wide text-slate-400 uppercase mt-2">
                    Issuing Office
                  </p>
                  <p className="font-sans text-sm font-medium text-slate-600">
                    OSCA · PDAO · BPLO Staff Portal
                  </p>
                </div>
              </div>

              <div
                className="h-px w-full mb-5"
                style={{ background: C.hairline }}
              />

              {/* Notices */}
              {idleExpired && !error && (
                <Notice
                  type="idle"
                  message="Your session expired due to inactivity. Please sign in again."
                />
              )}
              {error && <Notice type={errorType} message={error} />}

              <form onSubmit={handleSubmit} className="space-y-4">
                {/* Email + Password — laid out as a two-column ID data-field row */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label
                      htmlFor="email"
                      className="block font-mono text-[10px] tracking-wide text-slate-400 uppercase mb-1.5"
                    >
                      Email
                    </label>
                    <input
                      id="email"
                      type="email"
                      autoComplete="email"
                      required
                      placeholder="you@valenzuela.gov.ph"
                      value={form.email}
                      onChange={(e) =>
                        setForm((f) => ({ ...f, email: e.target.value }))
                      }
                      disabled={loading}
                      className="w-full text-sm font-sans text-slate-900 placeholder:text-slate-400 focus:outline-none"
                      style={{
                        background: C.fieldBg,
                        border: `1px solid ${C.hairline}`,
                        borderRadius: 6,
                        padding: "9px 12px",
                      }}
                      onFocus={(e) => {
                        e.target.style.borderColor = C.institutional;
                        e.target.style.borderWidth = "1.5px";
                      }}
                      onBlur={(e) => {
                        e.target.style.borderColor = C.hairline;
                        e.target.style.borderWidth = "1px";
                      }}
                    />
                  </div>

                  <div>
                    <label
                      htmlFor="password"
                      className="block font-mono text-[10px] tracking-wide text-slate-400 uppercase mb-1.5"
                    >
                      Password
                    </label>
                    <div className="relative">
                      <input
                        id="password"
                        type={showPw ? "text" : "password"}
                        autoComplete="current-password"
                        required
                        placeholder="••••••••"
                        value={form.password}
                        onChange={(e) =>
                          setForm((f) => ({ ...f, password: e.target.value }))
                        }
                        disabled={loading}
                        className="w-full text-sm font-sans text-slate-900 placeholder:text-slate-400 focus:outline-none"
                        style={{
                          background: C.fieldBg,
                          border: `1px solid ${C.hairline}`,
                          borderRadius: 6,
                          padding: "9px 36px 9px 12px",
                        }}
                        onFocus={(e) => {
                          e.target.style.borderColor = C.institutional;
                          e.target.style.borderWidth = "1.5px";
                        }}
                        onBlur={(e) => {
                          e.target.style.borderColor = C.hairline;
                          e.target.style.borderWidth = "1px";
                        }}
                      />
                      <button
                        type="button"
                        onClick={() => setShowPw((v) => !v)}
                        tabIndex={-1}
                        className="absolute right-2.5 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                      >
                        {showPw ? (
                          <EyeOff className="w-4 h-4" />
                        ) : (
                          <Eye className="w-4 h-4" />
                        )}
                      </button>
                    </div>
                  </div>
                </div>

                {/* Remember me + Forgot password */}
                <div className="flex items-center justify-between pt-1">
                  <label className="flex items-center gap-2 cursor-pointer select-none">
                    <button
                      type="button"
                      role="switch"
                      aria-checked={remember}
                      onClick={() => setRemember((v) => !v)}
                      className="relative inline-flex items-center rounded-full transition-colors focus:outline-none"
                      style={{
                        height: 18,
                        width: 32,
                        background: remember ? C.institutional : "#CBD0D6",
                      }}
                    >
                      <span
                        className="inline-block rounded-full bg-white shadow transition-transform"
                        style={{
                          height: 13,
                          width: 13,
                          transform: remember
                            ? "translateX(16px)"
                            : "translateX(2px)",
                        }}
                      />
                    </button>
                    <span className="font-sans text-xs text-slate-500">
                      Remember me
                    </span>
                  </label>

                  <button
                    type="button"
                    onClick={() => setShowForgotPw(true)}
                    className="font-sans text-xs font-semibold text-slate-600 hover:text-slate-900 hover:underline"
                  >
                    Forgot password?
                  </button>
                </div>

                {/* Submit */}
                <button
                  type="submit"
                  disabled={loading || !form.email || !form.password}
                  className="w-full flex items-center justify-center gap-2 py-2.5 text-sm font-semibold text-white transition-all"
                  style={{
                    borderRadius: 8,
                    background:
                      loading || !form.email || !form.password
                        ? C.institutionalMuted
                        : C.institutional,
                    cursor:
                      loading || !form.email || !form.password
                        ? "not-allowed"
                        : "pointer",
                  }}
                >
                  {loading ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      Signing in…
                    </>
                  ) : (
                    "Sign in"
                  )}
                </button>
              </form>
            </div>

            {/* ── Footer strip — reads like a control-number line ── */}
            <div
              className="px-6 py-3 flex items-center justify-between gap-4"
              style={{
                borderTop: `1px solid ${C.hairline}`,
                background: "#FAFBFC",
              }}
            >
              <span className="font-mono text-[9px] text-slate-400 leading-tight">
                PLV · CEIT Capstone 2026
                <br />© Valenzuela City
              </span>
              <div style={{ width: 90, flexShrink: 0 }}>
                <IDBarcode />
              </div>
            </div>
          </div>
        </div>
      </div>

      {showForgotPw && (
        <ForgotPasswordModal onClose={() => setShowForgotPw(false)} />
      )}
    </>
  );
}
