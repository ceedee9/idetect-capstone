import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider, useAuth } from "./context/AuthContext";
import { Component } from "react";
import LoginPage from "./pages/LoginPage";
import ResetPasswordPage from "./pages/ResetPasswordPage";
import DashboardPage from "./pages/DashboardPage";
import EstablishmentsPage from "./pages/EstablishmentsPage";
import EstablishmentDetailPage from "./pages/EstablishmentDetailPage";
import CreateEstablishmentPage from "./pages/CreateEstablishmentPage";
import AppShell from "./components/AppShell";
import BusinessRefusalsPage from "./pages/BusinessRefusalsPage";
import AuditLogsPage from "./pages/AuditLogsPage";
import StaffPage from "./pages/StaffPage";
import CallbackRequestsPage from "./pages/CallbackRequestsPage";

// Catches any render crash and shows a readable error instead of blank page
class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }
  static getDerivedStateFromError(error) {
    return { error };
  }
  render() {
    if (this.state.error) {
      return (
        <div style={{ padding: "40px", fontFamily: "monospace" }}>
          <h2 style={{ color: "#dc2626" }}>⚠ Render Error</h2>
          <pre
            style={{
              background: "#fef2f2",
              padding: "16px",
              borderRadius: "8px",
              fontSize: "13px",
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
              marginTop: "16px",
              padding: "8px 16px",
              background: "#1d4ed8",
              color: "white",
              border: "none",
              borderRadius: "6px",
              cursor: "pointer",
            }}
          >
            Back to Login
          </button>
        </div>
      );
    }
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
              path="/"
              element={
                <ProtectedRoute>
                  <AppShell />
                </ProtectedRoute>
              }
            >
              <Route index element={<DashboardPage />} />
              <Route path="establishments" element={<EstablishmentsPage />} />
              <Route
                path="establishments/create"
                element={<CreateEstablishmentPage />}
              />
              <Route
                path="establishments/:id"
                element={<EstablishmentDetailPage />}
              />
              <Route
                path="business-refusals"
                element={<BusinessRefusalsPage />}
              />
              <Route path="audit-logs" element={<AuditLogsPage />} />
              <Route path="callback-requests" element={<CallbackRequestsPage />} />
              <Route path="staff" element={<StaffPage />} />
            </Route>
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </ErrorBoundary>
  );
}
