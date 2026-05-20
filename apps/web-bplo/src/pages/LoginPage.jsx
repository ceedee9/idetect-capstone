import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Eye, EyeOff, AlertCircle, Loader2 } from "lucide-react";
import { useAuth } from "../context/AuthContext";
import axios from "axios";

const BG_IMAGE = "/idBackground.png";
const LOGO_SRC = "/IDETECT.png";

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
      await axios.post("/api/auth/staff/forgot-password", {
        email,
        origin: window.location.origin,
      });
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
        className="bg-white rounded-xl shadow-xl p-6 w-full max-w-sm mx-4"
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
              className="w-full rounded-md py-2.5 text-sm font-semibold text-white"
              style={{ background: "#3b82f6" }}
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
                  background: "#fef2f2",
                  color: "#dc2626",
                  border: "1px solid #fecaca",
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
                className="w-full rounded-md px-3.5 py-2.5 text-sm text-gray-900 outline-none"
                style={{
                  background: "#f3f4f6",
                  border: "1px solid transparent",
                }}
                onFocus={(e) => (e.target.style.border = "1px solid #3b82f6")}
                onBlur={(e) =>
                  (e.target.style.border = "1px solid transparent")
                }
              />
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={onClose}
                  disabled={loading}
                  className="flex-1 rounded-md py-2.5 text-sm font-medium text-gray-600"
                  style={{ background: "#f3f4f6" }}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={loading || !email}
                  className="flex-1 flex items-center justify-center gap-2 rounded-md py-2.5 text-sm font-semibold text-white"
                  style={{
                    background: loading || !email ? "#93c5fd" : "#3b82f6",
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

  const [form, setForm] = useState({ email: "", password: "" });
  const [showPw, setShowPw] = useState(false);
  const [remember, setRemember] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [showForgotPw, setShowForgotPw] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await login(form.email, form.password);
      navigate("/");
    } catch (err) {
      const msg = err.message?.includes("Access denied")
        ? err.message
        : err.response?.data?.message || "Invalid email or password.";
      setError(msg);
    } finally {
      setLoading(false);
    }
  }

  return (
    <>
      <div className="min-h-screen flex">
        {/* ════════════════════════════════════
          LEFT PANEL — background + logo
      ════════════════════════════════════ */}
        <div
          className="hidden lg:flex lg:w-1/2 relative flex-col items-start justify-between p-10 overflow-hidden"
          style={{
            backgroundImage: `url(${BG_IMAGE})`,
            backgroundSize: "cover",
            backgroundPosition: "center",
          }}
        >
          {/* Dark overlay */}
          <div className="absolute inset-0 bg-black/70" />

          {/* Logo — centered vertically in the panel */}
          <div className="relative z-10 flex items-center justify-center w-full flex-1">
            {LOGO_SRC === "/your-logo.png" ? (
              /* Placeholder shown until real logo is provided */
              <div
                className="flex items-center justify-center rounded-2xl"
                style={{
                  width: 360,
                  height: 140,
                  border: "2px dashed rgba(255,255,255,0.30)",
                  background: "rgba(255,255,255,0.06)",
                }}
              >
                <span style={{ color: "rgba(255,255,255,0.40)", fontSize: 13 }}>
                  [ Your Logo Here ]
                </span>
              </div>
            ) : (
              <img
                src={LOGO_SRC}
                alt="iDetect Logo"
                className="max-w-md w-full object-contain drop-shadow-2xl"
              />
            )}
          </div>

          {/* Bottom text */}
          <div className="relative z-10">
            <h2 className="font-heading font-bold text-white text-xl leading-snug">
              Business Permit &amp;
              <br />
              Licensing Office
            </h2>
            <p className="text-white/50 text-xs mt-1.5 leading-relaxed max-w-xs">
              Manage and monitor food service establishments registered under
              iDetect's discount verification network.
            </p>
            <p className="text-white/25 text-xs mt-4">
              Pamantasan ng Lungsod ng Valenzuela · CEIT Capstone 2026
              <br />
              De los Reyes · Enoria · Mercado · Santiago
            </p>
          </div>
        </div>

        {/* ════════════════════════════════════
          RIGHT PANEL — login form
      ════════════════════════════════════ */}
        <div className="flex-1 flex flex-col justify-between bg-white px-8 py-10 sm:px-16">
          <div /> {/* top spacer */}
          <div className="w-full max-w-sm mx-auto">
            {/* Mobile logo */}
            <div className="lg:hidden mb-8">
              {LOGO_SRC === "/your-logo.png" ? (
                <div
                  className="flex items-center justify-center rounded-xl mx-auto"
                  style={{
                    width: 160,
                    height: 60,
                    border: "2px dashed #d1d5db",
                    background: "#f9fafb",
                  }}
                >
                  <span style={{ color: "#9ca3af", fontSize: 12 }}>
                    [ Logo ]
                  </span>
                </div>
              ) : (
                <img
                  src={LOGO_SRC}
                  alt="iDetect Logo"
                  className="h-14 object-contain mx-auto"
                />
              )}
            </div>

            {/* Heading */}
            <div className="mb-7">
              <h1
                className="font-heading font-bold text-3xl text-gray-900"
                style={{ letterSpacing: "-0.5px" }}
              >
                Sign In
              </h1>
              <p className="text-xs font-semibold text-gray-400 tracking-widest uppercase mt-2">
                BPLO Administrator
              </p>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              {/* Error banner */}
              {error && (
                <div
                  className="flex items-start gap-2.5 px-4 py-3 rounded-lg text-sm"
                  style={{
                    background: "#fef2f2",
                    border: "1px solid #fecaca",
                    color: "#dc2626",
                  }}
                >
                  <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5" />
                  <span>{error}</span>
                </div>
              )}

              {/* Email */}
              <div>
                <label
                  htmlFor="email"
                  className="block text-xs font-medium text-gray-500 mb-1"
                >
                  Email
                </label>
                <input
                  id="email"
                  type="email"
                  autoComplete="email"
                  required
                  placeholder="Email"
                  value={form.email}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, email: e.target.value }))
                  }
                  disabled={loading}
                  className="w-full rounded-md px-3.5 py-2.5 text-sm text-gray-900 outline-none transition-all"
                  style={{
                    background: "#f3f4f6",
                    border: "1px solid transparent",
                  }}
                  onFocus={(e) => (e.target.style.border = "1px solid #3b82f6")}
                  onBlur={(e) =>
                    (e.target.style.border = "1px solid transparent")
                  }
                />
              </div>

              {/* Password */}
              <div>
                <label
                  htmlFor="password"
                  className="block text-xs font-medium text-gray-500 mb-1"
                >
                  Password
                </label>
                <div className="relative">
                  <input
                    id="password"
                    type={showPw ? "text" : "password"}
                    autoComplete="current-password"
                    required
                    placeholder="Enter password"
                    value={form.password}
                    onChange={(e) =>
                      setForm((f) => ({ ...f, password: e.target.value }))
                    }
                    disabled={loading}
                    className="w-full rounded-md px-3.5 py-2.5 pr-10 text-sm text-gray-900 outline-none transition-all"
                    style={{
                      background: "#f3f4f6",
                      border: "1px solid transparent",
                    }}
                    onFocus={(e) =>
                      (e.target.style.border = "1px solid #3b82f6")
                    }
                    onBlur={(e) =>
                      (e.target.style.border = "1px solid transparent")
                    }
                  />
                  <button
                    type="button"
                    onClick={() => setShowPw((v) => !v)}
                    tabIndex={-1}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                  >
                    {showPw ? (
                      <EyeOff className="w-4 h-4" />
                    ) : (
                      <Eye className="w-4 h-4" />
                    )}
                  </button>
                </div>
              </div>

              {/* Remember me + Forgot password */}
              <div className="flex items-center justify-between">
                <label className="flex items-center gap-2 cursor-pointer select-none">
                  <button
                    type="button"
                    role="switch"
                    aria-checked={remember}
                    onClick={() => setRemember((v) => !v)}
                    className="relative inline-flex h-5 w-9 items-center rounded-full transition-colors focus:outline-none"
                    style={{ background: remember ? "#3b82f6" : "#d1d5db" }}
                  >
                    <span
                      className="inline-block h-3.5 w-3.5 rounded-full bg-white shadow transition-transform"
                      style={{
                        transform: remember
                          ? "translateX(18px)"
                          : "translateX(2px)",
                      }}
                    />
                  </button>
                  <span className="text-xs text-gray-500">Remember me</span>
                </label>

                <button
                  type="button"
                  onClick={() => setShowForgotPw(true)}
                  className="text-xs font-medium hover:underline"
                  style={{ color: "#3b82f6" }}
                >
                  Forgot password?
                </button>
              </div>

              {/* Submit */}
              <button
                type="submit"
                disabled={loading || !form.email || !form.password}
                className="w-full flex items-center justify-center gap-2 rounded-md py-2.5 text-sm font-semibold text-white transition-all"
                style={{
                  background:
                    loading || !form.email || !form.password
                      ? "#93c5fd"
                      : "#3b82f6",
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
          {/* Footer */}
          <p className="text-center text-xs text-gray-400">© Valenzuela City</p>
        </div>
      </div>
      {showForgotPw && (
        <ForgotPasswordModal onClose={() => setShowForgotPw(false)} />
      )}
    </>
  );
}
