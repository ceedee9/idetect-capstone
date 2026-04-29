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
} from "lucide-react";
import { useState } from "react";
import { useAuth } from "../context/AuthContext";

const NAV = [
  { to: "/", icon: LayoutDashboard, label: "Dashboard", end: true },
  { to: "/beneficiaries", icon: Users, label: "Senior Citizens" },
  { to: "/fraud-flags", icon: Flag, label: "Fraud Flags" },
  { to: "/disputes", icon: Scale, label: "Disputes" },
  { to: "/audit-logs", icon: ScrollText, label: "Audit Logs" },
  { to: "/staff", icon: UserCog, label: "Staff" },
];

export default function AppShell() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);

  function handleLogout() {
    logout();
    navigate("/login");
  }

  return (
    <div className="flex h-screen bg-slate-50 overflow-hidden">
      {/* Mobile overlay */}
      {open && (
        <div
          className="fixed inset-0 z-20 bg-black/40 lg:hidden"
          onClick={() => setOpen(false)}
        />
      )}

      {/* ── Sidebar ── */}
      <aside
        className={`
        fixed lg:static inset-y-0 left-0 z-30 flex flex-col w-64
        bg-white border-r border-slate-100
        transform transition-transform duration-200
        ${open ? "translate-x-0" : "-translate-x-full lg:translate-x-0"}
      `}
      >
        {/* Brand */}
        <div className="flex items-center gap-3 px-5 py-5 border-b border-slate-100">
          <div className="min-w-0">
            <img
              src="/idetect-logo.png"
              alt="iDetect"
              className="h-12 w-auto"
            />
            <p className="text-xs text-osca-600 font-semibold mt-1">
              OSCA Portal
            </p>
          </div>
          <button
            onClick={() => setOpen(false)}
            className="ml-auto text-slate-400 hover:text-slate-600 lg:hidden"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Section label */}
        <div className="px-5 pt-5 pb-2">
          <p className="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
            Navigation
          </p>
        </div>

        {/* Nav links */}
        <nav className="flex-1 px-3 space-y-0.5 overflow-y-auto">
          {NAV.map(({ to, icon: Icon, label, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              onClick={() => setOpen(false)}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-semibold transition-all duration-100 group
                 ${isActive ? "sidebar-active text-osca-700" : "text-slate-500 hover:bg-slate-50 hover:text-slate-800"}`
              }
            >
              {({ isActive }) => (
                <>
                  <Icon
                    className={`w-4.5 h-4.5 flex-shrink-0 ${isActive ? "text-osca-600" : "text-slate-400 group-hover:text-slate-600"}`}
                  />
                  <span className="flex-1">{label}</span>
                  {isActive && (
                    <ChevronRight className="w-3.5 h-3.5 text-osca-400" />
                  )}
                </>
              )}
            </NavLink>
          ))}
        </nav>

        {/* Scope note */}
        <div className="mx-3 mb-3 px-3 py-2.5 bg-osca-50 rounded-xl border border-osca-100">
          <p className="text-[10px] font-bold text-osca-700 uppercase tracking-wider mb-0.5">
            Scope
          </p>
          <p className="text-xs text-osca-600 leading-relaxed">
            Senior Citizen records only. PWD data is in the PDAO Portal.
          </p>
        </div>

        {/* User */}
        <div className="border-t border-slate-100 px-3 py-3">
          <div className="flex items-center gap-3 px-2 py-2 rounded-xl">
            <div className="w-8 h-8 bg-osca-100 rounded-full flex items-center justify-center flex-shrink-0">
              <span className="text-xs font-bold text-osca-700">
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
        {/* Mobile header */}
        <header className="lg:hidden flex items-center gap-3 px-4 py-3 bg-white border-b border-slate-100">
          <button onClick={() => setOpen(true)} className="text-slate-500">
            <Menu className="w-5 h-5" />
          </button>
          <img src="/idetect-logo.png" alt="iDetect" className="h-8 w-auto" />
          <div className="ml-auto">
            <button className="btn-ghost p-1.5">
              <Bell className="w-4.5 h-4.5" />
            </button>
          </div>
        </header>

        {/* Desktop header */}
        <header className="hidden lg:flex items-center justify-between px-8 py-4 bg-white border-b border-slate-100">
          <p className="text-xs text-slate-400 font-semibold uppercase tracking-wider">
            Pamantasan ng Lungsod ng Valenzuela · Office of Senior Citizens
            Affairs
          </p>
          <div className="flex items-center gap-3">
            <button className="btn-ghost">
              <Bell className="w-4 h-4" />
            </button>
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
    </div>
  );
}
