import { useState, useEffect } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { Eye, EyeOff, CheckCircle, AlertCircle, Loader2 } from "lucide-react";
import { authAPI } from "../services/api";

const LOGO_SRC = "/IDETECT.png";

// Public page linked from the establishment account-created email —
// lets a newly created establishment choose its own password instead
// of receiving one by email.
export default function EstablishmentSetupPasswordPage() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();

  const token = searchParams.get("token") || "";
  const email = searchParams.get("email") || "";

  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [showPw, setShowPw] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(false);

  useEffect(() => {
    if (!token || !email) {
      setError(
        "Invalid setup link. Please contact your BPLO administrator for a new one.",
      );
    }
  }, [token, email]);

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");

    if (password !== confirm) {
      setError("Passwords do not match.");
      return;
    }
    if (password.length < 8) {
      setError("Password must be at least 8 characters.");
      return;
    }

    setLoading(true);
    try {
      await authAPI.establishmentSetupPassword(email, token, password);
      setSuccess(true);
    } catch (err) {
      setError(
        err.response?.data?.message ||
          "Something went wrong. Please try again or contact your BPLO administrator.",
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-paper px-4">
      <div className="w-full max-w-sm">
        <div className="flex justify-center mb-8">
          <img src={LOGO_SRC} alt="iDetect" className="h-12 object-contain" />
        </div>

        <div
          style={{
            background: "#fff",
            border: "1px solid #e5e7eb",
            borderRadius: 12,
            padding: "32px 28px",
          }}
        >
          {success ? (
            <div className="text-center">
              <CheckCircle
                className="mx-auto mb-4"
                style={{ color: "#16a34a", width: 48, height: 48 }}
              />
              <h2
                className="font-bold text-xl text-gray-900 mb-2"
                style={{ letterSpacing: "-0.5px" }}
              >
                Password Set!
              </h2>
              <p className="text-sm text-gray-500 mb-6">
                Your account is ready. Sign in from the Client Portal mobile app
                using your registered email and new password.
              </p>
              <button
                onClick={() => navigate("/login")}
                className="w-full rounded-md py-2.5 text-sm font-semibold text-white"
                style={{ background: "#3b82f6" }}
              >
                Go to Sign In
              </button>
            </div>
          ) : (
            <>
              <h2
                className="font-bold text-2xl text-gray-900 mb-1"
                style={{ letterSpacing: "-0.5px" }}
              >
                Set Your Password
              </h2>
              <p className="text-xs text-gray-400 mb-6">
                Choose a password for{" "}
                <span className="font-medium text-gray-600">{email}</span>
              </p>

              {error && (
                <div
                  className="flex items-start gap-2.5 px-4 py-3 rounded-lg text-sm mb-4"
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

              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="block text-xs font-medium text-gray-500 mb-1">
                    New Password
                  </label>
                  <div className="relative">
                    <input
                      type={showPw ? "text" : "password"}
                      required
                      placeholder="At least 8 characters"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      disabled={loading || !token}
                      className="w-full rounded-md px-3.5 py-2.5 pr-10 text-sm text-gray-900 outline-none"
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

                <div>
                  <label className="block text-xs font-medium text-gray-500 mb-1">
                    Confirm Password
                  </label>
                  <div className="relative">
                    <input
                      type={showConfirm ? "text" : "password"}
                      required
                      placeholder="Repeat new password"
                      value={confirm}
                      onChange={(e) => setConfirm(e.target.value)}
                      disabled={loading || !token}
                      className="w-full rounded-md px-3.5 py-2.5 pr-10 text-sm text-gray-900 outline-none"
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
                      onClick={() => setShowConfirm((v) => !v)}
                      tabIndex={-1}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                    >
                      {showConfirm ? (
                        <EyeOff className="w-4 h-4" />
                      ) : (
                        <Eye className="w-4 h-4" />
                      )}
                    </button>
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={loading || !token || !password || !confirm}
                  className="w-full flex items-center justify-center gap-2 rounded-md py-2.5 text-sm font-semibold text-white"
                  style={{
                    background:
                      loading || !token || !password || !confirm
                        ? "#93c5fd"
                        : "#3b82f6",
                    cursor:
                      loading || !token || !password || !confirm
                        ? "not-allowed"
                        : "pointer",
                  }}
                >
                  {loading ? (
                    <>
                      <Loader2 className="w-4 h-4 animate-spin" />
                      Setting Password…
                    </>
                  ) : (
                    "Set Password"
                  )}
                </button>
              </form>
            </>
          )}
        </div>

        <p className="text-center text-xs text-gray-400 mt-4">
          © Valenzuela City
        </p>
      </div>
    </div>
  );
}
