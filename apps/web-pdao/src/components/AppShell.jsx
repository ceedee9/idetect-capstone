import { Outlet, NavLink, useNavigate } from "react-router-dom";
import {
  LayoutDashboard,
  Users,
  Flag,
  Scale,
  ScrollText,
  UserCog,
  LogOut,
  Menu,
  X,
  Bell,
  ChevronRight,
  AlertTriangle,
  ShieldAlert,
} from "lucide-react";
import { useState, useEffect, useRef } from "react";
import { useAuth } from "../context/AuthContext";
import { useSessionTimeout } from "../hooks/useSessionTimeout";
import BreachReportModal from "./BreachReportModal";
import { staffAlertsAPI } from "../services/api";
import { fmtRelative } from "../utils/date";

const NAV = [
  { to: "/", icon: LayoutDashboard, label: "Dashboard", end: true },
  { to: "/beneficiaries", icon: Users, label: "PWD Records" },
  { to: "/fraud-flags", icon: Flag, label: "Fraud Flags" },
  { to: "/disputes", icon: Scale, label: "Disputes" },
  { to: "/audit-logs", icon: ScrollText, label: "Audit Logs" },
  { to: "/staff", icon: UserCog, label: "Staff" },
];

export default function AppShell() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);
  const [showBreachModal, setShowBreachModal] = useState(false);
  const { showWarning, secondsLeft, stayLoggedIn } = useSessionTimeout();

  // ── Notification bell ─────────────────────────────────────
  const [bellOpen, setBellOpen] = useState(false);
  const [alerts, setAlerts] = useState([]);
  const bellRef = useRef(null);

  async function loadAlerts() {
    try {
      const res = await staffAlertsAPI.list();
      setAlerts(res.data?.alerts ?? []);
    } catch {
      // silently ignore
    }
  }

  useEffect(() => {
    loadAlerts();
    const interval = setInterval(loadAlerts, 30000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    if (!bellOpen) return;
    function handleClickOutside(e) {
      if (bellRef.current && !bellRef.current.contains(e.target)) {
        setBellOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, [bellOpen]);

  const unreadCount = alerts.filter((a) => !a.is_read).length;

  async function handleMarkAllRead() {
    try {
      await staffAlertsAPI.markAllRead();
      setAlerts((prev) => prev.map((a) => ({ ...a, is_read: true })));
    } catch {
      // silently ignore
    }
  }

  function handleLogout() {
    logout();
    navigate("/login");
  }

  return (
    <div className="flex h-screen bg-slate-50 overflow-hidden">
      {open && (
        <div
          className="fixed inset-0 z-20 bg-black/40 lg:hidden"
          onClick={() => setOpen(false)}
        />
      )}

      {/* ── Sidebar ── */}
      <aside
        className={`fixed lg:static inset-y-0 left-0 z-30 flex flex-col w-64 bg-white border-r border-slate-100 transform transition-transform duration-200 ${open ? "translate-x-0" : "-translate-x-full lg:translate-x-0"}`}
      >
        {/* Brand */}
        <div className="flex items-center gap-3 px-5 py-5 border-b border-slate-100">
          <div className="min-w-0">
            <img
              src="/idetect-logo.png"
              alt="iDetect"
              className="h-12 w-auto"
            />
            <p className="text-xs text-pdao-600 font-semibold mt-1">
              PDAO Portal
            </p>
          </div>
          <button
            onClick={() => setOpen(false)}
            className="ml-auto text-slate-400 hover:text-slate-600 lg:hidden"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="px-5 pt-5 pb-2">
          <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
            Navigation
          </p>
        </div>

        <nav className="flex-1 px-3 space-y-0.5 overflow-y-auto">
          {NAV.map(({ to, icon: Icon, label, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              onClick={() => setOpen(false)}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-semibold transition-all duration-100 group
                 ${isActive ? "sidebar-active text-pdao-700" : "text-slate-500 hover:bg-slate-50 hover:text-slate-800"}`
              }
            >
              {({ isActive }) => (
                <>
                  <Icon
                    className={`w-4.5 h-4.5 flex-shrink-0 ${isActive ? "text-pdao-600" : "text-slate-400 group-hover:text-slate-600"}`}
                  />
                  <span className="flex-1">{label}</span>
                  {isActive && (
                    <ChevronRight className="w-3.5 h-3.5 text-pdao-400" />
                  )}
                </>
              )}
            </NavLink>
          ))}
        </nav>

        {/* Scope note */}
        <div className="mx-3 mb-3 px-3 py-2.5 bg-pdao-50 rounded-xl border border-pdao-100">
          <p className="text-[10px] font-bold text-pdao-700 uppercase tracking-wider mb-0.5">
            Scope
          </p>
          <p className="text-xs text-pdao-600 leading-relaxed">
            PWD records only (RA 10754). Senior Citizen data is in the OSCA
            Portal.
          </p>
          <button
            onClick={() => setShowBreachModal(true)}
            className="mt-2 flex items-center gap-1.5 text-[11px] font-semibold text-red-600 hover:text-red-700 transition-colors"
          >
            <ShieldAlert className="w-3.5 h-3.5" />
            Generate Breach Report
          </button>
        </div>

        {/* User */}
        <div className="border-t border-slate-100 px-3 py-3">
          <div className="flex items-center gap-3 px-2 py-2 rounded-xl">
            <div className="w-8 h-8 bg-pdao-100 rounded-full flex items-center justify-center flex-shrink-0">
              <span className="text-xs font-bold text-pdao-700">
                {user?.first_name?.[0]}
                {user?.last_name?.[0]}
              </span>
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-semibold text-slate-900 truncate">
                {user?.first_name} {user?.last_name}
              </p>
              <p className="text-xs text-slate-400 truncate">{user?.email}</p>
            </div>
            <button
              onClick={handleLogout}
              title="Sign out"
              className="text-slate-400 hover:text-danger-600 transition-colors"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>
      </aside>

      {/* ── Main ── */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        <header className="lg:hidden flex items-center gap-3 px-4 py-3 bg-white border-b border-slate-100">
          <button onClick={() => setOpen(true)} className="text-slate-500">
            <Menu className="w-5 h-5" />
          </button>
          <img src="/idetect-logo.png" alt="iDetect" className="h-8 w-auto" />
          <div className="ml-auto" ref={bellRef}>
            <button
              className="btn-ghost p-1.5 relative"
              onClick={() => {
                setBellOpen((b) => !b);
                loadAlerts();
              }}
            >
              <Bell className="w-4.5 h-4.5" />
              {unreadCount > 0 && (
                <span className="absolute -top-0.5 -right-0.5 w-4 h-4 bg-danger-500 rounded-full text-[9px] text-white font-bold flex items-center justify-center">
                  {unreadCount > 9 ? "9+" : unreadCount}
                </span>
              )}
            </button>
            {bellOpen && (
              <div className="absolute right-4 top-14 w-80 bg-white rounded-xl shadow-lg border border-slate-200 z-50 overflow-hidden">
                <div className="flex items-center justify-between px-4 py-3 border-b border-slate-100">
                  <h3 className="text-sm font-semibold text-slate-800">
                    Notifications
                  </h3>
                  {unreadCount > 0 && (
                    <button
                      onClick={handleMarkAllRead}
                      className="text-xs text-pdao-600 hover:text-pdao-700 font-medium"
                    >
                      Mark all read
                    </button>
                  )}
                </div>
                <div className="max-h-72 overflow-y-auto divide-y divide-slate-50">
                  {alerts.length === 0 ? (
                    <div className="py-8 text-center text-slate-400 text-sm">
                      <Bell className="w-7 h-7 mx-auto mb-2 opacity-25" />
                      No notifications
                    </div>
                  ) : (
                    alerts.map((a) => (
                      <div
                        key={a.id}
                        className={`px-4 py-3 ${a.is_read ? "" : "bg-pdao-50"}`}
                      >
                        <p className="text-xs font-semibold text-slate-800">
                          {a.title}
                        </p>
                        <p className="text-xs text-slate-500 mt-0.5 leading-snug">
                          {a.body}
                        </p>
                        <p className="text-[10px] text-slate-300 mt-1">
                          {fmtRelative(a.created_at)}
                        </p>
                      </div>
                    ))
                  )}
                </div>
              </div>
            )}
          </div>
        </header>

        <header className="hidden lg:flex items-center justify-between px-8 py-4 bg-white border-b border-slate-100">
          <p className="text-xs text-slate-400 font-semibold uppercase tracking-wider">
            Pamantasan ng Lungsod ng Valenzuela · Persons with Disability
            Affairs Office
          </p>
          <div className="flex items-center gap-3">
            <div className="relative" ref={bellRef}>
              <button
                className="btn-ghost relative"
                onClick={() => {
                  setBellOpen((b) => !b);
                  loadAlerts();
                }}
              >
                <Bell className="w-4 h-4" />
                {unreadCount > 0 && (
                  <span className="absolute -top-1 -right-1 w-4 h-4 bg-danger-500 rounded-full text-[9px] text-white font-bold flex items-center justify-center">
                    {unreadCount > 9 ? "9+" : unreadCount}
                  </span>
                )}
              </button>
              {bellOpen && (
                <div className="absolute right-0 top-10 w-80 bg-white rounded-xl shadow-lg border border-slate-200 z-50 overflow-hidden">
                  <div className="flex items-center justify-between px-4 py-3 border-b border-slate-100">
                    <h3 className="text-sm font-semibold text-slate-800">
                      Notifications
                    </h3>
                    {unreadCount > 0 && (
                      <button
                        onClick={handleMarkAllRead}
                        className="text-xs text-pdao-600 hover:text-pdao-700 font-medium"
                      >
                        Mark all read
                      </button>
                    )}
                  </div>
                  <div className="max-h-72 overflow-y-auto divide-y divide-slate-50">
                    {alerts.length === 0 ? (
                      <div className="py-8 text-center text-slate-400 text-sm">
                        <Bell className="w-7 h-7 mx-auto mb-2 opacity-25" />
                        No notifications
                      </div>
                    ) : (
                      alerts.map((a) => (
                        <div
                          key={a.id}
                          className={`px-4 py-3 ${a.is_read ? "" : "bg-pdao-50"}`}
                        >
                          <p className="text-xs font-semibold text-slate-800">
                            {a.title}
                          </p>
                          <p className="text-xs text-slate-500 mt-0.5 leading-snug">
                            {a.body}
                          </p>
                          <p className="text-[10px] text-slate-300 mt-1">
                            {fmtRelative(a.created_at)}
                          </p>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              )}
            </div>
            <div className="w-px h-5 bg-slate-200" />
            <span className="text-sm text-slate-600 font-medium">
              {user?.first_name} {user?.last_name}
            </span>
            <button
              onClick={handleLogout}
              className="btn-ghost text-danger-600 hover:bg-danger-50"
            >
              <LogOut className="w-4 h-4" />
              <span>Sign out</span>
            </button>
          </div>
        </header>

        <main className="flex-1 overflow-y-auto">
          <div className="page-enter">
            <Outlet />
          </div>
        </main>
      </div>

      {/* ── Session inactivity warning (REQ-2.17.7) ── */}
      {showWarning && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
          <div className="bg-white rounded-2xl shadow-2xl p-8 max-w-sm w-full mx-4">
            <div className="flex flex-col items-center text-center gap-4">
              <div className="w-14 h-14 rounded-full bg-amber-100 flex items-center justify-center">
                <AlertTriangle className="w-7 h-7 text-amber-600" />
              </div>
              <div>
                <h3 className="text-lg font-bold text-slate-900">
                  Session Expiring Soon
                </h3>
                <p className="text-sm text-slate-500 mt-1">
                  You will be automatically signed out in{" "}
                  <span className="font-bold text-amber-600">
                    {secondsLeft}s
                  </span>{" "}
                  due to inactivity.
                </p>
              </div>
              <div className="flex gap-3 w-full">
                <button
                  onClick={handleLogout}
                  className="flex-1 px-4 py-2.5 rounded-xl border border-slate-200 text-sm font-semibold text-slate-600 hover:bg-slate-50 transition-colors"
                >
                  Sign out now
                </button>
                <button
                  onClick={stayLoggedIn}
                  className="flex-1 px-4 py-2.5 rounded-xl bg-pdao-600 text-white text-sm font-semibold hover:bg-pdao-700 transition-colors"
                >
                  Stay logged in
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
      {showBreachModal && (
        <BreachReportModal onClose={() => setShowBreachModal(false)} />
      )}
    </div>
  );
}
