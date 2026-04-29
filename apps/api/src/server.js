// src/server.js
// iDetect API — main entry point.
// Wires together all middleware, routes, and starts the server.

require("dotenv").config();
const path = require("path");
const fs = require("fs");
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const rateLimit = require("express-rate-limit");

const { errorHandler } = require("./middleware/errorHandler");
const pool = require("./config/database");
const { startExpiryScheduler } = require("./services/expiryAlertScheduler");
const {
  startSlaEscalationScheduler,
} = require("./services/slaEscalationScheduler");

// Route imports
const authRoutes = require("./routes/auth");
const verificationRoutes = require("./routes/verification");
const fraudFlagRoutes = require("./routes/fraudFlags");
const beneficiaryRoutes = require("./routes/beneficiaries");
const establishmentRoutes = require("./routes/establishments");
const notificationRoutes = require("./routes/notifications");
const disputeRoutes = require("./routes/disputes");
const beneficiaryPortalRoutes = require("./routes/beneficiaryPortal");
const dashboardRoutes = require("./routes/dashboard");
const auditLogRoutes = require("./routes/auditLogs");
const reportRoutes = require("./routes/reports");
const staffRoutes = require("./routes/staff");

const app = express();
const PORT = process.env.PORT || 3000;

// ── Security middleware ────────────────────────────────────────
app.use(helmet()); // Sets secure HTTP headers
app.use(
  cors({
    origin:
      process.env.NODE_ENV === "development"
        ? "*" // Allow all origins in dev
        : process.env.ALLOWED_ORIGINS?.split(","), // Restrict in production
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE"],
  }),
);

// ── Rate limiting ──────────────────────────────────────────────
// Prevents brute-force attacks
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Max 100 requests per window
  message: { error: "Too many requests. Please try again later." },
});
app.use("/api/", limiter);

// Stricter limit on login endpoints
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { error: "Too many login attempts. Please wait 15 minutes." },
});
app.use("/api/auth", loginLimiter);

// ── General middleware ─────────────────────────────────────────
app.use(express.json({ limit: "10mb" })); // 10mb to allow base64 images
app.use(express.urlencoded({ extended: true }));
app.use(morgan(process.env.NODE_ENV === "development" ? "dev" : "combined"));

// ── Static uploads ─────────────────────────────────────────────
// Serves captured ID images at GET /uploads/:filename
const uploadsDir = path.join(__dirname, "..", "uploads");
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });
const disputeDocsDir = path.join(uploadsDir, "dispute-docs");
if (!fs.existsSync(disputeDocsDir))
  fs.mkdirSync(disputeDocsDir, { recursive: true });
app.use("/uploads", express.static(uploadsDir));

// ── Health check ───────────────────────────────────────────────
// Hit this to confirm the API is running: GET /api/health
app.get("/api/health", async (req, res) => {
  let dbStatus = "ok";
  try {
    await pool.query("SELECT 1");
  } catch {
    dbStatus = "error";
  }
  const overall = dbStatus === "ok" ? "ok" : "degraded";
  res.status(overall === "ok" ? 200 : 503).json({
    status: overall,
    service: "iDetect API",
    version: "1.0.0",
    database: dbStatus,
    timestamp: new Date().toISOString(),
  });
});

// ── Routes ────────────────────────────────────────────────────
app.use("/api/auth", authRoutes);
app.use("/api/verification", verificationRoutes);
app.use("/api/fraud-flags", fraudFlagRoutes);
app.use("/api/beneficiaries", beneficiaryRoutes);
app.use("/api/establishments", establishmentRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/disputes", disputeRoutes);
app.use("/api/beneficiary-portal", beneficiaryPortalRoutes);
app.use("/api/dashboard", dashboardRoutes);
app.use("/api/audit-logs", auditLogRoutes);
app.use("/api/reports", reportRoutes);
app.use("/api/staff", staffRoutes);

// ── 404 handler ────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ error: `Route ${req.method} ${req.path} not found` });
});

// ── Central error handler (must be last) ──────────────────────
app.use(errorHandler);

// ── Start server ───────────────────────────────────────────────
app.listen(PORT, "0.0.0.0", () => {
  console.log("");
  console.log("  iDetect API running");
  console.log(`  http://localhost:${PORT}/api/health`);
  console.log(`  Environment: ${process.env.NODE_ENV}`);

  // Start daily ID expiry alert scheduler
  startExpiryScheduler();

  // Start 30-minute SLA breach escalation scheduler (REQ-2.13.6)
  startSlaEscalationScheduler();
  console.log("");
});

module.exports = app;
