// src/app.js
// Reusable Express app for local dev and Vercel serverless deployment.

const net = require("net");
const dnsSync = require("dns");
const dns = require("dns").promises;
dnsSync.setDefaultResultOrder("ipv4first");
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const rateLimit = require("express-rate-limit");

const { errorHandler, createError } = require("./middleware/errorHandler");
const { authenticate } = require("./middleware/auth");
const pool = require("./config/database");
const { sendEmail } = require("./services/emailService");
const {
  ID_IMAGES_BUCKET,
  DISPUTE_DOCS_BUCKET,
  downloadStorageObject,
} = require("./services/storageService");

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

// ── Trust proxy ────────────────────────────────────────────────
app.set("trust proxy", 1);

// ── Security middleware ────────────────────────────────────────
app.use(helmet());
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
        : process.env.ALLOWED_ORIGINS?.split(","),
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE"],
  }),
);

// ── Rate limiting ──────────────────────────────────────────────
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: { error: "Too many requests. Please try again later." },
});
app.use("/api/", limiter);

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: { error: "Too many login attempts. Please wait 15 minutes." },
});
app.use("/api/auth", loginLimiter);

// ── General middleware ─────────────────────────────────────────
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan(process.env.NODE_ENV === "development" ? "dev" : "combined"));

// ── Authenticated file serving ────────────────────────────────
// All uploaded files (ID captures, dispute docs) live in Supabase Storage —
// nothing is written to local disk. Vercel's serverless filesystem is
// read-only outside of /tmp, so this route only ever proxies from Supabase.
app.get("/api/uploads/*", authenticate, (req, res) => {
  const requestedFile = req.params[0];

  if (!requestedFile || requestedFile.trim() === "") {
    return res.status(400).json({ error: "File path is required." });
  }

  const decodedPath = decodeURIComponent(requestedFile);
  if (decodedPath.includes("..") || decodedPath.includes("\\")) {
    return res.status(400).json({ error: "Invalid file path." });
  }

  const [bucket, ...rest] = decodedPath.split("/").filter(Boolean);
  const objectPath = rest.join("/");
  const allowedBuckets = new Set([ID_IMAGES_BUCKET, DISPUTE_DOCS_BUCKET]);

  if (!bucket || !objectPath || !allowedBuckets.has(bucket)) {
    return res.status(400).json({ error: "Invalid file path." });
  }

  return downloadStorageObject(bucket, objectPath)
    .then((downloaded) => {
      if (!downloaded) {
        return res.status(404).json({ error: "File not found." });
      }
      res.setHeader("Content-Type", downloaded.contentType);
      res.setHeader("Cache-Control", "private, max-age=60");
      return res.send(downloaded.buffer);
    })
    .catch((err) => {
      console.error("❌ Upload proxy error:", err.message);
      return res.status(500).json({ error: "Failed to load file." });
    });
});

// ── Health check ───────────────────────────────────────────────
app.get("/api/health", async (req, res) => {
  console.log("[HEALTH] Request received");
  const result = { status: "checking", steps: {} };

  let host, port;
  try {
    console.log("[HEALTH] Parsing DATABASE_URL...");
    const url = new URL(process.env.DATABASE_URL);
    host = url.hostname;
    port = url.port || 5432;
    console.log(
      `[HEALTH] Parsed host=${host} port=${port}. Starting DNS lookup...`,
    );
    const addresses = await Promise.race([
      dns.lookup(host, { all: true }),
      new Promise((_, reject) =>
        setTimeout(
          () => reject(new Error("DNS lookup timed out after 3s")),
          3000,
        ),
      ),
    ]);
    console.log("[HEALTH] DNS ok:", JSON.stringify(addresses));
    result.steps.dns = { ok: true, host, port, addresses };
  } catch (err) {
    console.log("[HEALTH] DNS failed:", err.message);
    result.steps.dns = { ok: false, error: err.message };
    return res.status(500).json(result);
  }

  try {
    console.log("[HEALTH] Starting raw TCP connect...");
    await new Promise((resolve, reject) => {
      const socket = net.createConnection({ host, port: Number(port) });
      const timer = setTimeout(() => {
        socket.destroy();
        reject(new Error("Raw TCP connect timed out after 4s"));
      }, 4000);
      socket.on("connect", () => {
        clearTimeout(timer);
        socket.destroy();
        resolve();
      });
      socket.on("error", (err) => {
        clearTimeout(timer);
        reject(err);
      });
    });
    console.log("[HEALTH] TCP connect ok");
    result.steps.tcp = { ok: true };
  } catch (err) {
    console.log("[HEALTH] TCP failed:", err.message);
    result.steps.tcp = { ok: false, error: err.message };
    return res.status(500).json(result);
  }

  try {
    console.log("[HEALTH] Starting pg query...");
    await Promise.race([
      pool.query("SELECT 1"),
      new Promise((_, reject) =>
        setTimeout(
          () => reject(new Error("pg query timed out after 6s")),
          6000,
        ),
      ),
    ]);
    console.log("[HEALTH] pg query ok");
    result.steps.query = { ok: true };
    result.status = "ok";
  } catch (err) {
    console.log("[HEALTH] pg query failed:", err.message);
    result.steps.query = { ok: false, error: err.message };
    result.status = "degraded";
  }

  console.log("[HEALTH] Sending response:", JSON.stringify(result));
  res.status(result.status === "ok" ? 200 : 500).json(result);
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

// ── Central error handler ──────────────────────────────────────
app.use(errorHandler);

module.exports = app;
