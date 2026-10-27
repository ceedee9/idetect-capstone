// src/routes/staff.js
// Staff user management — list, create, update, deactivate, reset password.
// Office admins manage accounts in their own role. Office Super Admins manage
// staff inside their own agency and may assign only that agency's admin role.

const express = require("express");
const bcrypt = require("bcryptjs");
const crypto = require("crypto");
const { body, param, validationResult } = require("express-validator");
const pool = require("../config/database");
const { authenticate, requireRole } = require("../middleware/auth");
const { openStaffAlertStream } = require("../services/staffAlertStream");
const {
  PASSWORD_MAX_LENGTH,
  assertPasswordPolicy,
} = require("../utils/passwordPolicy");

const router = express.Router();
const SALT_ROUNDS = 12;

// Every endpoint requires staff auth
router.use(authenticate);
router.use(requireRole([
  "bplo_super_admin",
  "osca_super_admin",
  "pdao_super_admin",
  "osca_admin",
  "pdao_admin",
  "bplo_admin",
]));

const SUPER_ADMIN_AGENCY = {
  bplo_super_admin: "bplo",
  osca_super_admin: "osca",
  pdao_super_admin: "pdao",
};
const AGENCY_ADMIN_ROLE = {
  bplo: "bplo_admin",
  osca: "osca_admin",
  pdao: "pdao_admin",
};

// Super Admins manage only the matching office-admin role in their agency.
function ownRole(req) {
  return SUPER_ADMIN_AGENCY[req.user.role]
    ? AGENCY_ADMIN_ROLE[SUPER_ADMIN_AGENCY[req.user.role]]
    : req.user.role;
}

function isOfficeSuperAdmin(req) {
  return Boolean(SUPER_ADMIN_AGENCY[req.user.role]);
}

function requireOfficeSuperAdmin(req, res, next) {
  if (!isOfficeSuperAdmin(req)) {
    return res.status(403).json({
      error: "Only your agency's Super Admin can manage staff accounts",
    });
  }
  next();
}

function scopedStaffQuery(req, includeWhere = true) {
  return {
    sql: includeWhere ? "WHERE role = $1" : "",
    params: includeWhere ? [ownRole(req)] : [],
  };
}

// ── LIST staff of same role ────────────────────────────────────
router.get("/", async (req, res, next) => {
  try {
    const scope = scopedStaffQuery(req);
    const { rows } = await pool.query(
      `SELECT id, email, full_name, role, is_active, created_at, updated_at
         FROM users
        ${scope.sql}
        ORDER BY created_at DESC`,
      scope.params,
    );
    res.json({ staff: rows });
  } catch (err) {
    next(err);
  }
});

// Live alert stream (Server-Sent Events). Static routes stay before "/:id".
router.get("/alerts/stream", (req, res) => {
  openStaffAlertStream(req, res, ownRole(req));
});

router.get("/alerts", async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, alert_type, severity, title, body, target_route,
              related_beneficiary_id, related_dispute_id, is_read, read_at,
              created_at
         FROM staff_alerts
        WHERE target_role = $1
        ORDER BY created_at DESC
        LIMIT 50`,
      [ownRole(req)],
    );
    const unread_count = rows.filter((r) => !r.is_read).length;
    res.json({ alerts: rows, unread_count });
  } catch (err) {
    next(err);
  }
});

// ── GET single staff member ────────────────────────────────────
router.get("/:id", param("id").isUUID(), async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty())
      return res.status(400).json({ errors: errors.array() });

    const { rows } = await pool.query(
      `SELECT id, email, full_name, role, is_active, created_at, updated_at
           FROM users WHERE id = $1
           AND role = $2`,
      [req.params.id, ownRole(req)],
    );
    if (!rows.length)
      return res.status(404).json({ error: "Staff member not found" });
    res.json({ staff: rows[0] });
  } catch (err) {
    next(err);
  }
});

// ── CREATE new staff account ───────────────────────────────────
router.post(
  "/",
  requireOfficeSuperAdmin,
  [
    body("email").isEmail().normalizeEmail(),
    body("full_name").trim().isLength({ min: 2, max: 255 }),
    body("password")
      .isLength({ max: PASSWORD_MAX_LENGTH })
      .withMessage(`Password must be at most ${PASSWORD_MAX_LENGTH} characters`)
      .bail()
      .custom(assertPasswordPolicy),
    body("role").optional().isIn(["bplo_admin", "osca_admin", "pdao_admin"]),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty())
        return res.status(400).json({ errors: errors.array() });

      const { email, full_name, password } = req.body;
      const role = ownRole(req);
      if (req.body.role && (!isOfficeSuperAdmin(req) || req.body.role !== role)) {
        return res.status(403).json({
          error: "You can only create staff for your own agency",
        });
      }

      // Check duplicate email
      const dup = await pool.query("SELECT id FROM users WHERE email = $1", [
        email,
      ]);
      if (dup.rows.length)
        return res.status(409).json({ error: "Email already registered" });

      const password_hash = await bcrypt.hash(password, SALT_ROUNDS);

      const { rows } = await pool.query(
        `INSERT INTO users (email, password_hash, full_name, role)
         VALUES ($1, $2, $3, $4)
         RETURNING id, email, full_name, role, is_active, created_at`,
        [email, password_hash, full_name, role],
      );

      // Audit log
      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata, ip_address)
         VALUES ($1, 'staff_created', 'users', $2, $3, $4)`,
        [
          req.user.id,
          rows[0].id,
          JSON.stringify({
            action: "staff_created",
            email,
            full_name,
            role,
          }),
          req.ip,
        ],
      );

      res.status(201).json({ staff: rows[0] });
    } catch (err) {
      next(err);
    }
  },
);

// ── UPDATE staff profile (name / email) ────────────────────────
router.patch(
  "/:id",
  requireOfficeSuperAdmin,
  [
    param("id").isUUID(),
    body("email").optional().isEmail().normalizeEmail(),
    body("full_name").optional().trim().isLength({ min: 2, max: 255 }),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty())
        return res.status(400).json({ errors: errors.array() });

      const { id } = req.params;
      const role = ownRole(req);

      // Verify target exists in the caller's scope.
      const existing = await pool.query(
        `SELECT id, role FROM users WHERE id = $1
         AND role = $2`,
        [id, role],
      );
      if (!existing.rows.length)
        return res.status(404).json({ error: "Staff member not found" });

      const sets = [];
      const vals = [];
      let idx = 1;

      if (req.body.email) {
        // Check for duplicate if changing email
        const dup = await pool.query(
          "SELECT id FROM users WHERE email = $1 AND id != $2",
          [req.body.email, id],
        );
        if (dup.rows.length)
          return res.status(409).json({ error: "Email already in use" });
        sets.push(`email = $${idx++}`);
        vals.push(req.body.email);
      }
      if (req.body.full_name) {
        sets.push(`full_name = $${idx++}`);
        vals.push(req.body.full_name);
      }
      if (req.body.role) {
        if (!isOfficeSuperAdmin(req) || req.body.role !== ownRole(req)) {
          return res.status(403).json({ error: "Only your agency's Super Admin can change this role" });
        }
        if (id === req.user.id) {
          return res.status(400).json({ error: "Cannot change your own staff role" });
        }
        sets.push(`role = $${idx++}`);
        vals.push(req.body.role);
      }

      if (!sets.length)
        return res.status(400).json({ error: "No fields to update" });

      vals.push(id);
      const { rows } = await pool.query(
        `UPDATE users SET ${sets.join(", ")} WHERE id = $${idx}
         RETURNING id, email, full_name, role, is_active, created_at, updated_at`,
        vals,
      );

      // Audit log
      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata, ip_address)
         VALUES ($1, 'staff_updated', 'users', $2, $3, $4)`,
        [
          req.user.id,
          id,
          JSON.stringify({
            action: "staff_updated",
            changes: Object.keys(req.body).filter(
              (k) => k !== "password" && req.body[k],
            ),
          }),
          req.ip,
        ],
      );

      if (req.body.role && req.body.role !== existing.rows[0].role) {
        await pool.query(
          `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata, ip_address)
           VALUES ($1, 'staff_role_changed', 'users', $2, $3, $4)`,
          [
            req.user.id,
            id,
            JSON.stringify({
              previous_role: existing.rows[0].role,
              new_role: req.body.role,
            }),
            req.ip,
          ],
        );
      }

      res.json({ staff: rows[0] });
    } catch (err) {
      next(err);
    }
  },
);

// ── TOGGLE active status (activate / deactivate) ──────────────
router.patch(
  "/:id/toggle-active",
  requireOfficeSuperAdmin,
  param("id").isUUID(),
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty())
        return res.status(400).json({ errors: errors.array() });

      const { id } = req.params;

      // Can't deactivate yourself
      if (id === req.user.id)
        return res
          .status(400)
          .json({ error: "Cannot deactivate your own account" });

      const existing = await pool.query(
        `SELECT id, is_active, role FROM users WHERE id = $1
         AND role = $2`,
        [id, ownRole(req)],
      );
      if (!existing.rows.length)
        return res.status(404).json({ error: "Staff member not found" });

      const newStatus = !existing.rows[0].is_active;
      if (
        SUPER_ADMIN_AGENCY[existing.rows[0].role] &&
        newStatus === false
      ) {
        const count = await pool.query(
          "SELECT COUNT(*)::int AS count FROM users WHERE role = $1 AND is_active = TRUE",
          [req.user.role],
        );
        if (count.rows[0].count <= 1) {
          return res.status(400).json({
            error: "Cannot deactivate the final active Super Admin",
          });
        }
      }
      const { rows } = await pool.query(
        `UPDATE users SET is_active = $1 WHERE id = $2
         RETURNING id, email, full_name, role, is_active, updated_at`,
        [newStatus, id],
      );

      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata, ip_address)
         VALUES ($1, $2, 'users', $3, $4, $5)`,
        [
          req.user.id,
          newStatus ? "staff_activated" : "staff_deactivated",
          id,
          JSON.stringify({
            action: newStatus ? "staff_activated" : "staff_deactivated",
            email: rows[0].email,
          }),
          req.ip,
        ],
      );

      res.json({ staff: rows[0] });
    } catch (err) {
      next(err);
    }
  },
);

// ── RESET password (admin sets new password for a staff member) ─
router.patch(
  "/:id/reset-password",
  requireOfficeSuperAdmin,
  [
    param("id").isUUID(),
    body("password")
      .isLength({ max: PASSWORD_MAX_LENGTH })
      .withMessage(`Password must be at most ${PASSWORD_MAX_LENGTH} characters`)
      .bail()
      .custom(assertPasswordPolicy),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty())
        return res.status(400).json({ errors: errors.array() });

      const { id } = req.params;

      const existing = await pool.query(
        `SELECT id FROM users WHERE id = $1
         AND role = $2`,
        [id, ownRole(req)],
      );
      if (!existing.rows.length)
        return res.status(404).json({ error: "Staff member not found" });

      const password_hash = await bcrypt.hash(req.body.password, SALT_ROUNDS);
      await pool.query("UPDATE users SET password_hash = $1 WHERE id = $2", [
        password_hash,
        id,
      ]);

      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata, ip_address)
         VALUES ($1, 'staff_password_reset', 'users', $2, $3, $4)`,
        [
          req.user.id,
          id,
          JSON.stringify({ action: "staff_password_reset", by: req.user.id }),
          req.ip,
        ],
      );

      res.json({ message: "Password reset successfully" });
    } catch (err) {
      next(err);
    }
  },
);

// ── CHANGE own password (self-service) ─────────────────────────
router.patch(
  "/me/change-password",
  [
    body("current_password").notEmpty(),
    body("new_password")
      .isLength({ max: PASSWORD_MAX_LENGTH })
      .withMessage(`Password must be at most ${PASSWORD_MAX_LENGTH} characters`)
      .bail()
      .custom(assertPasswordPolicy),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty())
        return res.status(400).json({ errors: errors.array() });

      const { current_password, new_password } = req.body;

      const { rows } = await pool.query(
        "SELECT id, password_hash FROM users WHERE id = $1",
        [req.user.id],
      );
      if (!rows.length)
        return res.status(404).json({ error: "User not found" });

      const match = await bcrypt.compare(
        current_password,
        rows[0].password_hash,
      );
      if (!match)
        return res.status(400).json({ error: "Current password is incorrect" });

      const password_hash = await bcrypt.hash(new_password, SALT_ROUNDS);
      await pool.query("UPDATE users SET password_hash = $1 WHERE id = $2", [
        password_hash,
        req.user.id,
      ]);

      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata, ip_address)
         VALUES ($1, 'password_changed', 'users', $2, $3, $4)`,
        [
          req.user.id,
          req.user.id,
          JSON.stringify({ action: "self_password_change" }),
          req.ip,
        ],
      );

      res.json({ message: "Password changed successfully" });
    } catch (err) {
      next(err);
    }
  },
);

// ── UNLOCK a locked staff account ─────────────────────────────
router.patch(
  "/:id/unlock",
  requireOfficeSuperAdmin,
  param("id").isUUID(),
  async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty())
      return res.status(400).json({ errors: errors.array() });

    const { id } = req.params;

    const existing = await pool.query(
      "SELECT id, email, locked_until FROM users WHERE id = $1 AND role = $2",
      [id, ownRole(req)],
    );
    if (!existing.rows.length)
      return res.status(404).json({ error: "Staff member not found" });

    await pool.query(
      "UPDATE users SET failed_attempts = 0, locked_until = NULL WHERE id = $1",
      [id],
    );

    await pool.query(
      `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata, ip_address)
         VALUES ($1, 'account_unlocked', 'users', $2, $3, $4)`,
      [
        req.user.id,
        id,
        JSON.stringify({
          unlocked_by: req.user.id,
          email: existing.rows[0].email,
        }),
        req.ip,
      ],
    );

    res.json({ message: "Account unlocked successfully" });
  } catch (err) {
    next(err);
  }
  },
);

// ── POST /alerts/mark-all-read — dismiss all alerts for the admin's role ─────
router.post("/alerts/mark-all-read", async (req, res, next) => {
  try {
    await pool.query(
      `UPDATE staff_alerts SET is_read = TRUE, read_at = COALESCE(read_at, NOW())
        WHERE target_role = $1 AND is_read = FALSE`,
      [ownRole(req)],
    );
    res.json({ message: "All alerts marked as read." });
  } catch (err) {
    next(err);
  }
});

// ── PATCH /alerts/:id/read ─────────────────────────────────────
router.patch("/alerts/:id/read", async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `UPDATE staff_alerts
          SET is_read = TRUE, read_at = COALESCE(read_at, NOW())
        WHERE id = $1 AND target_role = $2
        RETURNING id`,
      [req.params.id, ownRole(req)],
    );
    if (!rows.length) return res.status(404).json({ error: "Alert not found" });
    res.json({ message: "Alert marked as read." });
  } catch (err) {
    next(err);
  }
});

// ── POST /staff/breach-report (REQ-2.17.6) ───────────────────────────────────
// Generates and logs a breach incident report for NPC 72-hour notification.
router.post(
  "/breach-report",
  [
    body("nature_of_breach").isString().notEmpty().trim(),
    body("affected_categories").isArray({ min: 1 }),
    body("estimated_subjects").isInt({ min: 0 }),
    body("discovery_date").isISO8601(),
    body("notes").optional().isString().trim(),
  ],
  async (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty())
      return res.status(422).json({ message: errors.array()[0].msg });

    try {
      const {
        nature_of_breach,
        affected_categories,
        estimated_subjects,
        discovery_date,
        notes,
      } = req.body;

      const reportId = crypto.randomUUID();
      const generatedAt = new Date().toISOString();

      // Log the breach event in audit_logs for accountability
      await pool.query(
        `INSERT INTO audit_logs (user_id, action, metadata)
         VALUES ($1, 'breach_incident_report_generated', $2)`,
        [
          req.user.id,
          JSON.stringify({
            report_id: reportId,
            nature_of_breach,
            affected_categories,
            estimated_subjects,
            discovery_date,
            generated_by_role: req.user.role,
          }),
        ],
      );

      // Build a formatted plain-text report for NPC submission
      const formattedReport = [
        "===================================================",
        "       DATA BREACH INCIDENT REPORT",
        "       iDetect System — Valenzuela City LGU",
        "===================================================",
        `Report ID       : ${reportId}`,
        `Generated At    : ${new Date(generatedAt).toLocaleString("en-PH", { timeZone: "Asia/Manila" })} (PHT)`,
        `Reported By     : ${req.user.full_name || req.user.email} (${req.user.role})`,
        "",
        "SECTION 1 — NATURE OF THE BREACH",
        "-".repeat(50),
        nature_of_breach,
        "",
        "SECTION 2 — AFFECTED DATA CATEGORIES",
        "-".repeat(50),
        affected_categories.map((c) => `  • ${c}`).join("\n"),
        "",
        "SECTION 3 — SCOPE",
        "-".repeat(50),
        `Estimated number of affected data subjects: ${estimated_subjects.toLocaleString()}`,
        `Date/Time breach was discovered: ${new Date(discovery_date).toLocaleString("en-PH", { timeZone: "Asia/Manila" })} (PHT)`,
        "",
        "SECTION 4 — ADDITIONAL NOTES",
        "-".repeat(50),
        notes || "(none)",
        "",
        "===================================================",
        "NOTE: Under Republic Act 10173 (Data Privacy Act of 2012),",
        "this breach must be reported to the National Privacy Commission",
        "within 72 hours of discovery.",
        "NPC Breach Notification: https://www.privacy.gov.ph",
        "===================================================",
      ].join("\n");

      res.status(201).json({
        report_id: reportId,
        generated_at: generatedAt,
        formatted_report: formattedReport,
      });
    } catch (err) {
      next(err);
    }
  },
);

module.exports = router;
