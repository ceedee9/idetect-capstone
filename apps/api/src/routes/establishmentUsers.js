const express = require("express");
const bcrypt = require("bcryptjs");
const crypto = require("crypto");
const { body, param, validationResult } = require("express-validator");
const pool = require("../config/database");
const { sendEstablishmentUserInvitation } = require("../services/emailService");
const { isEstablishmentEmailTaken } = require("../utils/emailAvailability");
const {
  authenticateEstablishment,
} = require("../middleware/auth");

const router = express.Router();
const SALT_ROUNDS = 12;

router.use(authenticateEstablishment);

function requireSuperUser(req, res, next) {
  if (req.establishment?.role !== "establishment_super_user") {
    return res.status(403).json({
      error: "Only an establishment Super User can manage user accounts",
    });
  }
  next();
}

function validationError(req, res) {
  const errors = validationResult(req);
  return errors.isEmpty() ? null : res.status(400).json({ errors: errors.array() });
}

function establishmentId(req) {
  return req.establishment.id;
}

function actorId(req) {
  return req.establishment.establishment_user_id || null;
}

// List only users belonging to the authenticated establishment.
router.get("/", async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, email, full_name, role, account_status,
              CASE
                WHEN invitation_status = 'pending'
                 AND invitation_token_expires <= NOW() THEN 'expired'
                ELSE invitation_status
              END AS invitation_status,
              password_reset_required, last_login_at, created_at, updated_at
         FROM establishment_users
        WHERE establishment_id = $1
        ORDER BY created_at DESC`,
      [establishmentId(req)],
    );
    res.json({ users: rows });
  } catch (err) {
    next(err);
  }
});

// Create a regular user with an expiring invitation.
router.post(
  "/",
  requireSuperUser,
  [
    body("email").isEmail().normalizeEmail(),
    body("full_name").trim().isLength({ min: 2, max: 255 }),
  ],
  async (req, res, next) => {
    try {
      const errorResponse = validationError(req, res);
      if (errorResponse) return errorResponse;

      const { email, full_name } = req.body;
      const duplicate = await isEstablishmentEmailTaken(pool, email);
      if (duplicate) {
        return res.status(409).json({ error: "Email already registered" });
      }

      const invitationToken = crypto.randomBytes(32).toString("hex");
      const invitationTokenHash = crypto
        .createHash("sha256")
        .update(invitationToken)
        .digest("hex");
      const unusablePasswordHash = await bcrypt.hash(
        crypto.randomBytes(32).toString("hex"),
        SALT_ROUNDS,
      );
      const created = await pool.query(
        `INSERT INTO establishment_users
          (establishment_id, email, password_hash, full_name, role,
           account_status, invitation_status, created_by_user_id,
           invitation_token_hash, invitation_token_expires)
         VALUES ($1, $2, $3, $4, 'establishment_regular_user',
                 'inactive', 'pending', $5, $6, NOW() + INTERVAL '24 hours')
         RETURNING id, email, full_name, role, account_status, invitation_status,
                   password_reset_required, last_login_at, created_at, updated_at`,
        [
          establishmentId(req),
          email,
          unusablePasswordHash,
          full_name,
          actorId(req),
          invitationTokenHash,
        ],
      );

      await pool.query(
        `INSERT INTO audit_logs
          (establishment_id, action, target_table, target_id, metadata, ip_address)
         VALUES ($1, 'establishment_user_invited', 'establishment_users', $2, $3, $4)`,
        [
          establishmentId(req),
          created.rows[0].id,
          JSON.stringify({
            actor_user_id: actorId(req),
            email,
            role: "establishment_regular_user",
            invitation_status: "pending",
          }),
          req.ip,
        ],
      );

      const invitationOrigin =
        process.env.ESTABLISHMENT_PORTAL_ORIGIN ||
        process.env.ALLOWED_PORTAL_ORIGINS?.split(",")[0] ||
        "https://idetect.it.com";
      const invitationUrl =
        `${invitationOrigin.replace(/\/$/, "")}/establishment/accept-invitation` +
        `?token=${invitationToken}&email=${encodeURIComponent(email)}`;
      const emailResult = await sendEstablishmentUserInvitation({
        business_name: req.establishment.name || "your establishment",
        full_name,
        email,
        invitationUrl,
      });
      if (!emailResult.success) {
        return res.status(502).json({
          error: "User was created, but the invitation email could not be sent.",
          user: created.rows[0],
        });
      }
      res.status(201).json({ user: created.rows[0], invitation_sent: true });
    } catch (err) {
      next(err);
    }
  },
);

// Activate or deactivate a regular user in the same establishment.
router.patch(
  "/:id/status",
  requireSuperUser,
  [
    param("id").isUUID(),
    body("account_status").isIn(["active", "inactive", "suspended"]),
  ],
  async (req, res, next) => {
    try {
      const errorResponse = validationError(req, res);
      if (errorResponse) return errorResponse;

      const { id } = req.params;
      const { account_status } = req.body;
      const existing = await pool.query(
        `SELECT id, email, role, account_status
           FROM establishment_users
          WHERE id = $1 AND establishment_id = $2`,
        [id, establishmentId(req)],
      );
      if (!existing.rows.length) {
        return res.status(404).json({ error: "Establishment user not found" });
      }
      if (existing.rows[0].role !== "establishment_regular_user") {
        return res.status(403).json({ error: "Super User accounts cannot be changed here" });
      }

      const updated = await pool.query(
        `UPDATE establishment_users
            SET account_status = $1
          WHERE id = $2 AND establishment_id = $3
          RETURNING id, email, full_name, role, account_status, invitation_status,
                    password_reset_required, last_login_at, created_at, updated_at`,
        [account_status, id, establishmentId(req)],
      );
      const action =
        account_status === "active"
          ? "establishment_user_activated"
          : "establishment_user_deactivated";
      await pool.query(
        `INSERT INTO audit_logs
          (establishment_id, action, target_table, target_id, metadata, ip_address)
         VALUES ($1, $2, 'establishment_users', $3, $4, $5)`,
        [
          establishmentId(req),
          action,
          id,
          JSON.stringify({
            actor_user_id: actorId(req),
            previous_status: existing.rows[0].account_status,
            new_status: account_status,
          }),
          req.ip,
        ],
      );
      res.json({ user: updated.rows[0] });
    } catch (err) {
      next(err);
    }
  },
);

// Replace a pending or expired invitation with a fresh single-use token.
router.post(
  "/:id/resend-invitation",
  requireSuperUser,
  [param("id").isUUID()],
  async (req, res, next) => {
    try {
      const errorResponse = validationError(req, res);
      if (errorResponse) return errorResponse;

      const existing = await pool.query(
        `SELECT id, email, full_name, role, invitation_status
           FROM establishment_users
          WHERE id = $1 AND establishment_id = $2`,
        [req.params.id, establishmentId(req)],
      );
      if (!existing.rows.length) {
        return res.status(404).json({ error: "Establishment user not found" });
      }
      const user = existing.rows[0];
      if (user.role !== "establishment_regular_user") {
        return res.status(400).json({ error: "Only Regular Users can receive invitations" });
      }
      if (user.invitation_status === "accepted") {
        return res.status(400).json({ error: "This invitation has already been accepted" });
      }
      if (user.invitation_status === "revoked") {
        return res.status(400).json({ error: "This invitation has been revoked" });
      }

      const invitationToken = crypto.randomBytes(32).toString("hex");
      const invitationTokenHash = crypto
        .createHash("sha256")
        .update(invitationToken)
        .digest("hex");
      await pool.query(
        `UPDATE establishment_users
            SET invitation_status = 'pending',
                invitation_token_hash = $1,
                invitation_token_expires = NOW() + INTERVAL '24 hours',
                account_status = 'inactive'
          WHERE id = $2 AND establishment_id = $3`,
        [invitationTokenHash, req.params.id, establishmentId(req)],
      );

      const invitationOrigin =
        process.env.ESTABLISHMENT_PORTAL_ORIGIN ||
        process.env.ALLOWED_PORTAL_ORIGINS?.split(",")[0] ||
        "https://idetect.it.com";
      const invitationUrl =
        `${invitationOrigin.replace(/\/$/, "")}/establishment/accept-invitation` +
        `?token=${invitationToken}&email=${encodeURIComponent(user.email)}`;
      const emailResult = await sendEstablishmentUserInvitation({
        business_name: req.establishment.name || "your establishment",
        full_name: user.full_name,
        email: user.email,
        invitationUrl,
      });
      if (!emailResult.success) {
        return res.status(502).json({
          error: "The invitation was renewed, but the email could not be sent.",
        });
      }

      await pool.query(
        `INSERT INTO audit_logs
          (establishment_id, action, target_table, target_id, metadata, ip_address)
         VALUES ($1, 'establishment_user_invitation_resent', 'establishment_users', $2, $3, $4)`,
        [
          establishmentId(req),
          req.params.id,
          JSON.stringify({ actor_user_id: actorId(req), email: user.email }),
          req.ip,
        ],
      );
      res.json({ message: "Invitation resent successfully" });
    } catch (err) {
      next(err);
    }
  },
);

// Revoke an unused invitation and invalidate its token.
router.post(
  "/:id/revoke-invitation",
  requireSuperUser,
  [param("id").isUUID()],
  async (req, res, next) => {
    try {
      const errorResponse = validationError(req, res);
      if (errorResponse) return errorResponse;

      const updated = await pool.query(
        `UPDATE establishment_users
            SET invitation_status = 'revoked',
                invitation_token_hash = NULL,
                invitation_token_expires = NULL,
                account_status = 'inactive'
          WHERE id = $1 AND establishment_id = $2
            AND role = 'establishment_regular_user'
            AND invitation_status = 'pending'
          RETURNING id, email`,
        [req.params.id, establishmentId(req)],
      );
      if (!updated.rows.length) {
        return res.status(404).json({
          error: "Pending invitation not found",
        });
      }

      await pool.query(
        `INSERT INTO audit_logs
          (establishment_id, action, target_table, target_id, metadata, ip_address)
         VALUES ($1, 'establishment_user_invitation_revoked', 'establishment_users', $2, $3, $4)`,
        [
          establishmentId(req),
          req.params.id,
          JSON.stringify({ actor_user_id: actorId(req), email: updated.rows[0].email }),
          req.ip,
        ],
      );
      res.json({ message: "Invitation revoked" });
    } catch (err) {
      next(err);
    }
  },
);

router.patch(
  "/:id/role",
  requireSuperUser,
  [
    param("id").isUUID(),
    body("role").isIn([
      "establishment_super_user",
      "establishment_regular_user",
    ]),
  ],
  async (req, res, next) => {
    try {
      const errorResponse = validationError(req, res);
      if (errorResponse) return errorResponse;
      const existing = await pool.query(
        `SELECT id, role FROM establishment_users
          WHERE id = $1 AND establishment_id = $2`,
        [req.params.id, establishmentId(req)],
      );
      if (!existing.rows.length) {
        return res.status(404).json({ error: "Establishment user not found" });
      }
      if (existing.rows[0].role === req.body.role) {
        return res.status(400).json({ error: "User already has this role" });
      }
      if (req.params.id === actorId(req)) {
        return res.status(400).json({ error: "Cannot change your own role" });
      }
      const updated = await pool.query(
        `UPDATE establishment_users
            SET role = $1
          WHERE id = $2 AND establishment_id = $3
          RETURNING id, email, full_name, role, account_status, invitation_status,
                    password_reset_required, last_login_at, created_at, updated_at`,
        [req.body.role, req.params.id, establishmentId(req)],
      );
      await pool.query(
        `INSERT INTO audit_logs
          (establishment_id, action, target_table, target_id, metadata, ip_address)
         VALUES ($1, 'establishment_user_role_changed', 'establishment_users', $2, $3, $4)`,
        [
          establishmentId(req),
          req.params.id,
          JSON.stringify({
            actor_user_id: actorId(req),
            previous_role: existing.rows[0].role,
            new_role: req.body.role,
          }),
          req.ip,
        ],
      );
      return res.json({ user: updated.rows[0] });
    } catch (err) {
      next(err);
    }
  },
);

router.patch(
  "/:id/reset-password",
  requireSuperUser,
  [param("id").isUUID(), body("password").isLength({ min: 8, max: 128 })],
  async (req, res, next) => {
    try {
      const errorResponse = validationError(req, res);
      if (errorResponse) return errorResponse;

      const existing = await pool.query(
        `SELECT id, email, role FROM establishment_users
          WHERE id = $1 AND establishment_id = $2`,
        [req.params.id, establishmentId(req)],
      );
      if (!existing.rows.length) {
        return res.status(404).json({ error: "Establishment user not found" });
      }
      if (existing.rows[0].role !== "establishment_regular_user") {
        return res.status(403).json({ error: "Super User passwords cannot be reset here" });
      }

      const passwordHash = await bcrypt.hash(req.body.password, SALT_ROUNDS);
      await pool.query(
        `UPDATE establishment_users
            SET password_hash = $1, password_reset_required = FALSE,
                failed_attempts = 0, locked_until = NULL, account_status = 'active'
          WHERE id = $2 AND establishment_id = $3`,
        [passwordHash, req.params.id, establishmentId(req)],
      );
      await pool.query(
        `INSERT INTO audit_logs
          (establishment_id, action, target_table, target_id, metadata, ip_address)
         VALUES ($1, 'establishment_user_password_reset', 'establishment_users', $2, $3, $4)`,
        [
          establishmentId(req),
          req.params.id,
          JSON.stringify({ actor_user_id: actorId(req), email: existing.rows[0].email }),
          req.ip,
        ],
      );
      res.json({ message: "Password reset successfully" });
    } catch (err) {
      next(err);
    }
  },
);

module.exports = router;
