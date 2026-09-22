import { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import {
  ArrowLeft,
  Store,
  Save,
  AlertCircle,
  CheckCircle2,
  Loader2,
  Hash,
  MapPin,
  Phone,
  Mail,
  User,
  Building2,
  Calendar,
  KeyRound,
} from "lucide-react";
import { establishmentsAPI } from "../services/api";

const INITIAL = {
  business_name: "",
  business_permit_no: "",
  business_permit_expiry: "",
  owner_name: "",
  address: "",
  contact_number: "",
  email: "",
};

function FormField({ icon: Icon, label, required, children }) {
  return (
    <div>
      <label className="label flex items-center gap-1.5">
        <Icon className="w-3.5 h-3.5 text-slate-400" />
        {label}
        {required && <span className="text-danger-500">*</span>}
      </label>
      {children}
    </div>
  );
}

export default function CreateEstablishmentPage() {
  const navigate = useNavigate();
  const [form, setForm] = useState(INITIAL);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState(null);
  const [copied, setCopied] = useState(false);

  function set(field) {
    return (e) => setForm((prev) => ({ ...prev, [field]: e.target.value }));
  }

  function validate() {
    if (!form.business_name.trim()) return "Business name is required.";
    if (!form.business_permit_no.trim())
      return "Business permit number is required.";
    if (!form.owner_name.trim()) return "Owner name is required.";
    if (!form.address.trim()) return "Address is required.";
    if (!form.contact_number.trim()) return "Contact number is required.";
    if (!form.email.trim()) return "Email address is required.";
    if (!/\S+@\S+\.\S+/.test(form.email))
      return "Please enter a valid email address.";
    return null;
  }

  async function handleCopyLink() {
    if (!success?.setup_url) return;
    try {
      await navigator.clipboard.writeText(success.setup_url);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Clipboard API can fail on non-HTTPS/old browsers; fall back to a manual select
    }
  }

  async function handleSubmit(e) {
    e.preventDefault();
    setError("");

    const validationError = validate();
    if (validationError) {
      setError(validationError);
      return;
    }

    setLoading(true);
    try {
      const { data } = await establishmentsAPI.create({
        business_name: form.business_name.trim(),
        business_permit_no: form.business_permit_no.trim(),
        owner_name: form.owner_name.trim(),
        address: form.address.trim(),
        contact_number: form.contact_number.trim(),
        email: form.email.trim(),
        business_permit_expiry: form.business_permit_expiry || undefined,
      });
      setSuccess(data);
      setForm(INITIAL);
    } catch (err) {
      const msg =
        err.response?.data?.message ||
        err.response?.data?.errors?.[0]?.msg ||
        "Failed to create establishment. Please try again.";
      setError(msg);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="px-6 lg:px-8 py-8 max-w-3xl mx-auto space-y-6">
      {/* Breadcrumb */}
      <div className="flex items-center gap-2 text-sm text-gray-500">
        <Link
          to="/establishments"
          className="hover:text-gov-600 flex items-center gap-1 font-medium"
        >
          <ArrowLeft className="w-4 h-4" /> Establishments
        </Link>
        <span>/</span>
        <span className="text-gray-900 font-medium">Create New</span>
      </div>

      {/* Header */}
      <div className="flex items-center gap-4">
        <div className="w-12 h-12 bg-gov-50 rounded-2xl flex items-center justify-center">
          <Store className="w-6 h-6 text-gov-600" />
        </div>
        <div>
          <h1 className="font-heading font-bold text-2xl text-gray-900">
            Create Establishment Account
          </h1>
          <p className="text-gray-500 text-sm mt-0.5">
            Register a food service establishment and grant them immediate
            access to iDetect.
          </p>
        </div>
      </div>

      {/* Success message */}
      {success && (
        <div className="p-5 bg-success-50 border border-success-200 rounded-xl space-y-3">
          <div className="flex items-center gap-2 text-success-800">
            <CheckCircle2 className="w-5 h-5 flex-shrink-0" />
            <p className="font-semibold text-sm">{success.message}</p>
          </div>
          <div className="bg-white rounded-lg border border-success-100 p-4 text-sm space-y-2">
            <p className="text-gray-600">
              <span className="font-medium text-gray-900">Business: </span>
              {success.establishment?.business_name}
            </p>
            <p className="text-gray-600">
              <span className="font-medium text-gray-900">Permit No: </span>
              {success.establishment?.business_permit_no}
            </p>
            <p className="text-gray-600">
              <span className="font-medium text-gray-900">Login Email: </span>
              {success.establishment?.email}
            </p>
            <p className="text-gray-600">
              <span className="font-medium text-gray-900">Status: </span>
              <span className="text-success-700 font-medium">
                Approved — Active
              </span>
            </p>
          </div>
          {success.email_sent ? (
            <p className="text-xs text-amber-700 bg-amber-50 border border-amber-200 rounded px-3 py-2">
              A password-setup link has been emailed to the establishment. It
              expires in 24 hours.
            </p>
          ) : (
            <div className="text-xs text-danger-700 bg-danger-50 border border-danger-200 rounded px-3 py-2 space-y-1">
              <p className="font-medium">
                The setup-link email could not be sent. Share this link with the
                establishment directly — it expires in 24 hours.
              </p>
            </div>
          )}
          {success.setup_url && (
            <div className="space-y-1.5">
              <label className="text-xs font-medium text-gray-500">
                Setup link{" "}
                {success.email_sent ? "(backup — also sent by email)" : ""}
              </label>
              <div className="flex items-center gap-2">
                <input
                  type="text"
                  readOnly
                  value={success.setup_url}
                  onClick={(e) => e.target.select()}
                  className="input text-xs font-mono flex-1 bg-gray-50"
                />
                <button
                  type="button"
                  onClick={handleCopyLink}
                  className="btn-secondary text-xs whitespace-nowrap"
                >
                  {copied ? "Copied!" : "Copy Link"}
                </button>
              </div>
            </div>
          )}
          <p className="text-xs text-success-700">
            Once they set their password, they can log in to the Client Portal
            and begin scanning IDs.
          </p>
          <div className="flex gap-2 pt-1">
            <button
              onClick={() => setSuccess(null)}
              className="btn-secondary text-sm"
            >
              Create Another
            </button>
            <Link to="/establishments" className="btn-primary text-sm">
              Back to Establishments
            </Link>
          </div>
        </div>
      )}

      {/* Form */}
      {!success && (
        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Business Details */}
          <div className="card space-y-5">
            <div>
              <h2 className="font-heading font-semibold text-gray-900">
                Business Information
              </h2>
              <p className="text-xs text-gray-400 mt-0.5">
                Enter the establishment's Valenzuela City business permit
                details
              </p>
            </div>

            <div className="grid sm:grid-cols-2 gap-4">
              <FormField icon={Hash} label="Business Permit Number" required>
                <input
                  type="text"
                  className="input"
                  placeholder="e.g. BP-2026-00123"
                  value={form.business_permit_no}
                  onChange={set("business_permit_no")}
                  disabled={loading}
                />
              </FormField>

              <FormField icon={Building2} label="Business Name" required>
                <input
                  type="text"
                  className="input"
                  placeholder="e.g. Jollibee Karuhatan Branch"
                  value={form.business_name}
                  onChange={set("business_name")}
                  disabled={loading}
                />
              </FormField>
            </div>

            <FormField icon={User} label="Owner Name" required>
              <input
                type="text"
                className="input"
                placeholder="Full name of the business owner"
                value={form.owner_name}
                onChange={set("owner_name")}
                disabled={loading}
              />
            </FormField>

            <FormField icon={MapPin} label="Business Address" required>
              <input
                type="text"
                className="input"
                placeholder="Complete address in Valenzuela City"
                value={form.address}
                onChange={set("address")}
                disabled={loading}
              />
            </FormField>

            <FormField icon={Phone} label="Contact Number" required>
              <input
                type="text"
                className="input"
                placeholder="e.g. 09171234567"
                value={form.contact_number}
                onChange={set("contact_number")}
                disabled={loading}
              />
            </FormField>

            <FormField icon={Mail} label="Business Email Address" required>
              <input
                type="email"
                className="input"
                placeholder="e.g. owner@restaurant.com"
                value={form.email}
                onChange={set("email")}
                disabled={loading}
              />
              <p className="text-xs text-gray-400 mt-1">
                Login credentials will be auto-generated and sent to this email.
              </p>
            </FormField>

            <FormField icon={Calendar} label="Business Permit Expiry Date">
              <input
                type="date"
                className="input"
                value={form.business_permit_expiry}
                onChange={set("business_permit_expiry")}
                disabled={loading}
              />
            </FormField>
          </div>

          {/* Credentials note */}
          <div className="flex items-start gap-3 px-4 py-3 bg-blue-50 border border-blue-100 rounded-lg text-blue-700 text-sm">
            <KeyRound className="w-4 h-4 flex-shrink-0 mt-0.5" />
            <span>
              A secure login email and password will be{" "}
              <strong>automatically generated</strong> and sent to the
              establishment's email address. No manual credential entry needed.
            </span>
          </div>

          {/* Error */}
          {error && (
            <div className="flex items-center gap-2.5 px-4 py-3 bg-danger-50 border border-danger-100 rounded-lg text-danger-700 text-sm">
              <AlertCircle className="w-4 h-4 flex-shrink-0" />
              {error}
            </div>
          )}

          {/* Submit */}
          <div className="flex items-center justify-between pt-2">
            <Link to="/establishments" className="btn-ghost text-sm">
              Cancel
            </Link>
            <button type="submit" disabled={loading} className="btn-primary">
              {loading ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  Creating…
                </>
              ) : (
                <>
                  <Save className="w-4 h-4" />
                  Create &amp; Approve Establishment
                </>
              )}
            </button>
          </div>
        </form>
      )}
    </div>
  );
}
