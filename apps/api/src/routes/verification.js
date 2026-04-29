// src/routes/verification.js
// The core of iDetect — the ID verification endpoint.
//
//   POST /api/verification/scan
//     Called by the Client Portal (mobile) when an establishment scans an ID.
//     Accepts the OCR-extracted ID number + beneficiary type.
//     Returns VALID / SUSPICIOUS / INVALID.
//
//   GET  /api/verification/history
//     Called by Client Portal to show past scans for this establishment.

const path = require("path");
const fs = require("fs");
const { v4: uuidv4 } = require("uuid");
const express = require("express");
const { body, validationResult } = require("express-validator");
const pool = require("../config/database");
const { authenticateEstablishment } = require("../middleware/auth");
const { createError } = require("../middleware/errorHandler");
const { sendPushNotification } = require("../services/fcmService");

const router = express.Router();

const uploadsDir = path.join(__dirname, "..", "..", "uploads");

/**
 * Save a base64-encoded image to the uploads directory.
 * Returns a relative URL like "/uploads/abc123.jpg", or null on failure.
 */
function saveBase64Image(base64Data) {
  try {
    // Strip data URI prefix if present (data:image/jpeg;base64,...)
    const matches = base64Data.match(/^data:image\/(\w+);base64,(.+)$/);
    const ext = matches ? matches[1] : "jpg";
    const raw = matches ? matches[2] : base64Data;
    const filename = `${uuidv4()}.${ext}`;
    fs.writeFileSync(
      path.join(uploadsDir, filename),
      Buffer.from(raw, "base64"),
    );
    return `/uploads/${filename}`;
  } catch {
    return null;
  }
}

const normalizeIdNumber = (value) =>
  String(value || "")
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "")
    .trim();

// ── POST /api/verification/scan ────────────────────────────────
router.post(
  "/scan",
  authenticateEstablishment,
  [
    body("id_number").notEmpty().trim().toUpperCase(),
    body("beneficiary_type").isIn(["senior_citizen", "pwd"]),
    body("ocr_confidence_score").optional().isFloat({ min: 0, max: 100 }),
    body("ocr_raw_text").optional().isString(),
    body("image_data").optional().isString(), // base64-encoded captured ID image
    body("manually_entered").optional().isBoolean(),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const {
        id_number,
        beneficiary_type,
        ocr_confidence_score = null,
        ocr_raw_text = null,
        image_data = null,
        manually_entered = false,
      } = req.body;

      // Decode and save image if provided; build absolute URL for browser access
      let image_path = null;
      if (image_data) {
        const relativePath = saveBase64Image(image_data);
        if (relativePath) {
          const host = `${req.protocol}://${req.get("host")}`;
          image_path = `${host}${relativePath}`;
        }
      }

      const normalizedIdNumber = normalizeIdNumber(id_number);
      if (!normalizedIdNumber) {
        return res.status(400).json({ message: "Invalid ID number format." });
      }

      const establishment_id = req.establishment.id;

      // Check if OCR confidence is below threshold — note it but still verify
      const threshold = parseFloat(process.env.OCR_CONFIDENCE_THRESHOLD || 75);
      const lowConfidence =
        !manually_entered &&
        ocr_confidence_score !== null &&
        ocr_confidence_score < threshold;

      // Query the database for this ID
      const bResult = await pool.query(
        `SELECT id, full_name, beneficiary_type, status, validity_end, issuing_office
       FROM beneficiaries
       WHERE UPPER(REGEXP_REPLACE(id_number, '[^A-Za-z0-9]', '', 'g')) = $1
         AND beneficiary_type = $2`,
        [normalizedIdNumber, beneficiary_type],
      );

      const beneficiary = bResult.rows[0];

      // Determine result
      let result;
      let beneficiary_id = null;
      let message = "";

      if (!beneficiary) {
        const crossType = await pool.query(
          `SELECT id, beneficiary_type, full_name
         FROM beneficiaries
         WHERE UPPER(REGEXP_REPLACE(id_number, '[^A-Za-z0-9]', '', 'g')) = $1
         LIMIT 1`,
          [normalizedIdNumber],
        );

        if (crossType.rows.length) {
          // REQ-2.5.5: Cross-database conflict — return SUSPICIOUS, not invalid
          const conflicting = crossType.rows[0];
          result = "suspicious";
          message = `Cross-database conflict: ID scanned as ${beneficiary_type} but exists as ${conflicting.beneficiary_type}.`;
          beneficiary_id = conflicting.id;
        } else {
          result = "invalid";
          message = "ID not found in database.";
        }
      } else {
        beneficiary_id = beneficiary.id;

        if (beneficiary.status === "active") {
          // Check expiry
          const isExpired = new Date() > new Date(beneficiary.validity_end);
          if (isExpired) {
            result = "invalid";
            message = "ID has expired.";
          } else {
            result = "valid";
            message = "ID verified successfully.";
          }
        } else if (beneficiary.status === "suspended") {
          result = "suspicious";
          message = "ID is currently under investigation.";
        } else if (beneficiary.status === "revoked") {
          result = "invalid";
          message =
            "This ID has been confirmed fraudulent and is permanently blocked.";
        } else {
          result = "invalid";
          message = `ID status: ${beneficiary.status}.`;
        }
      }

      // If OCR confidence was low, append a warning to whatever result we got
      if (lowConfidence) {
        message = `(Low OCR confidence — result may be inaccurate) ${message}`;
      }

      // Save the verification log
      const logResult = await pool.query(
        `INSERT INTO verification_logs
         (establishment_id, beneficiary_id, id_number_scanned,
          beneficiary_type_detected, result, ocr_confidence_score,
          ocr_raw_text, image_path, manually_entered)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
       RETURNING id, verified_at`,
        [
          establishment_id,
          beneficiary_id,
          id_number,
          beneficiary_type,
          result,
          ocr_confidence_score,
          ocr_raw_text,
          image_path,
          manually_entered,
        ],
      );

      const log = logResult.rows[0];

      // REQ-2.5.5: Auto-generate discrepancy alert on cross-database conflict
      // Inserts a fraud_flag for BOTH portal types so OSCA and PDAO see it
      if (
        result === "suspicious" &&
        message.startsWith("Cross-database conflict")
      ) {
        const conflictNote = `Auto-generated: ${message} Scanned at establishment ${establishment_id}.`;

        // Flag for the scanned type (e.g. the senior_citizen portal)
        await pool.query(
          `INSERT INTO fraud_flags
           (verification_log_id, establishment_id, beneficiary_id,
            id_number_flagged, beneficiary_type, establishment_notes)
         VALUES ($1, $2, $3, $4, $5, $6)`,
          [
            log.id,
            establishment_id,
            beneficiary_id,
            id_number,
            beneficiary_type,
            conflictNote,
          ],
        );

        // Flag for the actual type the record belongs to (e.g. the pwd portal)
        const actualType =
          beneficiary_type === "senior_citizen" ? "pwd" : "senior_citizen";
        await pool.query(
          `INSERT INTO fraud_flags
           (verification_log_id, establishment_id, beneficiary_id,
            id_number_flagged, beneficiary_type, establishment_notes)
         VALUES ($1, $2, $3, $4, $5, $6)`,
          [
            log.id,
            establishment_id,
            beneficiary_id,
            id_number,
            actualType,
            conflictNote,
          ],
        );

        // Log conflict details in audit trail
        await pool.query(
          `INSERT INTO audit_logs
           (establishment_id, action, target_table, target_id, metadata)
         VALUES ($1, 'verification_performed', 'verification_logs', $2, $3)`,
          [
            establishment_id,
            log.id,
            JSON.stringify({
              conflict: true,
              scanned_type: beneficiary_type,
              actual_type: actualType,
              id_number,
              beneficiary_id,
            }),
          ],
        );
      }

      // Notify the beneficiary if they have an app account
      // REQ-2.11.1: SMS + push on each verification
      // REQ-2.11.2: Include specific denial reason for denied outcomes
      if (beneficiary_id) {
        const accountResult = await pool.query(
          "SELECT id, device_token FROM beneficiary_accounts WHERE beneficiary_id = $1 AND is_active = TRUE",
          [beneficiary_id],
        );
        if (accountResult.rows.length > 0) {
          const accountId = accountResult.rows[0].id;
          const notifType =
            result === "valid"
              ? "verification_approved"
              : "verification_denied";

          // Get establishment name for the notification
          const estResult = await pool.query(
            "SELECT business_name FROM establishments WHERE id = $1",
            [establishment_id],
          );
          const businessName =
            estResult.rows[0]?.business_name || "An establishment";

          const now = new Date().toLocaleString("en-PH", {
            timeZone: "Asia/Manila",
          });
          const title =
            result === "valid" ? "Discount Approved ✓" : "Discount Denied ✗";

          // REQ-2.11.2: Include specific denial reason
          let body;
          if (result === "valid") {
            body = `Your ID was verified at ${businessName} on ${now}. Outcome: Approved.`;
          } else {
            body = `Your ID was verified at ${businessName} on ${now}. Outcome: Denied — ${message}`;
          }

          // REQ-2.11.1: Insert push notification
          await pool.query(
            `INSERT INTO notifications
             (beneficiary_account_id, notification_type, title, body,
              channel, verification_log_id)
           VALUES ($1, $2, $3, $4, 'push', $5)`,
            [accountId, notifType, title, body, log.id],
          );

          // REQ-2.11.3: Insert SMS notification (independent of data access)
          await pool.query(
            `INSERT INTO notifications
             (beneficiary_account_id, notification_type, title, body,
              channel, verification_log_id)
           VALUES ($1, $2, $3, $4, 'sms', $5)`,
            [accountId, notifType, title, body, log.id],
          );

          // Dispatch push notification via FCM (fire-and-forget, non-blocking)
          const token = accountResult.rows[0].device_token;
          if (token) {
            sendPushNotification(token, title, body, {
              type: notifType,
              verification_id: log.id,
            })
              .then((fcmResult) => {
                // Clear stale token from DB if FCM reports it as invalid
                if (fcmResult.invalidToken) {
                  pool
                    .query(
                      "UPDATE beneficiary_accounts SET device_token = NULL WHERE id = $1",
                      [accountResult.rows[0].id],
                    )
                    .catch(() => {});
                }
              })
              .catch(() => {});
          }
        }
      }

      // Build the response — minimal data back to the establishment
      // (never expose full personal data)
      const response = {
        result,
        message,
        verification_id: log.id,
        verified_at: log.verified_at,
      };

      // On VALID, include just enough for the cashier to confirm
      if (result === "valid" && beneficiary) {
        response.beneficiary = {
          full_name: beneficiary.full_name,
          beneficiary_type: beneficiary.beneficiary_type,
          validity_end: beneficiary.validity_end,
          issuing_office: beneficiary.issuing_office,
        };
      }

      res.json(response);
    } catch (err) {
      next(err);
    }
  },
);

// ── GET /api/verification/status-updates ──────────────────────
// REQ-2.9.1 / REQ-2.9.3: Poll for beneficiary status changes since a given
// timestamp. The establishment app calls this every ~8 seconds to detect
// revoked/suspended IDs within 10 seconds of the DB change.
//
// Query params:
//   since            — Unix ms timestamp (default 0 = all time)
//   beneficiary_type — "senior_citizen" | "pwd"
router.get(
  "/status-updates",
  authenticateEstablishment,
  async (req, res, next) => {
    try {
      const since = new Date(parseInt(req.query.since, 10) || 0);
      const { beneficiary_type } = req.query;

      if (
        beneficiary_type &&
        !["senior_citizen", "pwd"].includes(beneficiary_type)
      ) {
        return res
          .status(400)
          .json({ message: "Invalid beneficiary_type filter." });
      }

      const result = await pool.query(
        `SELECT id_number, status, updated_at
         FROM beneficiaries
         WHERE updated_at > $1
           AND ($2::text IS NULL OR beneficiary_type = $2)
         ORDER BY updated_at DESC
         LIMIT 1000`,
        [since, beneficiary_type || null],
      );

      res.json({
        updates: result.rows,
        server_time: Date.now(),
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── GET /api/verification/history ─────────────────────────────
router.get("/history", authenticateEstablishment, async (req, res, next) => {
  try {
    const establishment_id = req.establishment.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    const result = await pool.query(
      `SELECT
         vl.id, vl.id_number_scanned, vl.beneficiary_type_detected,
         vl.result, vl.ocr_confidence_score, vl.manually_entered, vl.verified_at,
         b.full_name AS beneficiary_name
       FROM verification_logs vl
       LEFT JOIN beneficiaries b ON b.id = vl.beneficiary_id
       WHERE vl.establishment_id = $1
       ORDER BY vl.verified_at DESC
       LIMIT $2 OFFSET $3`,
      [establishment_id, limit, offset],
    );

    const countResult = await pool.query(
      "SELECT COUNT(*) FROM verification_logs WHERE establishment_id = $1",
      [establishment_id],
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

module.exports = router;
