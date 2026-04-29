// src/routes/notifications.js
// Notification endpoints for the Beneficiary Mobile Application.
//
//   GET   /api/notifications            — List notifications for authenticated beneficiary
//   GET   /api/notifications/unread-count — Get unread count
//   PATCH /api/notifications/:id/read   — Mark a notification as read
//   PATCH /api/notifications/read-all   — Mark all as read
//   POST  /api/notifications/unauthorized-use — Report unauthorized credential use (REQ-2.11.4)

const express = require("express");
const { body, validationResult } = require("express-validator");
const pool = require("../config/database");
const { authenticateBeneficiary } = require("../middleware/auth");
const { createError } = require("../middleware/errorHandler");

const router = express.Router();

// All routes require beneficiary authentication
router.use(authenticateBeneficiary);

// ── GET /api/notifications ─────────────────────────────────────
// REQ-2.11.5: Complete transaction notification history
router.get("/", async (req, res, next) => {
  try {
    const accountId = req.beneficiary.id || req.beneficiary.accountId;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 30;
    const offset = (page - 1) * limit;

    const result = await pool.query(
      `SELECT
         n.id, n.notification_type, n.title, n.body, n.channel,
         n.verification_log_id, n.dispute_id, n.is_read, n.sent_at,
         vl.result        AS verification_result,
         vl.verified_at   AS verification_time,
         e.business_name  AS establishment_name
       FROM notifications n
       LEFT JOIN verification_logs vl ON vl.id = n.verification_log_id
       LEFT JOIN establishments e ON e.id = vl.establishment_id
       WHERE n.beneficiary_account_id = $1
       ORDER BY n.sent_at DESC
       LIMIT $2 OFFSET $3`,
      [accountId, limit, offset],
    );

    const countResult = await pool.query(
      "SELECT COUNT(*) FROM notifications WHERE beneficiary_account_id = $1",
      [accountId],
    );

    res.json({
      data: result.rows,
      pagination: {
        page,
        limit,
        total: parseInt(countResult.rows[0].count),
        pages: Math.ceil(countResult.rows[0].count / limit),
      },
    });
  } catch (err) {
    next(err);
  }
});

// ── GET /api/notifications/unread-count ────────────────────────
router.get("/unread-count", async (req, res, next) => {
  try {
    const result = await pool.query(
      "SELECT COUNT(*) FROM notifications WHERE beneficiary_account_id = $1 AND is_read = FALSE",
      [req.beneficiary.id || req.beneficiary.accountId],
    );
    res.json({ count: parseInt(result.rows[0].count) });
  } catch (err) {
    next(err);
  }
});

// ── PATCH /api/notifications/:id/read ──────────────────────────
router.patch("/:id/read", async (req, res, next) => {
  try {
    const result = await pool.query(
      `UPDATE notifications SET is_read = TRUE
       WHERE id = $1 AND beneficiary_account_id = $2
       RETURNING id`,
      [req.params.id, req.beneficiary.id || req.beneficiary.accountId],
    );
    if (!result.rows.length) throw createError(404, "Notification not found");
    res.json({ message: "Marked as read." });
  } catch (err) {
    next(err);
  }
});

// ── PATCH /api/notifications/read-all ──────────────────────────
router.patch("/read-all", async (req, res, next) => {
  try {
    await pool.query(
      "UPDATE notifications SET is_read = TRUE WHERE beneficiary_account_id = $1 AND is_read = FALSE",
      [req.beneficiary.id || req.beneficiary.accountId],
    );
    res.json({ message: "All notifications marked as read." });
  } catch (err) {
    next(err);
  }
});

// ── POST /api/notifications/unauthorized-use ───────────────────
// REQ-2.11.4: Beneficiary reports unauthorized credential use
// directly from the transaction notification interface.
router.post(
  "/unauthorized-use",
  [
    body("verification_log_id").isUUID(),
    body("statement").optional().isString().trim(),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const accountId = req.beneficiary.id || req.beneficiary.accountId;
      const { verification_log_id, statement } = req.body;

      // Verify this notification belongs to this beneficiary
      const logResult = await pool.query(
        `SELECT vl.id, vl.establishment_id, vl.id_number_scanned,
              vl.beneficiary_type_detected, vl.beneficiary_id
       FROM verification_logs vl
       JOIN beneficiary_accounts ba ON ba.beneficiary_id = vl.beneficiary_id
       WHERE vl.id = $1 AND ba.id = $2`,
        [verification_log_id, accountId],
      );

      if (!logResult.rows.length) {
        throw createError(
          404,
          "Verification transaction not found or does not belong to your account.",
        );
      }

      const log = logResult.rows[0];

      // Create a fraud flag for this unauthorized use
      const flagResult = await pool.query(
        `INSERT INTO fraud_flags
         (verification_log_id, establishment_id, beneficiary_id,
          id_number_flagged, beneficiary_type, flag_status, establishment_notes)
       VALUES ($1, $2, $3, $4, $5, 'pending', $6)
       RETURNING id`,
        [
          verification_log_id,
          log.establishment_id,
          log.beneficiary_id,
          log.id_number_scanned,
          log.beneficiary_type_detected,
          `UNAUTHORIZED USE REPORTED BY BENEFICIARY: ${statement || "No additional details provided."}`,
        ],
      );

      // Audit log
      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
       VALUES ($1, 'unauthorized_use_reported', 'fraud_flags', $2, $3)`,
        [
          null, // beneficiary doesn't have a user_id in users table
          flagResult.rows[0].id,
          JSON.stringify({
            beneficiary_account_id: accountId,
            verification_log_id,
            reported_by: "beneficiary",
          }),
        ],
      );

      res.status(201).json({
        message:
          "Unauthorized use alert submitted. The relevant office has been notified for investigation.",
        flag_id: flagResult.rows[0].id,
      });
    } catch (err) {
      next(err);
    }
  },
);

module.exports = router;
