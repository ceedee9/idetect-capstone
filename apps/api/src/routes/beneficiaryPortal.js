// src/routes/beneficiaryPortal.js
// Beneficiary-facing endpoints for the mobile app.
// All routes require beneficiary authentication (OTP-based JWT).
//
//   GET  /api/beneficiary-portal/me               — Profile + ID status (REQ-2.12)
//   GET  /api/beneficiary-portal/transactions      — Verification transaction history
//   POST /api/beneficiary-portal/fraud-report       — Report fraud from beneficiary side (REQ-2.14)

const express = require("express");
const { body, validationResult } = require("express-validator");
const pool = require("../config/database");
const { authenticateBeneficiary } = require("../middleware/auth");
const { createError } = require("../middleware/errorHandler");
const { maskBeneficiary } = require("../utils/privacy");
const { createStaffAlert } = require("../services/staffAlerts");

const router = express.Router();

// All routes require beneficiary authentication
router.use(authenticateBeneficiary);

// ── GET /api/beneficiary-portal/me ─────────────────────────────
// REQ-2.12: Beneficiary views their own ID status
router.get("/me", async (req, res, next) => {
  try {
    const beneficiaryId =
      req.beneficiary.beneficiary_id || req.beneficiary.beneficiaryId;

    const result = await pool.query(
      `SELECT
         b.id, b.id_number, b.full_name, b.birthdate,
         b.beneficiary_type, b.issuing_office,
         b.validity_start, b.validity_end,
         b.status, b.status_reason, b.suspension_start_date,
         b.suspension_end_date, b.registered_mobile,
         b.created_at, b.updated_at,
         (SELECT COUNT(*) FROM verification_logs vl WHERE vl.beneficiary_id = b.id) AS total_verifications,
         (SELECT COUNT(*) FROM fraud_flags ff WHERE ff.beneficiary_id = b.id AND ff.flag_status = 'pending') AS pending_flags,
         (SELECT COUNT(*) FROM disputes d WHERE d.beneficiary_account_id = $2) AS active_disputes
       FROM beneficiaries b
       WHERE b.id = $1`,
      [beneficiaryId, req.beneficiary.id || req.beneficiary.accountId],
    );

    if (!result.rows.length) {
      throw createError(404, "Beneficiary record not found");
    }

    const b = result.rows[0];

    // Determine effective status considering expiry
    let effectiveStatus = b.status;
    if (b.status === "active" && new Date(b.validity_end) < new Date()) {
      effectiveStatus = "expired";
    }

    const suspensionEnd = b.suspension_end_date
      ? new Date(b.suspension_end_date)
      : null;
    const today = new Date();
    const todayDate = new Date(
      today.getFullYear(),
      today.getMonth(),
      today.getDate(),
    );
    const suspensionDaysRemaining = suspensionEnd
      ? Math.ceil((suspensionEnd - todayDate) / 86400000)
      : null;

    // The beneficiary is viewing their own record; the app masks the ID by default.
    const profile = maskBeneficiary({
      id: b.id,
      id_number: b.id_number,
      full_name: b.full_name,
      birthdate: b.birthdate,
      beneficiary_type: b.beneficiary_type,
      issuing_office: b.issuing_office,
      validity_start: b.validity_start,
      validity_end: b.validity_end,
      status: effectiveStatus,
      status_reason: b.status_reason,
      suspension_start_date: b.suspension_start_date,
      suspension_end_date: b.suspension_end_date,
      suspension_days_remaining: suspensionDaysRemaining,
      registered_mobile: b.registered_mobile,
      stats: {
        total_verifications: parseInt(b.total_verifications),
        pending_flags: parseInt(b.pending_flags),
        active_disputes: parseInt(b.active_disputes),
      },
      updated_at: b.updated_at,
    });
    // This is the authenticated beneficiary's own profile. The Flutter app
    // masks the value by default and only reveals it from local state.
    profile.id_number = b.id_number;
    profile.id_number = b.id_number;
    res.json(profile);
  } catch (err) {
    next(err);
  }
});

// ── GET /api/beneficiary-portal/transactions ───────────────────
// REQ-2.11.5: Beneficiary views their verification/transaction history
router.get("/transactions", async (req, res, next) => {
  try {
    const beneficiaryId =
      req.beneficiary.beneficiary_id || req.beneficiary.beneficiaryId;
    const page = parseInt(req.query.page) || 1;
    const limit = Math.min(parseInt(req.query.limit) || 20, 50);
    const offset = (page - 1) * limit;

    const result = await pool.query(
      `SELECT
         vl.id, vl.reference_no, vl.result, vl.ocr_confidence_score,
         vl.manually_entered, vl.verified_at,
         vl.establishment_id,
         e.business_name AS establishment_name,
         e.address AS establishment_address
       FROM verification_logs vl
       LEFT JOIN establishments e ON e.id = vl.establishment_id
       WHERE vl.beneficiary_id = $1
       ORDER BY vl.verified_at DESC
       LIMIT $2 OFFSET $3`,
      [beneficiaryId, limit, offset],
    );

    const countResult = await pool.query(
      "SELECT COUNT(*) FROM verification_logs WHERE beneficiary_id = $1",
      [beneficiaryId],
    );

    const total = parseInt(countResult.rows[0].count);

    res.json({
      data: result.rows,
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
});

// ── POST /api/beneficiary-portal/fraud-report ──────────────────
// REQ-2.14: Beneficiary reports suspected fraud on their ID
router.post(
  "/fraud-report",
  [
    body("verification_log_id").optional().isUUID(),
    body("report_type")
      .isIn(["unauthorized_use", "stolen_id", "fake_id", "other"])
      .withMessage("Invalid report type"),
    body("description")
      .isString()
      .trim()
      .isLength({ min: 10, max: 2000 })
      .withMessage("Description must be 10-2000 characters"),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const beneficiaryId =
        req.beneficiary.beneficiary_id || req.beneficiary.beneficiaryId;
      const accountId = req.beneficiary.id || req.beneficiary.accountId;
      const { verification_log_id, report_type, description } = req.body;

      // Insert as a dispute with type mapping
      const disputeType =
        report_type === "unauthorized_use"
          ? "unauthorized_use"
          : report_type === "stolen_id"
            ? "unauthorized_use"
            : "incorrect_db_info";

      const result = await pool.query(
        `INSERT INTO disputes
         (beneficiary_account_id, verification_log_id, dispute_type, explanation)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
        [accountId, verification_log_id || null, disputeType, description],
      );

      const dispute = result.rows[0];

      // Staff alerts for new disputes are created by the database trigger
      // (migration 049), so every submission path notifies the right offices.

      // Also create a fraud flag if there's a verification log
      if (verification_log_id) {
        // Get the verification log details
        const vlResult = await pool.query(
          "SELECT establishment_id, id_number_scanned, beneficiary_type_detected FROM verification_logs WHERE id = $1",
          [verification_log_id],
        );

        if (vlResult.rows.length > 0) {
          const vl = vlResult.rows[0];
          await pool.query(
            `INSERT INTO fraud_flags
               (verification_log_id, establishment_id, beneficiary_id,
                id_number_flagged, beneficiary_type, establishment_notes)
             VALUES ($1, $2, $3, $4, $5, $6)
             ON CONFLICT DO NOTHING`,
            [
              verification_log_id,
              vl.establishment_id,
              beneficiaryId,
              vl.id_number_scanned,
              vl.beneficiary_type_detected,
              `Beneficiary self-report: ${report_type} — ${description}`,
            ],
          );
        }
      }

      // Notify beneficiary
      await pool.query(
        `INSERT INTO notifications
         (beneficiary_account_id, notification_type, title, body, channel, dispute_id)
       VALUES ($1, 'fraud_report_received', $2, $3, 'push', $4)`,
        [
          accountId,
          "Fraud Report Received",
          `Your fraud report (Ref: ${dispute.id.slice(0, 8).toUpperCase()}) has been submitted. We will investigate and update you.`,
          dispute.id,
        ],
      );

      // Audit log
      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
       VALUES ($1, 'fraud_report_submitted', 'disputes', $2, $3)`,
        [
          null,
          dispute.id,
          JSON.stringify({
            report_type,
            beneficiary_id: beneficiaryId,
          }),
        ],
      );

      res.status(201).json({
        message:
          "Fraud report submitted successfully. You will be notified of updates.",
        reference: dispute.id.slice(0, 8).toUpperCase(),
        dispute_id: dispute.id,
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── POST /api/beneficiary-portal/callback-requests ─────────────
// A-18: Beneficiary asks BPLO to contact an establishment they transacted with.
// The establishment's phone number is never returned to the beneficiary app.
router.post(
  "/callback-requests",
  [
    body("establishment_id").isUUID().withMessage("Invalid establishment"),
    body("reason")
      .isIn(["transaction_question", "record_correction", "other"])
      .withMessage("Invalid reason"),
    body("note").optional().isString().trim().isLength({ max: 500 }),
    body("verification_log_id").optional().isUUID(),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const beneficiaryId =
        req.beneficiary.beneficiary_id || req.beneficiary.beneficiaryId;
      const accountId = req.beneficiary.id || req.beneficiary.accountId;
      const { establishment_id, verification_log_id, reason } = req.body;
      const note = req.body.note || null;

      const establishmentResult = await pool.query(
        "SELECT id FROM establishments WHERE id = $1 AND status = 'approved'",
        [establishment_id],
      );
      if (establishmentResult.rows.length === 0) {
        return res.status(404).json({ error: "Establishment not found" });
      }

      // Only establishments the beneficiary has transacted with can be contacted.
      const transactionResult = await pool.query(
        `SELECT id FROM verification_logs
         WHERE beneficiary_id = $1
           AND establishment_id = $2
           AND ($3::uuid IS NULL OR id = $3::uuid)
         LIMIT 1`,
        [beneficiaryId, establishment_id, verification_log_id || null],
      );
      if (transactionResult.rows.length === 0) {
        return res.status(403).json({
          error: "You can only contact an establishment you have transacted with",
        });
      }

      let result;
      try {
        result = await pool.query(
          `INSERT INTO establishment_callback_requests
           (beneficiary_account_id, establishment_id, verification_log_id, reason, note)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id, created_at`,
          [
            accountId,
            establishment_id,
            verification_log_id || null,
            reason,
            note,
          ],
        );
      } catch (err) {
        if (err.code === "23505") {
          return res.status(409).json({
            error: "You already have an open request for this establishment",
          });
        }
        throw err;
      }

      const request = result.rows[0];

      await pool.query(
        `INSERT INTO audit_logs (user_id, establishment_id, action, target_table, target_id, metadata)
       VALUES (NULL, $1, 'callback_requested', 'establishment_callback_requests', $2, $3)`,
        [
          establishment_id,
          request.id,
          JSON.stringify({
            reason,
            beneficiary_account_id: accountId,
            verification_log_id: verification_log_id || null,
          }),
        ],
      );

      createStaffAlert({
        targetRole: "bplo_admin",
        alertType: "callback_requested",
        severity: "medium",
        title: "New Callback Request",
        body: `A beneficiary asked BPLO to contact an establishment they transacted with. Reference ${request.id.slice(0, 8).toUpperCase()}.`,
        targetRoute: "/callback-requests",
        dedupeKey: `callback_request:${request.id}`,
      }).catch((err) =>
        console.error("⚠️  Staff alert insert failed:", err.message),
      );

      res.status(201).json({
        message:
          "Request sent. BPLO will contact the establishment and update you here.",
        request_id: request.id,
        reference: request.id.slice(0, 8).toUpperCase(),
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── GET /api/beneficiary-portal/callback-requests ──────────────
// A-18: Beneficiary sees the status of their own requests and any BPLO note.
router.get("/callback-requests", async (req, res, next) => {
  try {
    const accountId = req.beneficiary.id || req.beneficiary.accountId;

    const result = await pool.query(
      `SELECT
         r.id, r.reason, r.status, r.staff_note, r.created_at, r.handled_at,
         UPPER(LEFT(r.id::text, 8)) AS reference,
         e.business_name AS establishment_name
       FROM establishment_callback_requests r
       JOIN establishments e ON e.id = r.establishment_id
       WHERE r.beneficiary_account_id = $1
       ORDER BY r.created_at DESC
       LIMIT 50`,
      [accountId],
    );

    res.json({ data: result.rows });
  } catch (err) {
    next(err);
  }
});

// ── PATCH /api/beneficiary-portal/device-token ─────────────────
// Called by Flutter app on launch to register/refresh the FCM token.
router.patch(
  "/device-token",
  [body("device_token").isString().trim().notEmpty()],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const accountId = req.beneficiary.id;
      const { device_token } = req.body;

      await pool.query(
        "UPDATE beneficiary_accounts SET device_token = $1 WHERE id = $2",
        [device_token, accountId],
      );

      res.json({ message: "Device token registered" });
    } catch (err) {
      next(err);
    }
  },
);

module.exports = router;
