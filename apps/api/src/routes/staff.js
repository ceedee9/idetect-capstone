// src/routes/staff.js
// Staff user management — list, create, update, deactivate, reset password.
// All endpoints require an authenticated admin of the SAME role.
// i.e. osca_admin can only manage osca_admin accounts, etc.

const express = require("express");
const bcrypt = require("bcryptjs");
const crypto = require("crypto");
const { body, param, validationResult } = require("express-validator");
const pool = require("../config/database");
const { authenticate, requireRole } = require("../middleware/auth");

const router = express.Router();
const SALT_ROUNDS = 12;

// Every endpoint requires staff auth
router.use(authenticate);
router.use(requireRole(["osca_admin", "pdao_admin", "bplo_admin"]));

// Helper: admins can only manage users of their own role
function ownRole(req) {
  return req.user.role;
}

// ── LIST staff of same role ────────────────────────────────────
router.get("/", async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, email, full_name, role, is_active, created_at, updated_at
         FROM users
        WHERE role = $1
        ORDER BY created_at DESC`,
      [ownRole(req)],
    );
    res.json({ staff: rows });
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
           FROM users WHERE id = $1 AND role = $2`,
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
  [
    body("email").isEmail().normalizeEmail(),
    body("full_name").trim().isLength({ min: 2, max: 255 }),
    body("password").isLength({ min: 8, max: 128 }),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty())
        return res.status(400).json({ errors: errors.array() });

      const { email, full_name, password } = req.body;
      const role = ownRole(req);

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

      // Verify target exists and is same role
      const existing = await pool.query(
        "SELECT id FROM users WHERE id = $1 AND role = $2",
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

      res.json({ staff: rows[0] });
    } catch (err) {
      next(err);
    }
  },
);

// ── TOGGLE active status (activate / deactivate) ──────────────
router.patch(
  "/:id/toggle-active",
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
        "SELECT id, is_active FROM users WHERE id = $1 AND role = $2",
        [id, ownRole(req)],
      );
      if (!existing.rows.length)
        return res.status(404).json({ error: "Staff member not found" });

      const newStatus = !existing.rows[0].is_active;
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
  [param("id").isUUID(), body("password").isLength({ min: 8, max: 128 })],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty())
        return res.status(400).json({ errors: errors.array() });

      const { id } = req.params;

      const existing = await pool.query(
        "SELECT id FROM users WHERE id = $1 AND role = $2",
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
    body("new_password").isLength({ min: 8, max: 128 }),
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
router.patch("/:id/unlock", param("id").isUUID(), async (req, res, next) => {
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
});

module.exports = router;
