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
} from "lucide-react";
import { useBeneficiaries } from "../hooks/useBeneficiaries";
import { useDashboardStats } from "../hooks/useDashboardStats";
import { useAuth } from "../context/AuthContext";
import { reportsAPI } from "../services/api";
import StatCard from "../components/StatCard";
import StatusBadge from "../components/StatusBadge";
import { fmtRelative, fmtDate, calcAge } from "../utils/date";
import StatusDonutChart from "../components/charts/StatusDonutChart";
import RegistrationTrendChart from "../components/charts/RegistrationTrendChart";
import AgeDistributionChart from "../components/charts/AgeDistributionChart";
import DailyVerificationChart from "../components/charts/DailyVerificationChart";

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

  const hour = new Date().getHours();
  const greeting =
    hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening";

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-5 sm:py-8 space-y-5 sm:space-y-8 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="font-heading font-bold text-2xl text-slate-900">
            {greeting}, {user?.first_name ?? "Admin"} 👋
          </h1>
          <p className="text-slate-500 text-sm mt-1 font-medium">
            Senior Citizen beneficiary overview — Valenzuela City OSCA
          </p>
        </div>
        <div className="flex items-center gap-2">
          <ExportDropdown />
          <Link to="/beneficiaries/add" className="btn-primary">
            <Plus className="w-4 h-4" />
            Add Beneficiary
          </Link>
        </div>
      </div>

      {/* Stat cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          label="Total Records"
          value={stats.total}
          icon={Users}
          color="osca"
          loading={loading}
        />
        <StatCard
          label="Active"
          value={stats.active}
          icon={UserCheck}
          color="green"
          loading={loading}
          sub="Verified & eligible"
        />
        <StatCard
          label="Suspended"
          value={stats.suspended}
          icon={AlertTriangle}
          color="warm"
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
      <div className="grid lg:grid-cols-3 gap-4 sm:gap-6">
        {/* Registration Trend */}
        <div className="lg:col-span-2 card space-y-4">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-osca-50 rounded-xl flex items-center justify-center">
              <TrendingUp className="w-4 h-4 text-osca-600" />
            </div>
            <div>
              <h2 className="font-heading font-semibold text-slate-900 text-sm">
                Registrations — Last 6 Months
              </h2>
              <p className="text-xs text-slate-400 font-medium">
                Monthly new Senior Citizen records
              </p>
            </div>
          </div>
          {loading ? (
            <div className="skeleton h-40 sm:h-52 rounded-xl" />
          ) : (
            <RegistrationTrendChart beneficiaries={beneficiaries} />
          )}
        </div>

        {/* Status Donut */}
        <div className="card space-y-4">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-osca-50 rounded-xl flex items-center justify-center">
              <CheckCircle2 className="w-4 h-4 text-osca-600" />
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
            <div className="skeleton h-40 sm:h-52 rounded-xl" />
          ) : (
            <StatusDonutChart stats={stats} />
          )}
        </div>
      </div>

      {/* Age Distribution */}
      <div className="card space-y-4">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 bg-osca-50 rounded-xl flex items-center justify-center">
            <Users className="w-4 h-4 text-osca-600" />
          </div>
          <div>
            <h2 className="font-heading font-semibold text-slate-900 text-sm">
              Age Distribution
            </h2>
            <p className="text-xs text-slate-400 font-medium">
              Senior Citizens by age bracket
            </p>
          </div>
        </div>
        {loading ? (
          <div className="skeleton h-36 rounded-xl" />
        ) : (
          <AgeDistributionChart beneficiaries={beneficiaries} />
        )}
      </div>

      <div className="grid lg:grid-cols-3 gap-4 sm:gap-6">
        {/* Recently added — 2/3 */}
        <div className="lg:col-span-2 card space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 bg-osca-50 rounded-xl flex items-center justify-center">
                <Clock className="w-4 h-4 text-osca-600" />
              </div>
              <div>
                <h2 className="font-heading font-semibold text-slate-900 text-sm">
                  Recently Added
                </h2>
                <p className="text-xs text-slate-400 font-medium">
                  Newest Senior Citizen records
                </p>
              </div>
            </div>
            <Link
              to="/beneficiaries"
              className="btn-ghost text-xs text-osca-600 hover:text-osca-700 hover:bg-osca-50"
            >
              View all <ArrowRight className="w-3.5 h-3.5" />
            </Link>
          </div>

          {loading ? (
            <div className="space-y-3">
              {[...Array(4)].map((_, i) => (
                <div
                  key={i}
                  className="flex items-center gap-3 p-2 rounded-xl bg-osca-50/40"
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
              <div className="w-12 h-12 bg-osca-50 rounded-2xl flex items-center justify-center mx-auto mb-2">
                <Users className="w-6 h-6 text-osca-500" />
              </div>
              <p className="text-sm font-medium text-osca-700">
                No records yet
              </p>
              <p className="text-xs text-osca-600 mt-1">
                Add your first Senior Citizen beneficiary.
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
                    {/* Avatar */}
                    <div className="w-10 h-10 bg-osca-100 rounded-full flex items-center justify-center flex-shrink-0">
                      <span className="text-sm font-bold text-osca-700">
                        {initials || "?"}
                      </span>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold text-slate-900 truncate group-hover:text-osca-700">
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
                      <ArrowRight className="w-3.5 h-3.5 text-slate-200 group-hover:text-osca-400 transition-colors" />
                    </div>
                  </Link>
                );
              })}
            </div>
          )}
        </div>

        {/* Right column */}
        <div className="space-y-5">
          {/* Suspended records alert */}
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
                label: "Register new Senior Citizen",
                color: "text-osca-600",
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
              className="btn-ghost text-xs text-osca-600 hover:text-osca-700 hover:bg-osca-50 ml-auto"
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
            <div className="w-8 h-8 bg-osca-50 rounded-xl flex items-center justify-center">
              <Activity className="w-4 h-4 text-osca-600" />
            </div>
            <div>
              <h2 className="font-heading font-semibold text-slate-900 text-sm">
                Verification Activity
              </h2>
              <p className="text-xs text-slate-400 font-medium">
                Last 30 days — Senior Citizen scans
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

              <div className="text-center p-3 bg-osca-50 rounded-xl">
                <p className="text-3xl font-bold text-osca-800">
                  {dashStats.verifications.total}
                </p>
                <p className="text-xs text-osca-600 font-medium">
                  Total scans (30 days)
                </p>
              </div>

              {/* Daily verification bar chart */}
              {dashStats.verificationTrend?.length > 0 && (
                <div className="pt-3 border-t border-slate-100">
                  <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-2">
                    Daily Scans (14 days)
                  </p>
                  <DailyVerificationChart data={dashStats.verificationTrend} />
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
              className="btn-ghost text-xs text-osca-600 hover:text-osca-700 hover:bg-osca-50 ml-auto"
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
            <div className="p-3 rounded-xl bg-osca-50">
              <p className="text-xl font-bold text-osca-800">
                {dashStats.disputes.acknowledged}
              </p>
              <p className="text-[10px] text-osca-600 font-medium">In Review</p>
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

      {/* Scope reminder */}
      <div className="flex items-start gap-3 p-4 bg-osca-50 border border-osca-100 rounded-2xl text-sm">
        <TrendingUp className="w-4 h-4 text-osca-600 flex-shrink-0 mt-0.5" />
        <div>
          <p className="font-semibold text-osca-800">
            OSCA scope — Senior Citizens only
          </p>
          <p className="text-osca-600 text-xs mt-0.5">
            This portal manages Senior Citizen beneficiary records exclusively
            (RA 9994). PWD records are managed in the PDAO Portal.
            Compartmentalization is enforced at the API level by the{" "}
            <code className="font-mono bg-osca-100 px-1 rounded">
              osca_admin
            </code>{" "}
            role.
          </p>
        </div>
      </div>
    </div>
  );
}
