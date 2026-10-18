import { Outlet, NavLink, useNavigate } from "react-router-dom";
import {
  LayoutDashboard,
  Store,
  PhoneCall,
  Scale,
  ScrollText,
  UserCog,
  LogOut,
  ChevronRight,
  Bell,
  Menu,
  X,
  AlertTriangle,
  ShieldAlert,
} from "lucide-react";
import { useState } from "react";
import { useAuth } from "../context/AuthContext";
import { useSessionTimeout } from "../hooks/useSessionTimeout";
import BreachReportModal from "./BreachReportModal";

const NAV = [
  { to: "/", icon: LayoutDashboard, label: "Dashboard", end: true },
  { to: "/establishments", icon: Store, label: "Establishments" },
  { to: "/business-refusals", icon: Scale, label: "Refusal Reports" },
  { to: "/callback-requests", icon: PhoneCall, label: "Callback Requests" },
  { to: "/audit-logs", icon: ScrollText, label: "Audit Logs" },
  { to: "/staff", icon: UserCog, label: "Staff" },
];

export default function AppShell() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [showBreachModal, setShowBreachModal] = useState(false);
  const { showWarning, secondsLeft, stayLoggedIn } = useSessionTimeout();

  function handleLogout() {
    logout();
    navigate("/login");
  }

  return (
    <div className="flex h-screen bg-gray-50 overflow-hidden">
      {/* ── Mobile overlay ── */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 z-20 bg-black/40 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* ── Sidebar ── */}
      <aside
        className={`
        fixed lg:static inset-y-0 left-0 z-30
        flex flex-col w-64 bg-white border-r border-gray-100
        transform transition-transform duration-200 ease-in-out
        ${sidebarOpen ? "translate-x-0" : "-translate-x-full lg:translate-x-0"}
      `}
      >
        {/* Brand */}
        <div className="flex items-center gap-3 px-5 py-5 border-b border-gray-100">
          <div className="min-w-0">
            <img
              src="/idetect-logo.png"
              alt="iDetect"
              className="h-12 w-auto"
            />
            <p className="text-xs text-gov-600 font-medium mt-1">BPLO Portal</p>
          </div>
          <button
            onClick={() => setSidebarOpen(false)}
            className="ml-auto text-gray-400 hover:text-gray-600 lg:hidden"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Nav */}
        <nav className="flex-1 px-3 py-4 space-y-0.5 overflow-y-auto">
          {NAV.map(({ to, icon: Icon, label, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              onClick={() => setSidebarOpen(false)}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors duration-100 group
                 ${
                   isActive
                     ? "sidebar-item-active text-gov-700"
                     : "text-gray-600 hover:bg-gray-100 hover:text-gray-900"
                 }`
              }
            >
              {({ isActive }) => (
                <>
                  <Icon
                    className={`w-4.5 h-4.5 flex-shrink-0 ${isActive ? "text-gov-600" : "text-gray-400 group-hover:text-gray-600"}`}
                  />
                  <span>{label}</span>
                  {isActive && (
                    <ChevronRight className="w-3.5 h-3.5 ml-auto text-gov-400" />
                  )}
                </>
              )}
            </NavLink>
          ))}
        </nav>

        {/* Breach report shortcut */}
        <div className="mx-3 mb-1 px-3 py-2">
          <button
            onClick={() => setShowBreachModal(true)}
            className="flex items-center gap-1.5 text-[11px] font-semibold text-red-600 hover:text-red-700 transition-colors"
          >
            <ShieldAlert className="w-3.5 h-3.5" />
            Generate Breach Report
          </button>
        </div>

        {/* User footer */}
        <div className="border-t border-gray-100 px-3 py-3">
          <div className="flex items-center gap-3 px-2 py-2 rounded-lg">
            <div className="w-8 h-8 bg-gov-100 rounded-full flex items-center justify-center flex-shrink-0">
              <span className="text-xs font-bold text-gov-700">
                {user?.first_name?.[0]}
                {user?.last_name?.[0]}
              </span>
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-gray-900 truncate">
                {user?.first_name} {user?.last_name}
              </p>
              <p className="text-xs text-gray-500 truncate">{user?.email}</p>
            </div>
            <button
              onClick={handleLogout}
              title="Sign out"
              className="text-gray-400 hover:text-danger-600 transition-colors"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>
      </aside>

      {/* ── Main area ── */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        {/* Top bar (mobile) */}
        <header className="lg:hidden flex items-center gap-3 px-4 py-3 bg-white border-b border-gray-100 shadow-nav">
          <button
            onClick={() => setSidebarOpen(true)}
            className="text-gray-500"
          >
            <Menu className="w-5 h-5" />
          </button>
          <img src="/idetect-logo.png" alt="iDetect" className="h-8 w-auto" />
          <div className="ml-auto flex items-center gap-2">
            <button className="btn-ghost p-1.5">
              <Bell className="w-4.5 h-4.5" />
            </button>
          </div>
        </header>

        {/* Desktop top bar */}
        <header className="hidden lg:flex items-center justify-between px-8 py-4 bg-white border-b border-gray-100 shadow-nav">
          <div>
            <p className="text-xs text-gray-500 font-medium uppercase tracking-wider">
              Pamantasan ng Lungsod ng Valenzuela · BPLO
            </p>
          </div>
          <div className="flex items-center gap-3">
            <button className="btn-ghost relative">
              <Bell className="w-4 h-4" />
            </button>
            <div className="w-px h-5 bg-gray-200" />
            <span className="text-sm text-gray-600">
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

        {/* Page content */}
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
                  className="flex-1 px-4 py-2.5 rounded-xl bg-bplo-600 text-white text-sm font-semibold hover:bg-bplo-700 transition-colors"
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
