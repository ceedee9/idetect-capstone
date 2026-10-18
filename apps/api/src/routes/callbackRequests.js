// ── Establishment callback requests (A-18) ─────────────────────
//   GET   /api/callback-requests       — staff queue (BPLO: all, OSCA/PDAO: own type, read-only)
//   PATCH /api/callback-requests/:id   — BPLO updates status and adds a staff note
const express = require("express");
const { body, validationResult } = require("express-validator");
const pool = require("../config/database");
const { authenticate, requireRole } = require("../middleware/auth");
const { createError } = require("../middleware/errorHandler");
const { sendPushNotification } = require("../services/fcmService");

const router = express.Router();

const STAFF_ROLES = ["bplo_admin", "osca_admin", "pdao_admin"];
const TYPE_BY_PORTAL_ROLE = { osca_admin: "senior_citizen", pdao_admin: "pwd" };

// ── GET /api/callback-requests ─────────────────────────────────
router.get(
  "/",
  authenticate,
  requireRole(STAFF_ROLES),
  async (req, res, next) => {
    try {
      const status = ["open", "handled"].includes(req.query.status)
        ? req.query.status
        : null;
      const page = parseInt(req.query.page) || 1;
      const limit = Math.min(parseInt(req.query.limit) || 20, 50);
      const offset = (page - 1) * limit;

      const conditions = [];
      const params = [];
      const beneficiaryType = TYPE_BY_PORTAL_ROLE[req.user.portalRole];
      if (beneficiaryType) {
        params.push(beneficiaryType);
        conditions.push(`b.beneficiary_type = $${params.length}`);
      }
      if (status) {
        params.push(status);
        conditions.push(`r.status = $${params.length}`);
      }
      const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";

      const joins = `
        FROM establishment_callback_requests r
        JOIN beneficiary_accounts ba ON ba.id = r.beneficiary_account_id
        JOIN beneficiaries b ON b.id = ba.beneficiary_id`;

      const countResult = await pool.query(
        `SELECT COUNT(*) ${joins} ${where}`,
        params,
      );

      params.push(limit, offset);
      const result = await pool.query(
        `SELECT
           r.id, r.reason, r.note, r.status, r.staff_note,
           r.verification_log_id, r.created_at, r.handled_at,
           b.full_name          AS beneficiary_name,
           b.id_number          AS beneficiary_id_number,
           b.beneficiary_type,
           e.business_name      AS establishment_name,
           u.email              AS handled_by_email
         ${joins}
         JOIN establishments e ON e.id = r.establishment_id
         LEFT JOIN users u ON u.id = r.handled_by
         ${where}
         ORDER BY CASE r.status WHEN 'open' THEN 1 ELSE 2 END, r.created_at DESC
         LIMIT $${params.length - 1} OFFSET $${params.length}`,
        params,
      );

      const total = parseInt(countResult.rows[0].count);

      res.json({
        data: result.rows.map((row) => ({
          ...row,
          reference: row.id.slice(0, 8).toUpperCase(),
        })),
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit),
        },
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── PATCH /api/callback-requests/:id ───────────────────────────
// Only BPLO replies. Marking a request handled notifies the beneficiary.
router.patch(
  "/:id",
  authenticate,
  requireRole(["bplo_admin"]),
  [
    body("status")
      .optional()
      .isIn(["open", "handled"])
      .withMessage("Invalid status"),
    body("staff_note")
      .optional({ nullable: true })
      .isString()
      .trim()
      .isLength({ max: 300 })
      .withMessage("Staff note must be 300 characters or fewer"),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const { id } = req.params;
      const { status, staff_note } = req.body;
      if (status === undefined && staff_note === undefined) {
        throw createError(400, "Nothing to update");
      }

      const currentResult = await pool.query(
        "SELECT * FROM establishment_callback_requests WHERE id = $1",
        [id],
      );
      const current = currentResult.rows[0];
      if (!current) {
        throw createError(404, "Callback request not found");
      }

      const nextStatus = status !== undefined ? status : current.status;
      const becomingHandled =
        nextStatus === "handled" && current.status !== "handled";
      const nextStaffNote =
        staff_note === undefined ? current.staff_note : staff_note || null;

      let handledBy = current.handled_by;
      let handledAt = current.handled_at;
      if (becomingHandled) {
        handledBy = req.user.id;
        handledAt = new Date();
      }
      if (nextStatus === "open") {
        handledBy = null;
        handledAt = null;
      }

      let updated;
      try {
        updated = await pool.query(
          `UPDATE establishment_callback_requests
           SET status = $2, staff_note = $3, handled_by = $4, handled_at = $5
           WHERE id = $1
           RETURNING *`,
          [id, nextStatus, nextStaffNote, handledBy, handledAt],
        );
      } catch (err) {
        if (err.code === "23505") {
          throw createError(
            409,
            "This beneficiary already has an open request for this establishment",
          );
        }
        throw err;
      }

      if (becomingHandled) {
        const infoResult = await pool.query(
          `SELECT e.business_name, ba.device_token
           FROM establishments e
           JOIN beneficiary_accounts ba ON ba.id = $2
           WHERE e.id = $1`,
          [current.establishment_id, current.beneficiary_account_id],
        );
        const info = infoResult.rows[0];
        const notifTitle = "Callback Request Handled";
        const notifBody = `Your request to contact ${info?.business_name || "the establishment"} (Ref: ${id.slice(0, 8).toUpperCase()}) has been handled by BPLO. Open the app for details.`;

        await pool.query(
          `INSERT INTO notifications
           (beneficiary_account_id, notification_type, title, body, channel)
         VALUES ($1, 'callback_request_handled', $2, $3, 'push')`,
          [current.beneficiary_account_id, notifTitle, notifBody],
        );

        if (info?.device_token) {
          sendPushNotification(info.device_token, notifTitle, notifBody, {
            type: "callback_request_handled",
            request_id: id,
          })
            .then((fcmResult) => {
              if (fcmResult.invalidToken) {
                pool
                  .query(
                    "UPDATE beneficiary_accounts SET device_token = NULL WHERE id = $1",
                    [current.beneficiary_account_id],
                  )
                  .catch(() => {});
              }
            })
            .catch(() => {});
        }
      }

      await pool.query(
        `INSERT INTO audit_logs (user_id, establishment_id, action, target_table, target_id, metadata)
       VALUES ($1, $2, $3, 'establishment_callback_requests', $4, $5)`,
        [
          req.user.id,
          current.establishment_id,
          becomingHandled ? "callback_request_handled" : "callback_request_updated",
          id,
          JSON.stringify({
            from_status: current.status,
            to_status: nextStatus,
            staff_note_changed: nextStaffNote !== current.staff_note,
          }),
        ],
      );

      res.json({
        message: "Callback request updated.",
        data: updated.rows[0],
      });
    } catch (err) {
      next(err);
    }
  },
);

module.exports = router;
