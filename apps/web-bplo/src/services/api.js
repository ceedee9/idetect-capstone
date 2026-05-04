import axios from "axios";

// Base URL — Vite proxy forwards /api -> http://localhost:3000
const api = axios.create({
  baseURL: "/api",
  headers: { "Content-Type": "application/json" },
  timeout: 10000,
});

// Silent JWT refresh helper
let _refreshing = null;
async function ensureFreshToken() {
  const token = localStorage.getItem("bplo_token");
  if (!token) return token;
  try {
    const payload = JSON.parse(atob(token.split(".")[1]));
    const secsLeft = payload.exp - Math.floor(Date.now() / 1000);
    if (secsLeft > 300) return token;
    if (!_refreshing) {
      _refreshing = axios
        .post(
          "/api/auth/staff/refresh",
          {},
          {
            headers: { Authorization: `Bearer ${token}` },
          },
        )
        .then((r) => {
          localStorage.setItem("bplo_token", r.data.token);
          return r.data.token;
        })
        .catch(() => token)
        .finally(() => {
          _refreshing = null;
        });
    }
    return _refreshing;
  } catch {
    return token;
  }
}

// Attach JWT token to every request (with proactive refresh)
api.interceptors.request.use(async (config) => {
  let token;
  if (config.url?.includes("/auth/")) {
    token = localStorage.getItem("bplo_token");
    if (token) config.headers.Authorization = `Bearer ${token}`;
  } else {
    token = await ensureFreshToken();
    if (token) config.headers.Authorization = `Bearer ${token}`;
  }
  console.log(
    "[iDetect API Request]",
    config.method?.toUpperCase(),
    config.url,
    token ? "(token attached)" : "(NO TOKEN)",
  );
  return config;
});

// Handle errors — log all API errors to console for debugging
api.interceptors.response.use(
  (res) => {
    console.log(
      "[iDetect API Response]",
      res.config?.url,
      res.status,
      res.data,
    );
    return res;
  },
  (err) => {
    console.error("[iDetect API Error]", {
      url: err.config?.url,
      status: err.response?.status,
      data: err.response?.data,
    });
    // Only redirect on 401 for non-auth routes to avoid redirect loops
    if (err.response?.status === 401 && !err.config?.url?.includes("/auth/")) {
      localStorage.removeItem("bplo_token");
      localStorage.removeItem("bplo_user");
      window.location.href = "/login";
    }
    return Promise.reject(err);
  },
);

// ─── Auth ────────────────────────────────────────────────────────────────────

export const authAPI = {
  login: (email, password) =>
    api.post("/auth/staff/login", { email, password }),
};

// ─── Establishments ───────────────────────────────────────────────────────────

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

// ─── Verification logs (BPLO can see aggregate stats) ─────────────────────────

export const verificationAPI = {
  history: (params = {}) => api.get("/verification/history", { params }),
};

// ─── Disputes (BPLO sees business refusal disputes only) ──────────────────────

export const disputesAPI = {
  list: (params = {}) => api.get("/disputes", { params }),
  acknowledge: (id) => api.patch(`/disputes/${id}/acknowledge`),
  resolve: (id, decision, staff_response) =>
    api.patch(`/disputes/${id}/resolve`, { decision, staff_response }),
};

// ─── Fraud flags ──────────────────────────────────────────────────────────────
export const fraudFlagsAPI = {
  list: (params = {}) => api.get("/fraud-flags", { params }),
  review: (id, action, notes) =>
    api.patch(`/fraud-flags/${id}/review`, {
      decision: action === "confirm" ? "confirmed" : "dismissed",
      staff_notes: notes,
    }),
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

// ─── Breach incident report (REQ-2.17.6) ──────────────────────────────────────────
export const breachReportAPI = {
  generate: (payload) => api.post("/staff/breach-report", payload),
};

export default api;
