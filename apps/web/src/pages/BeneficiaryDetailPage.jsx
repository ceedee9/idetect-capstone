import { useState } from "react";
import { useParams, useNavigate, Link } from "react-router-dom";
import {
  ArrowLeft,
  User,
  MapPin,
  Phone,
  Calendar,
  Hash,
  UserCheck,
  UserX,
  AlertCircle,
  CheckCircle2,
  FileText,
  ShieldCheck,
  Clock,
  Mail,
  Pencil,
  RefreshCw,
} from "lucide-react";
import { useBeneficiary } from "../hooks/useBeneficiaries";
import { beneficiariesAPI } from "../services/api";
import { useAuth } from "../context/AuthContext";
import StatusBadge from "../components/StatusBadge";
import ConfirmModal from "../components/ConfirmModal";
import { fmtDate, fmtDateTime, fmtRelative, calcAge } from "../utils/date";

function InfoRow({ icon: Icon, label, value, mono = false }) {
  return (
    <div className="flex items-start gap-3 py-3.5 border-b border-slate-50 last:border-0">
      <div className="w-8 h-8 bg-slate-50 rounded-xl flex items-center justify-center flex-shrink-0 mt-0.5">
        <Icon className="w-4 h-4 text-slate-400" />
      </div>
      <div>
        <p className="text-xs text-slate-400 font-semibold uppercase tracking-wider">
          {label}
        </p>
        <p
          className={`text-sm text-slate-900 mt-0.5 font-medium ${mono ? "font-mono" : ""}`}
        >
          {value || "—"}
        </p>
      </div>
    </div>
  );
}

function TimelineDot({ done, color = "teal" }) {
  const colors = {
    teal: "bg-gov-500",
    warn: "bg-warn-500",
    red: "bg-danger-500",
    gray: "bg-slate-300",
  };
  return (
    <div
      className={`w-3 h-3 rounded-full border-2 border-white shadow-sm flex-shrink-0 mt-1
      ${done ? colors[color] : "bg-slate-200"}`}
    />
  );
}

export default function BeneficiaryDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isOsca = user?.role === "osca_admin";
  const recordLabel = isOsca ? "Senior Citizens" : "PWD Records";
  const beneficiaryTypeLabel = isOsca ? "Senior Citizen" : "PWD";
  const raText = isOsca ? "RA 9994" : "RA 10754";
  const discountText = isOsca ? "Senior Citizen privileges" : "PWD benefits";
  const { data: b, loading, error, refetch } = useBeneficiary(id);

  const [modal, setModal] = useState(null);
  const [actionLoading, setActionLoading] = useState(false);
  const [actionError, setActionError] = useState("");
  const [successMsg, setSuccessMsg] = useState("");

  // Edit record state
  const [editForm, setEditForm] = useState(null); // null = closed
  const [editLoading, setEditLoading] = useState(false);
  const [editError, setEditError] = useState("");

  // Renew state
  const [renewForm, setRenewForm] = useState(null); // null = closed
  const [renewLoading, setRenewLoading] = useState(false);
  const [renewError, setRenewError] = useState("");

  async function handleAction() {
    if (!modal) return;
    setActionLoading(true);
    setActionError("");
    const newStatus = modal === "activate" ? "active" : "suspended";
    try {
      await beneficiariesAPI.updateStatus(id, newStatus);
      setSuccessMsg(`Status updated to ${newStatus} successfully.`);
      setModal(null);
      await refetch();
    } catch (err) {
      setActionError(err.response?.data?.message || "Action failed.");
    } finally {
      setActionLoading(false);
    }
  }

  function openEdit() {
    setEditError("");
    setEditForm({
      full_name: b.full_name || "",
      birthdate: b.date_of_birth || b.birthdate || "",
      issuing_office: b.issuing_office || "",
      registered_mobile: b.contact_number || b.registered_mobile || "",
    });
  }

  async function handleEdit(e) {
    e.preventDefault();
    setEditLoading(true);
    setEditError("");
    try {
      await beneficiariesAPI.update(id, editForm);
      setSuccessMsg("Record updated successfully.");
      setEditForm(null);
      await refetch();
    } catch (err) {
      setEditError(err.response?.data?.message || "Update failed.");
    } finally {
      setEditLoading(false);
    }
  }

  function openRenew() {
    setRenewError("");
    const today = new Date().toISOString().slice(0, 10);
    const oneYear = new Date();
    oneYear.setFullYear(oneYear.getFullYear() + 1);
    setRenewForm({
      validity_start: today,
      validity_end: oneYear.toISOString().slice(0, 10),
    });
  }

  async function handleRenew(e) {
    e.preventDefault();
    setRenewLoading(true);
    setRenewError("");
    try {
      const res = await beneficiariesAPI.renew(
        id,
        renewForm.validity_start,
        renewForm.validity_end,
      );
      setSuccessMsg(res.data?.message || "ID renewed successfully.");
      setRenewForm(null);
      await refetch();
    } catch (err) {
      setRenewError(err.response?.data?.message || "Renewal failed.");
    } finally {
      setRenewLoading(false);
    }
  }

  if (loading)
    return (
      <div className="px-6 lg:px-8 py-8 max-w-4xl mx-auto space-y-6">
        <div className="skeleton h-5 w-40 rounded" />
        <div className="grid md:grid-cols-3 gap-6">
          <div className="md:col-span-2 card space-y-4">
            {[...Array(6)].map((_, i) => (
              <div key={i} className="flex gap-3">
                <div className="skeleton w-8 h-8 rounded-xl" />
                <div className="flex-1 space-y-1.5">
                  <div className="skeleton h-3 w-20" />
                  <div className="skeleton h-4 w-44" />
                </div>
              </div>
            ))}
          </div>
          <div className="card">
            <div className="skeleton h-4 w-32 mb-4" />
            <div className="space-y-3">
              {[...Array(4)].map((_, i) => (
                <div key={i} className="skeleton h-3 w-full" />
              ))}
            </div>
          </div>
        </div>
      </div>
    );

  if (error || !b)
    return (
      <div className="px-6 lg:px-8 py-8 max-w-4xl mx-auto">
        <Link to="/beneficiaries" className="btn-ghost mb-6 inline-flex">
          <ArrowLeft className="w-4 h-4" /> Beneficiaries
        </Link>
        <div className="card text-center py-12">
          <AlertCircle className="w-10 h-10 text-danger-400 mx-auto mb-3" />
          <p className="font-semibold text-slate-700">
            {error || "Beneficiary not found."}
          </p>
          <button
            onClick={() => navigate("/beneficiaries")}
            className="btn-secondary mt-4"
          >
            Back to list
          </button>
        </div>
      </div>
    );

  const age = calcAge(b.date_of_birth || b.birthdate);
  const fullName =
    b.last_name || b.first_name
      ? `${b.last_name || ""}${b.last_name && b.first_name ? "," : ""} ${b.first_name || ""}${b.middle_name ? " " + b.middle_name : ""}`.trim()
      : b.full_name || "Unknown beneficiary";
  const initials =
    [b.first_name?.[0], b.last_name?.[0]].filter(Boolean).join("") ||
    fullName
      .split(/\s+/)
      .map((x) => x[0])
      .filter(Boolean)
      .slice(0, 2)
      .join("")
      .toUpperCase();

  return (
    <div className="px-6 lg:px-8 py-8 max-w-4xl mx-auto space-y-6">
      {/* Breadcrumb */}
      <div className="flex items-center gap-2 text-sm text-slate-400">
        <Link
          to="/beneficiaries"
          className="hover:text-gov-600 flex items-center gap-1 font-semibold"
        >
          <ArrowLeft className="w-4 h-4" /> {recordLabel}
        </Link>
        <span>/</span>
        <span className="text-slate-900 font-semibold truncate">
          {fullName}
        </span>
      </div>

      {/* Page header */}
      <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 bg-gov-100 rounded-2xl flex items-center justify-center flex-shrink-0">
            <span className="text-xl font-bold text-gov-700">
              {initials || "?"}
            </span>
          </div>
          <div>
            <div className="flex items-center gap-2.5 flex-wrap">
              <h1 className="font-heading font-bold text-2xl text-slate-900">
                {fullName}
              </h1>
              <StatusBadge status={b.status} />
            </div>
            <p className="text-slate-400 text-sm mt-0.5 font-medium">
              {beneficiaryTypeLabel} ·{" "}
              {age ? `${age} years old` : "Age unknown"} · {b.id_number}
            </p>
          </div>
        </div>

        {/* Action buttons */}
        <div className="flex items-center gap-2 flex-shrink-0 flex-wrap">
          <button onClick={openEdit} className="btn-secondary">
            <Pencil className="w-4 h-4" />
            Edit Record
          </button>
          <button onClick={openRenew} className="btn-secondary">
            <RefreshCw className="w-4 h-4" />
            Process Renewal
          </button>
          {b.status === "suspended" && (
            <button
              onClick={() => setModal("activate")}
              className="btn-primary"
            >
              <UserCheck className="w-4 h-4" />
              Activate
            </button>
          )}
          {b.status === "active" && (
            <button onClick={() => setModal("suspend")} className="btn-danger">
              <UserX className="w-4 h-4" />
              Suspend
            </button>
          )}
        </div>
      </div>

      {/* Success banner */}
      {successMsg && (
        <div className="flex items-center gap-2.5 px-4 py-3 bg-gov-50 border border-gov-100 rounded-xl text-gov-700 text-sm font-medium">
          <CheckCircle2 className="w-4 h-4 flex-shrink-0" />
          {successMsg}
        </div>
      )}

      <div className="grid md:grid-cols-3 gap-6">
        {/* Main info */}
        <div className="md:col-span-2 space-y-5">
          <div className="card">
            <h2 className="font-heading font-bold text-slate-900 mb-0.5">
              Personal Information
            </h2>
            <p className="text-xs text-slate-400 font-medium mb-4">
              Official {isOsca ? "OSCA" : "PDAO"} registry record
            </p>
            <div>
              <InfoRow icon={Hash} label="ID Number" value={b.id_number} mono />
              <InfoRow icon={User} label="Full Name" value={fullName} />
              <InfoRow
                icon={Calendar}
                label="Date of Birth"
                value={`${fmtDate(b.date_of_birth || b.birthdate)}${age ? ` (${age} years old)` : ""}`}
              />
              <InfoRow
                icon={MapPin}
                label="Address"
                value={b.address || "Not captured in current record"}
              />
              <InfoRow
                icon={Phone}
                label="Contact Number"
                value={
                  b.contact_number || b.registered_mobile || "Not provided"
                }
              />
              <InfoRow
                icon={Mail}
                label="Email"
                value={b.email || "Not provided"}
              />
              <InfoRow
                icon={FileText}
                label="Notes"
                value={b.notes || "No notes"}
              />
            </div>
          </div>

          <div className="card">
            <h2 className="font-heading font-bold text-slate-900 mb-0.5">
              Record Metadata
            </h2>
            <p className="text-xs text-slate-400 font-medium mb-4">
              System timestamps and audit info
            </p>
            <div>
              <InfoRow
                icon={Clock}
                label="Date Registered"
                value={fmtDate(b.created_at)}
              />
              <InfoRow
                icon={Clock}
                label="Last Updated"
                value={`${fmtDateTime(b.updated_at)} (${fmtRelative(b.updated_at)})`}
              />
              <InfoRow
                icon={ShieldCheck}
                label="Issuing Office"
                value={b.issuing_office}
              />
              <InfoRow
                icon={Clock}
                label="Validity"
                value={`${fmtDate(b.validity_start)} to ${fmtDate(b.validity_end || b.id_expiry_date)}`}
              />
              <InfoRow
                icon={ShieldCheck}
                label="Beneficiary Type"
                value={`${beneficiaryTypeLabel} (${raText})`}
              />
            </div>
          </div>
        </div>

        {/* Sidebar */}
        <div className="space-y-5">
          {/* Status card */}
          <div className="card">
            <h3 className="font-heading font-semibold text-slate-900 text-sm mb-4">
              Status Timeline
            </h3>
            <div className="relative pl-5 space-y-4">
              {/* Vertical line */}
              <div className="absolute left-[5px] top-1 bottom-1 w-0.5 bg-slate-100" />

              {[
                {
                  label: "Record created",
                  sub: fmtDate(b.created_at),
                  done: true,
                  color: "teal",
                },
                {
                  label: "Active — eligible for discounts",
                  sub: b.status !== "inactive" ? "Verified" : null,
                  done: ["active", "suspended", "expired"].includes(b.status),
                  color: "teal",
                },
                {
                  label: "Suspended",
                  sub:
                    b.status === "suspended" ? fmtRelative(b.updated_at) : null,
                  done: b.status === "suspended",
                  color: "warn",
                },
                {
                  label: "Expired",
                  sub:
                    b.status === "expired"
                      ? fmtDate(b.validity_end || b.id_expiry_date)
                      : null,
                  done: b.status === "expired",
                  color: "red",
                },
              ].map(({ label, sub, done, color }) => (
                <div key={label} className="flex items-start gap-3">
                  <TimelineDot done={done} color={color} />
                  <div>
                    <p
                      className={`text-sm font-semibold ${done ? "text-slate-800" : "text-slate-300"}`}
                    >
                      {label}
                    </p>
                    {sub && (
                      <p className="text-xs text-slate-400 font-medium mt-0.5">
                        {sub}
                      </p>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Verification eligibility */}
          <div
            className={`card border ${b.status === "active" ? "border-gov-100 bg-gov-50" : "border-slate-100"}`}
          >
            <h3 className="font-heading font-semibold text-slate-900 text-sm mb-2">
              Scan Eligibility
            </h3>
            <div className="flex items-start gap-2.5">
              {b.status === "active" ? (
                <>
                  <CheckCircle2 className="w-5 h-5 text-gov-600 flex-shrink-0 mt-0.5" />
                  <p className="text-sm text-gov-700 font-medium">
                    VALID — will return green on scans
                  </p>
                </>
              ) : b.status === "suspended" ? (
                <>
                  <AlertCircle className="w-5 h-5 text-warn-600 flex-shrink-0 mt-0.5" />
                  <p className="text-sm text-warn-700 font-medium">
                    SUSPICIOUS — will flag on scans
                  </p>
                </>
              ) : (
                <>
                  <AlertCircle className="w-5 h-5 text-danger-500 flex-shrink-0 mt-0.5" />
                  <p className="text-sm text-danger-700 font-medium">
                    INVALID — will be denied on scans
                  </p>
                </>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Activate modal */}
      <ConfirmModal
        open={modal === "activate"}
        onClose={() => {
          setModal(null);
          setActionError("");
        }}
        onConfirm={handleAction}
        title="Activate Beneficiary"
        description={`Restore active status for ${fullName}? They will be eligible for ${discountText} immediately.`}
        confirmLabel="Activate"
        variant="primary"
        loading={actionLoading}
      >
        {actionError && (
          <p className="text-sm text-danger-600 flex items-center gap-1.5 mt-2">
            <AlertCircle className="w-4 h-4" />
            {actionError}
          </p>
        )}
      </ConfirmModal>

      {/* Suspend modal */}
      <ConfirmModal
        open={modal === "suspend"}
        onClose={() => {
          setModal(null);
          setActionError("");
        }}
        onConfirm={handleAction}
        title="Suspend Beneficiary"
        description={`Suspend ${fullName}? Their ID will return SUSPICIOUS on all establishment scans until reinstated.`}
        confirmLabel="Suspend"
        variant="warn"
        loading={actionLoading}
      >
        {actionError && (
          <p className="text-sm text-danger-600 flex items-center gap-1.5 mt-2">
            <AlertCircle className="w-4 h-4" />
            {actionError}
          </p>
        )}
      </ConfirmModal>

      {/* Edit Record modal */}
      {editForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-md">
            <div className="px-6 pt-6 pb-2">
              <h2 className="font-heading font-bold text-lg text-slate-900">
                Edit Record
              </h2>
              <p className="text-sm text-slate-500 mt-0.5">
                Correct beneficiary information. ID number cannot be changed.
              </p>
            </div>
            <form onSubmit={handleEdit} className="px-6 py-4 space-y-4">
              <div>
                <label className="label">Full Name</label>
                <input
                  className="input"
                  value={editForm.full_name}
                  onChange={(e) =>
                    setEditForm((f) => ({ ...f, full_name: e.target.value }))
                  }
                  required
                />
              </div>
              <div>
                <label className="label">Date of Birth</label>
                <input
                  type="date"
                  className="input"
                  value={editForm.birthdate}
                  onChange={(e) =>
                    setEditForm((f) => ({ ...f, birthdate: e.target.value }))
                  }
                />
              </div>
              <div>
                <label className="label">Issuing Office</label>
                <input
                  className="input"
                  value={editForm.issuing_office}
                  onChange={(e) =>
                    setEditForm((f) => ({
                      ...f,
                      issuing_office: e.target.value,
                    }))
                  }
                />
              </div>
              <div>
                <label className="label">Contact Number</label>
                <input
                  className="input"
                  value={editForm.registered_mobile}
                  onChange={(e) =>
                    setEditForm((f) => ({
                      ...f,
                      registered_mobile: e.target.value,
                    }))
                  }
                />
              </div>
              {editError && (
                <p className="text-sm text-danger-600 flex items-center gap-1.5">
                  <AlertCircle className="w-4 h-4" />
                  {editError}
                </p>
              )}
              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  className="btn-ghost"
                  onClick={() => setEditForm(null)}
                  disabled={editLoading}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn-primary"
                  disabled={editLoading}
                >
                  {editLoading ? "Saving…" : "Save Changes"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Process Renewal modal */}
      {renewForm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-md">
            <div className="px-6 pt-6 pb-2">
              <h2 className="font-heading font-bold text-lg text-slate-900">
                Process ID Renewal
              </h2>
              <p className="text-sm text-slate-500 mt-0.5">
                Extend the validity period for {fullName}. If the ID is
                currently expired, it will be reactivated.
              </p>
            </div>
            <form onSubmit={handleRenew} className="px-6 py-4 space-y-4">
              <div>
                <label className="label">New Validity Start</label>
                <input
                  type="date"
                  className="input"
                  value={renewForm.validity_start}
                  onChange={(e) =>
                    setRenewForm((f) => ({
                      ...f,
                      validity_start: e.target.value,
                    }))
                  }
                  required
                />
              </div>
              <div>
                <label className="label">New Validity End</label>
                <input
                  type="date"
                  className="input"
                  value={renewForm.validity_end}
                  onChange={(e) =>
                    setRenewForm((f) => ({
                      ...f,
                      validity_end: e.target.value,
                    }))
                  }
                  required
                />
              </div>
              {renewError && (
                <p className="text-sm text-danger-600 flex items-center gap-1.5">
                  <AlertCircle className="w-4 h-4" />
                  {renewError}
                </p>
              )}
              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  className="btn-ghost"
                  onClick={() => setRenewForm(null)}
                  disabled={renewLoading}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn-primary"
                  disabled={renewLoading}
                >
                  {renewLoading ? "Processing…" : "Confirm Renewal"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
