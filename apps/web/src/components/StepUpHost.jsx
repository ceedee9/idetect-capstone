import { useEffect, useState } from "react";
import { Eye, EyeOff } from "lucide-react";
import { registerStepUpHost } from "../utils/stepUp";

export default function StepUpHost() {
  const [req, setReq] = useState(null);
  const [password, setPassword] = useState("");
  const [showPw, setShowPw] = useState(false);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(
    () =>
      registerStepUpHost(
        (reason, verify) =>
          new Promise((resolve, reject) => {
            setPassword("");
            setError("");
            setReq({ reason, verify, resolve, reject });
          }),
      ),
    [],
  );

  if (!req) return null;

  function cancel() {
    req.reject(new Error("cancelled"));
    setReq(null);
  }

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      const proof = await req.verify(password);
      req.resolve(proof);
      setReq(null);
    } catch {
      setError("Incorrect password. Try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="fixed inset-0 z-[70] bg-black/40 flex items-center justify-center p-4">
      <form onSubmit={submit} className="bg-white rounded-2xl shadow-xl w-full max-w-sm p-6 space-y-4">
        <h2 className="font-heading font-bold text-lg text-slate-900">Confirm your password</h2>
        <p className="text-sm text-slate-500">
          {req.reason || "This action involves sensitive data."}
        </p>
        <div className="relative">
          <input
            type={showPw ? "text" : "password"}
            autoFocus
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            className="w-full border border-slate-200 rounded-lg px-3 py-2 pr-10 text-sm"
            placeholder="Password"
          />
          <button
            type="button"
            onClick={() => setShowPw((v) => !v)}
            tabIndex={-1}
            aria-label={showPw ? "Hide password" : "Show password"}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
          >
            {showPw ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
          </button>
        </div>
        {error && <p className="text-sm text-red-600">{error}</p>}
        <div className="flex justify-end gap-2">
          <button type="button" className="btn-secondary" onClick={cancel}>
            Cancel
          </button>
          <button type="submit" className="btn-primary" disabled={busy || !password}>
            {busy ? "Checking…" : "Confirm"}
          </button>
        </div>
      </form>
    </div>
  );
}
