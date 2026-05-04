import { useEffect, useRef, useState, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

const IDLE_TIMEOUT_MS = 15 * 60 * 1000; // 15 minutes
const WARN_BEFORE_MS = 2 * 60 * 1000; // warn 2 minutes before expiry
const IDLE_EVENTS = [
  "mousedown",
  "mousemove",
  "keydown",
  "scroll",
  "touchstart",
  "click",
];

/**
 * REQ-2.17.7 – Enforces automatic session expiry after a defined period of
 * inactivity, requiring re-authentication before resuming access.
 *
 * Returns { showWarning, secondsLeft, stayLoggedIn }
 */
export function useSessionTimeout() {
  const { isAuthenticated, logout } = useAuth();
  const navigate = useNavigate();

  const [showWarning, setShowWarning] = useState(false);
  const [secondsLeft, setSecondsLeft] = useState(120);

  const idleTimerRef = useRef(null);
  const warnTimerRef = useRef(null);
  const countdownRef = useRef(null);

  const doLogout = useCallback(() => {
    clearInterval(countdownRef.current);
    logout();
    navigate("/login?reason=idle", { replace: true });
  }, [logout, navigate]);

  const resetTimers = useCallback(() => {
    if (!isAuthenticated) return;

    setShowWarning(false);
    clearTimeout(idleTimerRef.current);
    clearTimeout(warnTimerRef.current);
    clearInterval(countdownRef.current);

    // Hard logout after full idle timeout
    idleTimerRef.current = setTimeout(doLogout, IDLE_TIMEOUT_MS);

    // Show warning 2 minutes before logout
    warnTimerRef.current = setTimeout(() => {
      setShowWarning(true);
      setSecondsLeft(120);
      countdownRef.current = setInterval(() => {
        setSecondsLeft((s) => {
          if (s <= 1) {
            clearInterval(countdownRef.current);
            return 0;
          }
          return s - 1;
        });
      }, 1000);
    }, IDLE_TIMEOUT_MS - WARN_BEFORE_MS);
  }, [isAuthenticated, doLogout]);

  useEffect(() => {
    if (!isAuthenticated) {
      clearTimeout(idleTimerRef.current);
      clearTimeout(warnTimerRef.current);
      clearInterval(countdownRef.current);
      setShowWarning(false);
      return;
    }

    resetTimers();
    IDLE_EVENTS.forEach((e) =>
      window.addEventListener(e, resetTimers, { passive: true }),
    );

    return () => {
      IDLE_EVENTS.forEach((e) => window.removeEventListener(e, resetTimers));
      clearTimeout(idleTimerRef.current);
      clearTimeout(warnTimerRef.current);
      clearInterval(countdownRef.current);
    };
  }, [isAuthenticated, resetTimers]);

  return { showWarning, secondsLeft, stayLoggedIn: resetTimers };
}
