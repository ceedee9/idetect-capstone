// src/routes/auth.js
// Login endpoints for all three user types:
//   POST /api/auth/staff/login        — Super Admin, BPLO, OSCA, PDAO admins
//   POST /api/auth/establishment/login — Client Portal (mobile)
//   POST /api/auth/beneficiary/request-otp  — Beneficiary app step 1
//   POST /api/auth/beneficiary/verify-otp   — Beneficiary app step 2

const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const { body, validationResult } = require("express-validator");
const pool = require("../config/database");
const { createError } = require("../middleware/errorHandler");
const { authenticateBeneficiary } = require("../middleware/auth");
const { sendOtp, sendSms } = require("../services/smsService");

const LOGIN_MAX_ATTEMPTS = 3;
const LOGIN_LOCKOUT_MS = 30 * 60 * 1000; // 30 minutes

const router = express.Router();
const STAFF_ABSOLUTE_SESSION_SECONDS = 8 * 60 * 60;

// Normalizes an id_number the same way beneficiaries.js does at storage
// time (uppercase, strip everything except A-Z0-9). Every beneficiary
// auth route below must run incoming id_number through this before
// querying, or a beneficiary ID entered with dashes/spaces (e.g. the
// PWD format 13-7504-000-000001) will never match the stored row.
const normalizeIdNumber = (value) =>
  String(value || "")
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "");

// ── Staff Login (BPLO / OSCA / PDAO) ──────────────────────────
router.post(
  "/staff/login",
  [body("email").isEmail().normalizeEmail(), body("password").notEmpty()],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const { email, password } = req.body;

      const result = await pool.query(
        "SELECT * FROM users WHERE email = $1 AND is_active = TRUE",
        [email],
      );

      const user = result.rows[0];
      // Use same error for unknown email to avoid enumeration
      if (!user) throw createError(401, "Invalid email or password");

      // Check lockout
      if (user.locked_until && new Date() < new Date(user.locked_until)) {
        const mins = Math.ceil(
          (new Date(user.locked_until) - new Date()) / 60000,
        );
        throw createError(
          423,
          `Account locked. Try again in ${mins} minute(s) or contact your administrator.`,
        );
      }

      const passwordMatch = await bcrypt.compare(password, user.password_hash);
      if (!passwordMatch) {
        const newAttempts = (user.failed_attempts || 0) + 1;
        await pool.query(
          `INSERT INTO audit_logs (user_id, action, metadata, ip_address)
           VALUES ($1, 'login_failed', $2, $3)`,
          [
            user.id,
            JSON.stringify({
              reason: "invalid_password",
              attempt_number: newAttempts,
            }),
            req.ip,
          ],
        );
        if (newAttempts >= LOGIN_MAX_ATTEMPTS) {
          const lockUntil = new Date(Date.now() + LOGIN_LOCKOUT_MS);
          await pool.query(
            "UPDATE users SET failed_attempts = $1, locked_until = $2 WHERE id = $3",
            [newAttempts, lockUntil, user.id],
          );
          await pool.query(
            `INSERT INTO audit_logs (user_id, action, metadata, ip_address)
             VALUES ($1, 'account_locked', $2, $3)`,
            [
              user.id,
              JSON.stringify({
                email: user.email,
                reason: "failed_login_attempts",
              }),
              req.ip,
            ],
          );
          // Notify via email (logged to console in dev — no email service yet)
          console.log(
            `🔒 [LOCKOUT] Staff account locked: ${user.email} — locked for 30 minutes`,
          );
          throw createError(
            423,
            "Account locked after too many failed attempts. Try again in 30 minutes or contact your administrator.",
          );
        }
        await pool.query(
          "UPDATE users SET failed_attempts = $1 WHERE id = $2",
          [newAttempts, user.id],
        );
        const remaining = LOGIN_MAX_ATTEMPTS - newAttempts;
        throw createError(
          401,
          `Invalid email or password. ${remaining} attempt(s) remaining.`,
        );
      }

      // Success — clear failed attempts and lockout
      await pool.query(
        "UPDATE users SET failed_attempts = 0, locked_until = NULL WHERE id = $1",
        [user.id],
      );

      // Log the login action
      await pool.query(
        `INSERT INTO audit_logs (user_id, action, metadata, ip_address)
       VALUES ($1, 'login', $2, $3)`,
        [user.id, JSON.stringify({ email: user.email }), req.ip],
      );

      const token = jwt.sign(
        {
          id: user.id,
          email: user.email,
          role: user.role,
          name: user.full_name,
          session_started_at: Math.floor(Date.now() / 1000),
        },
        process.env.JWT_SECRET_STAFF,
        { expiresIn: process.env.JWT_EXPIRES_IN },
      );

      res.json({
        token,
        user: {
          id: user.id,
          email: user.email,
          full_name: user.full_name,
          role: user.role,
        },
      });
    } catch (err) {
      next(err);
    }
  },
);

router.post("/staff/reauth", async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ") || !req.body?.password) {
      return res.status(401).json({ error: "Current password is required" });
    }

    const decoded = jwt.verify(
      authHeader.slice(7),
      process.env.JWT_SECRET_STAFF,
    );
    const result = await pool.query(
      "SELECT id, password_hash, is_active FROM users WHERE id = $1",
      [decoded.id],
    );
    const user = result.rows[0];
    if (!user?.is_active || !(await bcrypt.compare(req.body.password, user.password_hash))) {
      return res.status(401).json({ error: "Current password is incorrect" });
    }

    const stepUpToken = jwt.sign(
      { id: user.id, step_up: true },
      process.env.JWT_SECRET_STAFF,
      { expiresIn: "5m" },
    );
    res.json({ step_up_token: stepUpToken, expires_in: 300 });
  } catch (err) {
    if (err.name === "JsonWebTokenError" || err.name === "TokenExpiredError") {
      return res.status(401).json({ error: "Invalid or expired session" });
    }
    next(err);
  }
});

// ── Staff Token Refresh ─────────────────────────────────────────
// Accepts the current still-valid staff JWT and returns a fresh one.
// Called silently by portal interceptor before expiry to avoid logout.
router.post("/staff/refresh", async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      return res.status(401).json({ error: "No token provided" });
    }
    const token = authHeader.slice(7);

    let decoded;
    try {
      decoded = jwt.verify(token, process.env.JWT_SECRET_STAFF);
    } catch {
      return res.status(401).json({ error: "Invalid or expired token" });
    }

    const sessionStartedAt = decoded.session_started_at || decoded.iat;
    if (
      !sessionStartedAt ||
      Math.floor(Date.now() / 1000) - sessionStartedAt >=
        STAFF_ABSOLUTE_SESSION_SECONDS
    ) {
      return res.status(401).json({ error: "Session lifetime exceeded" });
    }

    // Confirm user still exists and is active
    const result = await pool.query(
      "SELECT id, email, role, full_name, is_active FROM users WHERE id = $1",
      [decoded.id],
    );
    if (!result.rows.length || !result.rows[0].is_active) {
      return res.status(401).json({ error: "Account not found or inactive" });
    }
    const user = result.rows[0];

    const newToken = jwt.sign(
      {
        id: user.id,
        email: user.email,
        role: user.role,
        name: user.full_name,
        session_started_at: sessionStartedAt,
      },
      process.env.JWT_SECRET_STAFF,
      { expiresIn: process.env.JWT_EXPIRES_IN },
    );

    res.json({ token: newToken });
  } catch (err) {
    next(err);
  }
});

// ── Staff Logout (audit only; JWTs are stateless) ──────────────
const LOGOUT_REASONS = ["manual", "idle_timeout"];
router.post("/staff/logout", async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      return res.status(401).json({ error: "No token provided" });
    }

    let decoded;
    try {
      decoded = jwt.verify(authHeader.slice(7), process.env.JWT_SECRET_STAFF);
    } catch {
      return res.status(401).json({ error: "Invalid or expired token" });
    }

    const reason = LOGOUT_REASONS.includes(req.body?.reason)
      ? req.body.reason
      : "manual";

    await pool.query(
      `INSERT INTO audit_logs (user_id, action, metadata, ip_address)
       VALUES ($1, 'logout', $2, $3)`,
      [decoded.id, JSON.stringify({ email: decoded.email, reason }), req.ip],
    );

    res.status(204).end();
  } catch (err) {
    next(err);
  }
});

// ── Establishment Login (Client Portal mobile app) ─────────────
router.post(
  "/establishment/login",
  [body("email").isEmail().normalizeEmail(), body("password").notEmpty()],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const { email, password } = req.body;

      const result = await pool.query(
        `SELECT
           e.*,
           eu.id AS establishment_user_id,
           eu.email AS user_email,
           eu.full_name AS user_full_name,
           eu.role AS user_role,
           eu.account_status AS user_account_status,
           eu.password_hash AS user_password_hash,
           eu.failed_attempts AS user_failed_attempts,
           eu.locked_until AS user_locked_until,
           eu.password_reset_required
         FROM establishments e
         LEFT JOIN establishment_users eu
           ON eu.establishment_id = e.id AND lower(eu.email) = lower($1)
         WHERE lower(e.email) = lower($1) OR eu.id IS NOT NULL
         ORDER BY CASE WHEN lower(e.email) = lower($1) THEN 0 ELSE 1 END,
                  CASE WHEN eu.id IS NOT NULL THEN 0 ELSE 1 END
         LIMIT 1`,
        [email],
      );

      const establishment = result.rows[0];
      if (!establishment) throw createError(401, "Invalid email or password");

      if (establishment.status !== "approved") {
        const messages = {
          pending: "Your account is awaiting BPLO approval",
          suspended: "Your account has been suspended. Contact BPLO.",
          revoked: "Your account has been revoked.",
        };
        throw createError(
          403,
          messages[establishment.status] || "Account not active",
        );
      }

      // Check lockout
      const userAccountStatus = establishment.user_account_status || "active";
      if (
        userAccountStatus !== "active" &&
        !(
          userAccountStatus === "locked" &&
          establishment.user_locked_until &&
          new Date() >= new Date(establishment.user_locked_until)
        )
      ) {
        throw createError(
          403,
          "Your establishment user account is not active.",
        );
      }

      if (
        (establishment.user_locked_until || establishment.locked_until) &&
        new Date() <
          new Date(establishment.user_locked_until || establishment.locked_until)
      ) {
        const mins = Math.ceil(
          (new Date(
            establishment.user_locked_until || establishment.locked_until,
          ) -
            new Date()) /
            60000,
        );
        throw createError(
          423,
          `Account locked. Try again in ${mins} minute(s) or contact BPLO.`,
        );
      }

      const passwordMatch = await bcrypt.compare(
        password,
        establishment.user_password_hash || establishment.password_hash,
      );
      if (!passwordMatch) {
          const newAttempts =
            (establishment.user_failed_attempts ??
              establishment.failed_attempts ??
              0) + 1;
        await pool.query(
          `INSERT INTO audit_logs (establishment_id, action, metadata, ip_address)
           VALUES ($1, 'login_failed', $2, $3)`,
          [
            establishment.id,
            JSON.stringify({
              reason: "invalid_password",
              attempt_number: newAttempts,
            }),
            req.ip,
          ],
        );
        if (newAttempts >= LOGIN_MAX_ATTEMPTS) {
          const lockUntil = new Date(Date.now() + LOGIN_LOCKOUT_MS);
          if (establishment.establishment_user_id) {
            await pool.query(
              "UPDATE establishment_users SET failed_attempts = $1, locked_until = $2, account_status = 'locked' WHERE id = $3",
              [newAttempts, lockUntil, establishment.establishment_user_id],
            );
          }
          await pool.query(
            "UPDATE establishments SET failed_attempts = $1, locked_until = $2 WHERE id = $3",
            [newAttempts, lockUntil, establishment.id],
          );
          await pool.query(
            `INSERT INTO audit_logs (establishment_id, action, metadata, ip_address)
             VALUES ($1, 'account_locked', $2, $3)`,
            [
              establishment.id,
              JSON.stringify({
                email: establishment.user_email || establishment.email,
                reason: "failed_login_attempts",
              }),
              req.ip,
            ],
          );
          // Notify owner via SMS
          if (establishment.contact_number) {
            await sendSms(
              establishment.contact_number,
              `iDetect: Your account (${establishment.business_name}) has been locked after ${LOGIN_MAX_ATTEMPTS} failed login attempts. It will auto-unlock in 30 minutes. Contact BPLO if this was not you.`,
            );
          }
          throw createError(
            423,
            "Account locked after too many failed attempts. Try again in 30 minutes or contact BPLO.",
          );
        }
        if (establishment.establishment_user_id) {
          await pool.query(
            "UPDATE establishment_users SET failed_attempts = $1 WHERE id = $2",
            [newAttempts, establishment.establishment_user_id],
          );
        }
        await pool.query(
          "UPDATE establishments SET failed_attempts = $1 WHERE id = $2",
          [newAttempts, establishment.id],
        );
        const remaining = LOGIN_MAX_ATTEMPTS - newAttempts;
        throw createError(
          401,
          `Invalid email or password. ${remaining} attempt(s) remaining.`,
        );
      }

      // Success — clear failed attempts and lockout
      if (establishment.establishment_user_id) {
        await pool.query(
          "UPDATE establishment_users SET failed_attempts = 0, locked_until = NULL, account_status = 'active', last_login_at = NOW() WHERE id = $1",
          [establishment.establishment_user_id],
        );
      }
      await pool.query(
        "UPDATE establishments SET failed_attempts = 0, locked_until = NULL WHERE id = $1",
        [establishment.id],
      );

      await pool.query(
        `INSERT INTO audit_logs (establishment_id, action, metadata, ip_address)
       VALUES ($1, 'login', $2, $3)`,
        [
          establishment.id,
          JSON.stringify({
            email: establishment.user_email || establishment.email,
            establishment_user_id: establishment.establishment_user_id || null,
          }),
          req.ip,
        ],
      );

      const token = jwt.sign(
        {
          id: establishment.id,
          establishment_user_id:
            establishment.establishment_user_id || null,
          name: establishment.business_name,
          type: "establishment",
          role: establishment.user_role || "establishment_super_user",
        },
        process.env.JWT_SECRET_ESTABLISHMENT,
        { expiresIn: process.env.JWT_EXPIRES_IN },
      );

      res.json({
        token,
        establishment: {
          id: establishment.id,
          business_name: establishment.business_name,
          email: establishment.email,
          owner_name: establishment.owner_name,
          address: establishment.address,
          status: establishment.status,
          user_id: establishment.establishment_user_id,
          user_role:
            establishment.user_role || "establishment_super_user",
        },
        user: {
          id: establishment.establishment_user_id || establishment.id,
          name: establishment.business_name,
          full_name: establishment.user_full_name || establishment.owner_name,
          email: establishment.user_email || establishment.email,
          role:
            establishment.user_role || "establishment_super_user",
        },
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── Establishment Logout (audit only; JWTs are stateless) ──────
const ESTABLISHMENT_LOGOUT_REASONS = [
  "manual",
  "idle_timeout",
];
// ── Establishment Re-authentication ───────────────────────────
// Confirms the signed-in establishment user's password and returns a
// short-lived step-up token for sensitive actions (such as export).
// Uses the same password rule as sign-in. Shares the /api/auth limiter.
router.post("/establishment/reauth", async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ") || !req.body?.password) {
      return res.status(401).json({ error: "Current password is required" });
    }

    const decoded = jwt.verify(
      authHeader.slice(7),
      process.env.JWT_SECRET_ESTABLISHMENT,
    );
    const result = await pool.query(
      `SELECT
         e.id,
         e.status,
         e.password_hash,
         eu.id AS establishment_user_id,
         eu.password_hash AS user_password_hash,
         eu.account_status AS user_account_status
       FROM establishments e
       LEFT JOIN establishment_users eu
         ON eu.establishment_id = e.id AND eu.id = $2
       WHERE e.id = $1`,
      [decoded.id, decoded.establishment_user_id || null],
    );
    const account = result.rows[0];
    if (!account || account.status !== "approved") {
      return res.status(403).json({ error: "Establishment account is not active" });
    }
    if (
      account.establishment_user_id &&
      account.user_account_status !== "active"
    ) {
      return res.status(403).json({ error: "Establishment user account is not active" });
    }

    const passwordMatch = await bcrypt.compare(
      req.body.password,
      account.user_password_hash || account.password_hash,
    );
    if (!passwordMatch) {
      return res.status(401).json({ error: "Current password is incorrect" });
    }

    const stepUpToken = jwt.sign(
      {
        id: account.id,
        establishment_user_id: account.establishment_user_id || null,
        step_up: true,
      },
      process.env.JWT_SECRET_ESTABLISHMENT,
      { expiresIn: "5m" },
    );
    res.json({ step_up_token: stepUpToken, expires_in: 300 });
  } catch (err) {
    if (err.name === "JsonWebTokenError" || err.name === "TokenExpiredError") {
      return res.status(401).json({ error: "Invalid or expired session" });
    }
    next(err);
  }
});

router.post("/establishment/logout", async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      return res.status(401).json({ error: "No token provided" });
    }

    let decoded;
    try {
      decoded = jwt.verify(
        authHeader.slice(7),
        process.env.JWT_SECRET_ESTABLISHMENT,
      );
    } catch {
      return res.status(401).json({ error: "Invalid or expired token" });
    }

    const reason = ESTABLISHMENT_LOGOUT_REASONS.includes(req.body?.reason)
      ? req.body.reason
      : "manual";

    await pool.query(
      `INSERT INTO audit_logs (establishment_id, action, metadata, ip_address)
       VALUES ($1, 'logout', $2, $3)`,
      [
        decoded.id,
        JSON.stringify({ reason }),
        req.ip,
      ],
    );

    res.status(204).end();
  } catch (err) {
    next(err);
  }
});

// ── Beneficiary OTP Request (step 1 of 2) ─────────────────────
// Beneficiary enters their ID number + birthdate.
// System verifies they exist in the DB, then sends OTP to their mobile.
router.post(
  "/beneficiary/request-otp",
  [body("id_number").notEmpty().trim(), body("birthdate").isDate()],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const id_number = normalizeIdNumber(req.body.id_number);
      const { birthdate } = req.body;

      // Find matching beneficiary
      const bResult = await pool.query(
        `SELECT b.*, ba.id AS account_id, ba.otp_attempts
       FROM beneficiaries b
       LEFT JOIN beneficiary_accounts ba ON ba.beneficiary_id = b.id
       WHERE b.id_number = $1 AND b.birthdate = $2`,
        [id_number, birthdate],
      );

      const beneficiary = bResult.rows[0];
      // If ID doesn't exist, return generic message (don't reveal)
      if (!beneficiary) {
        return res.json({
          message: "If your details match our records, an OTP has been sent.",
        });
      }

      if (beneficiary.status === "suspended") {
        await pool.query(
          `INSERT INTO audit_logs
            (action, target_table, target_id, metadata, ip_address)
           VALUES ('login_failed', 'beneficiaries', $1, $2, $3)`,
          [
            beneficiary.id,
            JSON.stringify({
              reason: "suspended_beneficiary_authentication",
              method: "otp",
            }),
            req.ip,
          ],
        );
        const endDate = beneficiary.suspension_end_date
          ? new Date(beneficiary.suspension_end_date)
          : null;
        const today = new Date();
        const todayDate = new Date(
          today.getFullYear(),
          today.getMonth(),
          today.getDate(),
        );
        const daysRemaining = endDate
          ? Math.ceil((endDate - todayDate) / 86400000)
          : null;
        return res.status(423).json({
          error: "Your beneficiary record is currently suspended.",
          suspension_status: daysRemaining != null && daysRemaining > 0
            ? "suspended"
            : "suspension_expired_review_required",
          suspension_end_date: beneficiary.suspension_end_date,
          suspension_days_remaining: daysRemaining,
          status_reason: beneficiary.status_reason,
        });
      }

      // If no mobile number registered, tell the app so it can prompt registration
      if (!beneficiary.registered_mobile) {
        return res.json({
          message: "No mobile number registered for this ID.",
          mobile_required: true,
          beneficiary_name: beneficiary.full_name,
        });
      }

      // Generate a 6-digit OTP
      const otp = Math.floor(100000 + Math.random() * 900000).toString();
      const otpHash = await bcrypt.hash(otp, 10);
      const otpExpires = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

      // Create or update beneficiary_account
      if (beneficiary.account_id) {
        await pool.query(
          `UPDATE beneficiary_accounts
         SET otp_hash = $1, otp_expires_at = $2, otp_attempts = 0
         WHERE id = $3`,
          [otpHash, otpExpires, beneficiary.account_id],
        );
      } else {
        await pool.query(
          `INSERT INTO beneficiary_accounts (beneficiary_id, otp_hash, otp_expires_at)
         VALUES ($1, $2, $3)`,
          [beneficiary.id, otpHash, otpExpires],
        );
      }

      // Send OTP via SMS (Semaphore)
      await sendOtp(beneficiary.registered_mobile, otp);
      if (process.env.NODE_ENV === "development") {
        console.log(`🔐 OTP for ${id_number}: ${otp}`);
      }

      res.json({
        message: "If your details match our records, an OTP has been sent.",
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── Beneficiary OTP Verify (step 2 of 2) ──────────────────────
router.post(
  "/beneficiary/verify-otp",
  [
    body("id_number").notEmpty().trim(),
    body("otp").isLength({ min: 6, max: 6 }),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const id_number = normalizeIdNumber(req.body.id_number);
      const { otp } = req.body;

      const result = await pool.query(
        `SELECT b.id AS beneficiary_id, b.full_name, b.beneficiary_type,
              ba.id AS account_id, ba.otp_hash, ba.otp_expires_at, ba.otp_attempts
       FROM beneficiaries b
       JOIN beneficiary_accounts ba ON ba.beneficiary_id = b.id
       WHERE b.id_number = $1`,
        [id_number],
      );

      const record = result.rows[0];
      if (!record) throw createError(401, "Invalid credentials");

      // Check expiry
      if (new Date() > new Date(record.otp_expires_at)) {
        throw createError(401, "OTP has expired. Please request a new one.");
      }

      // Check attempts (max 5)
      if (record.otp_attempts >= 5) {
        await pool.query(
          `INSERT INTO audit_logs
            (action, target_table, target_id, metadata, ip_address)
           VALUES ('account_locked', 'beneficiaries', $1, $2, $3)`,
          [
            record.beneficiary_id,
            JSON.stringify({ reason: "otp_attempt_limit", method: "otp" }),
            req.ip,
          ],
        );
        throw createError(429, "Too many attempts. Please request a new OTP.");
      }

      const otpMatch = await bcrypt.compare(otp, record.otp_hash);
      if (!otpMatch) {
        await pool.query(
          "UPDATE beneficiary_accounts SET otp_attempts = otp_attempts + 1 WHERE id = $1",
          [record.account_id],
        );
        if (record.otp_attempts + 1 >= 5) {
          await pool.query(
            `INSERT INTO audit_logs
              (action, target_table, target_id, metadata, ip_address)
             VALUES ('account_locked', 'beneficiaries', $1, $2, $3)`,
            [
              record.beneficiary_id,
              JSON.stringify({
                reason: "otp_attempt_limit",
                method: "otp",
              }),
              req.ip,
            ],
          );
        }
        throw createError(401, "Invalid OTP");
      }

      // Clear OTP after successful use, and mark the account active —
      // this is the first-ever successful login, and login-pin's query
      // requires is_active = TRUE to find the row at all. Bumping
      // session_version signs out any other phone holding this account.
      const session = await pool.query(
        `UPDATE beneficiary_accounts
   SET otp_hash = NULL, otp_expires_at = NULL, otp_attempts = 0,
       last_login = NOW(), is_active = TRUE,
       session_version = session_version + 1, device_token = NULL
   WHERE id = $1
   RETURNING session_version`,
        [record.account_id],
      );

      const token = jwt.sign(
        {
          id: record.account_id,
          beneficiary_id: record.beneficiary_id,
          type: "beneficiary",
          sv: session.rows[0].session_version,
        },
        process.env.JWT_SECRET_BENEFICIARY,
        { expiresIn: process.env.JWT_EXPIRES_IN },
      );

      res.json({
        token,
        beneficiary: {
          full_name: record.full_name,
          beneficiary_type: record.beneficiary_type,
        },
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── Beneficiary Register Mobile Number ─────────────────────────
// First-time setup: beneficiary provides their mobile number.
// System saves it and sends a confirmation OTP to proceed with login.
router.post(
  "/beneficiary/register-mobile",
  [
    body("id_number").notEmpty().trim(),
    body("birthdate").isDate(),
    body("mobile_number")
      .notEmpty()
      .trim()
      .matches(/^(\+?63|0)9\d{9}$/),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const id_number = normalizeIdNumber(req.body.id_number);
      const { birthdate, mobile_number } = req.body;

      // Verify identity first
      const bResult = await pool.query(
        `SELECT b.*, ba.id AS account_id
       FROM beneficiaries b
       LEFT JOIN beneficiary_accounts ba ON ba.beneficiary_id = b.id
       WHERE b.id_number = $1 AND b.birthdate = $2`,
        [id_number, birthdate],
      );

      const beneficiary = bResult.rows[0];
      if (!beneficiary) {
        return res
          .status(404)
          .json({ error: "ID number and birthdate do not match our records." });
      }

      if (beneficiary.registered_mobile) {
        return res.status(400).json({
          error: "A mobile number is already registered for this ID.",
        });
      }

      // Normalize mobile: convert +63 or 0 prefix to 09 format
      let normalized = mobile_number.replace(/^\+63/, "0");
      if (!normalized.startsWith("0")) normalized = "0" + normalized;

      // Save the mobile number
      await pool.query(
        "UPDATE beneficiaries SET registered_mobile = $1 WHERE id = $2",
        [normalized, beneficiary.id],
      );

      // Generate OTP and send it
      const otp = Math.floor(100000 + Math.random() * 900000).toString();
      const otpHash = await bcrypt.hash(otp, 10);
      const otpExpires = new Date(Date.now() + 10 * 60 * 1000);

      if (beneficiary.account_id) {
        await pool.query(
          `UPDATE beneficiary_accounts
         SET otp_hash = $1, otp_expires_at = $2, otp_attempts = 0
         WHERE id = $3`,
          [otpHash, otpExpires, beneficiary.account_id],
        );
      } else {
        await pool.query(
          `INSERT INTO beneficiary_accounts (beneficiary_id, otp_hash, otp_expires_at)
         VALUES ($1, $2, $3)`,
          [beneficiary.id, otpHash, otpExpires],
        );
      }

      // Send OTP via SMS (Semaphore)
      await sendOtp(normalized, otp);
      if (process.env.NODE_ENV === "development") {
        console.log(
          `🔐 OTP for ${id_number} (new mobile ${normalized}): ${otp}`,
        );
      }

      res.json({
        message: "Mobile number registered! An OTP has been sent.",
        mobile_registered: true,
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── Beneficiary Set PIN (after first OTP login) ────────────────
// Authenticated beneficiary sets a 4-digit PIN for future logins.
router.post(
  "/beneficiary/set-pin",
  authenticateBeneficiary,
  [body("pin").isLength({ min: 4, max: 4 }).isNumeric()],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: "PIN must be exactly 4 digits." });
      }

      const { pin } = req.body;
      const pinHash = await bcrypt.hash(pin, 10);

      await pool.query(
        "UPDATE beneficiary_accounts SET pin_hash = $1, pin_attempts = 0, pin_locked_until = NULL WHERE id = $2",
        [pinHash, req.beneficiary.id],
      );

      res.json({ message: "PIN set successfully.", pin_set: true });
    } catch (err) {
      next(err);
    }
  },
);

// ── Beneficiary Login with PIN ─────────────────────────────────
// Returning beneficiary can sign in with ID number + 4-digit PIN
// instead of OTP, for cases where SMS/biometric isn't available.
router.post(
  "/beneficiary/login-pin",
  [
    body("id_number").notEmpty().trim(),
    body("pin").isLength({ min: 4, max: 4 }).isNumeric(),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const id_number = normalizeIdNumber(req.body.id_number);
      const { pin } = req.body;

      const result = await pool.query(
        `SELECT b.id AS beneficiary_id, b.full_name, b.beneficiary_type,
                b.status, b.status_reason, b.suspension_end_date,
                ba.id AS account_id, ba.pin_hash, ba.pin_attempts, ba.pin_locked_until
         FROM beneficiaries b
         JOIN beneficiary_accounts ba ON ba.beneficiary_id = b.id
         WHERE b.id_number = $1 AND ba.is_active = TRUE`,
        [id_number],
      );

      const record = result.rows[0];

      // Don't reveal whether the ID exists
      if (!record || !record.pin_hash) {
        throw createError(401, "Invalid credentials");
      }

      if (record.status === "suspended") {
        await pool.query(
          `INSERT INTO audit_logs
            (action, target_table, target_id, metadata, ip_address)
           VALUES ('login_failed', 'beneficiaries', $1, $2, $3)`,
          [
            record.beneficiary_id,
            JSON.stringify({
              reason: "suspended_beneficiary_authentication",
              method: "pin",
            }),
            req.ip,
          ],
        );
        const endDate = record.suspension_end_date
          ? new Date(record.suspension_end_date)
          : null;
        const today = new Date();
        const todayDate = new Date(
          today.getFullYear(),
          today.getMonth(),
          today.getDate(),
        );
        const daysRemaining = endDate
          ? Math.ceil((endDate - todayDate) / 86400000)
          : null;
        throw createError(
          423,
          daysRemaining != null && daysRemaining > 0
            ? `Your beneficiary record is suspended. ${daysRemaining} day(s) remaining.`
            : "Your suspension period has ended and is awaiting office review.",
        );
      }

      // Check lock
      if (
        record.pin_locked_until &&
        new Date() < new Date(record.pin_locked_until)
      ) {
        const mins = Math.ceil(
          (new Date(record.pin_locked_until) - new Date()) / 60000,
        );
        throw createError(
          429,
          `Too many attempts. Try again in ${mins} minute(s).`,
        );
      }

      // Check attempts (max 3, then lock for 30 minutes + SMS notify)
      if (record.pin_attempts >= LOGIN_MAX_ATTEMPTS) {
        const lockUntil = new Date(Date.now() + LOGIN_LOCKOUT_MS);
        await pool.query(
          "UPDATE beneficiary_accounts SET pin_locked_until = $1, pin_attempts = 0 WHERE id = $2",
          [lockUntil, record.account_id],
        );
        await pool.query(
          `INSERT INTO audit_logs
            (action, target_table, target_id, metadata, ip_address)
           VALUES ('account_locked', 'beneficiaries', $1, $2, $3)`,
          [
            record.beneficiary_id,
            JSON.stringify({ reason: "pin_attempt_limit", method: "pin" }),
            req.ip,
          ],
        );
        // Fetch mobile number to notify
        const benef = await pool.query(
          "SELECT registered_mobile FROM beneficiaries WHERE id = $1",
          [record.beneficiary_id],
        );
        if (benef.rows[0]?.registered_mobile) {
          await sendSms(
            benef.rows[0].registered_mobile,
            `iDetect: Your PIN login has been locked after ${LOGIN_MAX_ATTEMPTS} failed attempts. It will auto-unlock in 30 minutes. If this was not you, contact your local office.`,
          );
        }
        throw createError(423, "Too many attempts. PIN locked for 30 minutes.");
      }

      const pinMatch = await bcrypt.compare(pin, record.pin_hash);
      if (!pinMatch) {
        const newAttempts = record.pin_attempts + 1;
        if (newAttempts >= LOGIN_MAX_ATTEMPTS) {
          const lockUntil = new Date(Date.now() + LOGIN_LOCKOUT_MS);
          await pool.query(
            "UPDATE beneficiary_accounts SET pin_locked_until = $1, pin_attempts = $2 WHERE id = $3",
            [lockUntil, newAttempts, record.account_id],
          );
          await pool.query(
            `INSERT INTO audit_logs
              (action, target_table, target_id, metadata, ip_address)
             VALUES ('account_locked', 'beneficiaries', $1, $2, $3)`,
            [
              record.beneficiary_id,
              JSON.stringify({ reason: "pin_attempt_limit", method: "pin" }),
              req.ip,
            ],
          );
          const benef = await pool.query(
            "SELECT registered_mobile FROM beneficiaries WHERE id = $1",
            [record.beneficiary_id],
          );
          if (benef.rows[0]?.registered_mobile) {
            await sendSms(
              benef.rows[0].registered_mobile,
              `iDetect: Your PIN login has been locked after ${LOGIN_MAX_ATTEMPTS} failed attempts. It will auto-unlock in 30 minutes. If this was not you, contact your local office.`,
            );
          }
          throw createError(
            423,
            "Account locked after too many failed attempts. Try again in 30 minutes.",
          );
        }
        await pool.query(
          "UPDATE beneficiary_accounts SET pin_attempts = pin_attempts + 1 WHERE id = $1",
          [record.account_id],
        );
        const remaining = LOGIN_MAX_ATTEMPTS - newAttempts;
        throw createError(
          401,
          `Invalid PIN. ${remaining > 0 ? remaining : 0} attempt(s) remaining.`,
        );
      }

      // Success — clear attempts, update last_login, and sign out any
      // other phone holding this account (see session_version).
      const session = await pool.query(
        `UPDATE beneficiary_accounts
   SET pin_attempts = 0, pin_locked_until = NULL, last_login = NOW(),
       session_version = session_version + 1, device_token = NULL
   WHERE id = $1
   RETURNING session_version`,
        [record.account_id],
      );

      const jwtToken = jwt.sign(
        {
          id: record.account_id,
          beneficiary_id: record.beneficiary_id,
          type: "beneficiary",
          sv: session.rows[0].session_version,
        },
        process.env.JWT_SECRET_BENEFICIARY,
        { expiresIn: process.env.JWT_EXPIRES_IN },
      );

      res.json({
        token: jwtToken,
        beneficiary: {
          full_name: record.full_name,
          beneficiary_type: record.beneficiary_type,
        },
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── Staff: Forgot Password (Self-service via email link) ──────
// Accepts email, generates a secure reset token, and emails a
// reset link back.  Always returns 200 to prevent enumeration.
router.post(
  "/staff/forgot-password",
  [body("email").isEmail().normalizeEmail()],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty())
        return res.status(400).json({ errors: errors.array() });

      const { email, origin } = req.body;

      const result = await pool.query(
        "SELECT id, full_name FROM users WHERE email = $1 AND is_active = TRUE",
        [email],
      );

      // Always reply the same message (don't reveal whether email exists)
      if (!result.rows.length) {
        return res.json({
          message:
            "If an account with that email exists, a reset link has been sent.",
        });
      }

      const user = result.rows[0];
      const crypto = require("crypto");
      const token = crypto.randomBytes(32).toString("hex");
      const tokenHash = crypto.createHash("sha256").update(token).digest("hex");
      const expires = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

      await pool.query(
        "UPDATE users SET reset_token = $1, reset_token_expires = $2 WHERE id = $3",
        [tokenHash, expires, user.id],
      );

      // Build reset URL from the requesting portal's origin (whitelist-validated)
      const allowedOrigins = (process.env.ALLOWED_PORTAL_ORIGINS || "")
        .split(",")
        .map((o) => o.trim())
        .filter(Boolean);

      let safeOrigin =
        origin && allowedOrigins.length && allowedOrigins.includes(origin)
          ? origin
          : allowedOrigins[0] || "https://idetect-bplo.up.railway.app";

      const resetUrl = `${safeOrigin}/reset-password?token=${token}&email=${encodeURIComponent(email)}`;

      const { sendEmail } = require("../services/emailService");
      await sendEmail({
        to: email,
        subject: "iDetect — Password Reset Request",
        text: `Hello ${user.full_name},\n\nA password reset was requested for your iDetect staff account.\n\nClick the link below to set a new password (expires in 1 hour):\n${resetUrl}\n\nIf you did not request this, ignore this email — your password has not changed.\n\n— iDetect System`,
        html: `<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;border:1px solid #e5e7eb;border-radius:8px;overflow:hidden;"><div style="background:#1e40af;padding:20px 24px;"><h2 style="color:#fff;margin:0;font-size:18px;">iDetect Staff Portal</h2><p style="color:#bfdbfe;margin:4px 0 0;font-size:13px;">Password Reset</p></div><div style="padding:24px;"><p style="margin-top:0;">Hello <strong>${user.full_name}</strong>,</p><p>A password reset was requested for your iDetect staff account. Click the button below to set a new password.</p><p style="text-align:center;margin:24px 0;"><a href="${resetUrl}" style="background:#1d4ed8;color:#fff;padding:12px 24px;border-radius:6px;text-decoration:none;font-weight:600;font-size:14px;">Reset My Password</a></p><p style="font-size:12px;color:#6b7280;">This link expires in <strong>1 hour</strong>. If you did not request a password reset, you can safely ignore this email.</p><hr style="border:none;border-top:1px solid #e5e7eb;margin:16px 0;"><p style="font-size:11px;color:#9ca3af;margin:0;">iDetect · Valenzuela City LGU</p></div></div>`,
      });

      res.json({
        message:
          "If an account with that email exists, a reset link has been sent.",
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── Staff: Reset Password via email token ──────────────────────
// Verifies the token from the reset link and sets the new password.
// Also clears any account lockout.
router.post(
  "/staff/reset-password",
  [
    body("email").isEmail().normalizeEmail(),
    body("token").notEmpty().trim(),
    body("new_password")
      .isLength({ min: 8 })
      .withMessage("Password must be at least 8 characters"),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty())
        return res.status(400).json({ errors: errors.array() });

      const { email, token, new_password } = req.body;
      const crypto = require("crypto");
      const tokenHash = crypto.createHash("sha256").update(token).digest("hex");

      const result = await pool.query(
        `SELECT id FROM users
         WHERE email = $1
           AND reset_token = $2
           AND reset_token_expires > NOW()
           AND is_active = TRUE`,
        [email, tokenHash],
      );

      if (!result.rows.length) {
        return res.status(400).json({
          message: "Invalid or expired reset link. Please request a new one.",
        });
      }

      const user = result.rows[0];
      const password_hash = await bcrypt.hash(new_password, 12);

      await pool.query(
        `UPDATE users
         SET password_hash       = $1,
             reset_token         = NULL,
             reset_token_expires = NULL,
             failed_attempts     = 0,
             locked_until        = NULL
         WHERE id = $2`,
        [password_hash, user.id],
      );

      await pool.query(
        `INSERT INTO audit_logs (user_id, action, metadata)
         VALUES ($1, 'password_reset', $2)`,
        [user.id, JSON.stringify({ email, via: "self_service_email_token" })],
      );

      res.json({ message: "Password reset successfully. You can now log in." });
    } catch (err) {
      next(err);
    }
  },
);

// ── Establishment: Forgot Password (Self-service) ─────────────
// REQ-2.2.6: Send OTP to registered contact_number
router.post(
  "/establishment/forgot-password",
  [body("contact_number").notEmpty().trim()],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty())
        return res.status(400).json({ errors: errors.array() });

      const { contact_number } = req.body;

      const result = await pool.query(
        "SELECT id, business_name FROM establishments WHERE contact_number = $1 AND status = 'approved'",
        [contact_number],
      );

      // Always return success to prevent enumeration
      if (!result.rows.length) {
        return res.json({
          message: "If a matching account exists, an OTP will be sent.",
        });
      }

      const est = result.rows[0];
      const otp = Math.floor(100000 + Math.random() * 900000).toString();
      const expires = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

      await pool.query(
        "UPDATE establishments SET reset_otp = $1, reset_otp_expires = $2 WHERE id = $3",
        [otp, expires, est.id],
      );

      await sendSms(
        contact_number,
        `iDetect: Your password reset OTP for ${est.business_name} is: ${otp}. It expires in 10 minutes. Do not share this code.`,
      );

      res.json({
        message: "If a matching account exists, an OTP will be sent.",
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── Establishment: Reset Password via OTP ─────────────────────
// REQ-2.2.6: Verify OTP and set new password
router.post(
  "/establishment/reset-password",
  [
    body("contact_number").notEmpty().trim(),
    body("otp").isLength({ min: 6, max: 6 }),
    body("new_password")
      .isLength({ min: 8 })
      .withMessage("Password must be at least 8 characters"),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty())
        return res.status(400).json({ errors: errors.array() });

      const { contact_number, otp, new_password } = req.body;

      const result = await pool.query(
        `SELECT id, business_name, reset_otp, reset_otp_expires
         FROM establishments
         WHERE contact_number = $1 AND status = 'approved'`,
        [contact_number],
      );

      if (!result.rows.length)
        return res.status(400).json({ message: "Invalid request." });

      const est = result.rows[0];

      if (!est.reset_otp || est.reset_otp !== otp)
        return res.status(400).json({ message: "Invalid OTP." });

      if (new Date() > new Date(est.reset_otp_expires))
        return res.status(400).json({ message: "OTP has expired." });

      const password_hash = await bcrypt.hash(new_password, 12);

      await pool.query(
        `UPDATE establishments
         SET password_hash = $1, reset_otp = NULL, reset_otp_expires = NULL,
             failed_attempts = 0, locked_until = NULL, updated_at = NOW()
         WHERE id = $2`,
        [password_hash, est.id],
      );

      await pool.query(
        `UPDATE establishment_users
         SET password_hash = $1, failed_attempts = 0, locked_until = NULL,
             updated_at = NOW()
         WHERE establishment_id = $2 AND role = 'establishment_super_user'`,
        [password_hash, est.id],
      );

      await pool.query(
        `INSERT INTO audit_logs (establishment_id, action, metadata)
        VALUES ($1, 'password_reset', $2)`,
        [
          est.id,
          JSON.stringify({
            business_name: est.business_name,
            via: "self_service_otp",
          }),
        ],
      );

      res.json({ message: "Password reset successfully. You can now log in." });
    } catch (err) {
      next(err);
    }
  },
);

// ── Establishment: Set Password via one-time setup link ───────
// Used the first time a BPLO-created account signs in — the token
// is emailed by POST /api/establishments and is single-use (24h TTL).
router.post(
  "/establishment/setup-password",
  [
    body("email").isEmail().normalizeEmail(),
    body("token").notEmpty().trim(),
    body("new_password")
      .isLength({ min: 8 })
      .withMessage("Password must be at least 8 characters"),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty())
        return res.status(400).json({ errors: errors.array() });

      const { email, token, new_password } = req.body;
      const crypto = require("crypto");
      const tokenHash = crypto.createHash("sha256").update(token).digest("hex");

      const result = await pool.query(
        `SELECT id FROM establishments
         WHERE email = $1
           AND password_setup_token = $2
           AND password_setup_token_expires > NOW()`,
        [email, tokenHash],
      );

      if (!result.rows.length) {
        return res.status(400).json({
          message:
            "Invalid or expired setup link. Please contact your BPLO administrator for a new one.",
        });
      }

      const est = result.rows[0];
      const password_hash = await bcrypt.hash(new_password, 12);

      await pool.query(
        `UPDATE establishments
         SET password_hash = $1, password_setup_token = NULL,
             password_setup_token_expires = NULL, updated_at = NOW()
         WHERE id = $2`,
        [password_hash, est.id],
      );

      await pool.query(
        `UPDATE establishment_users
         SET password_hash = $1, updated_at = NOW()
         WHERE establishment_id = $2 AND role = 'establishment_super_user'`,
        [password_hash, est.id],
      );

      await pool.query(
        `INSERT INTO audit_logs (establishment_id, action, metadata)
         VALUES ($1, 'password_reset', $2)`,
        [est.id, JSON.stringify({ email, via: "initial_setup_link" })],
      );

      res.json({ message: "Password set successfully. You can now log in." });
    } catch (err) {
      next(err);
    }
  },
);

// ── Establishment user: accept invitation and set password ─────
router.post(
  "/establishment/accept-invitation",
  [
    body("email").isEmail().normalizeEmail(),
    body("token").notEmpty().trim(),
    body("new_password")
      .isLength({ min: 8, max: 128 })
      .withMessage("Password must be between 8 and 128 characters"),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const { email, token, new_password } = req.body;
      const tokenHash = crypto.createHash("sha256").update(token).digest("hex");
      const result = await pool.query(
        `SELECT id, establishment_id, invitation_status
           FROM establishment_users
          WHERE lower(email) = lower($1)
            AND invitation_token_hash = $2
            AND invitation_token_expires > NOW()`,
        [email, tokenHash],
      );
      if (
        !result.rows.length ||
        result.rows[0].invitation_status !== "pending"
      ) {
        return res.status(400).json({
          error:
            "Invalid or expired invitation. Contact your establishment administrator.",
        });
      }

      const passwordHash = await bcrypt.hash(new_password, 12);
      const user = result.rows[0];
      await pool.query(
        `UPDATE establishment_users
            SET password_hash = $1,
                account_status = 'active',
                invitation_status = 'accepted',
                invitation_token_hash = NULL,
                invitation_token_expires = NULL,
                password_reset_required = FALSE,
                failed_attempts = 0,
                locked_until = NULL,
                approved_at = NOW()
          WHERE id = $2`,
        [passwordHash, user.id],
      );
      await pool.query(
        `INSERT INTO audit_logs
          (establishment_id, action, target_table, target_id, metadata)
         VALUES ($1, 'establishment_user_created', 'establishment_users', $2, $3)`,
        [
          user.establishment_id,
          user.id,
          JSON.stringify({ via: "invitation_accepted", email }),
        ],
      );
      res.json({ message: "Invitation accepted. You can now log in." });
    } catch (err) {
      next(err);
    }
  },
);

// ── Establishment: Change Password (in-session, current password
// required) ─────────────────────────────────────────────────────
// "Option A" from the design discussion: authenticated establishment
// re-enters their current password to set a new one — no OTP wait.
// The existing forgot-password/reset-password OTP pair above is
// unchanged and still serves the "I'm locked out, not logged in" case;
// this route is for the logged-in "change my password" case only.
router.post(
  "/establishment/change-password",
  [
    body("current_password").notEmpty(),
    body("new_password")
      .isLength({ min: 8 })
      .withMessage("Password must be at least 8 characters"),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      // Same bearer-token pattern as staff/refresh above.
      const authHeader = req.headers.authorization;
      if (!authHeader?.startsWith("Bearer ")) {
        return res.status(401).json({ error: "No token provided" });
      }
      const token = authHeader.slice(7);

      let decoded;
      try {
        decoded = jwt.verify(token, process.env.JWT_SECRET_ESTABLISHMENT);
      } catch {
        return res.status(401).json({ error: "Invalid or expired token" });
      }

      const { current_password, new_password } = req.body;

      const result = await pool.query(
        `SELECT
           e.id,
           e.password_hash AS legacy_password_hash,
           e.business_name,
           eu.id AS establishment_user_id,
           eu.password_hash,
           eu.role
         FROM establishments e
         LEFT JOIN establishment_users eu
           ON eu.establishment_id = e.id
          AND eu.id = $2
         WHERE e.id = $1 AND e.status = 'approved'`,
        [decoded.id, decoded.establishment_user_id],
      );
      const establishment = result.rows[0];
      if (!establishment) {
        return res.status(404).json({ error: "Account not found." });
      }

      const currentMatch = await bcrypt.compare(
        current_password,
        establishment.password_hash || establishment.legacy_password_hash,
      );
      if (!currentMatch) {
        throw createError(401, "Current password is incorrect.");
      }

      if (current_password === new_password) {
        return res.status(400).json({
          error: "New password must be different from your current password.",
        });
      }

      const password_hash = await bcrypt.hash(new_password, 12);

      await pool.query(
        `UPDATE establishments
         SET password_hash = $1, updated_at = NOW()
         WHERE id = $2`,
        [password_hash, establishment.id],
      );
      if (establishment.establishment_user_id) {
        await pool.query(
          `UPDATE establishment_users
           SET password_hash = $1, password_reset_required = FALSE
           WHERE id = $2`,
          [password_hash, establishment.establishment_user_id],
        );
      }

      // NOTE: this file uses two different audit_logs shapes elsewhere
      // (login/lockout use establishment_id + ip_address; the OTP-based
      // reset-password route above uses user_id + target_table/target_id
      // instead). Followed the establishment_id + ip_address shape here
      // since it matches this route's own login-adjacent context — worth
      // reconciling into one convention if audit_logs' actual schema
      // only supports one of these shapes.
      await pool.query(
        `INSERT INTO audit_logs (establishment_id, action, metadata, ip_address)
         VALUES ($1, 'password_changed', $2, $3)`,
        [
          establishment.id,
          JSON.stringify({
            business_name: establishment.business_name,
            via: "authenticated_change_password",
          }),
          req.ip,
        ],
      );

      res.json({ message: "Password updated successfully." });
    } catch (err) {
      next(err);
    }
  },
);

module.exports = router;
