import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import {
  Users,
  UserCheck,
  UserX,
  AlertTriangle,
  ArrowRight,
  Flag,
  Plus,
  Clock,
  Accessibility,
  ShieldAlert,
  FileWarning,
  Activity,
  Download,
  TrendingUp,
  CheckCircle2,
} from "lucide-react";
import { useBeneficiaries } from "../hooks/useBeneficiaries";
import { useDashboardStats } from "../hooks/useDashboardStats";
import { useAuth } from "../context/AuthContext";
import StatCard from "../components/StatCard";
import StatusBadge from "../components/StatusBadge";
import { fmtRelative } from "../utils/date";
import { reportsAPI } from "../services/api";
import StatusDonutChart from "../components/charts/StatusDonutChart";
import RegistrationTrendChart from "../components/charts/RegistrationTrendChart";

const TYPE_BAR_CLASSES = [
  "bg-pdao-500",
  "bg-pdao-400",
  "bg-pdao-300",
  "bg-pdao-600",
  "bg-pdao-200",
];

const TYPE_COUNT_CLASSES = [
  "text-pdao-800",
  "text-pdao-700",
  "text-pdao-600",
  "text-pdao-800",
  "text-pdao-500",
];

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

export default function DashboardPage() {
  const { user } = useAuth();
  const { data: beneficiaries, loading } = useBeneficiaries();
  const { data: dashStats, loading: statsLoading } = useDashboardStats();

  const stats = useMemo(
    () => ({
      total: beneficiaries.length,
      active: beneficiaries.filter((b) => b.status === "active").length,
      suspended: beneficiaries.filter((b) => b.status === "suspended").length,
      expired: beneficiaries.filter((b) => b.status === "expired").length,
    }),
    [beneficiaries],
  );

  // Breakdown by disability type
  const byType = useMemo(() => {
    const counts = {};
    beneficiaries.forEach((b) => {
      const t = b.disability_type?.toLowerCase() ?? "other";
      counts[t] = (counts[t] ?? 0) + 1;
    });
    return counts;
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

  const hour = new Date().getHours();
  const greeting =
    hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening";

  return (
    <div className="px-6 lg:px-8 py-8 space-y-8 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="font-heading font-bold text-2xl text-slate-900">
            {greeting}, {user?.first_name ?? "Admin"} 👋
          </h1>
          <p className="text-slate-500 text-sm mt-1 font-medium">
            PWD beneficiary overview — Valenzuela City PDAO
          </p>
        </div>
        <div className="flex items-center gap-2">
          <ExportDropdown />
          <Link to="/beneficiaries/add" className="btn-primary">
            <Plus className="w-4 h-4" />
            Add PWD Record
          </Link>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          label="Total Records"
          value={stats.total}
          icon={Users}
          color="pdao"
          loading={loading}
        />
        <StatCard
          label="Active"
          value={stats.active}
          icon={UserCheck}
          color="green"
          loading={loading}
          sub="Eligible for discounts"
        />
        <StatCard
          label="Suspended"
          value={stats.suspended}
          icon={AlertTriangle}
          color="warn"
          loading={loading}
          sub="Flagged or on hold"
        />
        <StatCard
          label="Expired"
          value={stats.expired}
          icon={UserX}
          color="red"
          loading={loading}
          sub="ID past validity"
        />
      </div>

      {/* ── Analytics Overview ─────────────────────────────────────── */}
      <div className="grid lg:grid-cols-3 gap-6">
        {/* Registration Trend */}
        <div className="lg:col-span-2 card space-y-4">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-pdao-50 rounded-xl flex items-center justify-center">
              <TrendingUp className="w-4 h-4 text-pdao-600" />
            </div>
            <div>
              <h2 className="font-heading font-semibold text-slate-900 text-sm">
                Registrations — Last 6 Months
              </h2>
              <p className="text-xs text-slate-400 font-medium">
                Monthly new PWD records
              </p>
            </div>
          </div>
          {loading ? (
            <div className="skeleton h-52 rounded-xl" />
          ) : (
            <RegistrationTrendChart beneficiaries={beneficiaries} />
          )}
        </div>

        {/* Status Donut */}
        <div className="card space-y-4">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-pdao-50 rounded-xl flex items-center justify-center">
              <CheckCircle2 className="w-4 h-4 text-pdao-600" />
            </div>
            <div>
              <h2 className="font-heading font-semibold text-slate-900 text-sm">
                Status Breakdown
              </h2>
              <p className="text-xs text-slate-400 font-medium">
                Current distribution
              </p>
            </div>
          </div>
          {loading ? (
            <div className="skeleton h-52 rounded-xl" />
          ) : (
            <StatusDonutChart stats={stats} />
          )}
        </div>
      </div>

      <div className="grid lg:grid-cols-3 gap-6">
        {/* Recently added */}
        <div className="lg:col-span-2 card space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 bg-pdao-50 rounded-xl flex items-center justify-center">
                <Clock className="w-4 h-4 text-pdao-600" />
              </div>
              <div>
                <h2 className="font-heading font-semibold text-slate-900 text-sm">
                  Recently Added
                </h2>
                <p className="text-xs text-slate-400 font-medium">
                  Newest PWD records
                </p>
              </div>
            </div>
            <Link
              to="/beneficiaries"
              className="btn-ghost text-xs text-pdao-600 hover:text-pdao-700 hover:bg-pdao-50"
            >
              View all <ArrowRight className="w-3.5 h-3.5" />
            </Link>
          </div>

          {loading ? (
            <div className="space-y-3">
              {[...Array(4)].map((_, i) => (
                <div
                  key={i}
                  className="flex items-center gap-3 p-2 rounded-xl bg-pdao-50/40"
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
              <div className="w-12 h-12 bg-pdao-50 rounded-2xl flex items-center justify-center mx-auto mb-2">
                <Accessibility className="w-6 h-6 text-pdao-500" />
              </div>
              <p className="text-sm font-medium text-pdao-700">
                No records yet
              </p>
              <p className="text-xs text-pdao-600 mt-1">
                Add your first PWD beneficiary record.
              </p>
            </div>
          ) : (
            <div className="divide-y divide-slate-50">
              {recentlyAdded.map((b) => {
                const initials = [b.first_name?.[0], b.last_name?.[0]]
                  .filter(Boolean)
                  .join("");
                return (
                  <Link
                    key={b.id}
                    to={`/beneficiaries/${b.id}`}
                    className="flex items-center gap-3 py-3 -mx-2 px-2 rounded-xl hover:bg-slate-50 transition-colors group"
                  >
                    <div className="w-10 h-10 bg-pdao-100 rounded-full flex items-center justify-center flex-shrink-0">
                      <span className="text-sm font-bold text-pdao-700">
                        {initials || "?"}
                      </span>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold text-slate-900 truncate group-hover:text-pdao-700">
                        {b.last_name}, {b.first_name}
                        {b.middle_name ? ` ${b.middle_name[0]}.` : ""}
                      </p>
                      <div className="flex items-center gap-2 mt-0.5">
                        <p className="text-xs text-slate-400 font-medium truncate">
                          {b.id_number}
                        </p>
                        {b.disability_type && (
                          <span className="dtype-tag capitalize text-[10px]">
                            {b.disability_type}
                          </span>
                        )}
                      </div>
                    </div>
                    <div className="flex items-center gap-2 flex-shrink-0">
                      <StatusBadge status={b.status} />
                      <ArrowRight className="w-3.5 h-3.5 text-slate-200 group-hover:text-pdao-400 transition-colors" />
                    </div>
                  </Link>
                );
              })}
            </div>
          )}
        </div>

        {/* Right column */}
        <div className="space-y-5">
          {/* Suspended alert */}
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
              <p className="text-xs text-slate-400 font-medium text-center py-4">
                No suspended records
              </p>
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

          {/* Disability type breakdown */}
          {!loading && stats.total > 0 && (
            <div className="card space-y-3">
              <h3 className="font-heading font-semibold text-slate-900 text-sm">
                By Disability Type
              </h3>
              <div className="space-y-2">
                {Object.entries(byType)
                  .sort((a, b) => b[1] - a[1])
                  .slice(0, 5)
                  .map(([type, count], idx) => (
                    <div key={type} className="flex items-center gap-2">
                      <div className="flex-1">
                        <div className="flex items-center justify-between mb-1">
                          <span className="text-xs font-semibold text-slate-600 capitalize">
                            {type}
                          </span>
                          <span
                            className={`text-xs font-bold ${TYPE_COUNT_CLASSES[idx % TYPE_COUNT_CLASSES.length]}`}
                          >
                            {count}
                          </span>
                        </div>
                        <div className="h-1.5 bg-slate-100 rounded-full overflow-hidden">
                          <div
                            className={`h-full rounded-full transition-all duration-500 ${TYPE_BAR_CLASSES[idx % TYPE_BAR_CLASSES.length]}`}
                            style={{
                              width: `${Math.round((count / stats.total) * 100)}%`,
                            }}
                          />
                        </div>
                      </div>
                    </div>
                  ))}
              </div>
            </div>
          )}

          {/* Quick actions */}
          <div className="card space-y-2">
            <h3 className="font-heading font-semibold text-slate-900 text-sm mb-3">
              Quick Actions
            </h3>
            {[
              {
                to: "/beneficiaries/add",
                icon: Plus,
                label: "Register new PWD",
                color: "text-pdao-600",
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
      <div className="grid lg:grid-cols-2 gap-6">
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
              className="btn-ghost text-xs text-pdao-600 hover:text-pdao-700 hover:bg-pdao-50 ml-auto"
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

              {/* Top flagged beneficiaries */}
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

        {/* Verification activity (30 days) */}
        <div className="card space-y-4">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-pdao-50 rounded-xl flex items-center justify-center">
              <Activity className="w-4 h-4 text-pdao-600" />
            </div>
            <div>
              <h2 className="font-heading font-semibold text-slate-900 text-sm">
                Verification Activity
              </h2>
              <p className="text-xs text-slate-400 font-medium">
                Last 30 days — PWD scans
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
              <div className="grid grid-cols-4 gap-2 text-center">
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

              <div className="text-center p-3 bg-pdao-50 rounded-xl">
                <p className="text-3xl font-bold text-pdao-800">
                  {dashStats.verifications.total}
                </p>
                <p className="text-xs text-pdao-600 font-medium">
                  Total scans (30 days)
                </p>
              </div>

              {/* Mini trend bar chart */}
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
                          className="flex-1 rounded-t-sm bg-pdao-300 hover:bg-pdao-500 transition-colors cursor-default"
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

      {/* Dispute summary */}
      {dashStats?.disputes && !statsLoading && (
        <div className="card">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-8 h-8 bg-blue-50 rounded-xl flex items-center justify-center">
              <FileWarning className="w-4 h-4 text-blue-600" />
            </div>
            <div>
              <h2 className="font-heading font-semibold text-slate-900 text-sm">
                Disputes
              </h2>
              <p className="text-xs text-slate-400 font-medium">
                Beneficiary-submitted dispute resolutions
              </p>
            </div>
            <Link
              to="/disputes"
              className="btn-ghost text-xs text-pdao-600 hover:text-pdao-700 hover:bg-pdao-50 ml-auto"
            >
              View all <ArrowRight className="w-3.5 h-3.5" />
            </Link>
          </div>
          <div className="grid grid-cols-4 gap-3 text-center">
            <div className="p-3 rounded-xl bg-blue-50">
              <p className="text-xl font-bold text-blue-800">
                {dashStats.disputes.total}
              </p>
              <p className="text-[10px] text-blue-600 font-medium">Total</p>
            </div>
            <div className="p-3 rounded-xl bg-warn-50">
              <p className="text-xl font-bold text-warn-800">
                {dashStats.disputes.submitted}
              </p>
              <p className="text-[10px] text-warn-600 font-medium">Awaiting</p>
            </div>
            <div className="p-3 rounded-xl bg-pdao-50">
              <p className="text-xl font-bold text-pdao-800">
                {dashStats.disputes.acknowledged}
              </p>
              <p className="text-[10px] text-pdao-600 font-medium">In Review</p>
            </div>
            <div className="p-3 rounded-xl bg-success-50">
              <p className="text-xl font-bold text-success-800">
                {dashStats.disputes.closed}
              </p>
              <p className="text-[10px] text-success-600 font-medium">Closed</p>
            </div>
          </div>
        </div>
      )}

      {/* Scope note */}
      <div className="flex items-start gap-3 p-4 bg-pdao-50 border border-pdao-100 rounded-2xl text-sm">
        <Accessibility className="w-4 h-4 text-pdao-600 flex-shrink-0 mt-0.5" />
        <div>
          <p className="font-semibold text-pdao-800">
            PDAO scope — PWD records only
          </p>
          <p className="text-pdao-600 text-xs mt-0.5">
            This portal manages PWD beneficiary records exclusively (RA 10754).
            Senior Citizen records are managed in the OSCA Portal.
            Compartmentalization is enforced at the API level by the{" "}
            <code className="font-mono bg-pdao-100 px-1 rounded">
              pdao_admin
            </code>{" "}
            role.
          </p>
        </div>
      </div>
    </div>
  );
}
