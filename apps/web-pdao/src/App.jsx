import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { Component } from "react";
import { AuthProvider, useAuth } from "./context/AuthContext";
import AppShell from "./components/AppShell";
import LoginPage from "./pages/LoginPage";
import ResetPasswordPage from "./pages/ResetPasswordPage";
import DashboardPage from "./pages/DashboardPage";
import BeneficiariesPage from "./pages/BeneficiariesPage";
import BeneficiaryDetailPage from "./pages/BeneficiaryDetailPage";
import AddBeneficiaryPage from "./pages/AddBeneficiaryPage";
import FraudFlagsPage from "./pages/FraudFlagsPage";
import DisputesPage from "./pages/DisputesPage";
import CallbackRequestsPage from "./pages/CallbackRequestsPage";
import AuditLogsPage from "./pages/AuditLogsPage";
import StaffPage from "./pages/StaffPage";

class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }
  static getDerivedStateFromError(e) {
    return { error: e };
  }
  render() {
    if (this.state.error)
      return (
        <div style={{ padding: 40, fontFamily: "monospace" }}>
          <h2 style={{ color: "#dc2626" }}>⚠ Render Error</h2>
          <pre
            style={{
              background: "#fef2f2",
              padding: 16,
              borderRadius: 8,
              fontSize: 13,
              whiteSpace: "pre-wrap",
            }}
          >
            {this.state.error.message}
            {"\n\n"}
            {this.state.error.stack}
          </pre>
          <button
            onClick={() => {
              this.setState({ error: null });
              window.location.href = "/login";
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
            Back to Login
          </button>
        </div>
      );
    return this.props.children;
  }
}

function ProtectedRoute({ children }) {
  const { isAuthenticated } = useAuth();
  return isAuthenticated ? children : <Navigate to="/login" replace />;
}
function PublicRoute({ children }) {
  const { isAuthenticated } = useAuth();
  return isAuthenticated ? <Navigate to="/" replace /> : children;
}

export default function App() {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            <Route path="/reset-password" element={<ResetPasswordPage />} />
            <Route
              path="/login"
              element={
                <PublicRoute>
                  <LoginPage />
                </PublicRoute>
              }
            />
            <Route
              path="/"
              element={
                <ProtectedRoute>
                  <AppShell />
                </ProtectedRoute>
              }
            >
              <Route index element={<DashboardPage />} />
              <Route path="beneficiaries" element={<BeneficiariesPage />} />
              <Route
                path="beneficiaries/add"
                element={<AddBeneficiaryPage />}
              />
              <Route
                path="beneficiaries/:id"
                element={<BeneficiaryDetailPage />}
              />
              <Route path="fraud-flags" element={<FraudFlagsPage />} />
              <Route path="disputes" element={<DisputesPage />} />
              <Route path="callback-requests" element={<CallbackRequestsPage />} />
              <Route path="audit-logs" element={<AuditLogsPage />} />
              <Route path="staff" element={<StaffPage />} />
            </Route>
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </ErrorBoundary>
  );
}
