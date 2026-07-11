import axios from "axios";

const configuredApiBaseUrl = (import.meta.env?.VITE_API_URL || "/api").trim();
const normalizedApiBaseUrl = configuredApiBaseUrl.replace(/\/$/, "");
const buildApiPath = (path) => {
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  return normalizedPath.startsWith("/api")
    ? normalizedPath
    : `/api${normalizedPath}`;
};

const api = axios.create({
  baseURL: normalizedApiBaseUrl,
  headers: { "Content-Type": "application/json" },
  timeout: 10000,
});

// ── Silent JWT refresh helper ─────────────────────────────────────────────────
// Decodes exp from the JWT payload without a library, refreshes proactively
// when < 5 minutes remain. Uses a shared promise to avoid concurrent refresh calls.
let _refreshing = null;
async function ensureFreshToken() {
  const token = localStorage.getItem("staff_token");
  if (!token) return token;
  try {
    const payload = JSON.parse(atob(token.split(".")[1]));
    const secsLeft = payload.exp - Math.floor(Date.now() / 1000);
    if (secsLeft > 300) return token; // >5 min remaining — no refresh needed
    if (!_refreshing) {
      _refreshing = axios
        .post(
          buildApiPath("/auth/staff/refresh"),
          {},
          { headers: { Authorization: `Bearer ${token}` } },
        )
        .then((r) => {
          localStorage.setItem("staff_token", r.data.token);
          return r.data.token;
        })
        .catch(() => token) // refresh failed — return old token, 401 will redirect
        .finally(() => {
          _refreshing = null;
        });
    }
    return _refreshing;
  } catch {
    return token;
  }
}

// ── Request interceptor — attach JWT (with proactive refresh) ─────────────────
api.interceptors.request.use(async (config) => {
  const requestUrl = config.url || "";
  if (!/^https?:\/\//i.test(requestUrl)) {
    config.url = buildApiPath(requestUrl);
  }

  if (requestUrl.includes("/auth/")) {
    // Skip refresh for auth endpoints to avoid recursion
    const token = localStorage.getItem("staff_token");
    if (token) config.headers.Authorization = `Bearer ${token}`;
  } else {
    const token = await ensureFreshToken();
    if (token) config.headers.Authorization = `Bearer ${token}`;
  }
  console.log("[iDetect API]", config.method?.toUpperCase(), config.url);
  return config;
});

// ── Response interceptor — log errors and redirect on 401 ────────────────────
api.interceptors.response.use(
  (res) => res,
  (err) => {
    console.error("[iDetect API Error]", {
      url: err.config?.url,
      status: err.response?.status,
      data: err.response?.data,
    });
    if (err.response?.status === 401 && !err.config?.url?.includes("/auth/")) {
      localStorage.removeItem("staff_token");
      localStorage.removeItem("staff_user");
      window.location.href = "/login";
    }
    return Promise.reject(err);
  },
);

// ─── Auth ─────────────────────────────────────────────────────────────────────
export const authAPI = {
  login: (email, password) =>
    api.post("/auth/staff/login", { email, password }),
};

// ─── Beneficiaries ────────────────────────────────────────────────────────────
// Both OSCA (senior_citizen) and PDAO (pwd) use this same API module.
// The server automatically scopes results by the JWT role.
// The `beneficiary_type` value is passed by the caller based on user.role.
export const beneficiariesAPI = {
  list: (params = {}) => api.get("/beneficiaries", { params }),

  getById: (id) => api.get(`/beneficiaries/${id}`),

  create: (data, beneficiaryType) => {
    const hasApiShape =
      data.full_name &&
      data.birthdate &&
      data.issuing_office &&
      data.validity_start &&
      data.validity_end;

    const normalizedMobile = (
      data.contact_number ||
      data.registered_mobile ||
      ""
    )
      .replace(/[^\d+]/g, "")
      .trim();

    const payload = hasApiShape
      ? {
          ...data,
          id_number: data.id_number?.trim().toUpperCase(),
          registered_mobile: normalizedMobile || undefined,
          beneficiary_type: beneficiaryType,
        }
      : {
          id_number: data.id_number?.trim().toUpperCase(),
          full_name: [data.first_name, data.middle_name, data.last_name]
            .filter(Boolean)
            .join(" ")
            .replace(/\s+/g, " ")
            .trim(),
          birthdate: data.date_of_birth,
          issuing_office:
            beneficiaryType === "senior_citizen"
              ? "OSCA Valenzuela"
              : "PDAO Valenzuela",
          validity_start: new Date().toISOString().slice(0, 10),
          validity_end: (() => {
            const d = new Date();
            d.setFullYear(d.getFullYear() + 1);
            return d.toISOString().slice(0, 10);
          })(),
          registered_mobile: normalizedMobile || undefined,
          beneficiary_type: beneficiaryType,
        };

    return api.post("/beneficiaries", payload);
  },

  importBulk: (records) => api.post("/beneficiaries/import", { records }),

  updateStatus: (id, status) =>
    api.patch(`/beneficiaries/${id}/status`, { status }),

  update: (id, data) => api.put(`/beneficiaries/${id}`, data),

  renew: (id, validity_start, validity_end) =>
    api.post(`/beneficiaries/${id}/renew`, { validity_start, validity_end }),

  expiringSoon: (days = 30) =>
    api.get("/beneficiaries/expiring-soon", { params: { days } }),

  recentlyAutoSuspended: (hours = 24) =>
    api.get("/beneficiaries/recently-auto-suspended", { params: { hours } }),
};

// ─── Establishments (BPLO only) ───────────────────────────────────────────────
export const establishmentsAPI = {
  list: (params = {}) => api.get("/establishments", { params }),

  get: (id) => api.get(`/establishments/${id}`),

  create: (data) => api.post("/establishments", data),

  approve: (id) => api.patch(`/establishments/${id}/approve`),

  suspend: (id, reason) =>
    api.patch(`/establishments/${id}/suspend`, { reason }),

  revoke: (id, reason) => api.patch(`/establishments/${id}/revoke`, { reason }),

  unlock: (id) => api.patch(`/establishments/${id}/unlock`),

  updateContact: (id, data) => api.patch(`/establishments/${id}/contact`, data),

  adminResetPassword: (id, new_password) =>
    api.patch(`/establishments/${id}/admin-reset-password`, { new_password }),

  expiringPermits: (days = 30) =>
    api.get("/establishments/expiring-permits", { params: { days } }),

  delete: (id) => api.delete(`/establishments/${id}`),

  importBulk: (records) => api.post("/establishments/bulk-import", { records }),

  downloadCredentials: (token) =>
    api.get(`/establishments/bulk-credentials/${token}`, {
      responseType: "blob",
    }),
};

// ─── Fraud flags ──────────────────────────────────────────────────────────────
export const fraudFlagsAPI = {
  list: (params = {}) => api.get("/fraud-flags", { params }),
  review: (id, action, notes) =>
    api.patch(`/fraud-flags/${id}/review`, {
      decision: action === "confirm" ? "confirmed" : "dismissed",
      staff_notes: notes,
    }),
  restore: (id, staff_notes) =>
    api.patch(`/fraud-flags/${id}/restore`, { staff_notes }),
};

// ─── Disputes ─────────────────────────────────────────────────────────────────
export const disputesAPI = {
  list: (params = {}) => api.get("/disputes", { params }),
  acknowledge: (id) => api.patch(`/disputes/${id}/acknowledge`),
  resolve: (id, decision, staff_response) =>
    api.patch(`/disputes/${id}/resolve`, { decision, staff_response }),
};

// ─── Verification logs ────────────────────────────────────────────────────────
export const verificationAPI = {
  history: (params = {}) => api.get("/verification/history", { params }),
};

// ─── Dashboard analytics ──────────────────────────────────────────────────────
export const dashboardAPI = {
  stats: () => api.get("/dashboard/stats"),
};

// ─── Audit logs ───────────────────────────────────────────────────────────────
export const auditLogsAPI = {
  list: (params = {}) => api.get("/audit-logs", { params }),
  exportCsv: (params = {}) =>
    api.get("/audit-logs/export", { params, responseType: "blob" }),
};

// ─── Reports / CSV export ─────────────────────────────────────────────────────
export const reportsAPI = {
  exportVerifications: (params = {}) =>
    api.get("/reports/verifications/export", { params, responseType: "blob" }),
  exportFraudFlags: (params = {}) =>
    api.get("/reports/fraud-flags/export", { params, responseType: "blob" }),
  exportDisputes: (params = {}) =>
    api.get("/reports/disputes/export", { params, responseType: "blob" }),
};

// ─── Staff management ─────────────────────────────────────────────────────────
export const staffAPI = {
  list: () => api.get("/staff"),
  get: (id) => api.get(`/staff/${id}`),
  create: (data) => api.post("/staff", data),
  update: (id, data) => api.patch(`/staff/${id}`, data),
  toggleActive: (id) => api.patch(`/staff/${id}/toggle-active`),
  resetPassword: (id, password) =>
    api.patch(`/staff/${id}/reset-password`, { password }),
  changePassword: (current_password, new_password) =>
    api.patch("/staff/me/change-password", { current_password, new_password }),
  unlock: (id) => api.patch(`/staff/${id}/unlock`),
};

// ─── Staff alerts ─────────────────────────────────────────────────────────────
export const staffAlertsAPI = {
  list: () => api.get("/staff/alerts"),
  markAllRead: () => api.post("/staff/alerts/mark-all-read"),
};

// ─── Breach incident report (REQ-2.17.6) ─────────────────────────────────────
export const breachReportAPI = {
  generate: (payload) => api.post("/staff/breach-report", payload),
};

export default api;
