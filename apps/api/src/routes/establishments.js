// src/routes/establishments.js
// Establishment management for the BPLO Portal.
//
//   GET   /api/establishments                — List all establishments
//   GET   /api/establishments/:id            — Get single establishment
//   POST  /api/establishments                — BPLO: create establishment (REQ-2.2.1)
//   POST  /api/establishments/bulk-import    — BPLO: bulk create from CSV/Excel
//   POST  /api/establishments/register       — Public: submit registration
//   PATCH /api/establishments/:id/approve    — BPLO approves
//   PATCH /api/establishments/:id/suspend    — BPLO suspends
//   PATCH /api/establishments/:id/revoke     — BPLO revokes

const express = require("express");
const bcrypt = require("bcryptjs");
const crypto = require("crypto");
const { body, param, validationResult } = require("express-validator");
const pool = require("../config/database");
const { authenticate, requireRole } = require("../middleware/auth");
const { createError } = require("../middleware/errorHandler");
const { sendSms } = require("../services/smsService");
const { sendEstablishmentSetupLink } = require("../services/emailService");

const router = express.Router();

// ── In-memory one-time credential token store ──────────────────
// Bulk import generates a temporary token (15-min TTL).
// The BPLO officer downloads credentials once via the token endpoint.
// Tokens are deleted immediately after first download (or on expiry).
const _credentialTokens = new Map(); // token → { credentials, expiresAt }

setInterval(
  () => {
    const now = Date.now();
    for (const [token, entry] of _credentialTokens.entries()) {
      if (entry.expiresAt < now) _credentialTokens.delete(token);
    }
  },
  5 * 60 * 1000,
); // GC every 5 minutes

// ── POST /api/establishments/register (PUBLIC) ─────────────────
// Businesses self-register. Account starts as 'pending'.
router.post(
  "/register",
  [
    body("email").isEmail().normalizeEmail(),
    body("password").isLength({ min: 8 }),
    body("business_name").notEmpty().trim(),
    body("business_permit_no").notEmpty().trim().toUpperCase(),
    body("owner_name").notEmpty().trim(),
    body("address").notEmpty().trim(),
    body("contact_number").notEmpty().trim(),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const {
        email,
        password,
        business_name,
        business_permit_no,
        owner_name,
        address,
        contact_number,
      } = req.body;

      const password_hash = await bcrypt.hash(password, 12);

      const result = await pool.query(
        `INSERT INTO establishments
         (email, password_hash, business_name, business_permit_no,
          owner_name, address, contact_number)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       RETURNING id, email, business_name, status, created_at`,
        [
          email,
          password_hash,
          business_name,
          business_permit_no,
          owner_name,
          address,
          contact_number,
        ],
      );

      // Audit log for self-registration
      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
       VALUES (NULL, 'establishment_self_registered', 'establishments', $1, $2)`,
        [
          result.rows[0].id,
          JSON.stringify({
            business_name,
            business_permit_no: business_permit_no.toUpperCase(),
            email,
          }),
        ],
      );

      res.status(201).json({
        message:
          "Registration submitted. Your account is pending BPLO approval.",
        establishment: result.rows[0],
      });
    } catch (err) {
      next(err);
    }
  },
);

// All routes below require BPLO admin authentication
router.use(authenticate);
router.use(requireRole("bplo_admin"));

// ── Helpers ──────────────────────────────────────────────────
// Generate a readable random password (no ambiguous chars: 0/O, I/1/l)
function generatePassword(length = 12) {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
  const bytes = crypto.randomBytes(length);
  let result = "";
  for (let i = 0; i < length; i++) {
    result += chars[bytes[i] % chars.length];
  }
  return result;
}

// Generate a placeholder login email from the permit number when none is provided
function generateEmail(business_permit_no) {
  const slug = business_permit_no.toLowerCase().replace(/[^a-z0-9]/g, "");
  return `${slug}@idetect-bplo.ph`;
}

// Normalize date strings / Excel serials to ISO yyyy-mm-dd
function toIsoDate(value) {
  if (!value && value !== 0) return null;
  if (typeof value === "number") {
    // Excel serial date
    const ms = Math.round((value - 25569) * 86400 * 1000);
    const d = new Date(ms);
    if (isNaN(d.getTime())) return null;
    return d.toISOString().slice(0, 10);
  }
  const raw = String(value).trim();
  if (!raw) return null;
  const direct = new Date(raw);
  if (!isNaN(direct.getTime())) return direct.toISOString().slice(0, 10);
  // Try MM/DD/YYYY
  const mdy = raw.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})$/);
  if (mdy) {
    let [, m, d, y] = mdy;
    if (y.length === 2) y = Number(y) > 50 ? `19${y}` : `20${y}`;
    const parsed = new Date(`${y}-${m.padStart(2, "0")}-${d.padStart(2, "0")}`);
    if (!isNaN(parsed.getTime())) return parsed.toISOString().slice(0, 10);
  }
  return null;
}

// ── POST /api/establishments/bulk-import ──────────────────────
// REQ-2.2.1 (bulk): Import multiple establishments at once.
// Auto-generates email (if not supplied) and password for each row.
// Returns generated credentials (one-time) and logs them in audit trail.
router.post("/bulk-import", async (req, res, next) => {
  try {
    const rows = Array.isArray(req.body?.records) ? req.body.records : null;
    if (!rows || rows.length === 0) {
      return res
        .status(400)
        .json({ message: "records must be a non-empty array" });
    }
    if (rows.length > 500) {
      return res
        .status(400)
        .json({ message: "Maximum 500 establishments per import." });
    }

    const invalidRows = [];
    const validRows = [];

    rows.forEach((row, index) => {
      const rowNum = index + 2; // 1-based, row 1 is header
      const business_name = String(row.business_name || "").trim();
      const business_permit_no = String(row.business_permit_no || "")
        .trim()
        .toUpperCase();
      const owner_name = String(row.owner_name || "").trim();
      const address = String(row.address || "").trim();
      const contact_number = String(row.contact_number || "").trim();
      const email = String(row.email || "")
        .trim()
        .toLowerCase();
      const permit_expiry = toIsoDate(row.business_permit_expiry);

      if (!business_name)
        return invalidRows.push({
          row: rowNum,
          error: "business_name is required",
        });
      if (!business_permit_no)
        return invalidRows.push({
          row: rowNum,
          error: "business_permit_no is required",
        });
      if (!owner_name)
        return invalidRows.push({
          row: rowNum,
          error: "owner_name is required",
        });
      if (!address)
        return invalidRows.push({ row: rowNum, error: "address is required" });
      if (!contact_number)
        return invalidRows.push({
          row: rowNum,
          error: "contact_number is required",
        });
      if (email && !/\S+@\S+\.\S+/.test(email))
        return invalidRows.push({
          row: rowNum,
          error: "email format is invalid",
        });

      const resolvedEmail = email || generateEmail(business_permit_no);
      const plainPassword = generatePassword(12);

      validRows.push({
        business_name,
        business_permit_no,
        owner_name,
        address,
        contact_number,
        email: resolvedEmail,
        email_was_provided: !!email,
        plain_password: plainPassword,
        business_permit_expiry: permit_expiry,
      });
    });

    if (validRows.length === 0) {
      return res.status(400).json({
        message: "No valid rows found in import payload.",
        summary: {
          total: rows.length,
          valid: 0,
          inserted: 0,
          duplicates: 0,
          invalid: invalidRows.length,
        },
        invalidRows,
      });
    }

    // Hash all passwords before opening the transaction
    const hashed = await Promise.all(
      validRows.map((r) => bcrypt.hash(r.plain_password, 12)),
    );

    const client = await pool.connect();
    let inserted = 0;
    let duplicates = 0;
    const credentials = []; // plaintext — returned once to BPLO officer

    try {
      await client.query("BEGIN");

      for (let i = 0; i < validRows.length; i++) {
        const row = validRows[i];
        const password_hash = hashed[i];

        // Skip duplicate permit numbers silently (count as duplicate)
        const dupPermit = await client.query(
          "SELECT id FROM establishments WHERE business_permit_no = $1",
          [row.business_permit_no],
        );
        if (dupPermit.rows.length) {
          duplicates++;
          continue;
        }

        // Skip duplicate email (auto-generated emails could collide on very similar permit nos)
        const dupEmail = await client.query(
          "SELECT id FROM establishments WHERE email = $1",
          [row.email],
        );
        let finalEmail = row.email;
        if (dupEmail.rows.length) {
          // Append a short suffix to make it unique
          finalEmail = row.email.replace(
            "@",
            `_${crypto.randomBytes(3).toString("hex")}@`,
          );
        }

        const result = await client.query(
          `INSERT INTO establishments
             (email, password_hash, business_name, business_permit_no,
              owner_name, address, contact_number, business_permit_expiry,
              status, approved_by, approved_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'approved',$9,NOW())
           RETURNING id`,
          [
            finalEmail,
            password_hash,
            row.business_name,
            row.business_permit_no,
            row.owner_name,
            row.address,
            row.contact_number,
            row.business_permit_expiry || null,
            req.user.id,
          ],
        );

        await client.query(
          `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
           VALUES ($1, 'establishment_created', 'establishments', $2, $3)`,
          [
            req.user.id,
            result.rows[0].id,
            JSON.stringify({
              business_name: row.business_name,
              business_permit_no: row.business_permit_no,
              created_by_bplo: true,
              bulk_import: true,
              email_auto_generated: !row.email_was_provided,
            }),
          ],
        );

        inserted++;
        credentials.push({
          business_name: row.business_name,
          business_permit_no: row.business_permit_no,
          email: finalEmail,
          password: row.plain_password,
          email_auto_generated: !row.email_was_provided,
        });
      }

      // Single bulk audit log entry
      await client.query(
        `INSERT INTO audit_logs (user_id, action, target_table, metadata)
         VALUES ($1, 'establishment_bulk_import', 'establishments', $2)`,
        [
          req.user.id,
          JSON.stringify({
            total: rows.length,
            valid: validRows.length,
            inserted,
            duplicates,
            invalid: invalidRows.length,
            inserted_permit_nos: credentials.map((c) => c.business_permit_no),
          }),
        ],
      );

      await client.query("COMMIT");
    } catch (txErr) {
      await client.query("ROLLBACK");
      throw txErr;
    } finally {
      client.release();
    }

    res.status(201).json({
      message: `Bulk import complete. ${inserted} establishment(s) created.`,
      summary: {
        total: rows.length,
        valid: validRows.length,
        inserted,
        duplicates,
        invalid: invalidRows.length,
      },
      // Credentials are NOT returned in this response to avoid plaintext
      // exposure in logs/proxies. Use the one-time download token below.
      credentialToken: (() => {
        if (inserted === 0) return null;
        const token = crypto.randomUUID();
        _credentialTokens.set(token, {
          credentials,
          expiresAt: Date.now() + 15 * 60 * 1000,
        });
        return token;
      })(),
      credentialTokenExpiresInMinutes: inserted > 0 ? 15 : null,
      invalidRows,
    });
  } catch (err) {
    next(err);
  }
});

// ── GET /api/establishments/bulk-credentials/:token ───────────
// One-time download of plaintext credentials from a bulk import.
// Token is consumed on first access (or expires after 15 min).
router.get(
  "/bulk-credentials/:token",
  authenticate,
  requireRole(["bplo_admin"]),
  (req, res) => {
    const { token } = req.params;
    const entry = _credentialTokens.get(token);

    if (!entry) {
      return res
        .status(404)
        .json({ error: "Token not found or already used." });
    }
    if (entry.expiresAt < Date.now()) {
      _credentialTokens.delete(token);
      return res.status(410).json({ error: "Token has expired." });
    }

    // Consume the token immediately (single-use)
    _credentialTokens.delete(token);

    const { credentials } = entry;

    // Return as CSV for direct browser download
    const header =
      "business_name,business_permit_no,email,password,email_auto_generated\n";
    const rows = credentials
      .map((c) =>
        [
          `"${c.business_name}"`,
          c.business_permit_no,
          c.email,
          c.password,
          c.email_auto_generated,
        ].join(","),
      )
      .join("\n");

    res.setHeader("Content-Type", "text/csv");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="idetect_credentials_${Date.now()}.csv"`,
    );
    res.send(header + rows);
  },
);

// REQ-2.2.1: BPLO officer directly creates a Client Portal account
// for an establishment. Account is immediately approved.
router.post(
  "/",
  [
    body("email").isEmail().normalizeEmail(),
    body("business_name").notEmpty().trim(),
    body("business_permit_no").notEmpty().trim().toUpperCase(),
    body("owner_name").notEmpty().trim(),
    body("address").notEmpty().trim(),
    body("contact_number").notEmpty().trim(),
    body("business_permit_expiry").optional().isDate(),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const {
        email,
        business_name,
        business_permit_no,
        owner_name,
        address,
        contact_number,
        business_permit_expiry,
      } = req.body;

      const existingPermit = await pool.query(
        "SELECT id FROM establishments WHERE business_permit_no = $1",
        [business_permit_no.toUpperCase()],
      );
      if (existingPermit.rows.length) {
        return res.status(409).json({
          message:
            "An establishment with this business permit number already exists.",
        });
      }

      // Check for duplicate email
      const existingEmail = await pool.query(
        "SELECT id FROM establishments WHERE email = $1",
        [email],
      );
      if (existingEmail.rows.length) {
        return res.status(409).json({
          message: "An establishment with this email already exists.",
        });
      }

      // Password is set by the establishment via a one-time link (avoids
      // emailing a plaintext password, which mail providers often block as
      // phishing-like content). The stored hash is a random placeholder
      // that cannot be used to log in until the setup link is completed.
      const password_hash = await bcrypt.hash(
        crypto.randomBytes(32).toString("hex"),
        12,
      );
      const setupToken = crypto.randomBytes(32).toString("hex");
      const setupTokenHash = crypto
        .createHash("sha256")
        .update(setupToken)
        .digest("hex");
      const setupTokenExpires = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24h

      const client = await pool.connect();
      let result;
      try {
        await client.query("BEGIN");

        result = await client.query(
          `INSERT INTO establishments
           (email, password_hash, business_name, business_permit_no,
            owner_name, address, contact_number, business_permit_expiry,
            status, approved_by, approved_at,
            password_setup_token, password_setup_token_expires)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8, 'approved', $9, NOW(), $10, $11)
         RETURNING id, email, business_name, business_permit_no, status, created_at`,
          [
            email,
            password_hash,
            business_name,
            business_permit_no.toUpperCase(),
            owner_name,
            address,
            contact_number,
            business_permit_expiry || null,
            req.user.id,
            setupTokenHash,
            setupTokenExpires,
          ],
        );

        await client.query(
          `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
         VALUES ($1, 'establishment_created', 'establishments', $2, $3)`,
          [
            req.user.id,
            result.rows[0].id,
            JSON.stringify({
              business_name,
              business_permit_no: business_permit_no.toUpperCase(),
              created_by_bplo: true,
            }),
          ],
        );

        await client.query("COMMIT");
      } catch (txErr) {
        await client.query("ROLLBACK");
        throw txErr;
      } finally {
        client.release();
      }

      // Send the password-setup link to the establishment email — awaited
      // so a delivery failure is reflected in the response instead of
      // silently reporting success while nothing was actually sent.
      const allowedOrigins = (process.env.ALLOWED_PORTAL_ORIGINS || "")
        .split(",")
        .map((o) => o.trim())
        .filter(Boolean);
      const setupOrigin = allowedOrigins[0] || "https://idetect.it.com";
      const setupUrl = `${setupOrigin}/establishment/setup-password?token=${setupToken}&email=${encodeURIComponent(email)}`;

      const emailResult = await sendEstablishmentSetupLink({
        business_name,
        email,
        setupUrl,
      }).catch((err) => {
        console.error(
          `[EMAIL] Failed to send setup link to ${email}:`,
          err.message,
        );
        return { success: false, error: err.message };
      });

      // Also notify via SMS if contact number provided (fire-and-forget —
      // SMS delivery isn't the primary channel here, so we don't block on it)
      if (contact_number) {
        sendSms(
          contact_number,
          `Welcome to iDetect! Your establishment account (${business_name}) has been created. Check your email (${email}) to set your password.`,
        ).catch((err) => console.error("[SMS] Failed:", err.message));
      }

      res.status(201).json({
        message: emailResult?.success
          ? `Establishment "${business_name}" created and approved successfully. A password-setup link has been sent to ${email}.`
          : `Establishment "${business_name}" created and approved successfully, but the setup-link email to ${email} could not be sent. Please ask the establishment to use "Forgot password" once you resend it, or contact them manually.`,
        establishment: result.rows[0],
        email_sent: !!emailResult?.success,
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── GET /api/establishments/expiring-permits ──────────────────
// REQ-2.2.5: Returns establishments whose permit expires within :days (default 30)
router.get(
  "/expiring-permits",
  authenticate,
  requireRole("bplo_admin"),
  async (req, res, next) => {
    try {
      const days = parseInt(req.query.days) || 30;
      const result = await pool.query(
        `SELECT id, business_name, business_permit_no, owner_name,
                contact_number, status, business_permit_expiry,
                (business_permit_expiry - CURRENT_DATE) AS days_until_expiry
         FROM establishments
         WHERE business_permit_expiry IS NOT NULL
           AND status = 'approved'
           AND business_permit_expiry <= CURRENT_DATE + $1::int
         ORDER BY business_permit_expiry ASC`,
        [days],
      );
      res.json({ data: result.rows });
    } catch (err) {
      next(err);
    }
  },
);

// ── GET /api/establishments/:id ────────────────────────────────
router.get("/:id", async (req, res, next) => {
  try {
    const result = await pool.query(
      `SELECT id, email, business_name, business_permit_no, owner_name,
             address, contact_number, business_type, status,
             approved_by, approved_at, suspended_reason, created_at, updated_at
      FROM establishments WHERE id = $1`,
      [req.params.id],
    );

    if (!result.rows.length) throw createError(404, "Establishment not found");

    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
});

// ── GET /api/establishments ────────────────────────────────────
router.get("/", async (req, res, next) => {
  try {
    const status = req.query.status || null;
    const search = req.query.search || "";
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    let query = `
      SELECT id, business_name, business_permit_no, owner_name,
             address, contact_number, status, approved_at, created_at
      FROM establishments WHERE 1=1
    `;
    const params = [];
    let idx = 1;

    if (status) {
      query += ` AND status = $${idx++}`;
      params.push(status);
    }
    if (search) {
      query += ` AND (business_name ILIKE $${idx} OR business_permit_no ILIKE $${idx})`;
      params.push(`%${search}%`);
      idx++;
    }

    query += ` ORDER BY created_at DESC LIMIT $${idx} OFFSET $${idx + 1}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);
    res.json({ data: result.rows });
  } catch (err) {
    next(err);
  }
});

// ── PATCH /api/establishments/:id/approve ─────────────────────
router.patch("/:id/approve", async (req, res, next) => {
  try {
    const result = await pool.query(
      `UPDATE establishments
       SET status = 'approved', approved_by = $1, approved_at = NOW()
       WHERE id = $2 AND status = 'pending'
       RETURNING business_name`,
      [req.user.id, req.params.id],
    );

    if (!result.rows.length)
      throw createError(404, "Establishment not found or already processed");

    // REQ-2.2.4: Notify establishment on approval
    const approvedEst = await pool.query(
      "SELECT contact_number, business_name FROM establishments WHERE id = $1",
      [req.params.id],
    );
    if (approvedEst.rows[0]?.contact_number) {
      await sendSms(
        approvedEst.rows[0].contact_number,
        `iDetect: Your establishment account (${approvedEst.rows[0].business_name}) has been approved. You can now log in to the iDetect Client Portal and begin scanning IDs.`,
      );
    }

    await pool.query(
      `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
       VALUES ($1, 'establishment_approved', 'establishments', $2, $3)`,
      [
        req.user.id,
        req.params.id,
        JSON.stringify({ business_name: result.rows[0].business_name }),
      ],
    );

    res.json({
      message: `${result.rows[0].business_name} approved successfully.`,
    });
  } catch (err) {
    next(err);
  }
});

// ── PATCH /api/establishments/:id/suspend ─────────────────────
router.patch(
  "/:id/suspend",
  [body("reason").notEmpty().trim()],
  async (req, res, next) => {
    try {
      const { reason } = req.body;

      const suspended = await pool.query(
        `UPDATE establishments
       SET status = 'suspended', suspended_reason = $1
       WHERE id = $2
       RETURNING business_name, contact_number`,
        [reason, req.params.id],
      );

      // REQ-2.2.4: Notify establishment on suspension
      if (suspended.rows[0]?.contact_number) {
        await sendSms(
          suspended.rows[0].contact_number,
          `iDetect: Your establishment account (${suspended.rows[0].business_name}) has been SUSPENDED. Reason: ${reason}. Contact BPLO for assistance.`,
        );
      }

      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
       VALUES ($1, 'establishment_suspended', 'establishments', $2, $3)`,
        [req.user.id, req.params.id, JSON.stringify({ reason })],
      );

      res.json({ message: "Establishment suspended." });
    } catch (err) {
      next(err);
    }
  },
);

// ── PATCH /api/establishments/:id/revoke ──────────────────────
router.patch(
  "/:id/revoke",
  [body("reason").notEmpty().trim()],
  async (req, res, next) => {
    try {
      const { reason } = req.body;

      const result = await pool.query(
        `UPDATE establishments
       SET status = 'revoked', suspended_reason = $1
       WHERE id = $2 AND status IN ('approved', 'suspended')
       RETURNING business_name, contact_number`,
        [reason, req.params.id],
      );

      if (!result.rows.length)
        throw createError(404, "Establishment not found or cannot be revoked");

      // REQ-2.2.4: Notify establishment on revocation
      if (result.rows[0].contact_number) {
        await sendSms(
          result.rows[0].contact_number,
          `iDetect: Your establishment account (${result.rows[0].business_name}) has been REVOKED. Reason: ${reason}. Contact BPLO for more information.`,
        );
      }

      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
       VALUES ($1, 'establishment_revoked', 'establishments', $2, $3)`,
        [
          req.user.id,
          req.params.id,
          JSON.stringify({
            reason,
            business_name: result.rows[0].business_name,
          }),
        ],
      );

      res.json({
        message: `${result.rows[0].business_name} has been revoked.`,
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── PATCH /api/establishments/:id/unlock ──────────────────────
router.patch(
  "/:id/unlock",
  param("id").isUUID(),
  authenticate,
  requireRole("bplo_admin"),
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty())
        return res.status(400).json({ errors: errors.array() });

      const { id } = req.params;

      const result = await pool.query(
        `UPDATE establishments
            SET failed_attempts = 0, locked_until = NULL
          WHERE id = $1
          RETURNING id, business_name, email`,
        [id],
      );

      if (!result.rows.length)
        throw createError(404, "Establishment not found");

      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata, ip_address)
         VALUES ($1, 'account_unlocked', 'establishments', $2, $3, $4)`,
        [
          req.user.id,
          id,
          JSON.stringify({
            unlocked_by: req.user.id,
            business_name: result.rows[0].business_name,
          }),
          req.ip,
        ],
      );

      res.json({
        message: `${result.rows[0].business_name} has been unlocked.`,
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── PATCH /api/establishments/:id/contact ─────────────────────
// REQ-2.2.6: BPLO officer updates establishment contact details
router.patch(
  "/:id/contact",
  [
    param("id").isUUID(),
    body("contact_number").optional().trim().notEmpty(),
    body("email").optional().isEmail().normalizeEmail(),
    body("owner_name").optional().trim().notEmpty(),
    body("address").optional().trim().notEmpty(),
  ],
  authenticate,
  requireRole("bplo_admin"),
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty())
        return res.status(400).json({ errors: errors.array() });

      const { id } = req.params;
      const { contact_number, email, owner_name, address } = req.body;

      if (!contact_number && !email && !owner_name && !address) {
        return res.status(400).json({ message: "No fields to update." });
      }

      const setClauses = [];
      const values = [];
      let idx = 1;
      if (contact_number) {
        setClauses.push(`contact_number = $${idx++}`);
        values.push(contact_number);
      }
      if (email) {
        setClauses.push(`email = $${idx++}`);
        values.push(email);
      }
      if (owner_name) {
        setClauses.push(`owner_name = $${idx++}`);
        values.push(owner_name);
      }
      if (address) {
        setClauses.push(`address = $${idx++}`);
        values.push(address);
      }
      values.push(id);

      const result = await pool.query(
        `UPDATE establishments SET ${setClauses.join(", ")}, updated_at = NOW()
         WHERE id = $${idx}
         RETURNING id, business_name, email, contact_number, owner_name, address`,
        values,
      );

      if (!result.rows.length)
        throw createError(404, "Establishment not found");

      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
         VALUES ($1, 'establishment_updated', 'establishments', $2, $3)`,
        [
          req.user.id,
          id,
          JSON.stringify({ updated_fields: Object.keys(req.body) }),
        ],
      );

      res.json({
        message: "Contact details updated.",
        establishment: result.rows[0],
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── PATCH /api/establishments/:id/admin-reset-password ────────
// REQ-2.2.6: BPLO officer force-resets establishment password
router.patch(
  "/:id/admin-reset-password",
  [
    param("id").isUUID(),
    body("new_password")
      .isLength({ min: 8 })
      .withMessage("Password must be at least 8 characters"),
  ],
  authenticate,
  requireRole("bplo_admin"),
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty())
        return res.status(400).json({ errors: errors.array() });

      const { id } = req.params;
      const { new_password } = req.body;
      const password_hash = await bcrypt.hash(new_password, 12);

      const result = await pool.query(
        `UPDATE establishments
         SET password_hash = $1, failed_attempts = 0, locked_until = NULL, updated_at = NOW()
         WHERE id = $2
         RETURNING id, business_name, contact_number, email`,
        [password_hash, id],
      );
      if (!result.rows.length)
        throw createError(404, "Establishment not found");

      const est = result.rows[0];

      // Notify establishment of the forced reset
      if (est.contact_number) {
        await sendSms(
          est.contact_number,
          `iDetect: Your establishment account (${est.business_name}) password has been reset by a BPLO officer. Use your email (${est.email}) and the new password provided to you to log in.`,
        );
      }

      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
         VALUES ($1, 'password_reset_by_admin', 'establishments', $2, $3)`,
        [
          req.user.id,
          id,
          JSON.stringify({
            business_name: est.business_name,
            reset_by: req.user.id,
          }),
        ],
      );

      res.json({
        message: `Password for ${est.business_name} has been reset.`,
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── DELETE /api/establishments/:id ────────────────────────────
// Only revoked establishments can be deleted. Logs before deletion.
router.delete(
  "/:id",
  param("id").isUUID(),
  authenticate,
  requireRole("bplo_admin"),
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty())
        return res.status(400).json({ errors: errors.array() });

      const { id } = req.params;

      // Fetch before delete to confirm it's revoked and capture metadata
      const existing = await pool.query(
        "SELECT id, business_name, status FROM establishments WHERE id = $1",
        [id],
      );

      if (!existing.rows.length)
        throw createError(404, "Establishment not found");

      if (existing.rows[0].status !== "revoked")
        throw createError(
          400,
          "Only revoked establishments can be deleted. Revoke it first.",
        );

      // Log deletion before deleting (fire-and-forget to avoid enum errors blocking delete)
      pool
        .query(
          `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
         VALUES ($1, 'establishment_deleted', 'establishments', $2, $3)`,
          [
            req.user.id,
            id,
            JSON.stringify({
              business_name: existing.rows[0].business_name,
              deleted_by: req.user.id,
            }),
          ],
        )
        .catch((err) =>
          console.error(
            "[AUDIT] establishment_deleted log failed:",
            err.message,
          ),
        );

      await pool.query("DELETE FROM establishments WHERE id = $1", [id]);

      res.json({
        message: `"${existing.rows[0].business_name}" has been permanently deleted.`,
      });
    } catch (err) {
      next(err);
    }
  },
);

module.exports = router;
