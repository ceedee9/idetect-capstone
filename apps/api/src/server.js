require("dotenv").config();
const path = require("path");
const app = require("./app");
const pool = require("./config/database");
const { waitForDatabaseConnection } = require("./config/database");
const { startExpiryScheduler } = require("./services/expiryAlertScheduler");
const { execFile } = require("child_process");
const {
  startSlaEscalationScheduler,
} = require("./services/slaEscalationScheduler");
const { startFlagDecayScheduler } = require("./services/flagDecayScheduler");
const {
  startExpiredStatusScheduler,
} = require("./services/expiredStatusScheduler");
const PORT = process.env.PORT || 3000;
async function runStartupMigrations() {
  try {
    await pool.query(`
      ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'dispute_submitted';
    `);
    await pool.query(`
      ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'dispute_escalated';
    `);
    await pool.query(`
      ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'verification_manual';
    `);
    await pool.query(`
      ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'verification_action_taken';
    `);
    await pool.query(`
      ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'breach_incident_report_generated';
    `);
    await pool.query(`
      ALTER TYPE audit_action ADD VALUE IF NOT EXISTS 'sla_ack_escalation';
    `);
    console.log("✅ Startup migrations applied.");
  } catch (err) {
    console.warn("⚠️  Startup migration warning:", err.message);
  }
}

async function ensureSeedAdminAccounts() {
  const defaultPassword = process.env.DEFAULT_STAFF_PASSWORD || "Password123!";
  const passwordHash = require("bcryptjs").hashSync(defaultPassword, 12);
  try {
    const existing = await pool.query(
      `SELECT email FROM users WHERE email IN ($1, $2, $3)`,
      [
        "bplo.admin@valenzuela.gov.ph",
        "osca.admin@valenzuela.gov.ph",
        "pdao.admin@valenzuela.gov.ph",
      ],
    );
    const existingEmails = new Set(existing.rows.map((row) => row.email));
    const inserts = [
      {
        email: "bplo.admin@valenzuela.gov.ph",
        full_name: "Maria Santos",
        role: "bplo_admin",
      },
      {
        email: "osca.admin@valenzuela.gov.ph",
        full_name: "Jose Reyes",
        role: "osca_admin",
      },
      {
        email: "pdao.admin@valenzuela.gov.ph",
        full_name: "Ana Cruz",
        role: "pdao_admin",
      },
    ];
    for (const account of inserts) {
      if (!existingEmails.has(account.email)) {
        await pool.query(
          `INSERT INTO users (email, password_hash, full_name, role) VALUES ($1, $2, $3, $4)`,
          [account.email, passwordHash, account.full_name, account.role],
        );
        console.log(`✅ Seeded staff account: ${account.email}`);
      }
    }
  } catch (err) {
    console.warn("⚠️ Seed admin accounts skipped:", err.message);
  }
}

async function runMigrationsOnStartup() {
  return new Promise((resolve, reject) => {
    const scriptPath = path.resolve(__dirname, "..", "scripts", "migrate.js");
    console.log("🔄 Running database migrations on startup...");
    execFile(
      "node",
      [scriptPath],
      { env: process.env, cwd: path.resolve(__dirname, "..") },
      (err, stdout, stderr) => {
        if (stdout) console.log(stdout.trim());
        if (stderr) console.error(stderr.trim());
        if (err) {
          console.error("❌ Startup migrations failed:", err.message);
          reject(err);
          return;
        }
        console.log("✅ Startup migrations completed.");
        resolve();
      },
    );
  });
}

async function startServer() {
  const dbReady = await waitForDatabaseConnection();
  if (!dbReady) {
    throw new Error("Database is unavailable; refusing to start server.");
  }

  await runStartupMigrations();
  await runMigrationsOnStartup();
  await ensureSeedAdminAccounts();

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
  const closeServer = () => {
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
  };

  closeServer();

  // Force-exit if the server hasn't closed within 15 seconds
  setTimeout(() => {
    console.error("[Shutdown] Forced exit after 15s timeout.");
    process.exit(1);
  }, 15_000);
}

process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
process.on("SIGINT", () => gracefulShutdown("SIGINT"));

module.exports = app;
