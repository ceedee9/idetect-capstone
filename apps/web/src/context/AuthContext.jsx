import { createContext, useContext, useState, useCallback } from "react";
import { authAPI } from "../services/api";

const AuthContext = createContext(null);

const ALLOWED_ROLES = [
  "super_admin",
  "osca_admin",
  "pdao_admin",
  "bplo_admin",
];

export function AuthProvider({ children }) {
  const [user, setUser] = useState(() => {
    try {
      const stored = localStorage.getItem("staff_user");
      return stored ? JSON.parse(stored) : null;
    } catch {
      return null;
    }
  });
  const [token, setToken] = useState(() => localStorage.getItem("staff_token"));

  const login = useCallback(async (email, password) => {
    const res = await authAPI.login(email, password);
    const { token: newToken, user: newUser } = res.data;

    if (!ALLOWED_ROLES.includes(newUser.role)) {
      throw new Error(
        "Access denied. This portal is for authorized staff only.",
      );
    }

    localStorage.setItem("staff_token", newToken);
    localStorage.setItem("staff_user", JSON.stringify(newUser));
    setToken(newToken);
    setUser(newUser);
    return newUser;
  }, []);

  const logout = useCallback((reason = "manual") => {
    // Token is passed explicitly: the request interceptor runs after it is cleared below.
    const currentToken = localStorage.getItem("staff_token");
    if (currentToken) {
      authAPI.logout(reason, currentToken).catch(() => {});
    }
    localStorage.removeItem("staff_token");
    localStorage.removeItem("staff_user");
    setToken(null);
    setUser(null);
  }, []);

  return (
    <AuthContext.Provider
      value={{ user, token, login, logout, isAuthenticated: !!token }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
