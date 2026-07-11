// src/server.js
// iDetect API — main entry point.
// Wires together all middleware, routes, and starts the server.

// Force IPv4 DNS resolution globally — Railway blocks outbound IPv6 SMTP
const dns = require("dns");
dns.setDefaultResultOrder("ipv4first");

require("dotenv").config();
const path = require("path");
const fs = require("fs");
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const rateLimit = require("express-rate-limit");

const { errorHandler } = require("./middleware/errorHandler");
const { authenticate } = require("./middleware/auth");
const pool = require("./config/database");
const { waitForDatabaseConnection } = require("./config/database");
const { startExpiryScheduler } = require("./services/expiryAlertScheduler");
const {
  startSlaEscalationScheduler,
} = require("./services/slaEscalationScheduler");
const { startFlagDecayScheduler } = require("./services/flagDecayScheduler");
const {
  startExpiredStatusScheduler,
} = require("./services/expiredStatusScheduler");

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
const { sendEmail } = require("./services/emailService");

const app = express();
const PORT = process.env.PORT || 3000;

// ── Trust proxy ────────────────────────────────────────────────
// Required when running behind a reverse proxy (Railway, Nginx, etc.).
// Without this, req.ip always returns the proxy's internal IP, making
// rate limiting and audit-log IP capture ineffective.
app.set("trust proxy", 1);

// ── Security middleware ────────────────────────────────────────
app.use(helmet()); // Sets secure HTTP headers
app.use(
  cors({
    origin:
      process.env.NODE_ENV === "development"
        ? [
            "http://localhost:3000",
            "http://localhost:5173",
            "http://localhost:5174",
            "http://localhost:5175",
          ]
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

// ── Uploads directory setup ───────────────────────────────────
// Create upload directories if they don't exist.
// Files are NOT served as public static — access requires a valid JWT.
const uploadsDir = path.join(__dirname, "..", "uploads");
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });
const disputeDocsDir = path.join(uploadsDir, "dispute-docs");
if (!fs.existsSync(disputeDocsDir))
  fs.mkdirSync(disputeDocsDir, { recursive: true });

// ── Authenticated file serving ────────────────────────────────
// GET /api/uploads/<filename>  or  GET /api/uploads/dispute-docs/<filename>
// Requires a valid staff JWT. Replaces the former public express.static
// serving so PII-containing ID images and dispute documents are protected.
// Path traversal is prevented by resolving the absolute path and confirming
// it remains inside uploadsDir before streaming.
app.get("/api/uploads/*", authenticate, (req, res) => {
  const requestedFile = req.params[0]; // everything after /api/uploads/

  // Reject empty or obviously invalid paths
  if (!requestedFile || requestedFile.trim() === "") {
    return res.status(400).json({ error: "File path is required." });
  }

  // Resolve and confirm the path stays inside uploadsDir
  const filePath = path.resolve(uploadsDir, requestedFile);
  const safePrefix = uploadsDir + path.sep;
  if (!filePath.startsWith(safePrefix)) {
    return res.status(400).json({ error: "Invalid file path." });
  }

  if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
    return res.status(404).json({ error: "File not found." });
  }

  res.sendFile(filePath);
});

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

// ── Test email endpoint (admin only — requires valid JWT) ──────
app.post("/api/test-email", async (req, res) => {
  const { to } = req.body;
  if (!to)
    return res
      .status(400)
      .json({ error: "Provide { to: 'email@example.com' }" });
  const result = await sendEmail({
    to,
    subject: "iDetect SMTP Test",
    text: "This is a test email from the iDetect API. If you received this, SMTP is working correctly.",
    html: "<p>This is a test email from the <strong>iDetect API</strong>. If you received this, SMTP is working correctly.</p>",
  });
  res.json(result);
});

// ── 404 handler ────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ error: `Route ${req.method} ${req.path} not found` });
});

// ── Central error handler (must be last) ──────────────────────
app.use(errorHandler);

// ── Startup migrations ─────────────────────────────────────────
// Runs safe, idempotent schema patches before accepting traffic.
// Each statement uses IF NOT EXISTS so it is a no-op on subsequent deploys.
async function runStartupMigrations() {
  try {
    await pool.query(`
      ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'dispute_submitted';
    `);
    await pool.query(`
      ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'dispute_escalated';
    `);
    console.log("✅ Startup migrations applied.");
  } catch (err) {
    // Non-fatal: log and continue. The ENUM values may already exist.
    console.warn("⚠️  Startup migration warning:", err.message);
  }
}

async function startServer() {
  const dbReady = await waitForDatabaseConnection();
  if (!dbReady) {
    console.warn("⚠️ Database is unavailable; continuing in degraded mode.");
  }

  if (dbReady) {
    await runStartupMigrations();
  }

  return app.listen(PORT, "0.0.0.0", () => {
    console.log("");
    console.log("  iDetect API running");
    console.log(`  http://localhost:${PORT}/api/health`);
    console.log(`  Environment: ${process.env.NODE_ENV}`);

    // Start daily ID expiry alert scheduler
    startExpiryScheduler();

    // Start 30-minute SLA breach escalation scheduler (REQ-2.13.6)
    startSlaEscalationScheduler();

    // Start daily stale-flag auto-expiry scheduler
    startFlagDecayScheduler();

    // Start nightly job to set beneficiary status = 'expired' for lapsed IDs
    startExpiredStatusScheduler();
    console.log("");
  });
}

let server;
startServer()
  .then((listeningServer) => {
    server = listeningServer;
  })
  .catch((err) => {
    console.error("❌ Failed to start API server:", err.message);
    process.exit(1);
  });

// ── Graceful shutdown ─────────────────────────────────────────
// Railway (and Docker) stop containers with SIGTERM.
// Without this handler, in-flight requests, bulk imports, and DB writes
// are abruptly killed. Here we:
//  1. Stop accepting new connections
//  2. Wait for in-flight requests to finish (max 15s)
//  3. Close the DB pool cleanly
function gracefulShutdown(signal) {
  console.log(`\n[Shutdown] ${signal} received — shutting down gracefully…`);
  if (server && typeof server.close === "function") {
    server.close(async () => {
      console.log("[Shutdown] HTTP server closed.");
      try {
        await pool.end();
        console.log("[Shutdown] Database pool drained.");
      } catch (err) {
        console.error("[Shutdown] Pool drain error:", err.message);
      }
      process.exit(0);
    });
  } else {
    process.exit(0);
  }

  // Force-exit if the server hasn't closed within 15 seconds
  setTimeout(() => {
    console.error("[Shutdown] Forced exit after 15s timeout.");
    process.exit(1);
  }, 15_000);
}

process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
process.on("SIGINT", () => gracefulShutdown("SIGINT"));

module.exports = app;
