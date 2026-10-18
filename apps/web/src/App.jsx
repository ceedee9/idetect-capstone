import { lazy, Suspense } from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { Component } from "react";
import { AuthProvider, useAuth } from "./context/AuthContext";
import AppShell from "./components/AppShell";

// ── Lazy-loaded pages for code splitting ─────────────────────────────────────
const LoginPage = lazy(() => import("./pages/LoginPage"));
const DashboardPage = lazy(() => import("./pages/DashboardPage"));

// OSCA + PDAO pages
const BeneficiariesPage = lazy(() => import("./pages/BeneficiariesPage"));
const BeneficiaryDetailPage = lazy(
  () => import("./pages/BeneficiaryDetailPage"),
);
const AddBeneficiaryPage = lazy(() => import("./pages/AddBeneficiaryPage"));

// BPLO-only pages
const EstablishmentsPage = lazy(() => import("./pages/EstablishmentsPage"));
const EstablishmentDetailPage = lazy(
  () => import("./pages/EstablishmentDetailPage"),
);
const CreateEstablishmentPage = lazy(
  () => import("./pages/CreateEstablishmentPage"),
);
const BusinessRefusalsPage = lazy(() => import("./pages/BusinessRefusalsPage"));

// Shared pages (all roles)
const FraudFlagsPage = lazy(() => import("./pages/FraudFlagsPage"));
const DisputesPage = lazy(() => import("./pages/DisputesPage"));
const CallbackRequestsPage = lazy(() => import("./pages/CallbackRequestsPage"));
const AuditLogsPage = lazy(() => import("./pages/AuditLogsPage"));
const StaffPage = lazy(() => import("./pages/StaffPage"));
const ResetPasswordPage = lazy(() => import("./pages/ResetPasswordPage"));
const EstablishmentSetupPasswordPage = lazy(
  () => import("./pages/EstablishmentSetupPasswordPage"),
);

// ── Error boundary ────────────────────────────────────────────────────────────
class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }
  static getDerivedStateFromError(error) {
    return { error };
  }
  render() {
    if (this.state.error)
      return (
        <div style={{ padding: 40, fontFamily: "monospace" }}>
          <h2 style={{ color: "#dc2626" }}>⚠ Unable to load this page</h2>
          <pre
            style={{
              background: "#fef2f2",
              padding: 16,
              borderRadius: 8,
              fontSize: 13,
              whiteSpace: "pre-wrap",
            }}
          >
            Something went wrong while loading the page. Please reload and try
            again.
          </pre>
          <button
            onClick={() => {
              this.setState({ error: null });
              window.location.reload();
            }}
            style={{
              marginTop: 16,
              padding: "8px 16px",
              background: "#1d4ed8",
              color: "white",
              border: "none",
              borderRadius: 8,
              cursor: "pointer",
            }}
          >
            Reload Page
          </button>
        </div>
      );
    return this.props.children;
  }
}

// ── Route guards ──────────────────────────────────────────────────────────────

/** Redirects unauthenticated users to /login */
function ProtectedRoute({ children }) {
  const { isAuthenticated } = useAuth();
  return isAuthenticated ? children : <Navigate to="/login" replace />;
}

/** Redirects authenticated users away from public routes (e.g. login) */
function PublicRoute({ children }) {
  const { isAuthenticated } = useAuth();
  return isAuthenticated ? <Navigate to="/" replace /> : children;
}

/**
 * Restricts a route to specific roles.
 * If the user's role is not in `roles`, redirects to the dashboard root.
 */
function RoleRoute({ children, roles }) {
  const { user } = useAuth();
  if (!user || !roles.includes(user.role)) {
    return <Navigate to="/" replace />;
  }
  return children;
}

// ── Page loading fallback ─────────────────────────────────────────────────────
function PageLoader() {
  return (
    <div className="flex items-center justify-center h-64">
      <div className="w-8 h-8 border-4 border-gov-200 border-t-gov-600 rounded-full animate-spin" />
    </div>
  );
}

// ── App ───────────────────────────────────────────────────────────────────────
export default function App() {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <BrowserRouter>
          <Suspense fallback={<PageLoader />}>
            <Routes>
              {/* Public */}
              <Route
                path="/login"
                element={
                  <PublicRoute>
                    <LoginPage />
                  </PublicRoute>
                }
              />
              <Route path="/reset-password" element={<ResetPasswordPage />} />
              <Route
                path="/establishment/setup-password"
                element={<EstablishmentSetupPasswordPage />}
              />
              <Route
                path="/establishment/accept-invitation"
                element={<EstablishmentSetupPasswordPage />}
              />

              {/* Protected shell */}
              <Route
                path="/"
                element={
                  <ProtectedRoute>
                    <AppShell />
                  </ProtectedRoute>
                }
              >
                {/* Dashboard — all roles */}
                <Route index element={<DashboardPage />} />

                {/* ── OSCA + PDAO routes (senior_citizen / pwd beneficiaries) ── */}
                <Route
                  path="beneficiaries"
                  element={
                    <RoleRoute roles={["osca_admin", "osca_super_admin", "pdao_admin", "pdao_super_admin"]}>
                      <BeneficiariesPage />
                    </RoleRoute>
                  }
                />
                <Route
                  path="beneficiaries/add"
                  element={
                    <RoleRoute roles={["osca_admin", "osca_super_admin", "pdao_admin", "pdao_super_admin"]}>
                      <AddBeneficiaryPage />
                    </RoleRoute>
                  }
                />
                <Route
                  path="beneficiaries/:id"
                  element={
                    <RoleRoute roles={["osca_admin", "osca_super_admin", "pdao_admin", "pdao_super_admin"]}>
                      <BeneficiaryDetailPage />
                    </RoleRoute>
                  }
                />

                {/* ── BPLO-only routes ── */}
                <Route
                  path="establishments"
                  element={
                    <RoleRoute roles={["bplo_admin", "bplo_super_admin"]}>
                      <EstablishmentsPage />
                    </RoleRoute>
                  }
                />
                <Route
                  path="establishments/create"
                  element={
                    <RoleRoute roles={["bplo_admin", "bplo_super_admin"]}>
                      <CreateEstablishmentPage />
                    </RoleRoute>
                  }
                />
                <Route
                  path="establishments/:id"
                  element={
                    <RoleRoute roles={["bplo_admin", "bplo_super_admin"]}>
                      <EstablishmentDetailPage />
                    </RoleRoute>
                  }
                />
                <Route
                  path="business-refusals"
                  element={
                    <RoleRoute roles={["bplo_admin", "bplo_super_admin"]}>
                      <BusinessRefusalsPage />
                    </RoleRoute>
                  }
                />

                {/* ── Shared routes — OSCA + PDAO (fraud flags) ── */}
                <Route
                  path="fraud-flags"
                  element={
                    <RoleRoute roles={["osca_admin", "osca_super_admin", "pdao_admin", "pdao_super_admin"]}>
                      <FraudFlagsPage />
                    </RoleRoute>
                  }
                />

                {/* ── Shared routes — all roles ── */}
                <Route path="disputes" element={<DisputesPage />} />
                <Route
                  path="callback-requests"
                  element={
                    <RoleRoute roles={["bplo_admin", "bplo_super_admin"]}>
                      <CallbackRequestsPage />
                    </RoleRoute>
                  }
                />
                <Route path="audit-logs" element={<AuditLogsPage />} />
                <Route path="staff" element={<StaffPage />} />
              </Route>

              {/* Catch-all */}
              <Route path="*" element={<Navigate to="/" replace />} />
            </Routes>
          </Suspense>
        </BrowserRouter>
      </AuthProvider>
    </ErrorBoundary>
  );
}
