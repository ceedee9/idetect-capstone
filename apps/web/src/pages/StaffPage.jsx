import { useState, useEffect, useCallback } from "react";
import { createPortal } from "react-dom";
import {
  Users,
  Plus,
  RefreshCw,
  AlertCircle,
  UserCheck,
  UserX,
  KeyRound,
  Pencil,
  X,
  Check,
  Mail,
  User,
  Shield,
  LockOpen,
} from "lucide-react";
import { staffAPI } from "../services/api";
import { fmtDateTime } from "../utils/date";
import StatusBadge from "../components/StatusBadge";
import EmptyState from "../components/EmptyState";
import { useAuth } from "../context/AuthContext";

export default function StaffPage() {
  const { user } = useAuth();
  const [staff, setStaff] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [toast, setToast] = useState(null);

  // Modal state
  const [showCreate, setShowCreate] = useState(false);
  const [showEdit, setShowEdit] = useState(null); // staff object
  const [showResetPw, setShowResetPw] = useState(null); // staff object

  const fetchStaff = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await staffAPI.list();
      setStaff(res.data?.staff ?? []);
    } catch (err) {
      setError(err.response?.data?.error || "Failed to load staff.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchStaff();
  }, [fetchStaff]);

  function flash(msg) {
    setToast(msg);
    setTimeout(() => setToast(null), 3500);
  }

  async function handleToggleActive(member) {
    try {
      await staffAPI.toggleActive(member.id);
      flash(
        member.is_active
          ? `${member.full_name} deactivated.`
          : `${member.full_name} activated.`,
      );
      fetchStaff();
    } catch (err) {
      setError(err.response?.data?.error || "Failed to change account status.");
    }
  }

  async function handleUnlock(member) {
    try {
      await staffAPI.unlock(member.id);
      flash(`${member.full_name}'s account has been unlocked.`);
      fetchStaff();
    } catch (err) {
      setError(err.response?.data?.error || "Failed to unlock account.");
    }
  }

  return (
    <div className="px-6 lg:px-8 py-8 max-w-5xl mx-auto space-y-6">
      {/* Toast */}
      {toast && (
        <div className="fixed top-4 right-4 z-50 bg-success-600 text-white px-4 py-2.5 rounded-xl shadow-lg text-sm font-semibold animate-in slide-in-from-top-2">
          {toast}
        </div>
      )}

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="font-heading font-bold text-2xl text-slate-900">
            Staff Accounts
          </h1>
          <p className="text-slate-500 text-sm mt-0.5 font-medium">
            {user?.role === "super_admin"
              ? "Manage authorized staff accounts and roles"
              : `Manage ${roleLabel(user?.role)} user accounts`}
          </p>
        </div>
        <div className="flex items-center gap-2 self-start">
          <button onClick={() => setShowCreate(true)} className="btn-primary">
            <Plus className="w-4 h-4" />
            Add Staff
          </button>
          <button
            onClick={fetchStaff}
            disabled={loading}
            className="btn-secondary"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? "animate-spin" : ""}`} />
            Refresh
          </button>
        </div>
      </div>

      {error && (
        <div className="flex items-center gap-2.5 px-4 py-3 bg-danger-50 border border-danger-100 rounded-xl text-danger-700 text-sm">
          <AlertCircle className="w-4 h-4 flex-shrink-0" />
          {error}
          <button
            className="ml-auto text-danger-400 hover:text-danger-600"
            onClick={() => setError(null)}
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* Summary */}
      <div className="grid grid-cols-2 gap-4">
        <div className="card p-4">
          <p className="text-xs font-bold uppercase tracking-wider text-slate-400">
            Total Accounts
          </p>
          <p className="font-heading font-bold text-2xl text-slate-900 mt-1">
            {loading ? "—" : staff.length}
          </p>
        </div>
        <div className="card p-4">
          <p className="text-xs font-bold uppercase tracking-wider text-slate-400">
            Active
          </p>
          <p className="font-heading font-bold text-2xl text-success-600 mt-1">
            {loading ? "—" : staff.filter((s) => s.is_active).length}
          </p>
        </div>
      </div>

      {/* Staff list */}
      <div className="card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-200 bg-tableHeader">
                <th className="text-left px-4 py-3 font-semibold text-slate-500 text-xs uppercase tracking-wider">
                  Name
                </th>
                <th className="text-left px-4 py-3 font-semibold text-slate-500 text-xs uppercase tracking-wider">
                  Email
                </th>
                <th className="text-left px-4 py-3 font-semibold text-slate-500 text-xs uppercase tracking-wider">
                  Status
                </th>
                <th className="text-left px-4 py-3 font-semibold text-slate-500 text-xs uppercase tracking-wider">
                  Created
                </th>
                <th className="text-right px-4 py-3 font-semibold text-slate-500 text-xs uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-200">
              {loading ? (
                [...Array(3)].map((_, i) => (
                  <tr key={i}>
                    {[...Array(5)].map((__, j) => (
                      <td key={j} className="px-4 py-2.5">
                        <div className="skeleton h-4 w-full rounded" />
                      </td>
                    ))}
                  </tr>
                ))
              ) : staff.length === 0 ? (
                <tr>
                  <td colSpan={5}>
                    <EmptyState
                      icon={Users}
                      tone="gov"
                      title="No staff accounts found"
                      description="Add an authorized staff account to manage this portal."
                    />
                  </td>
                </tr>
              ) : (
                staff.map((m) => (
                  <tr key={m.id} className="transition-colors">
                    <td className="px-4 py-2.5 font-medium text-slate-900">
                      {m.full_name}
                    </td>
                    <td className="px-4 py-2.5 font-mono text-xs text-slate-500">
                      {m.email}
                    </td>
                    <td className="px-4 py-2.5">
                      <div className="flex items-center gap-1.5">
                        <StatusBadge
                          status={m.is_active ? "active" : "inactive"}
                        />
                        {m.locked_until &&
                          new Date() < new Date(m.locked_until) && (
                            <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-amber-50 text-amber-700 border border-amber-100">
                              Locked
                            </span>
                          )}
                      </div>
                    </td>
                    <td className="px-4 py-2.5 font-mono text-xs text-slate-400">
                      {fmtDateTime(m.created_at)}
                    </td>
                    <td className="px-4 py-2.5">
                      <div className="flex items-center justify-end gap-1">
                        <button
                          title="Edit"
                          onClick={() => setShowEdit(m)}
                          className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-700 transition-colors"
                        >
                          <Pencil className="w-4 h-4" />
                        </button>
                        <button
                          title="Reset password"
                          onClick={() => setShowResetPw(m)}
                          className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-400 hover:text-slate-700 transition-colors"
                        >
                          <KeyRound className="w-4 h-4" />
                        </button>
                        <button
                          title={m.is_active ? "Deactivate" : "Activate"}
                          onClick={() => handleToggleActive(m)}
                          className={`p-1.5 rounded-lg transition-colors ${
                            m.is_active
                              ? "hover:bg-danger-50 text-slate-400 hover:text-danger-600"
                              : "hover:bg-success-50 text-slate-400 hover:text-success-600"
                          }`}
                        >
                          {m.is_active ? (
                            <UserX className="w-4 h-4" />
                          ) : (
                            <UserCheck className="w-4 h-4" />
                          )}
                        </button>
                        {m.locked_until &&
                          new Date() < new Date(m.locked_until) && (
                            <button
                              title="Unlock account"
                              onClick={() => handleUnlock(m)}
                              className="p-1.5 rounded-lg hover:bg-amber-50 text-amber-500 hover:text-amber-700 transition-colors"
                            >
                              <LockOpen className="w-4 h-4" />
                            </button>
                          )}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Create modal */}
      {showCreate && (
        <CreateStaffModal
          isSuperAdmin={user?.role === "super_admin"}
          currentRole={user?.role}
          onClose={() => setShowCreate(false)}
          onCreated={() => {
            setShowCreate(false);
            flash("Staff account created.");
            fetchStaff();
          }}
        />
      )}

      {/* Edit modal */}
      {showEdit && (
        <EditStaffModal
          member={showEdit}
          onClose={() => setShowEdit(null)}
          onUpdated={() => {
            setShowEdit(null);
            flash("Staff updated.");
            fetchStaff();
          }}
        />
      )}

      {/* Reset password modal */}
      {showResetPw && (
        <ResetPasswordModal
          member={showResetPw}
          onClose={() => setShowResetPw(null)}
          onReset={() => {
            setShowResetPw(null);
            flash("Password reset.");
            fetchStaff();
          }}
        />
      )}
    </div>
  );
}

/* ── Modals ────────────────────────────────────────────────── */

function Overlay({ children, onClose }) {
  return createPortal(
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-4">
      <div
        className="absolute inset-0 bg-slate-950/45"
        onClick={onClose}
        aria-hidden="true"
      />
      <div className="relative flex max-h-[calc(100vh-2rem)] w-full max-w-md flex-col overflow-y-auto rounded-2xl bg-white p-6 shadow-2xl">
        <div className="space-y-4">{children}</div>
      </div>
    </div>,
    document.body,
  );
}

function roleLabel(role) {
  return (
    {
      super_admin: "Super Admin",
      bplo_admin: "BPLO",
      osca_admin: "OSCA",
      pdao_admin: "PDAO",
    }[role] || "staff"
  );
}

function CreateStaffModal({ onClose, onCreated, isSuperAdmin, currentRole }) {
  const [form, setForm] = useState({
    full_name: "",
    email: "",
    password: "",
    role: isSuperAdmin ? "bplo_admin" : currentRole,
  });
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");

  async function handleSubmit(e) {
    e.preventDefault();
    setBusy(true);
    setErr("");
    try {
      await staffAPI.create(form);
      onCreated();
    } catch (ex) {
      setErr(ex.response?.data?.error || "Failed to create account.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Overlay onClose={onClose}>
      <div className="flex items-center justify-between">
        <h2 className="font-heading font-bold text-lg text-slate-900">
          Add Staff Account
        </h2>
        <button
          onClick={onClose}
          className="text-slate-400 hover:text-slate-600"
        >
          <X className="w-5 h-5" />
        </button>
      </div>
      <form
        onSubmit={handleSubmit}
        className="space-y-3"
        autoComplete="off"
      >
        <div>
          <label className="label text-xs">Full Name</label>
          <div className="relative">
            <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
            <input
              type="text"
              className="input pl-9 text-sm w-full"
              placeholder="Juan Dela Cruz"
              required
              minLength={2}
              value={form.full_name}
              onChange={(e) => setForm({ ...form, full_name: e.target.value })}
            />
          </div>
        </div>
        <div>
          <label className="label text-xs">Email</label>
          <div className="relative">
            <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
            <input
              type="email"
              className="input pl-9 text-sm w-full"
              placeholder="name@valenzuela.gov.ph"
              required
              autoComplete="off"
              value={form.email}
              onChange={(e) => setForm({ ...form, email: e.target.value })}
            />
          </div>
        </div>
        <div>
          <label className="label text-xs">Password</label>
          <div className="relative">
            <KeyRound className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
            <input
              type="password"
              className="input pl-9 text-sm w-full"
              placeholder="Min 8 characters"
              required
              minLength={8}
              autoComplete="new-password"
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
            />
          </div>
        </div>
        <div>
          <label className="label text-xs">Staff role</label>
          {isSuperAdmin ? (
            <select
              className="input text-sm w-full"
              value={form.role}
              onChange={(e) => setForm({ ...form, role: e.target.value })}
            >
              <option value="bplo_admin">BPLO Admin</option>
              <option value="osca_admin">OSCA Admin</option>
              <option value="pdao_admin">PDAO Admin</option>
            </select>
          ) : (
            <div className="input text-sm w-full bg-slate-50 text-slate-600">
              {roleLabel(currentRole)} Admin
            </div>
          )}
        </div>
        <div className="flex items-center gap-1.5 text-xs text-slate-400">
          <Shield className="w-3.5 h-3.5" />
          {isSuperAdmin
            ? "Only approved office-admin roles can be assigned here."
            : `Account will be created as a ${roleLabel(currentRole)} Admin.`}
        </div>
        {err && (
          <p className="text-sm text-danger-600 flex items-center gap-1.5">
            <AlertCircle className="w-4 h-4" />
            {err}
          </p>
        )}
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={onClose} className="btn-secondary">
            Cancel
          </button>
          <button type="submit" disabled={busy} className="btn-primary">
            {busy ? "Creating…" : "Create Account"}
          </button>
        </div>
      </form>
    </Overlay>
  );
}

function EditStaffModal({ member, onClose, onUpdated }) {
  const [form, setForm] = useState({
    full_name: member.full_name,
    email: member.email,
  });
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");

  async function handleSubmit(e) {
    e.preventDefault();
    setBusy(true);
    setErr("");
    try {
      const data = {};
      if (form.full_name !== member.full_name) data.full_name = form.full_name;
      if (form.email !== member.email) data.email = form.email;
      if (!Object.keys(data).length) {
        onClose();
        return;
      }
      await staffAPI.update(member.id, data);
      onUpdated();
    } catch (ex) {
      setErr(ex.response?.data?.error || "Failed to update.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Overlay onClose={onClose}>
      <div className="flex items-center justify-between">
        <h2 className="font-heading font-bold text-lg text-slate-900">
          Edit Staff
        </h2>
        <button
          onClick={onClose}
          className="text-slate-400 hover:text-slate-600"
        >
          <X className="w-5 h-5" />
        </button>
      </div>
      <form onSubmit={handleSubmit} className="space-y-3">
        <div>
          <label className="label text-xs">Full Name</label>
          <input
            type="text"
            className="input text-sm w-full"
            required
            minLength={2}
            value={form.full_name}
            onChange={(e) => setForm({ ...form, full_name: e.target.value })}
          />
        </div>
        <div>
          <label className="label text-xs">Email</label>
          <input
            type="email"
            className="input text-sm w-full"
            required
            value={form.email}
            onChange={(e) => setForm({ ...form, email: e.target.value })}
          />
        </div>
        {err && (
          <p className="text-sm text-danger-600 flex items-center gap-1.5">
            <AlertCircle className="w-4 h-4" />
            {err}
          </p>
        )}
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={onClose} className="btn-secondary">
            Cancel
          </button>
          <button type="submit" disabled={busy} className="btn-primary">
            {busy ? "Saving…" : "Save Changes"}
          </button>
        </div>
      </form>
    </Overlay>
  );
}

function ResetPasswordModal({ member, onClose, onReset }) {
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");

  async function handleSubmit(e) {
    e.preventDefault();
    setBusy(true);
    setErr("");
    try {
      await staffAPI.resetPassword(member.id, password);
      onReset();
    } catch (ex) {
      setErr(ex.response?.data?.error || "Failed to reset password.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <Overlay onClose={onClose}>
      <div className="flex items-center justify-between">
        <h2 className="font-heading font-bold text-lg text-slate-900">
          Reset Password
        </h2>
        <button
          onClick={onClose}
          className="text-slate-400 hover:text-slate-600"
        >
          <X className="w-5 h-5" />
        </button>
      </div>
      <p className="text-sm text-slate-500">
        Set a new password for{" "}
        <span className="font-semibold text-slate-700">{member.full_name}</span>
      </p>
      <form onSubmit={handleSubmit} className="space-y-3">
        <div>
          <label className="label text-xs">New Password</label>
          <div className="relative">
            <KeyRound className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
            <input
              type="password"
              className="input pl-9 text-sm w-full"
              placeholder="Min 8 characters"
              required
              minLength={8}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>
        </div>
        {err && (
          <p className="text-sm text-danger-600 flex items-center gap-1.5">
            <AlertCircle className="w-4 h-4" />
            {err}
          </p>
        )}
        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={onClose} className="btn-secondary">
            Cancel
          </button>
          <button type="submit" disabled={busy} className="btn-primary">
            {busy ? "Resetting…" : "Reset Password"}
          </button>
        </div>
      </form>
    </Overlay>
  );
}
