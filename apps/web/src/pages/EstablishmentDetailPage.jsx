import { useState } from "react";
import { useParams, useNavigate, Link } from "react-router-dom";
import {
  ArrowLeft,
  Store,
  MapPin,
  Phone,
  Mail,
  Calendar,
  CheckCircle2,
  Ban,
  AlertCircle,
  Loader2,
  Clock,
  Building2,
  Hash,
  ExternalLink,
  LockOpen,
  Key,
  Edit,
  Trash2,
} from "lucide-react";
import { useEstablishment } from "../hooks/useEstablishments";
import { establishmentsAPI } from "../services/api";
import StatusBadge from "../components/StatusBadge";
import ConfirmModal from "../components/ConfirmModal";
import { fmtDate, fmtDateTime } from "../utils/date";

function InfoRow({ icon: Icon, label, value }) {
  return (
    <div className="flex items-start gap-3 py-3 border-b border-gray-50 last:border-0">
      <div className="w-8 h-8 bg-gray-50 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5">
        <Icon className="w-4 h-4 text-gray-400" />
      </div>
      <div>
        <p className="text-xs text-gray-500 font-medium">{label}</p>
        <p className="text-sm text-gray-900 mt-0.5">{value || "—"}</p>
      </div>
    </div>
  );
}

function TimelineItem({ label, date, active, color = "gray" }) {
  const colors = {
    green: "bg-success-500",
    yellow: "bg-warn-500",
    red: "bg-danger-500",
    gray: "bg-gray-300",
    blue: "bg-gov-500",
  };
  return (
    <div className="flex items-start gap-3">
      <div
        className={`w-2.5 h-2.5 rounded-full mt-1.5 flex-shrink-0 ${active ? colors[color] : "bg-gray-200"}`}
      />
      <div>
        <p
          className={`text-sm font-medium ${active ? "text-gray-900" : "text-gray-400"}`}
        >
          {label}
        </p>
        {date && (
          <p className="text-xs text-gray-400 mt-0.5">{fmtDateTime(date)}</p>
        )}
      </div>
    </div>
  );
}

export default function EstablishmentDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { data: est, loading, error, refetch } = useEstablishment(id);

  const [modal, setModal] = useState(null); // 'approve' | 'suspend' | 'revoke' | 'unlock' | 'resetPwd' | 'editContact' | null
  const [suspendReason, setSuspendReason] = useState("");
  const [revokeReason, setRevokeReason] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [contactFields, setContactFields] = useState({
    contact_number: "",
    email: "",
    owner_name: "",
    address: "",
  });
  const [actionLoading, setActionLoading] = useState(false);
  const [actionError, setActionError] = useState("");
  const [successMsg, setSuccessMsg] = useState("");

  function openModal(name) {
    setActionError("");
    if (name === "editContact") {
      setContactFields({
        contact_number: est?.contact_number || "",
        email: est?.email || "",
        owner_name: est?.owner_name || "",
        address: est?.address || "",
      });
    }
    setModal(name);
  }

  async function handleAction() {
    setActionLoading(true);
    setActionError("");
    try {
      if (modal === "approve") {
        await establishmentsAPI.approve(id);
        setSuccessMsg(`"${est.business_name}" has been approved.`);
      } else if (modal === "suspend") {
        await establishmentsAPI.suspend(
          id,
          suspendReason || "Suspended by BPLO admin.",
        );
        setSuccessMsg(`"${est.business_name}" has been suspended.`);
      } else if (modal === "revoke") {
        await establishmentsAPI.revoke(
          id,
          revokeReason || "Revoked by BPLO admin.",
        );
        setSuccessMsg(`"${est.business_name}" has been revoked.`);
      } else if (modal === "unlock") {
        await establishmentsAPI.unlock(id);
        setSuccessMsg(`"${est.business_name}" login has been unlocked.`);
      } else if (modal === "resetPwd") {
        if (!newPassword || newPassword.length < 8)
          throw new Error("Password must be at least 8 characters.");
        await establishmentsAPI.adminResetPassword(id, newPassword);
        setSuccessMsg(
          `Password for "${est.business_name}" has been reset. They will be notified via SMS.`,
        );
        setNewPassword("");
      } else if (modal === "editContact") {
        const payload = {};
        if (contactFields.contact_number !== est.contact_number)
          payload.contact_number = contactFields.contact_number;
        if (contactFields.email !== est.email)
          payload.email = contactFields.email;
        if (contactFields.owner_name !== est.owner_name)
          payload.owner_name = contactFields.owner_name;
        if (contactFields.address !== est.address)
          payload.address = contactFields.address;
        if (!Object.keys(payload).length) {
          setModal(null);
          return;
        }
        await establishmentsAPI.updateContact(id, payload);
        setSuccessMsg(`Contact details for "${est.business_name}" updated.`);
      } else if (modal === "delete") {
        await establishmentsAPI.delete(id);
        // Navigate away immediately — record is gone
        navigate("/establishments");
        return;
      }
      setModal(null);
      setSuspendReason("");
      setRevokeReason("");
      await refetch();
    } catch (err) {
      setActionError(
        err.response?.data?.message ||
          err.response?.data?.error ||
          "Action failed. Please try again.",
      );
    } finally {
      setActionLoading(false);
    }
  }

  if (loading) {
    return (
      <div className="px-6 lg:px-8 py-8 max-w-4xl mx-auto space-y-6">
        <div className="flex items-center gap-3">
          <div className="skeleton w-8 h-8 rounded-lg" />
          <div className="skeleton h-6 w-48" />
        </div>
        <div className="grid md:grid-cols-3 gap-6">
          <div className="md:col-span-2 card space-y-4">
            {[...Array(5)].map((_, i) => (
              <div key={i} className="flex gap-3">
                <div className="skeleton w-8 h-8 rounded-lg" />
                <div className="flex-1 space-y-1.5">
                  <div className="skeleton h-3 w-24" />
                  <div className="skeleton h-4 w-40" />
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
  }

  if (error || !est) {
    return (
      <div className="px-6 lg:px-8 py-8 max-w-4xl mx-auto">
        <Link to="/establishments" className="btn-ghost mb-6 inline-flex">
          <ArrowLeft className="w-4 h-4" /> Establishments
        </Link>
        <div className="card text-center py-12">
          <AlertCircle className="w-10 h-10 text-danger-400 mx-auto mb-3" />
          <p className="font-medium text-gray-700">
            {error || "Establishment not found."}
          </p>
          <button
            onClick={() => navigate("/establishments")}
            className="btn-secondary mt-4"
          >
            Back to Establishments
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="px-6 lg:px-8 py-8 max-w-4xl mx-auto space-y-6">
      {/* Breadcrumb */}
      <div className="flex items-center gap-2 text-sm text-gray-500">
        <Link
          to="/establishments"
          className="hover:text-gov-600 flex items-center gap-1 font-medium"
        >
          <ArrowLeft className="w-4 h-4" /> Establishments
        </Link>
        <span>/</span>
        <span className="text-gray-900 font-medium truncate">
          {est.business_name}
        </span>
      </div>

      {/* Page header */}
      <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 bg-gov-50 rounded-2xl flex items-center justify-center flex-shrink-0">
            <Store className="w-7 h-7 text-gov-600" />
          </div>
          <div>
            <div className="flex items-center gap-2.5 flex-wrap">
              <h1 className="font-heading font-bold text-2xl text-gray-900">
                {est.business_name}
              </h1>
              <StatusBadge status={est.status} />
            </div>
            <p className="text-gray-500 text-sm mt-0.5 capitalize">
              {est.business_type?.replace(/_/g, " ")} · Added{" "}
              {fmtDate(est.created_at)}
            </p>
            <p className="font-mono text-xs text-gray-400 mt-0.5">
              Ref: {est.reference_no}
            </p>
          </div>
        </div>

        {/* Action buttons */}
        <div className="flex items-center gap-2 flex-shrink-0">
          {est.status === "pending" && (
            <button onClick={() => setModal("approve")} className="btn-primary">
              <CheckCircle2 className="w-4 h-4" />
              Approve
            </button>
          )}
          {est.status === "approved" && (
            <button onClick={() => setModal("suspend")} className="btn-danger">
              <Ban className="w-4 h-4" />
              Suspend
            </button>
          )}
          {(est.status === "approved" || est.status === "suspended") && (
            <button
              onClick={() => setModal("revoke")}
              className="btn-ghost text-danger-600 hover:bg-danger-50"
            >
              <Ban className="w-4 h-4" />
              Revoke
            </button>
          )}
          {est.status === "suspended" && (
            <button onClick={() => setModal("approve")} className="btn-primary">
              <CheckCircle2 className="w-4 h-4" />
              Reinstate
            </button>
          )}
          {est.locked_until && new Date() < new Date(est.locked_until) && (
            <button
              onClick={() => openModal("unlock")}
              className="btn-ghost text-amber-600 hover:bg-amber-50"
            >
              <LockOpen className="w-4 h-4" />
              Unlock Login
            </button>
          )}
          <button
            onClick={() => openModal("editContact")}
            className="btn-ghost text-gov-600 hover:bg-gov-50"
          >
            <Edit className="w-4 h-4" />
            Update Contact
          </button>
          <button
            onClick={() => openModal("resetPwd")}
            className="btn-ghost text-orange-600 hover:bg-orange-50"
          >
            <Key className="w-4 h-4" />
            Reset Password
          </button>
          {est.status === "revoked" && (
            <button
              onClick={() => openModal("delete")}
              className="btn-ghost text-danger-600 hover:bg-danger-50"
            >
              <Trash2 className="w-4 h-4" />
              Delete
            </button>
          )}
        </div>
      </div>

      {/* Success message */}
      {successMsg && (
        <div className="flex items-center gap-2.5 px-4 py-3 bg-success-50 border border-success-100 rounded-lg text-success-700 text-sm">
          <CheckCircle2 className="w-4 h-4 flex-shrink-0" />
          {successMsg}
        </div>
      )}

      <div className="grid md:grid-cols-3 gap-6">
        {/* Main info */}
        <div className="md:col-span-2 space-y-6">
          {/* Contact & location */}
          <div className="card">
            <h2 className="font-heading font-semibold text-gray-900 mb-1">
              Business Information
            </h2>
            <p className="text-xs text-gray-400 mb-4">
              Registered details submitted by the establishment
            </p>
            <div className="divide-y divide-gray-50">
              <InfoRow
                icon={Hash}
                label="Establishment ID"
                value={`#${est.id}`}
              />
              <InfoRow
                icon={Building2}
                label="Business Type"
                value={est.business_type?.replace(/_/g, " ")}
              />
              <InfoRow icon={MapPin} label="Address" value={est.address} />
              <InfoRow
                icon={Phone}
                label="Contact Phone"
                value={est.contact_phone}
              />
              <InfoRow
                icon={Mail}
                label="Contact Email"
                value={est.contact_email}
              />
              <InfoRow
                icon={Calendar}
                label="Date Registered"
                value={fmtDate(est.created_at)}
              />
              <InfoRow
                icon={Calendar}
                label="Business Permit Expiry"
                value={
                  est.business_permit_expiry
                    ? fmtDate(est.business_permit_expiry)
                    : "Not set"
                }
              />
              <InfoRow
                icon={Calendar}
                label="Last Updated"
                value={fmtDateTime(est.updated_at)}
              />
            </div>
          </div>

          {/* Suspension info */}
          {est.status === "suspended" && est.suspension_reason && (
            <div className="flex items-start gap-3 p-4 bg-danger-50 border border-danger-100 rounded-xl">
              <Ban className="w-4 h-4 text-danger-600 mt-0.5 flex-shrink-0" />
              <div>
                <p className="text-sm font-medium text-danger-800">
                  Suspension reason
                </p>
                <p className="text-sm text-danger-700 mt-0.5">
                  {est.suspension_reason}
                </p>
              </div>
            </div>
          )}
        </div>

        {/* Sidebar: status timeline + quick actions */}
        <div className="space-y-5">
          {/* Status lifecycle */}
          <div className="card">
            <h3 className="font-heading font-semibold text-gray-900 text-sm mb-4">
              Status Timeline
            </h3>
            <div className="space-y-4 pl-1">
              <TimelineItem
                label="Application submitted"
                date={est.created_at}
                active={true}
                color="blue"
              />
              <TimelineItem
                label="Approved by BPLO"
                date={est.status !== "pending" ? est.updated_at : null}
                active={["approved", "suspended", "revoked"].includes(
                  est.status,
                )}
                color="green"
              />
              <TimelineItem
                label="Active — scanning enabled"
                date={est.status === "approved" ? est.updated_at : null}
                active={est.status === "approved"}
                color="green"
              />
              {est.status === "suspended" && (
                <TimelineItem
                  label="Suspended"
                  date={est.updated_at}
                  active={true}
                  color="red"
                />
              )}
              {est.status === "revoked" && (
                <TimelineItem
                  label="Revoked"
                  date={est.updated_at}
                  active={true}
                  color="red"
                />
              )}
            </div>
          </div>

          {/* Quick info */}
          <div className="card">
            <h3 className="font-heading font-semibold text-gray-900 text-sm mb-3">
              Quick Reference
            </h3>
            <div className="space-y-2 text-xs text-gray-600">
              <p className="flex items-start gap-1.5">
                <Clock className="w-3.5 h-3.5 text-gray-400 mt-0.5 flex-shrink-0" />
                Verification scans require <strong>approved</strong> status.
              </p>
              <p className="flex items-start gap-1.5">
                <AlertCircle className="w-3.5 h-3.5 text-gray-400 mt-0.5 flex-shrink-0" />
                Suspended establishments are blocked from scanning immediately.
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Approve modal */}
      <ConfirmModal
        open={modal === "approve"}
        onClose={() => {
          setModal(null);
          setActionError("");
        }}
        onConfirm={handleAction}
        title={
          est.status === "suspended"
            ? "Reinstate Establishment"
            : "Approve Establishment"
        }
        description={
          est.status === "suspended"
            ? `Reinstate "${est.business_name}" and restore their access to the iDetect scanning network?`
            : `Approve "${est.business_name}" and grant them access to scan Senior Citizen and PWD IDs?`
        }
        confirmLabel={est.status === "suspended" ? "Reinstate" : "Approve"}
        variant="primary"
        loading={actionLoading}
      >
        {actionError && (
          <p className="text-sm text-danger-600 flex items-center gap-1.5">
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
          setSuspendReason("");
        }}
        onConfirm={handleAction}
        title="Suspend Establishment"
        description={`Suspend "${est.business_name}"? They will immediately lose access to iDetect scanning.`}
        confirmLabel="Suspend"
        variant="danger"
        loading={actionLoading}
      >
        <div className="mt-1">
          <label className="label text-xs">Reason (optional)</label>
          <textarea
            className="input text-sm"
            placeholder="e.g. Expired business permit, violation…"
            value={suspendReason}
            onChange={(e) => setSuspendReason(e.target.value)}
            disabled={actionLoading}
            maxLength={2500}
            rows={4}
          />
          <p className="mt-1 text-xs text-gray-500 text-right" aria-live="polite">
            {suspendReason.length} / 2,500 characters
          </p>
        </div>
        {actionError && (
          <p className="text-sm text-danger-600 flex items-center gap-1.5 mt-3">
            <AlertCircle className="w-4 h-4" />
            {actionError}
          </p>
        )}
      </ConfirmModal>

      {/* Revoke modal */}
      <ConfirmModal
        open={modal === "revoke"}
        onClose={() => {
          setModal(null);
          setActionError("");
          setRevokeReason("");
        }}
        onConfirm={handleAction}
        title="Revoke Establishment"
        description={`Permanently revoke "${est.business_name}"? This will remove their access to iDetect and cannot be undone easily.`}
        confirmLabel="Revoke"
        variant="danger"
        loading={actionLoading}
      >
        <div className="mt-1">
          <label className="label text-xs">Reason (required)</label>
          <input
            type="text"
            className="input text-sm"
            placeholder="e.g. Fraudulent activity, permanent closure…"
            value={revokeReason}
            onChange={(e) => setRevokeReason(e.target.value)}
            disabled={actionLoading}
          />
        </div>
        {actionError && (
          <p className="text-sm text-danger-600 flex items-center gap-1.5 mt-3">
            <AlertCircle className="w-4 h-4" />
            {actionError}
          </p>
        )}
      </ConfirmModal>

      <ConfirmModal
        open={modal === "unlock"}
        title="Unlock Login"
        description={`Clear the login lockout for "${est.business_name}"? They will be able to log in immediately.`}
        confirmLabel="Unlock"
        confirmClassName="btn-primary"
        onClose={() => setModal(null)}
        onConfirm={handleAction}
        loading={actionLoading}
      >
        {actionError && (
          <p className="flex items-center gap-1.5 text-sm text-danger-600 mt-2">
            <AlertCircle className="w-4 h-4" />
            {actionError}
          </p>
        )}
      </ConfirmModal>

      {/* Force Reset Password modal */}
      <ConfirmModal
        open={modal === "resetPwd"}
        title="Reset Establishment Password"
        description={`Set a new password for "${est.business_name}". The establishment will be notified via SMS.`}
        confirmLabel="Reset Password"
        variant="danger"
        onClose={() => {
          setModal(null);
          setNewPassword("");
          setActionError("");
        }}
        onConfirm={handleAction}
        loading={actionLoading}
      >
        <div className="mt-1">
          <label className="label text-xs">
            New Password (min 8 characters)
          </label>
          <input
            type="password"
            className="input text-sm"
            placeholder="Enter new password"
            value={newPassword}
            onChange={(e) => setNewPassword(e.target.value)}
            disabled={actionLoading}
            minLength={8}
          />
        </div>
        {actionError && (
          <p className="flex items-center gap-1.5 text-sm text-danger-600 mt-2">
            <AlertCircle className="w-4 h-4" />
            {actionError}
          </p>
        )}
      </ConfirmModal>

      {/* Update Contact Details modal */}
      <ConfirmModal
        open={modal === "editContact"}
        title="Update Contact Details"
        description={`Update contact information for "${est.business_name}".`}
        confirmLabel="Save Changes"
        variant="primary"
        onClose={() => {
          setModal(null);
          setActionError("");
        }}
        onConfirm={handleAction}
        loading={actionLoading}
      >
        <div className="space-y-3 mt-1">
          <div>
            <label className="label text-xs">Contact Number</label>
            <input
              type="text"
              className="input text-sm"
              value={contactFields.contact_number}
              onChange={(e) =>
                setContactFields((f) => ({
                  ...f,
                  contact_number: e.target.value,
                }))
              }
              disabled={actionLoading}
            />
          </div>
          <div>
            <label className="label text-xs">Email</label>
            <input
              type="email"
              className="input text-sm"
              value={contactFields.email}
              onChange={(e) =>
                setContactFields((f) => ({ ...f, email: e.target.value }))
              }
              disabled={actionLoading}
            />
          </div>
          <div>
            <label className="label text-xs">Owner Name</label>
            <input
              type="text"
              className="input text-sm"
              value={contactFields.owner_name}
              onChange={(e) =>
                setContactFields((f) => ({ ...f, owner_name: e.target.value }))
              }
              disabled={actionLoading}
            />
          </div>
          <div>
            <label className="label text-xs">Address</label>
            <input
              type="text"
              className="input text-sm"
              value={contactFields.address}
              onChange={(e) =>
                setContactFields((f) => ({ ...f, address: e.target.value }))
              }
              disabled={actionLoading}
            />
          </div>
        </div>
        {actionError && (
          <p className="flex items-center gap-1.5 text-sm text-danger-600 mt-2">
            <AlertCircle className="w-4 h-4" />
            {actionError}
          </p>
        )}
      </ConfirmModal>

      {/* Delete modal — only for revoked establishments */}
      <ConfirmModal
        open={modal === "delete"}
        title="Permanently Delete Establishment"
        description={`Delete "${est?.business_name}" from the system? This cannot be undone. Only revoked establishments can be deleted.`}
        confirmLabel="Delete Permanently"
        variant="danger"
        onClose={() => {
          setModal(null);
          setActionError("");
        }}
        onConfirm={handleAction}
        loading={actionLoading}
      >
        {actionError && (
          <p className="flex items-center gap-1.5 text-sm text-danger-600 mt-2">
            <AlertCircle className="w-4 h-4" />
            {actionError}
          </p>
        )}
      </ConfirmModal>
    </div>
  );
}
