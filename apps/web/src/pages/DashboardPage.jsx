import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import {
  Users,
  UserCheck,
  UserX,
  AlertTriangle,
  ArrowRight,
  TrendingUp,
  Flag,
  Plus,
  Clock,
  ShieldAlert,
  FileWarning,
  Activity,
  CheckCircle2,
  Download,
  Store,
  XCircle,
  BarChart3,
} from "lucide-react";
import { useBeneficiaries } from "../hooks/useBeneficiaries";
import { useDashboardStats } from "../hooks/useDashboardStats";
import { useEstablishments } from "../hooks/useEstablishments";
import { useExpiringPermits } from "../hooks/useExpiringPermits";
import { useAuth } from "../context/AuthContext";
import { reportsAPI } from "../services/api";
import StatCard from "../components/StatCard";
import StatusBadge from "../components/StatusBadge";
import { fmtRelative, fmtDate, calcAge } from "../utils/date";
import EstablishmentStatusDonut from "../components/charts/EstablishmentStatusDonut";
import EstablishmentTrendChart from "../components/charts/EstablishmentTrendChart";

function downloadBlob(blob, name) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

function ExportDropdown() {
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);
  async function doExport(fn, name) {
    setBusy(true);
    setOpen(false);
    try {
      const r = await fn();
      downloadBlob(new Blob([r.data]), name);
    } catch {
      /* silent */
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        disabled={busy}
        className="btn-secondary"
      >
        <Download className={`w-4 h-4 ${busy ? "animate-pulse" : ""}`} />
        Export
      </button>
      {open && (
        <>
          <div className="fixed inset-0 z-10" onClick={() => setOpen(false)} />
          <div className="absolute right-0 mt-1 w-52 bg-white rounded-xl shadow-lg border border-slate-100 z-20 py-1">
            <button
              className="w-full text-left px-4 py-2 text-sm hover:bg-slate-50"
              onClick={() =>
                doExport(
                  () => reportsAPI.exportVerifications(),
                  `verifications-${new Date().toISOString().slice(0, 10)}.csv`,
                )
              }
            >
              Verifications CSV
            </button>
            <button
              className="w-full text-left px-4 py-2 text-sm hover:bg-slate-50"
              onClick={() =>
                doExport(
                  () => reportsAPI.exportFraudFlags(),
                  `fraud-flags-${new Date().toISOString().slice(0, 10)}.csv`,
                )
              }
            >
              Fraud Flags CSV
            </button>
            <button
              className="w-full text-left px-4 py-2 text-sm hover:bg-slate-50"
              onClick={() =>
                doExport(
                  () => reportsAPI.exportDisputes(),
                  `disputes-${new Date().toISOString().slice(0, 10)}.csv`,
                )
              }
            >
              Disputes CSV
            </button>
          </div>
        </>
      )}
    </div>
  );
}

// ── OSCA / PDAO Beneficiary Dashboard ─────────────────────────────────────────
function BeneficiaryDashboard({ user }) {
  const { data: beneficiaries, loading } = useBeneficiaries();
  const { data: dashStats, loading: statsLoading } = useDashboardStats();

  const isOsca = user.role === "osca_admin";
  const roleColor = isOsca ? "osca" : "pdao";
  const scopeLabel = isOsca
    ? "Senior Citizen beneficiary overview — Valenzuela City OSCA"
    : "PWD Records overview — Valenzuela City PDAO";
  const recordLabel = isOsca ? "Senior Citizens" : "PWD Records";
  const addLabel = isOsca ? "Add Beneficiary" : "Add PWD Record";

  const stats = useMemo(() => {
    if (!beneficiaries.length)
      return { total: 0, active: 0, suspended: 0, expired: 0 };
    return {
      total: beneficiaries.length,
      active: beneficiaries.filter((b) => b.status === "active").length,
      suspended: beneficiaries.filter((b) => b.status === "suspended").length,
      expired: beneficiaries.filter((b) => b.status === "expired").length,
    };
  }, [beneficiaries]);

  const recentlyAdded = useMemo(
    () =>
      [...beneficiaries]
        .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
        .slice(0, 5),
    [beneficiaries],
  );
  const suspended = useMemo(
    () => beneficiaries.filter((b) => b.status === "suspended").slice(0, 4),
    [beneficiaries],
  );

  const overviewTitle = isOsca
    ? "Senior Citizen Records Overview"
    : "PWD Records Overview";
  const overviewSummary = loading
    ? "Loading beneficiary records..."
    : `${stats.total} ${isOsca ? "senior citizen" : "PWD"} record${stats.total === 1 ? "" : "s"}. ${stats.suspended > 0 ? `${stats.suspended} need attention.` : "No records are currently suspended."}`;

  // Role-aware color classes (must be complete strings for Tailwind purge)
  const colors = isOsca
    ? {
        avatarBg: "bg-osca-100",
        avatarText: "text-osca-700",
        listBg: "bg-osca-50/40",
        emptyBg: "bg-osca-50",
        emptyIcon: "text-osca-500",
        emptyText: "text-osca-700",
        emptyBody: "text-osca-600",
        viewBtn: "text-osca-600 hover:text-osca-700 hover:bg-osca-50",
        hoverText: "group-hover:text-osca-700",
        chevron: "group-hover:text-osca-400",
        verifyBg: "bg-osca-50",
        verifyText: "text-osca-800",
        verifyLabel: "text-osca-600",
        sectionBg: "bg-osca-50",
        sectionIcon: "text-osca-600",
      }
    : {
        avatarBg: "bg-pdao-100",
        avatarText: "text-pdao-700",
        listBg: "bg-pdao-50/40",
        emptyBg: "bg-pdao-50",
        emptyIcon: "text-pdao-500",
        emptyText: "text-pdao-700",
        emptyBody: "text-pdao-600",
        viewBtn: "text-pdao-600 hover:text-pdao-700 hover:bg-pdao-50",
        hoverText: "group-hover:text-pdao-700",
        chevron: "group-hover:text-pdao-400",
        verifyBg: "bg-pdao-50",
        verifyText: "text-pdao-800",
        verifyLabel: "text-pdao-600",
        sectionBg: "bg-pdao-50",
        sectionIcon: "text-pdao-600",
      };

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-5 sm:py-8 space-y-5 sm:space-y-8 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="font-heading font-bold text-2xl text-slate-900">
            {overviewTitle}
          </h1>
          <p className="text-slate-500 text-sm mt-1 font-medium">
            {overviewSummary}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <ExportDropdown />
          <Link to="/beneficiaries/add" className="btn-primary">
            <Plus className="w-4 h-4" />
            {addLabel}
          </Link>
        </div>
      </div>

      {/* Stat cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          label="Total Records"
          value={stats.total}
          icon={Users}
          color={roleColor}
          loading={loading}
        />
        <StatCard
          label="Active"
          value={stats.active}
          icon={UserCheck}
          color={roleColor}
          loading={loading}
          sub="Verified & eligible"
        />
        <StatCard
          label="Suspended"
          value={stats.suspended}
          icon={AlertTriangle}
          color={roleColor}
          loading={loading}
          sub="Flagged or on hold"
        />
        <StatCard
          label="Expired"
          value={stats.expired}
          icon={UserX}
          color={roleColor}
          loading={loading}
          sub="ID past validity"
        />
      </div>

      <div className="grid lg:grid-cols-3 gap-4 sm:gap-6">
        {/* Recently added — 2/3 */}
        <div className="lg:col-span-2 card space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div
                className={`w-8 h-8 rounded-xl flex items-center justify-center ${colors.sectionBg}`}
              >
                <Clock className={`w-4 h-4 ${colors.sectionIcon}`} />
              </div>
              <div>
                <h2 className="font-heading font-semibold text-slate-900 text-sm">
                  Recently Added
                </h2>
                <p className="text-xs text-slate-400 font-medium">
                  Newest {recordLabel} records
                </p>
              </div>
            </div>
            <Link
              to="/beneficiaries"
              className={`btn-ghost text-xs ${colors.viewBtn}`}
            >
              View all <ArrowRight className="w-3.5 h-3.5" />
            </Link>
          </div>

          {loading ? (
            <div className="space-y-3">
              {[...Array(4)].map((_, i) => (
                <div
                  key={i}
                  className={`flex items-center gap-3 p-2 rounded-xl ${colors.listBg}`}
                >
                  <div className="skeleton w-10 h-10 rounded-full" />
                  <div className="flex-1 space-y-1.5">
                    <div className="skeleton h-3.5 w-44" />
                    <div className="skeleton h-3 w-28" />
                  </div>
                  <div className="skeleton h-6 w-16 rounded-full" />
                </div>
              ))}
            </div>
          ) : recentlyAdded.length === 0 ? (
            <div className="text-center py-10">
              <div
                className={`w-12 h-12 rounded-2xl flex items-center justify-center mx-auto mb-2 ${colors.emptyBg}`}
              >
                <Users className={`w-6 h-6 ${colors.emptyIcon}`} />
              </div>
              <p className={`text-sm font-medium ${colors.emptyText}`}>
                No records yet
              </p>
              <p className={`text-xs mt-1 ${colors.emptyBody}`}>
                Add your first {recordLabel} beneficiary.
              </p>
            </div>
          ) : (
            <div className="divide-y divide-slate-50">
              {recentlyAdded.map((b) => {
                const age = calcAge(b.date_of_birth);
                const initials = [b.first_name?.[0], b.last_name?.[0]]
                  .filter(Boolean)
                  .join("");
                return (
                  <Link
                    key={b.id}
                    to={`/beneficiaries/${b.id}`}
                    className="flex items-center gap-3 py-3 -mx-2 px-2 rounded-xl hover:bg-slate-50 transition-colors group"
                  >
                    <div
                      className={`w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 ${colors.avatarBg}`}
                    >
                      <span
                        className={`text-sm font-bold ${colors.avatarText}`}
                      >
                        {initials || "?"}
                      </span>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p
                        className={`text-sm font-semibold text-slate-900 truncate ${colors.hoverText}`}
                      >
                        {b.last_name}, {b.first_name}{" "}
                        {b.middle_name ? b.middle_name[0] + "." : ""}
                      </p>
                      <p className="text-xs text-slate-400 font-medium truncate">
                        {b.id_number} {age ? `· ${age} yrs old` : ""} · Added{" "}
                        {fmtRelative(b.created_at)}
                      </p>
                    </div>
                    <div className="flex items-center gap-2 flex-shrink-0">
                      <StatusBadge status={b.status} />
                      <ArrowRight
                        className={`w-3.5 h-3.5 text-slate-200 ${colors.chevron} transition-colors`}
                      />
                    </div>
                  </Link>
                );
              })}
            </div>
          )}
        </div>

        {/* Right column */}
        <div className="space-y-5">
          {/* Suspended records */}
          <div className="card space-y-3">
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 bg-warn-50 rounded-xl flex items-center justify-center">
                <AlertTriangle className="w-4 h-4 text-warn-700" />
              </div>
              <div>
                <h2 className="font-heading font-semibold text-slate-900 text-sm">
                  Suspended
                </h2>
                <p className="text-xs text-slate-400 font-medium">
                  Needs attention
                </p>
              </div>
            </div>
            {loading ? (
              <div className="space-y-2">
                {[...Array(3)].map((_, i) => (
                  <div
                    key={i}
                    className="skeleton h-10 w-full rounded-xl bg-warn-50/60"
                  />
                ))}
              </div>
            ) : suspended.length === 0 ? (
              <div className="text-center py-4">
                <p className="text-xs text-slate-400 font-medium">
                  No suspended records
                </p>
              </div>
            ) : (
              <div className="space-y-2">
                {suspended.map((b) => (
                  <Link
                    key={b.id}
                    to={`/beneficiaries/${b.id}`}
                    className="flex items-center gap-2.5 p-2.5 rounded-xl bg-warn-50 hover:bg-warn-100 transition-colors group"
                  >
                    <div className="w-7 h-7 bg-warn-100 rounded-full flex items-center justify-center flex-shrink-0">
                      <span className="text-xs font-bold text-warn-700">
                        {b.first_name?.[0]}
                        {b.last_name?.[0]}
                      </span>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-xs font-semibold text-slate-800 truncate">
                        {b.first_name} {b.last_name}
                      </p>
                      <p className="text-[10px] text-slate-400 font-mono">
                        {b.id_number}
                      </p>
                    </div>
                    <ArrowRight className="w-3 h-3 text-warn-400 group-hover:text-warn-600" />
                  </Link>
                ))}
                {stats.suspended > 4 && (
                  <Link
                    to="/beneficiaries?status=suspended"
                    className="block text-center text-xs text-warn-700 font-semibold hover:underline pt-1"
                  >
                    +{stats.suspended - 4} more →
                  </Link>
                )}
              </div>
            )}
          </div>

          {/* Quick links */}
          <div className="card space-y-2">
            <h3 className="font-heading font-semibold text-slate-900 text-sm mb-3">
              Quick Actions
            </h3>
            {[
              {
                to: "/beneficiaries/add",
                icon: Plus,
                label: `Register new ${isOsca ? "Senior Citizen" : "PWD"}`,
                color: `text-${roleColor}-600`,
              },
              {
                to: "/beneficiaries?status=expired",
                icon: UserX,
                label: "Review expired records",
                color: "text-danger-600",
              },
              {
                to: "/fraud-flags",
                icon: Flag,
                label: "Review fraud flags",
                color: "text-warn-700",
              },
            ].map(({ to, icon: Icon, label, color }) => (
              <Link
                key={to}
                to={to}
                className="flex items-center gap-3 p-3 rounded-xl hover:bg-slate-50 transition-colors group"
              >
                <Icon className={`w-4 h-4 ${color} flex-shrink-0`} />
                <span className="text-sm text-slate-600 font-medium group-hover:text-slate-900">
                  {label}
                </span>
                <ArrowRight className="w-3.5 h-3.5 text-slate-200 group-hover:text-slate-400 ml-auto" />
              </Link>
            ))}
          </div>
        </div>
      </div>

      {/* Fraud & Verification Analytics */}
      <div className="grid lg:grid-cols-2 gap-4 sm:gap-6">
        {/* Fraud flags overview */}
        <div className="card space-y-4">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-danger-50 rounded-xl flex items-center justify-center">
              <ShieldAlert className="w-4 h-4 text-danger-600" />
            </div>
            <div>
              <h2 className="font-heading font-semibold text-slate-900 text-sm">
                Fraud Flags
              </h2>
              <p className="text-xs text-slate-400 font-medium">
                Establishment-reported suspicious IDs
              </p>
            </div>
            <Link
              to="/fraud-flags"
              className={`btn-ghost text-xs ${colors.viewBtn} ml-auto`}
            >
              View all <ArrowRight className="w-3.5 h-3.5" />
            </Link>
          </div>
          {statsLoading ? (
            <div className="grid grid-cols-2 gap-3">
              {[...Array(4)].map((_, i) => (
                <div key={i} className="skeleton h-16 rounded-xl" />
              ))}
            </div>
          ) : dashStats?.fraudFlags ? (
            <>
              <div className="grid grid-cols-2 gap-3">
                <div className="p-3 rounded-xl bg-warn-50">
                  <p className="text-2xl font-bold text-warn-800">
                    {dashStats.fraudFlags.pending}
                  </p>
                  <p className="text-xs text-warn-600 font-medium">
                    Pending review
                  </p>
                </div>
                <div className="p-3 rounded-xl bg-danger-50">
                  <p className="text-2xl font-bold text-danger-800">
                    {dashStats.fraudFlags.confirmed}
                  </p>
                  <p className="text-xs text-danger-600 font-medium">
                    Confirmed fraud
                  </p>
                </div>
                <div className="p-3 rounded-xl bg-blue-50">
                  <p className="text-2xl font-bold text-blue-800">
                    {dashStats.fraudFlags.reviewing}
                  </p>
                  <p className="text-xs text-blue-600 font-medium">
                    Under review
                  </p>
                </div>
                <div className="p-3 rounded-xl bg-slate-50">
                  <p className="text-2xl font-bold text-slate-600">
                    {dashStats.fraudFlags.dismissed}
                  </p>
                  <p className="text-xs text-slate-500 font-medium">
                    Dismissed
                  </p>
                </div>
              </div>
              {dashStats.topFlagged?.length > 0 && (
                <div className="pt-3 border-t border-slate-100">
                  <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">
                    Most Flagged IDs
                  </p>
                  <div className="space-y-1.5">
                    {dashStats.topFlagged.map((f, i) => (
                      <div
                        key={f.id_number}
                        className="flex items-center gap-2 text-xs"
                      >
                        <span className="w-5 h-5 bg-danger-100 rounded-full text-danger-700 font-bold flex items-center justify-center flex-shrink-0">
                          {i + 1}
                        </span>
                        <span className="font-mono text-slate-600 truncate">
                          {f.id_number}
                        </span>
                        {f.full_name && (
                          <span className="text-slate-400 truncate">
                            {f.full_name}
                          </span>
                        )}
                        <span className="ml-auto font-bold text-danger-600 flex-shrink-0">
                          {f.flag_count}×
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </>
          ) : (
            <p className="text-xs text-slate-400 text-center py-4">
              No fraud data available
            </p>
          )}
        </div>

        {/* Verification activity */}
        <div className="card space-y-4">
          <div className="flex items-center gap-3">
            <div
              className={`w-8 h-8 rounded-xl flex items-center justify-center ${colors.sectionBg}`}
            >
              <Activity className={`w-4 h-4 ${colors.sectionIcon}`} />
            </div>
            <div>
              <h2 className="font-heading font-semibold text-slate-900 text-sm">
                Verification Activity
              </h2>
              <p className="text-xs text-slate-400 font-medium">
                Last 30 days — {recordLabel} scans
              </p>
            </div>
          </div>
          {statsLoading ? (
            <div className="space-y-3">
              <div className="skeleton h-20 rounded-xl" />
              <div className="skeleton h-8 w-full rounded-xl" />
            </div>
          ) : dashStats?.verifications ? (
            <>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-center">
                <div className="p-2 rounded-lg bg-success-50">
                  <p className="text-lg font-bold text-success-700">
                    {dashStats.verifications.valid}
                  </p>
                  <p className="text-[10px] text-success-600 font-medium">
                    Valid
                  </p>
                </div>
                <div className="p-2 rounded-lg bg-warn-50">
                  <p className="text-lg font-bold text-warn-700">
                    {dashStats.verifications.suspicious}
                  </p>
                  <p className="text-[10px] text-warn-600 font-medium">
                    Suspicious
                  </p>
                </div>
                <div className="p-2 rounded-lg bg-danger-50">
                  <p className="text-lg font-bold text-danger-700">
                    {dashStats.verifications.invalid}
                  </p>
                  <p className="text-[10px] text-danger-600 font-medium">
                    Invalid
                  </p>
                </div>
                <div className="p-2 rounded-lg bg-slate-50">
                  <p className="text-lg font-bold text-slate-600">
                    {dashStats.verifications.manual_review}
                  </p>
                  <p className="text-[10px] text-slate-500 font-medium">
                    Manual
                  </p>
                </div>
              </div>
              <div className={`text-center p-3 rounded-xl ${colors.verifyBg}`}>
                <p className={`text-3xl font-bold ${colors.verifyText}`}>
                  {dashStats.verifications.total}
                </p>
                <p className={`text-xs font-medium ${colors.verifyLabel}`}>
                  Total scans (30 days)
                </p>
              </div>
              {dashStats.verificationTrend?.length > 0 && (
                <div className="pt-3 border-t border-slate-100">
                  <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">
                    Daily Scans (14 days)
                  </p>
                  <div className="flex items-end gap-1 h-16">
                    {dashStats.verificationTrend.map((d) => {
                      const max = Math.max(
                        ...dashStats.verificationTrend.map((t) => t.count),
                        1,
                      );
                      const pct = Math.max((d.count / max) * 100, 4);
                      return (
                        <div
                          key={d.date}
                          className="flex-1 rounded-t-sm bg-gov-300 hover:bg-gov-500 transition-colors cursor-default"
                          style={{ height: `${pct}%` }}
                          title={`${d.date}: ${d.count} scans`}
                        />
                      );
                    })}
                  </div>
                  <div className="flex justify-between mt-1">
                    <span className="text-[9px] text-slate-400">14d ago</span>
                    <span className="text-[9px] text-slate-400">Today</span>
                  </div>
                </div>
              )}
            </>
          ) : (
            <p className="text-xs text-slate-400 text-center py-4">
              No verification data available
            </p>
          )}
        </div>
      </div>
    </div>
  );
}

// ── BPLO Establishment Dashboard ───────────────────────────────────────────────
function EstablishmentDashboard({ user }) {
  const { data: establishments, loading } = useEstablishments();
  const { data: dashStats, loading: statsLoading } = useDashboardStats();
  const { data: expiringPermits, loading: expiryLoading } =
    useExpiringPermits(30);

  const stats = useMemo(() => {
    if (!establishments.length)
      return { total: 0, pending: 0, approved: 0, suspended: 0 };
    return {
      total: establishments.length,
      pending: establishments.filter((e) => e.status === "pending").length,
      approved: establishments.filter((e) => e.status === "approved").length,
      suspended: establishments.filter((e) => e.status === "suspended").length,
    };
  }, [establishments]);

  const pendingList = useMemo(
    () =>
      establishments
        .filter((e) => e.status === "pending")
        .sort((a, b) => new Date(a.created_at) - new Date(b.created_at))
        .slice(0, 5),
    [establishments],
  );

  const recentActivity = useMemo(
    () =>
      [...establishments]
        .sort(
          (a, b) =>
            new Date(b.updated_at ?? b.created_at) -
            new Date(a.updated_at ?? a.created_at),
        )
        .slice(0, 6),
    [establishments],
  );

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-5 sm:py-8 space-y-5 sm:space-y-8 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="font-heading font-bold text-2xl text-gray-900">
            Business Permit Overview
          </h1>
          <p className="text-gray-500 text-sm mt-1">
            {loading
              ? "Loading your establishment activity..."
              : `${stats.total} registered establishment${stats.total === 1 ? "" : "s"}. ${stats.pending > 0 ? `${stats.pending} awaiting approval.` : "No approvals are waiting for review."}`}
          </p>
        </div>
        <ExportDropdown />
      </div>

      {/* Permit Expiry Alert Banner */}
      {!expiryLoading && expiringPermits.length > 0 && (
        <div className="flex items-start gap-3 p-4 bg-orange-50 border border-orange-200 rounded-xl">
          <AlertTriangle className="w-5 h-5 text-orange-600 flex-shrink-0 mt-0.5" />
          <div className="flex-1 min-w-0">
            <p className="font-semibold text-orange-800 text-sm">
              {expiringPermits.filter((e) => e.days_until_expiry < 0).length > 0
                ? `${expiringPermits.filter((e) => e.days_until_expiry < 0).length} permit(s) expired · ${expiringPermits.filter((e) => e.days_until_expiry >= 0).length} expiring within 30 days`
                : `${expiringPermits.length} business permit(s) expiring within 30 days`}
            </p>
            <div className="mt-2 space-y-1">
              {expiringPermits.slice(0, 5).map((est) => (
                <Link
                  key={est.id}
                  to={`/establishments/${est.id}`}
                  className="flex items-center gap-2 text-xs text-orange-700 hover:text-orange-900"
                >
                  <Store className="w-3.5 h-3.5 flex-shrink-0" />
                  <span className="font-medium truncate">
                    {est.business_name}
                  </span>
                  <span className="text-orange-500 flex-shrink-0">
                    {est.days_until_expiry < 0
                      ? `Expired ${Math.abs(est.days_until_expiry)}d ago`
                      : est.days_until_expiry === 0
                        ? "Expires today"
                        : `Expires in ${est.days_until_expiry}d`}
                  </span>
                </Link>
              ))}
            </div>
            {expiringPermits.length > 5 && (
              <Link
                to="/establishments"
                className="text-xs text-orange-600 hover:underline font-medium mt-1 block"
              >
                +{expiringPermits.length - 5} more →
              </Link>
            )}
          </div>
        </div>
      )}

      {/* Stat cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          label="Total Establishments"
          value={stats.total}
          icon={Store}
          color="gov"
          loading={loading}
        />
        <StatCard
          label="Pending Approval"
          value={stats.pending}
          icon={Clock}
          color="gov"
          loading={loading}
        />
        <StatCard
          label="Approved"
          value={stats.approved}
          icon={CheckCircle2}
          color="gov"
          loading={loading}
        />
        <StatCard
          label="Suspended"
          value={stats.suspended}
          icon={XCircle}
          color="gov"
          loading={loading}
        />
      </div>

      {/* ── Analytics Overview ─────────────────────────────────────── */}
      <div className="grid lg:grid-cols-3 items-start gap-4 sm:gap-6">
        {/* Registration Trend */}
        <div className="lg:col-span-2 card space-y-4">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-gov-50 rounded-xl flex items-center justify-center">
              <TrendingUp className="w-4 h-4 text-gov-600" />
            </div>
            <div>
              <h2 className="font-heading font-semibold text-gray-900 text-sm">
                Registrations — Last 6 Months
              </h2>
              <p className="text-xs text-gray-500">
                New establishments registered monthly
              </p>
            </div>
          </div>
          {loading ? (
            <div className="skeleton h-40 sm:h-52 rounded-xl" />
          ) : (
            <EstablishmentTrendChart establishments={establishments} />
          )}
        </div>

        {/* Status Donut */}
        <div className="card space-y-4">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-gov-50 rounded-xl flex items-center justify-center">
              <BarChart3 className="w-4 h-4 text-gov-600" />
            </div>
            <div>
              <h2 className="font-heading font-semibold text-gray-900 text-sm">
                Status Breakdown
              </h2>
              <p className="text-xs text-gray-500">
                Current permit distribution
              </p>
            </div>
          </div>
          {loading ? (
            <div className="skeleton h-40 sm:h-52 rounded-xl" />
          ) : (
            <EstablishmentStatusDonut stats={stats} />
          )}
        </div>
      </div>

      <div className="grid lg:grid-cols-3 gap-4 sm:gap-6">
        {/* Pending queue */}
        <div className="lg:col-span-2 card space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 bg-warn-50 rounded-lg flex items-center justify-center">
                <Clock className="w-4 h-4 text-warn-700" />
              </div>
              <div>
                <h2 className="font-heading font-semibold text-gray-900 text-sm">
                  Pending Approvals
                </h2>
                <p className="text-xs text-gray-500">Awaiting your review</p>
              </div>
            </div>
            <Link
              to="/establishments?status=pending"
              className="btn-ghost text-xs text-gov-600 hover:text-gov-700 hover:bg-gov-50"
            >
              View all <ArrowRight className="w-3.5 h-3.5" />
            </Link>
          </div>
          {loading ? (
            <div className="space-y-3">
              {[...Array(3)].map((_, i) => (
                <div key={i} className="flex items-center gap-3">
                  <div className="skeleton w-9 h-9 rounded-lg" />
                  <div className="flex-1 space-y-1.5">
                    <div className="skeleton h-3.5 w-48" />
                    <div className="skeleton h-3 w-32" />
                  </div>
                  <div className="skeleton h-6 w-20 rounded-full" />
                </div>
              ))}
            </div>
          ) : pendingList.length === 0 ? (
            <div className="text-center py-8">
              <CheckCircle2 className="w-10 h-10 text-success-500 mx-auto mb-2" />
              <p className="text-sm font-medium text-gray-700">
                All caught up!
              </p>
              <p className="text-xs text-gray-400 mt-0.5">
                No establishments pending approval.
              </p>
            </div>
          ) : (
            <div className="divide-y divide-gray-50">
              {pendingList.map((est) => (
                <Link
                  key={est.id}
                  to={`/establishments/${est.id}`}
                  className="flex items-center gap-3 py-3 -mx-2 px-2 rounded-lg hover:bg-gray-50 transition-colors group"
                >
                  <div className="w-9 h-9 bg-gov-50 rounded-lg flex items-center justify-center flex-shrink-0">
                    <Store className="w-4.5 h-4.5 text-gov-600" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-gray-900 truncate group-hover:text-gov-700">
                      {est.business_name}
                    </p>
                    <p className="text-xs text-gray-500 truncate">
                      {est.business_type} · {est.address}
                    </p>
                  </div>
                  <div className="flex items-center gap-2 flex-shrink-0">
                    <StatusBadge status={est.status} />
                    <ArrowRight className="w-3.5 h-3.5 text-gray-300 group-hover:text-gov-400 transition-colors" />
                  </div>
                </Link>
              ))}
            </div>
          )}
          {!loading && stats.pending > 5 && (
            <div className="pt-2 border-t border-gray-50">
              <Link
                to="/establishments?status=pending"
                className="text-xs text-gov-600 hover:underline font-medium"
              >
                +{stats.pending - 5} more pending establishments →
              </Link>
            </div>
          )}
        </div>

        {/* Recent activity */}
        <div className="card space-y-4">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 bg-gov-50 rounded-lg flex items-center justify-center">
              <TrendingUp className="w-4 h-4 text-gov-600" />
            </div>
            <div>
              <h2 className="font-heading font-semibold text-gray-900 text-sm">
                Recent Activity
              </h2>
              <p className="text-xs text-gray-500">Latest changes</p>
            </div>
          </div>
          {loading ? (
            <div className="space-y-4">
              {[...Array(5)].map((_, i) => (
                <div key={i} className="space-y-1">
                  <div className="skeleton h-3.5 w-40" />
                  <div className="skeleton h-3 w-24" />
                </div>
              ))}
            </div>
          ) : (
            <div className="space-y-3">
              {recentActivity.map((est) => (
                <Link
                  key={est.id}
                  to={`/establishments/${est.id}`}
                  className="flex items-start gap-2.5 group"
                >
                  <div
                    className={`mt-0.5 w-2 h-2 rounded-full flex-shrink-0 ${est.status === "approved" ? "bg-success-500" : est.status === "pending" ? "bg-warn-500" : est.status === "suspended" ? "bg-danger-500" : "bg-gray-300"}`}
                  />
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-medium text-gray-800 truncate group-hover:text-gov-700">
                      {est.business_name}
                    </p>
                    <p className="text-xs text-gray-400">
                      {fmtRelative(est.updated_at ?? est.created_at)}
                    </p>
                  </div>
                  <StatusBadge status={est.status} />
                </Link>
              ))}
              {recentActivity.length === 0 && (
                <p className="text-xs text-gray-400 text-center py-4">
                  No activity yet.
                </p>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Analytics */}
      <div className="grid lg:grid-cols-2 gap-4 sm:gap-6">
        <div className="card space-y-4">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-gov-50 rounded-lg flex items-center justify-center">
              <Activity className="w-4 h-4 text-gov-600" />
            </div>
            <div>
              <h2 className="font-heading font-semibold text-gray-900 text-sm">
                Verification Activity
              </h2>
              <p className="text-xs text-gray-500">
                Last 30 days — all beneficiary types
              </p>
            </div>
          </div>
          {statsLoading ? (
            <div className="space-y-3">
              <div className="skeleton h-20 rounded-xl" />
              <div className="skeleton h-8 w-full rounded-xl" />
            </div>
          ) : dashStats?.verifications ? (
            <>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-center">
                <div className="p-2 rounded-lg bg-success-50">
                  <p className="text-lg font-bold text-success-700">
                    {dashStats.verifications.valid}
                  </p>
                  <p className="text-[10px] text-success-600 font-medium">
                    Valid
                  </p>
                </div>
                <div className="p-2 rounded-lg bg-warn-50">
                  <p className="text-lg font-bold text-warn-700">
                    {dashStats.verifications.suspicious}
                  </p>
                  <p className="text-[10px] text-warn-600 font-medium">
                    Suspicious
                  </p>
                </div>
                <div className="p-2 rounded-lg bg-danger-50">
                  <p className="text-lg font-bold text-danger-700">
                    {dashStats.verifications.invalid}
                  </p>
                  <p className="text-[10px] text-danger-600 font-medium">
                    Invalid
                  </p>
                </div>
                <div className="p-2 rounded-lg bg-gray-50">
                  <p className="text-lg font-bold text-gray-600">
                    {dashStats.verifications.manual_review}
                  </p>
                  <p className="text-[10px] text-gray-500 font-medium">
                    Manual
                  </p>
                </div>
              </div>
              <div className="text-center p-3 bg-gov-50 rounded-xl">
                <p className="text-3xl font-bold text-gov-800">
                  {dashStats.verifications.total}
                </p>
                <p className="text-xs text-gov-600 font-medium">
                  Total scans (30 days)
                </p>
              </div>
              {dashStats.verificationTrend?.length > 0 && (
                <div className="pt-3 border-t border-gray-100">
                  <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-2">
                    Daily Scans (14 days)
                  </p>
                  <div className="flex items-end gap-1 h-16">
                    {dashStats.verificationTrend.map((d) => {
                      const max = Math.max(
                        ...dashStats.verificationTrend.map((t) => t.count),
                        1,
                      );
                      const pct = Math.max((d.count / max) * 100, 4);
                      return (
                        <div
                          key={d.date}
                          className="flex-1 rounded-t-sm bg-gov-300 hover:bg-gov-500 transition-colors cursor-default"
                          style={{ height: `${pct}%` }}
                          title={`${d.date}: ${d.count} scans`}
                        />
                      );
                    })}
                  </div>
                  <div className="flex justify-between mt-1">
                    <span className="text-[9px] text-gray-400">14d ago</span>
                    <span className="text-[9px] text-gray-400">Today</span>
                  </div>
                </div>
              )}
            </>
          ) : (
            <p className="text-xs text-gray-400 text-center py-4">
              No verification data available
            </p>
          )}
        </div>

        <div className="space-y-6">
          <div className="card space-y-4">
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 bg-blue-50 rounded-lg flex items-center justify-center">
                <BarChart3 className="w-4 h-4 text-blue-600" />
              </div>
              <div>
                <h2 className="font-heading font-semibold text-gray-900 text-sm">
                  Top Scanning Establishments
                </h2>
                <p className="text-xs text-gray-500">
                  By verification count (30 days)
                </p>
              </div>
            </div>
            {statsLoading ? (
              <div className="space-y-2">
                {[...Array(5)].map((_, i) => (
                  <div key={i} className="skeleton h-8 w-full rounded-lg" />
                ))}
              </div>
            ) : dashStats?.topEstablishments?.length > 0 ? (
              <div className="space-y-2">
                {dashStats.topEstablishments.map((est, i) => {
                  const max = dashStats.topEstablishments[0]?.scan_count || 1;
                  const pct = Math.round((est.scan_count / max) * 100);
                  return (
                    <div key={est.establishment_id} className="space-y-1">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2 min-w-0">
                          <span className="w-5 h-5 bg-gov-100 rounded-full text-gov-700 text-xs font-bold flex items-center justify-center flex-shrink-0">
                            {i + 1}
                          </span>
                          <span className="text-xs font-medium text-gray-700 truncate">
                            {est.business_name}
                          </span>
                        </div>
                        <span className="text-xs font-bold text-gov-700 flex-shrink-0 ml-2">
                          {est.scan_count}
                        </span>
                      </div>
                      <div className="h-1.5 bg-gray-100 rounded-full overflow-hidden">
                        <div
                          className="h-full rounded-full bg-gov-400 transition-all duration-500"
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <p className="text-xs text-gray-400 text-center py-4">
                No scanning data yet
              </p>
            )}
          </div>

          {dashStats?.disputes && !statsLoading && (
            <div className="card space-y-3">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 bg-warn-50 rounded-lg flex items-center justify-center">
                  <FileWarning className="w-4 h-4 text-warn-700" />
                </div>
                <div>
                  <h2 className="font-heading font-semibold text-gray-900 text-sm">
                    Business Refusal Disputes
                  </h2>
                  <p className="text-xs text-gray-500">
                    Discount denial complaints
                  </p>
                </div>
              </div>
              <div className="grid grid-cols-3 gap-3 text-center">
                <div className="p-2.5 rounded-lg bg-blue-50">
                  <p className="text-xl font-bold text-blue-800">
                    {dashStats.disputes.total}
                  </p>
                  <p className="text-[10px] text-blue-600 font-medium">Total</p>
                </div>
                <div className="p-2.5 rounded-lg bg-warn-50">
                  <p className="text-xl font-bold text-warn-800">
                    {dashStats.disputes.submitted}
                  </p>
                  <p className="text-[10px] text-warn-600 font-medium">Open</p>
                </div>
                <div className="p-2.5 rounded-lg bg-success-50">
                  <p className="text-xl font-bold text-success-800">
                    {dashStats.disputes.closed}
                  </p>
                  <p className="text-[10px] text-success-600 font-medium">
                    Closed
                  </p>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      <div className="flex items-start gap-3 p-4 bg-gov-50 border border-gov-100 rounded-xl text-sm">
        <AlertTriangle className="w-4 h-4 text-gov-600 flex-shrink-0 mt-0.5" />
        <div>
          <p className="font-medium text-gov-800">BPLO role scope</p>
          <p className="text-gov-600 text-xs mt-0.5">
            This portal manages establishments only. Beneficiary data (Senior
            Citizen &amp; PWD records) is handled by the OSCA and PDAO portals.
          </p>
        </div>
      </div>
    </div>
  );
}

// ── Unified DashboardPage ──────────────────────────────────────────────────────
export default function DashboardPage() {
  const { user } = useAuth();
  if (user?.role === "bplo_admin")
    return <EstablishmentDashboard user={user} />;
  return <BeneficiaryDashboard user={user} />;
}
