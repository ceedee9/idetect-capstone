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

const express = require("express");
const { body, validationResult } = require("express-validator");
const pool = require("../config/database");
const { authenticateEstablishment } = require("../middleware/auth");
const { createError } = require("../middleware/errorHandler");
const { sendPushNotification } = require("../services/fcmService");
const { sendSms } = require("../services/smsService");
const {
  uploadIdCaptureBase64,
  buildAbsoluteApiUploadUrl,
} = require("../services/storageService");
const rateLimit = require("express-rate-limit");

const router = express.Router();

// Jaro-Winkler string similarity — returns 0.0 to 1.0.
// Used to fuzzy-match OCR-extracted names against stored beneficiary names.
// See: https://en.wikipedia.org/wiki/Jaro%E2%80%93Winkler_distance
function jaroWinkler(s1, s2) {
  if (!s1 || !s2) return 0;
  s1 = s1.toUpperCase().trim();
  s2 = s2.toUpperCase().trim();
  if (s1 === s2) return 1;

  const len1 = s1.length;
  const len2 = s2.length;
  const matchDist = Math.max(Math.floor(Math.max(len1, len2) / 2) - 1, 0);

  const s1Matched = new Array(len1).fill(false);
  const s2Matched = new Array(len2).fill(false);
  let matches = 0;

  for (let i = 0; i < len1; i++) {
    const lo = Math.max(0, i - matchDist);
    const hi = Math.min(i + matchDist + 1, len2);
    for (let j = lo; j < hi; j++) {
      if (!s2Matched[j] && s1[i] === s2[j]) {
        s1Matched[i] = s2Matched[j] = true;
        matches++;
        break;
      }
    }
  }

  if (matches === 0) return 0;

  let transpositions = 0;
  let k = 0;
  for (let i = 0; i < len1; i++) {
    if (!s1Matched[i]) continue;
    while (!s2Matched[k]) k++;
    if (s1[i] !== s2[k]) transpositions++;
    k++;
  }

  const jaro =
    (matches / len1 +
      matches / len2 +
      (matches - transpositions / 2) / matches) /
    3;

  let prefixLen = 0;
  const maxPrefix = Math.min(4, Math.min(len1, len2));
  while (prefixLen < maxPrefix && s1[prefixLen] === s2[prefixLen]) prefixLen++;

  return jaro + prefixLen * 0.1 * (1 - jaro);
}

// Per-establishment rate limit on the scan endpoint.
// 60 scans per minute prevents automated ID enumeration even if an
// establishment account credential is compromised.
// Key is resolved after authenticateEstablishment runs.
const scanLimiter = rateLimit({
  windowMs: 60_000,
  max: 60,
  keyGenerator: (req) => req.establishment?.id || req.ip,
  message: {
    error: "Too many scan requests. Please wait before scanning again.",
  },
  standardHeaders: true,
  legacyHeaders: false,
});

const normalizeIdNumber = (value) =>
  String(value || "")
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "")
    .trim();

// ── POST /api/verification/scan ────────────────────────────────
router.post(
  "/scan",
  authenticateEstablishment,
  scanLimiter,
  [
    body("id_number").notEmpty().trim().toUpperCase(),
    body("beneficiary_type").isIn(["senior_citizen", "pwd"]),
    body("ocr_confidence_score").optional().isFloat({ min: 0, max: 100 }),
    body("ocr_raw_text").optional().isString(),
    body("image_data").optional().isString(), // base64-encoded captured ID image
    body("manually_entered").optional().isBoolean(),
    body("extracted_name").optional().isString().trim(),
    body("extracted_dob").optional().isString().trim(),
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
        extracted_name = null,
        extracted_dob = null,
      } = req.body;

      // Cross-validation state — populated below when result is VALID.
      let crossNameMatchScore = null;
      let crossFieldsMatched = null;

      // Sanitize extracted_dob once to a YYYY-MM-DD string for safe DB insertion.
      let safeExtractedDob = null;
      if (extracted_dob) {
        try {
          const d = new Date(extracted_dob);
          if (!isNaN(d.getTime()))
            safeExtractedDob = d.toISOString().slice(0, 10);
        } catch {
          /* ignore invalid date strings */
        }
      }

      // Upload captured image to Supabase Storage and expose it
      // through the authenticated /api/uploads route.
      let image_path = null;
      if (image_data) {
        const uploaded = await uploadIdCaptureBase64(image_data);
        if (uploaded) {
          image_path = buildAbsoluteApiUploadUrl(
            req,
            uploaded.bucket,
            uploaded.objectPath,
          );
        }
      }

      const normalizedIdNumber = normalizeIdNumber(id_number);
      if (!normalizedIdNumber) {
        return res.status(400).json({ message: "Invalid ID number format." });
      }

      const establishment_id = req.establishment.id;

      // Check if extraction quality score is below threshold — note it but still verify
      // (This score is a heuristic indicator of OCR output quality, not a true statistical confidence)
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

      // ── Cross-validate OCR-extracted name and DOB against stored record ──
      // Only runs when the ID was initially found and VALID. A mismatch
      // downgrades the result to SUSPICIOUS so the discount is not granted.
      //
      // When the scan is NOT manually entered (i.e. OCR was used) but the
      // pipeline failed to extract BOTH the name and DOB, we cannot confirm
      // the cardholder's identity from the card image alone. Downgrade to
      // manual_review so the cashier physically inspects the card.
      const NAME_THRESHOLD = parseFloat(
        process.env.OCR_NAME_MATCH_THRESHOLD || "0.80",
      );
      if (
        result === "valid" &&
        beneficiary &&
        !manually_entered &&
        !extracted_name &&
        !safeExtractedDob
      ) {
        result = "manual_review";
        message =
          "OCR could not extract name or date of birth from this card. " +
          "Please inspect the physical ID carefully before approving the discount.";
      } else if (
        result === "valid" &&
        beneficiary &&
        (extracted_name || safeExtractedDob)
      ) {
        let nameOk = true;
        let dobOk = true;

        if (extracted_name) {
          crossNameMatchScore = parseFloat(
            jaroWinkler(extracted_name, beneficiary.full_name).toFixed(3),
          );
          nameOk = crossNameMatchScore >= NAME_THRESHOLD;
        }

        if (safeExtractedDob) {
          const dbDate = new Date(beneficiary.birthdate)
            .toISOString()
            .slice(0, 10);
          dobOk = safeExtractedDob === dbDate;
        }

        crossFieldsMatched = nameOk && dobOk;

        if (!crossFieldsMatched) {
          result = "suspicious";
          if (!nameOk && !dobOk) {
            message =
              "ID number found but name and date of birth on card do not match the record.";
          } else if (!nameOk) {
            message = `ID number found but name on card does not match record (similarity: ${(crossNameMatchScore * 100).toFixed(0)}%).`;
          } else {
            message =
              "ID number found but date of birth on card does not match the record.";
          }
        }
      }

      // If extraction quality score was low on an otherwise-valid result, downgrade to
      // manual_review so the cashier physically inspects the card.
      // On already-invalid/suspicious results, just annotate the message.
      if (lowConfidence) {
        if (result === "valid") {
          result = "manual_review";
          message = `Low extraction quality score (${ocr_confidence_score?.toFixed(0)}%). Please inspect the physical ID carefully before approving the discount.`;
        } else {
          message = `(Low extraction quality: ${ocr_confidence_score?.toFixed(0)}%) ${message}`;
        }
      }

      // Save the verification log
      const logResult = await pool.query(
        `INSERT INTO verification_logs
         (establishment_id, beneficiary_id, id_number_scanned,
          beneficiary_type_detected, result, ocr_confidence_score,
          ocr_raw_text, image_path, manually_entered,
          extracted_name, extracted_dob, name_match_score, fields_matched)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)
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
          extracted_name,
          safeExtractedDob,
          crossNameMatchScore,
          crossFieldsMatched,
        ],
      );

      const log = logResult.rows[0];

      // Log every verification attempt to the audit trail, so staff can see
      // full scan activity under Audit Logs > Verifications (not just
      // manual entries or cross-database conflicts).
      await pool.query(
        `INSERT INTO audit_logs
         (establishment_id, action, target_table, target_id, metadata)
         VALUES ($1, 'verification_performed', 'verification_logs', $2, $3)`,
        [
          establishment_id,
          log.id,
          JSON.stringify({
            result,
            beneficiary_type,
            id_number,
            manually_entered,
            beneficiary_id,
          }),
        ],
      );

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
      }

      // Notify the beneficiary if they have an app account
      // REQ-2.11.1: SMS + push on each verification
      // REQ-2.11.2: Include specific denial reason for denied outcomes
      if (beneficiary_id) {
        const accountResult = await pool.query(
          `SELECT ba.id, ba.device_token, b.registered_mobile
           FROM beneficiary_accounts ba
           JOIN beneficiaries b ON b.id = ba.beneficiary_id
           WHERE ba.beneficiary_id = $1 AND ba.is_active = TRUE`,
          [beneficiary_id],
        );
        if (accountResult.rows.length > 0) {
          const accountId = accountResult.rows[0].id;
          // manual_review means the ID IS in the database (valid record found);
          // treat it as approved but note that a physical check was required.
          const isApproved = result === "valid" || result === "manual_review";
          const notifType = isApproved
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
          const title = isApproved
            ? "Discount Approved ✓"
            : "Discount Denied ✗";

          // REQ-2.11.2: Include specific denial reason
          let body;
          if (result === "valid") {
            body = `Your ID was verified at ${businessName} on ${now}. Outcome: Approved.`;
          } else if (result === "manual_review") {
            body = `Your ID was verified at ${businessName} on ${now}. Outcome: Approved — your ID is registered. Note: scan quality was low; the cashier verified your physical card.`;
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

          // REQ-2.11.3: Insert SMS notification record and dispatch via Semaphore
          await pool.query(
            `INSERT INTO notifications
             (beneficiary_account_id, notification_type, title, body,
              channel, verification_log_id)
           VALUES ($1, $2, $3, $4, 'sms', $5)`,
            [accountId, notifType, title, body, log.id],
          );

          // Dispatch SMS (fire-and-forget, non-blocking)
          const mobile = accountResult.rows[0].registered_mobile;
          if (mobile) {
            sendSms(mobile, `${title}: ${body}`).catch(() => {});
          }

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

      // Gap 7: Audit log for manually entered IDs — gives supervisors visibility
      // into cashier behaviour without OCR evidence. Uses the dedicated action
      // 'verification_manual' so the BPLO can filter and visually distinguish
      // these entries from camera-based scans.
      if (manually_entered) {
        await pool.query(
          `INSERT INTO audit_logs
           (establishment_id, action, target_table, target_id, metadata)
           VALUES ($1, 'verification_manual', 'verification_logs', $2, $3)`,
          [
            establishment_id,
            log.id,
            JSON.stringify({
              manually_entered: true,
              id_number,
              beneficiary_type,
              result,
            }),
          ],
        );
      }

      // Build the response — minimal data back to the establishment
      // (never expose full personal data)
      const response = {
        result,
        message,
        verification_id: log.id,
        verified_at: log.verified_at,
      };

      // On VALID or MANUAL_REVIEW, include just enough for the cashier to confirm.
      // manual_review means the ID IS in the database (found and active) but OCR
      // could not confirm the cardholder — so the cashier needs the stored name
      // to compare against the physical card.
      if ((result === "valid" || result === "manual_review") && beneficiary) {
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
          AND ($2::text IS NULL OR beneficiary_type = $2::beneficiary_type)
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

// ── POST /api/verification/:id/cashier-action ────────────────────────────
// Gap 8: Record the cashier's deliberate action on a SUSPICIOUS/MANUAL_REVIEW
// result. action must be 'approved' | 'denied' | 'reported'.
// Inserted into audit_logs so BPLO supervisors can see override patterns.
router.post(
  "/:id/cashier-action",
  authenticateEstablishment,
  async (req, res, next) => {
    try {
      const { id } = req.params;
      const { action } = req.body;
      const establishment_id = req.establishment.id;

      const VALID_ACTIONS = ["approved", "denied", "reported"];
      if (!action || !VALID_ACTIONS.includes(action)) {
        return res.status(400).json({
          message: `action must be one of: ${VALID_ACTIONS.join(", ")}`,
        });
      }

      // Verify the log belongs to this establishment before writing
      const logCheck = await pool.query(
        "SELECT id FROM verification_logs WHERE id = $1 AND establishment_id = $2",
        [id, establishment_id],
      );
      if (logCheck.rows.length === 0) {
        return res.status(404).json({ message: "Verification log not found." });
      }

      await pool.query(
        `INSERT INTO audit_logs
         (establishment_id, action, target_table, target_id, metadata)
         VALUES ($1, 'verification_action_taken', 'verification_logs', $2, $3)`,
        [establishment_id, id, JSON.stringify({ cashier_action: action })],
      );

      res.json({ logged: true });
    } catch (err) {
      next(err);
    }
  },
);

module.exports = router;
