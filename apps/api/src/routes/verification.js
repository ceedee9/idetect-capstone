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

const crypto = require("crypto");
const express = require("express");
const { body, validationResult } = require("express-validator");
const pool = require("../config/database");
const { authenticateEstablishment } = require("../middleware/auth");
const { requireEstablishmentStepUp } = require("../middleware/stepUp");
const { createError } = require("../middleware/errorHandler");
const { sendPushNotification } = require("../services/fcmService");
const { sendSms } = require("../services/smsService");
const { maskIdNumber } = require("../utils/privacy");
const ExcelJS = require("exceljs");
const { buildReportPdf } = require("../services/auditReportPdf");
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
    body("id_format").optional().isIn(["old", "new"]),
    body("seal_detected").optional().isBoolean(),
    body("client_scan_id").optional().isString().isLength({ min: 8, max: 64 }),
    body("scanned_at").optional().isISO8601(),
    body("offline_queued").optional().isBoolean(),
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
        id_format = "old",
        seal_detected = null,
        client_scan_id = null,
        scanned_at = null,
        offline_queued = false,
      } = req.body;

      // A replayed offline scan that the server already recorded is returned
      // as-is, so a retry never creates a second log entry.
      if (client_scan_id) {
        const prior = await pool.query(
          `SELECT id, reference_no, verified_at, result FROM verification_logs
           WHERE establishment_id = $1 AND client_scan_id = $2`,
          [req.establishment.id, client_scan_id],
        );
        if (prior.rows[0]) {
          const p = prior.rows[0];
          return res.status(200).json({
            result: p.result,
            message: "This scan was already recorded.",
            verification_id: p.id,
            reference_no: p.reference_no,
            verified_at: p.verified_at,
            duplicate: true,
          });
        }
      }

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

      // New-format Senior/PWD IDs carry a holographic seal; a heuristic
      // check runs client-side before this request. seal_detected === false
      // means the check ran and did NOT find the seal. (null means the
      // check wasn't run or was inconclusive — not treated as a flag.)
      const sealFlagged = id_format === "new" && seal_detected === false;

      // Query the database for this ID
      const bResult = await pool.query(
        `SELECT id, full_name, beneficiary_type, status, validity_end, issuing_office, birthdate
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
          const dob = beneficiary.birthdate;
          const dbDate =
            dob instanceof Date
              ? `${dob.getFullYear()}-${String(dob.getMonth() + 1).padStart(2, "0")}-${String(dob.getDate()).padStart(2, "0")}`
              : String(dob).slice(0, 10);
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

      // If the new-format ID's seal wasn't detected on an otherwise-valid
      // result, downgrade to manual_review — same treatment as low OCR
      // confidence. This is a heuristic flag, not proof of a fake ID, so
      // we ask a human to check rather than auto-rejecting.
      if (sealFlagged) {
        if (result === "valid") {
          result = "manual_review";
          message =
            "Holographic seal not detected on this new-format ID. Please inspect the physical ID carefully before approving the discount.";
        } else {
          message = `(Seal not detected) ${message}`;
        }
      }

      // Save the verification log
      const logResult = await pool.query(
        `INSERT INTO verification_logs
         (establishment_id, establishment_user_id, beneficiary_id, id_number_scanned,
          beneficiary_type_detected, result, ocr_confidence_score,
          ocr_raw_text, image_path, manually_entered,
          extracted_name, extracted_dob, name_match_score, fields_matched,id_format,
          client_scan_id, scanned_at, offline_queued)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)
       RETURNING id, reference_no, verified_at`,
        [
          establishment_id,
          req.establishment.establishment_user_id || null,
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
          id_format,
          client_scan_id,
          scanned_at ? new Date(scanned_at).toISOString() : null,
          offline_queued === true || offline_queued === "true",
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
            id_format,
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
           (verification_log_id, establishment_id, establishment_user_id, beneficiary_id,
            id_number_flagged, beneficiary_type, establishment_notes)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          [
            log.id,
            establishment_id,
            req.establishment.establishment_user_id || null,
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
           (verification_log_id, establishment_id, establishment_user_id, beneficiary_id,
            id_number_flagged, beneficiary_type, establishment_notes)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          [
            log.id,
            establishment_id,
            req.establishment.establishment_user_id || null,
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

      // Supplementary audit entry when a new-format scan's seal check came
      // back negative — lets OSCA/BPLO filter these separately from
      // ordinary verifications, same pattern as the block above.
      if (sealFlagged) {
        await pool.query(
          `INSERT INTO audit_logs
           (establishment_id, action, target_table, target_id, metadata)
           VALUES ($1, 'seal_not_detected', 'verification_logs', $2, $3)`,
          [
            establishment_id,
            log.id,
            JSON.stringify({
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
        reference_no: log.reference_no,
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
// timestamp. The establishment app calls this every 8 seconds to detect
// revoked/suspended IDs within seconds of the DB change.
//
// Query params:
//   since            — Unix ms timestamp (default 0 = all time)
//   beneficiary_type — "senior_citizen" | "pwd"
// Response: updates[] (id_number is a one-way hash, never plain or masked),
// has_more, and next_since (the cursor for the next request).
//
// One-way SHA-256 key for the device blocked-ID cache. Must match
// LocalDatabase.cacheKeyFor in the Flutter app.
const idCacheKey = (value) =>
  crypto
    .createHash("sha256")
    .update(String(value || "").toUpperCase().replace(/[^A-Z0-9]/g, ""))
    .digest("hex");

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
        ORDER BY updated_at ASC
        LIMIT 1000`,
        [since, beneficiary_type || null],
      );

      const serverTime = Date.now();
      const rows = result.rows;
      const hasMore = rows.length === 1000;
      res.json({
        updates: rows.map((row) => ({
          id_number: idCacheKey(row.id_number),
          status: row.status,
          updated_at: row.updated_at,
        })),
        has_more: hasMore,
        next_since: hasMore
          ? new Date(rows[rows.length - 1].updated_at).getTime()
          : serverTime,
        server_time: serverTime,
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── GET /api/verification/history ─────────────────────────────
// REQ-2.16.5: Establishment staff compliance report — date range filter,
// summary counts (computed client-side by the caller from these rows),
// paginated log.
//
// Query params:
//   page, limit  — pagination (unchanged)
//   start_date   — YYYY-MM-DD, inclusive
//   end_date     — YYYY-MM-DD, inclusive (implemented as < end_date + 1 day
//                  so the entire end day's timestamps are included, not just
//                  midnight)
//   result       — one of valid | suspicious | invalid | manual_review
//
// All three filters are optional and additive (AND'd together). Added
// because the Client Portal's history screen was already sending these
// three params and silently getting back unfiltered results — the filters
// are now real instead of decorative.
// Filters shared by GET /history and GET /history/export, so the exported
// file always contains exactly the rows the history screen shows.
const HISTORY_RESULTS = ["valid", "suspicious", "invalid", "manual_review"];
const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

const resultLabel = (value) =>
  value ? value.replace(/_/g, " ").toUpperCase() : "";

function buildHistoryFilters(query, establishment_id) {
  const { start_date, end_date, result: resultFilter } = query;

  if (resultFilter && !HISTORY_RESULTS.includes(resultFilter)) {
    return { error: `result must be one of: ${HISTORY_RESULTS.join(", ")}` };
  }
  if (
    (start_date && !ISO_DATE_PATTERN.test(start_date)) ||
    (end_date && !ISO_DATE_PATTERN.test(end_date))
  ) {
    return { error: "start_date and end_date must be in YYYY-MM-DD format" };
  }

  const whereClauses = ["vl.establishment_id = $1"];
  const filterParams = [establishment_id];
  let idx = 2;

  if (start_date) {
    whereClauses.push(`vl.verified_at >= $${idx}::date`);
    filterParams.push(start_date);
    idx++;
  }
  if (end_date) {
    whereClauses.push(`vl.verified_at < ($${idx}::date + INTERVAL '1 day')`);
    filterParams.push(end_date);
    idx++;
  }
  if (resultFilter) {
    whereClauses.push(`vl.result = $${idx}`);
    filterParams.push(resultFilter);
    idx++;
  }

  return {
    whereSql: whereClauses.join(" AND "),
    filterParams,
    nextIdx: idx,
  };
}

router.get("/history", authenticateEstablishment, async (req, res, next) => {
  try {
    const establishment_id = req.establishment.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    const filters = buildHistoryFilters(req.query, establishment_id);
    if (filters.error) {
      return res.status(400).json({ message: filters.error });
    }
    const { whereSql, filterParams, nextIdx: idx } = filters;

    const dataResult = await pool.query(
      `SELECT
         vl.id, vl.reference_no, vl.id_number_scanned, vl.beneficiary_type_detected,
         vl.result, vl.ocr_confidence_score, vl.manually_entered, vl.verified_at,
         b.full_name AS beneficiary_name
       FROM verification_logs vl
       LEFT JOIN beneficiaries b ON b.id = vl.beneficiary_id
       WHERE ${whereSql}
       ORDER BY vl.verified_at DESC
       LIMIT $${idx} OFFSET $${idx + 1}`,
      [...filterParams, limit, offset],
    );

    const countResult = await pool.query(
      `SELECT COUNT(*) FROM verification_logs vl WHERE ${whereSql}`,
      filterParams,
    );

    res.json({
      data: dataResult.rows.map((row) => ({
        ...row,
        id_number_scanned: maskIdNumber(row.id_number_scanned),
      })),
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

// ── GET /api/verification/history/export ─────────────────────
// Establishment audit export. Same filters as /history (start_date, end_date,
// result), but every matching row is returned as an Excel (format=xlsx) or
// PDF (format=pdf) file. ID numbers are masked unless full_ids=true, which
// only super users can use. Each export is written to audit_logs (data_export).
const EXPORT_MAX_ROWS = 5000;
const EXPORT_FORMATS = {
  xlsx: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  pdf: "application/pdf",
};
const exportHeaders = (fullIds) => [
  "Reference No",
  "Date & Time",
  fullIds ? "ID Number" : "ID Number (masked)",
  "Beneficiary Type",
  "Beneficiary Name",
  "Result",
  "OCR Confidence",
  "Entry Method",
];

const formatExportDate = (value) =>
  value
    ? new Date(value).toLocaleString("en-PH", {
        timeZone: "Asia/Manila",
        dateStyle: "medium",
        timeStyle: "short",
      })
    : "";

// Checked before the step-up password prompt, so regular users are refused
// without being asked for a password.
const requireExportSuperUser = (req, res, next) => {
  if (req.establishment?.role !== "establishment_super_user") {
    return res.status(403).json({
      message: "Only an establishment Super User can export scan history",
    });
  }
  next();
};

router.get(
  "/history/export",
  authenticateEstablishment,
  requireExportSuperUser,
  requireEstablishmentStepUp,
  async (req, res, next) => {
    try {
      const establishment_id = req.establishment.id;
      const { format, start_date, end_date, result: resultFilter } = req.query;
      const fullIds = req.query.full_ids === "true";

      if (!Object.prototype.hasOwnProperty.call(EXPORT_FORMATS, format)) {
        return res.status(400).json({ message: "format must be xlsx or pdf" });
      }
      const filters = buildHistoryFilters(req.query, establishment_id);
      if (filters.error) {
        return res.status(400).json({ message: filters.error });
      }
      const { whereSql, filterParams, nextIdx } = filters;

      const dataResult = await pool.query(
        `SELECT
           vl.reference_no, vl.id_number_scanned, vl.beneficiary_type_detected,
           vl.result, vl.ocr_confidence_score, vl.manually_entered, vl.verified_at,
           b.full_name AS beneficiary_name
         FROM verification_logs vl
         LEFT JOIN beneficiaries b ON b.id = vl.beneficiary_id
         WHERE ${whereSql}
         ORDER BY vl.verified_at DESC
         LIMIT $${nextIdx}`,
        [...filterParams, EXPORT_MAX_ROWS + 1],
      );

      if (dataResult.rows.length > EXPORT_MAX_ROWS) {
        return res.status(400).json({
          message: `This range has more than ${EXPORT_MAX_ROWS} scans. Narrow the date range and export again.`,
        });
      }

      const rows = dataResult.rows.map((r) => [
        r.reference_no ?? "",
        formatExportDate(r.verified_at),
        fullIds ? r.id_number_scanned ?? "" : maskIdNumber(r.id_number_scanned),
        r.beneficiary_type_detected ?? "",
        r.beneficiary_name ?? "",
        resultLabel(r.result),
        r.ocr_confidence_score ?? "",
        r.manually_entered ? "Manual" : "Scanned",
      ]);
      const headers = exportHeaders(fullIds);

      const generatedAt = new Date();
      let file;
      if (format === "xlsx") {
        const workbook = new ExcelJS.Workbook();
        workbook.creator = "iDetect";
        const sheet = workbook.addWorksheet("Scan History");
        sheet.columns = headers.map((header) => ({ header, width: 22 }));
        sheet.getRow(1).font = { bold: true };
        sheet.views = [{ state: "frozen", ySplit: 1 }];
        sheet.addRows(rows);
        file = await workbook.xlsx.writeBuffer();
      } else {
        file = await buildReportPdf({
          title: "Scan History Report",
          cover: [
            ["Generated", formatExportDate(generatedAt)],
            ["Date range", `${start_date || "Any start"} to ${end_date || "Any end"}`],
            ["Result filter", resultFilter ? resultLabel(resultFilter) : "All results"],
            ["Records", String(rows.length)],
            fullIds
              ? ["Note", "Full ID numbers included. Keep this file confidential."]
              : ["Note", "ID numbers are masked."],
          ],
          columns: headers,
          rows,
        });
      }

      await pool.query(
        `INSERT INTO audit_logs
         (establishment_id, action, target_table, metadata)
         VALUES ($1, 'data_export', 'verification_logs', $2)`,
        [
          establishment_id,
          JSON.stringify({
            export: "establishment_scan_history",
            format,
            result_filter: resultFilter ?? "all",
            start_date: start_date ?? null,
            end_date: end_date ?? null,
            row_count: rows.length,
            full_ids: fullIds,
            establishment_user_id: req.establishment.establishment_user_id ?? null,
          }),
        ],
      );

      const datestamp = generatedAt.toLocaleDateString("en-CA", {
        timeZone: "Asia/Manila",
      });
      res.setHeader("Content-Type", EXPORT_FORMATS[format]);
      res.setHeader(
        "Content-Disposition",
        `attachment; filename="scan-history-${datestamp}.${format}"`,
      );
      return res.send(Buffer.from(file));
    } catch (err) {
      next(err);
    }
  },
);

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
