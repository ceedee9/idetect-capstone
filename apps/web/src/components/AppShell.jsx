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
  Store,
  Landmark,
} from "lucide-react";
import { useState, useEffect, useRef, useCallback } from "react";
import StepUpHost from "./StepUpHost";
import { useAuth } from "../context/AuthContext";
import { useSessionTimeout } from "../hooks/useSessionTimeout";
import BreachReportModal from "./BreachReportModal";
import { staffAlertsAPI } from "../services/api";
import { connectStaffAlertStream } from "../utils/staffAlertStream";
import { fmtRelative } from "../utils/date";
import { CivicStripe } from "./CivicChrome";

// ── Role-based navigation configuration ──────────────────────────────────────
const NAV_BY_ROLE = {
  osca_admin: [
    { to: "/", icon: LayoutDashboard, label: "Dashboard", end: true },
    { to: "/beneficiaries", icon: Users, label: "Senior Citizens" },
    { to: "/fraud-flags", icon: Flag, label: "Fraud Flags" },
    { to: "/disputes", icon: Scale, label: "Disputes" },
    { to: "/audit-logs", icon: ScrollText, label: "Audit Logs" },
    { to: "/staff", icon: UserCog, label: "Staff" },
  ],
  pdao_admin: [
    { to: "/", icon: LayoutDashboard, label: "Dashboard", end: true },
    { to: "/beneficiaries", icon: Users, label: "PWD Records" },
    { to: "/fraud-flags", icon: Flag, label: "Fraud Flags" },
    { to: "/disputes", icon: Scale, label: "Disputes" },
    { to: "/audit-logs", icon: ScrollText, label: "Audit Logs" },
    { to: "/staff", icon: UserCog, label: "Staff" },
  ],
  bplo_admin: [
    { to: "/", icon: LayoutDashboard, label: "Dashboard", end: true },
    { to: "/establishments", icon: Store, label: "Establishments" },
    { to: "/business-refusals", icon: Scale, label: "Refusal Reports" },
    { to: "/audit-logs", icon: ScrollText, label: "Audit Logs" },
    { to: "/staff", icon: UserCog, label: "Staff" },
  ],
};

// ── Role-to-theme mapping ─────────────────────────────────────────────────────
// Returns Tailwind class fragments per portal identity color
const THEME = {
  osca_admin: {
    accent: "osca", // used as text-osca-600, bg-osca-50, etc.
    brandText: "text-osca-600",
    portalLabel: "OSCA Portal",
    scopeText: "Senior Citizen records only. PWD data is in the PDAO Portal.",
    headerLabel: "Office of Senior Citizens Affairs",
    sidebarActive:
      "sidebar-active-osca text-osca-700 border-l-2 border-osca-600",
    sidebarIcon: "text-osca-600",
    sidebarChevron: "text-osca-400",
    avatarBg: "bg-osca-100",
    avatarText: "text-osca-700",
    scopeBg: "bg-white border-osca-300 border-l-2",
    scopeTitle: "text-osca-700",
    scopeBody: "text-slate-600",
    scopeMarker: "text-osca-600",
    stayBtn: "bg-osca-600 hover:bg-osca-700",
    alertBg: "bg-osca-50",
    viewBtn: "text-osca-600 hover:text-osca-700",
  },
  pdao_admin: {
    accent: "pdao",
    brandText: "text-pdao-600",
    portalLabel: "PDAO Portal",
    scopeText: "PWD records only. Senior Citizen data is in the OSCA Portal.",
    headerLabel: "Persons with Disability Affairs Office",
    sidebarActive:
      "sidebar-active-pdao text-pdao-700 border-l-2 border-pdao-600",
    sidebarIcon: "text-pdao-600",
    sidebarChevron: "text-pdao-400",
    avatarBg: "bg-pdao-100",
    avatarText: "text-pdao-700",
    scopeBg: "bg-white border-pdao-300 border-l-2",
    scopeTitle: "text-pdao-700",
    scopeBody: "text-slate-600",
    scopeMarker: "text-pdao-600",
    stayBtn: "bg-pdao-600 hover:bg-pdao-700",
    alertBg: "bg-pdao-50",
    viewBtn: "text-pdao-600 hover:text-pdao-700",
  },
  bplo_admin: {
    accent: "gov",
    brandText: "text-gov-600",
    portalLabel: "BPLO Portal",
    scopeText: "Business Permit & Licensing Office management.",
    headerLabel: "Business Permit & Licensing Office",
    sidebarActive: "sidebar-item-active text-gov-700 border-l-2 border-gov-600",
    sidebarIcon: "text-gov-600",
    sidebarChevron: "text-gov-400",
    avatarBg: "bg-gov-100",
    avatarText: "text-gov-700",
    scopeBg: "bg-white border-gov-300 border-l-2",
    scopeTitle: "text-gov-700",
    scopeBody: "text-slate-600",
    scopeMarker: "text-gov-600",
    stayBtn: "bg-gov-600 hover:bg-gov-700",
    alertBg: "bg-gov-50",
    viewBtn: "text-gov-600 hover:text-gov-700",
  },
};

export default function AppShell() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const [open, setOpen] = useState(false);
  const [showBreachModal, setShowBreachModal] = useState(false);
  const { showWarning, secondsLeft, stayLoggedIn } = useSessionTimeout();

  // ── Notification bell ─────────────────────────────────────
  const [bellOpen, setBellOpen] = useState(false);
  const [alerts, setAlerts] = useState([]);
  const [alertsError, setAlertsError] = useState("");
  const [liveStatus, setLiveStatus] = useState("connecting");
  const [toasts, setToasts] = useState([]);
  const [desktopPermission, setDesktopPermission] = useState(() =>
    typeof Notification === "undefined" ? "unsupported" : Notification.permission,
  );
  const bellRef = useRef(null);
  const knownAlertIds = useRef(new Set());
  // Refs keep the live handler stable so route changes never reset the stream.
  const navigateRef = useRef(navigate);
  const desktopPermissionRef = useRef(desktopPermission);
  navigateRef.current = navigate;
  desktopPermissionRef.current = desktopPermission;

  const loadAlerts = useCallback(async () => {
    try {
      const res = await staffAlertsAPI.list();
      const list = res.data?.alerts ?? [];
      list.forEach((a) => knownAlertIds.current.add(a.id));
      setAlerts(list);
      setAlertsError("");
    } catch (error) {
      console.error("Failed to load staff notifications:", error);
      setAlertsError("Notifications could not be loaded. Please try again.");
    }
  }, []);

  // Alerts pushed over the live stream appear instantly, with no refresh.
  const handleLiveAlert = useCallback((alert) => {
    if (knownAlertIds.current.has(alert.id)) return;
    knownAlertIds.current.add(alert.id);
    setAlerts((prev) =>
      prev.some((a) => a.id === alert.id) ? prev : [alert, ...prev].slice(0, 50),
    );
    // Pop-ups stay until the admin clicks or closes them.
    setToasts((prev) =>
      [alert, ...prev.filter((t) => t.id !== alert.id)].slice(0, 4),
    );

    if (document.hidden && desktopPermissionRef.current === "granted") {
      const desktopNotice = new Notification(alert.title, {
        body: alert.body,
        tag: alert.id,
      });
      desktopNotice.onclick = () => {
        window.focus();
        if (alert.target_route) navigateRef.current(alert.target_route);
        desktopNotice.close();
      };
    }
  }, []);

  useEffect(() => {
    loadAlerts();
    // Safety net in case the live stream is blocked by a proxy.
    const interval = setInterval(loadAlerts, 30000);
    const refreshWhenVisible = () => {
      if (!document.hidden) loadAlerts();
    };
    document.addEventListener("visibilitychange", refreshWhenVisible);
    return () => {
      clearInterval(interval);
      document.removeEventListener("visibilitychange", refreshWhenVisible);
    };
  }, [loadAlerts]);

  useEffect(() => {
    return connectStaffAlertStream({
      onAlert: handleLiveAlert,
      onStatus: (status) => {
        setLiveStatus(status);
        // Catch up on anything created while the stream was disconnected.
        if (status === "live") loadAlerts();
      },
    });
  }, [handleLiveAlert, loadAlerts]);

  async function enableDesktopAlerts() {
    if (typeof Notification === "undefined") return;
    setDesktopPermission(await Notification.requestPermission());
  }

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

  useEffect(() => {
    const baseTitle = "iDetect — Staff Portal";
    document.title = unreadCount > 0 ? `(${unreadCount}) ${baseTitle}` : baseTitle;
    return () => {
      document.title = baseTitle;
    };
  }, [unreadCount]);

  async function handleMarkAllRead() {
    try {
      await staffAlertsAPI.markAllRead();
      setAlerts((prev) => prev.map((a) => ({ ...a, is_read: true })));
      setToasts([]);
    } catch (error) {
      console.error("Failed to mark staff notifications as read:", error);
      setAlertsError("Could not mark notifications as read. Please try again.");
    }
  }

  async function markAlertRead(alert) {
    if (alert.is_read) return;
    try {
      await staffAlertsAPI.markRead(alert.id);
      setAlerts((prev) =>
        prev.map((item) =>
          item.id === alert.id
            ? { ...item, is_read: true, read_at: new Date().toISOString() }
            : item,
        ),
      );
    } catch (error) {
      console.error("Failed to mark staff notification as read:", error);
      setAlertsError("Could not mark this notification as read.");
    }
  }

  // Closing an alert acknowledges it without navigating away.
  function dismissAlert(alert) {
    setToasts((prev) => prev.filter((t) => t.id !== alert.id));
    markAlertRead(alert);
  }

  async function handleAlertClick(alert) {
    setToasts((prev) => prev.filter((t) => t.id !== alert.id));
    await markAlertRead(alert);
    setBellOpen(false);
    if (alert.target_route) navigate(alert.target_route);
  }

  const role = user?.role ?? "osca_admin";
  const portalRole = role.endsWith("_super_admin")
    ? role.replace("_super_admin", "_admin")
    : role;
  const nav = NAV_BY_ROLE[portalRole] ?? NAV_BY_ROLE.osca_admin;
  const theme = THEME[portalRole] ?? THEME.osca_admin;

  const alertsStatusBar = (
    <div className="flex items-center justify-between gap-2 px-4 py-2 border-b border-slate-100 bg-slate-50/60">
      <span className="flex items-center gap-1.5 text-[11px] font-medium text-slate-500">
        <span
          className={`w-1.5 h-1.5 rounded-full ${
            liveStatus === "live" ? "bg-emerald-500" : "bg-amber-400"
          }`}
        />
        {liveStatus === "live" ? "Live updates on" : "Reconnecting…"}
      </span>
      {desktopPermission === "default" && (
        <button
          onClick={enableDesktopAlerts}
          className={`text-[11px] font-medium ${theme.viewBtn}`}
        >
          Enable desktop alerts
        </button>
      )}
    </div>
  );

  // Shared bell dropdown; each header passes its own anchor position.
  const bellPanel = (positionClass) => {
    const unread = alerts.filter((a) => !a.is_read);
    return (
      <div
        className={`${positionClass} z-50 w-96 max-w-[calc(100vw-2rem)] overflow-hidden rounded-2xl border border-slate-200 bg-white shadow-xl`}
      >
        <div className="flex items-center justify-between gap-3 border-b border-slate-100 px-5 py-4">
          <div>
            <h3 className="text-base font-semibold text-slate-800">Notifications</h3>
            <p className="mt-0.5 text-xs text-slate-400">{unread.length} unread</p>
          </div>
          {unread.length > 0 && (
            <button
              onClick={handleMarkAllRead}
              className={`text-sm font-medium ${theme.viewBtn}`}
            >
              Mark all read
            </button>
          )}
        </div>
        {alertsStatusBar}
        <div className="max-h-[28rem] overflow-y-auto divide-y divide-slate-100">
          {alertsError ? (
            <div className="px-5 py-8 text-center text-sm text-danger-600">
              {alertsError}
            </div>
          ) : unread.length === 0 ? (
            <div className="px-5 py-12 text-center text-slate-400">
              <Bell className="mx-auto mb-3 h-9 w-9 opacity-25" />
              <p className="text-sm font-medium text-slate-500">You're all caught up</p>
              <p className="mt-1 text-xs">New alerts will appear here in real time.</p>
            </div>
          ) : (
            unread.map((a) => (
              <div
                key={a.id}
                onClick={() => handleAlertClick(a)}
                className={`group relative cursor-pointer py-4 pl-5 pr-12 hover:bg-slate-50 ${theme.alertBg}`}
              >
                <p className="text-sm font-semibold text-slate-800">{a.title}</p>
                <p className="mt-1 text-sm leading-relaxed text-slate-600">{a.body}</p>
                <p className="mt-2 text-xs text-slate-400">{fmtRelative(a.created_at)}</p>
                <button
                  aria-label="Dismiss notification"
                  title="Dismiss"
                  onClick={(event) => {
                    event.stopPropagation();
                    dismissAlert(a);
                  }}
                  className="absolute right-3 top-3 rounded-md p-1 text-slate-400 hover:bg-slate-200 hover:text-slate-700"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>
            ))
          )}
        </div>
      </div>
    );
  };

  function handleLogout() {
    logout();
    navigate("/login");
  }

  return (
    <div className="flex flex-col h-screen bg-paper overflow-hidden">
      <CivicStripe />
      <div className="flex flex-1 min-h-0">
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
          <div className="relative flex items-center justify-center px-5 py-5 border-b border-slate-100">
            <div className="flex min-w-0 flex-col items-center">
              <img
                src="/idetect-logo.png"
                alt="iDetect"
                className="h-12 w-auto"
              />
              <p
                className={`font-display text-xs font-semibold mt-1 ${theme.brandText}`}
              >
                {theme.portalLabel}
              </p>
            </div>
            <button
              onClick={() => setOpen(false)}
              className="absolute right-4 top-5 text-slate-400 hover:text-slate-600 lg:hidden"
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
            {nav.map(({ to, icon: Icon, label, end }) => (
              <NavLink
                key={to}
                to={to}
                end={end}
                onClick={() => setOpen(false)}
                className={({ isActive }) =>
                  `flex items-center gap-3 px-3 py-2.5 rounded-registry-lg border-l-2 text-sm font-semibold transition-all duration-100 group
                 ${
                   isActive
                     ? `${theme.sidebarActive}`
                     : "border-transparent text-slate-500 hover:bg-slate-50 hover:text-slate-800"
                 }`
                }
              >
                {({ isActive }) => (
                  <>
                    <Icon
                      className={`w-4.5 h-4.5 flex-shrink-0 ${
                        isActive
                          ? theme.sidebarIcon
                          : "text-slate-400 group-hover:text-slate-600"
                      }`}
                      strokeWidth={isActive ? 2.5 : 1.7}
                    />
                    <span className="flex-1">{label}</span>
                    {isActive && (
                      <ChevronRight
                        className={`w-3.5 h-3.5 ${theme.sidebarChevron}`}
                      />
                    )}
                  </>
                )}
              </NavLink>
            ))}
          </nav>

          {/* Scope note */}
          <div
            className={`mx-3 mb-3 px-3 py-2.5 rounded-registry border ${theme.scopeBg}`}
          >
            <div className="flex items-start gap-2">
              <Landmark
                className={`w-3.5 h-3.5 mt-0.5 flex-shrink-0 ${theme.scopeMarker}`}
                strokeWidth={1.8}
                aria-hidden="true"
              />
              <div className="min-w-0">
                <p
                  className={`text-[10px] font-bold uppercase tracking-wider mb-0.5 ${theme.scopeTitle}`}
                >
                  Scope
                </p>
                <p className={`text-[11px] leading-snug ${theme.scopeBody}`}>
                  {theme.scopeText}
                </p>
              </div>
            </div>
            <button
              onClick={() => setShowBreachModal(true)}
              className="mt-2 flex items-center gap-1.5 text-[11px] font-semibold text-red-600 hover:text-red-700 transition-colors"
            >
              <ShieldAlert className="w-3.5 h-3.5" />
              Generate Breach Report
            </button>
          </div>

          {/* User footer */}
          <div className="border-t border-slate-100 px-3 py-3">
            <div className="flex items-center gap-3 px-2 py-2 rounded-xl">
              <div
                className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 ${theme.avatarBg}`}
              >
                <span className={`text-xs font-bold ${theme.avatarText}`}>
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

        {/* ── Main content area ── */}
        <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
          {/* Mobile header */}
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
              {bellOpen && bellPanel("absolute right-4 top-14")}
            </div>
          </header>

          {/* Desktop header */}
          <header className="hidden lg:flex items-center justify-between px-8 py-4 bg-white border-b border-slate-100">
            <p className="font-display text-xs text-slate-400 font-semibold uppercase tracking-wider">
              Pamantasan ng Lungsod ng Valenzuela · {theme.headerLabel}
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
                {bellOpen && bellPanel("absolute right-0 top-10")}
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

          <main className="flex-1 min-w-0 overflow-y-auto overflow-x-hidden">
            <div className="page-enter">
              <Outlet />
            </div>
          </main>
          <StepUpHost />

          {/* ── Shared footer ── */}
          <footer className="border-t border-slate-100 bg-white px-8 py-2.5 flex-shrink-0">
            <p className="text-[11px] text-slate-400">
              iDetect · Pamantasan ng Lungsod ng Valenzuela · CEIT Capstone 2026
            </p>
          </footer>
        </div>
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
                  className={`flex-1 px-4 py-2.5 rounded-xl text-white text-sm font-semibold transition-colors ${theme.stayBtn}`}
                >
                  Stay logged in
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {toasts.length > 0 && (
        <div
          aria-live="polite"
          className="fixed top-4 right-4 z-[60] flex w-96 max-w-[calc(100vw-2rem)] flex-col gap-3"
        >
          {toasts.map((toast) => (
            <div
              key={toast.id}
              role="alert"
              onClick={() => handleAlertClick(toast)}
              className="page-enter cursor-pointer rounded-2xl border border-slate-200 bg-white p-5 shadow-xl hover:bg-slate-50"
            >
              <div className="flex items-start gap-3.5">
                <span className="mt-0.5 flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-danger-50 text-danger-600">
                  <Bell className="h-5 w-5" />
                </span>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold text-slate-900">{toast.title}</p>
                  <p className="mt-1 text-sm leading-relaxed text-slate-600">
                    {toast.body}
                  </p>
                  <p className={`mt-2 text-xs font-semibold ${theme.viewBtn}`}>
                    View now →
                  </p>
                </div>
                <button
                  aria-label="Dismiss notification"
                  title="Dismiss"
                  onClick={(event) => {
                    event.stopPropagation();
                    dismissAlert(toast);
                  }}
                  className="-mr-1 -mt-1 rounded-md p-1 text-slate-400 hover:bg-slate-200 hover:text-slate-700"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {showBreachModal && (
        <BreachReportModal onClose={() => setShowBreachModal(false)} />
      )}
    </div>
  );
}
