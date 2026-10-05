// src/routes/fraudFlags.js
// Fraud flag endpoints.
//
//   POST /api/fraud-flags              — Establishment flags a suspicious ID
//   GET  /api/fraud-flags              — OSCA/PDAO views their incoming flags
//   PATCH /api/fraud-flags/:id/review  — OSCA/PDAO confirms or dismisses a flag

const express = require("express");
const { body, validationResult } = require("express-validator");
const rateLimit = require("express-rate-limit");
const pool = require("../config/database");
const {
  authenticate,
  authenticateEstablishment,
  requireRole,
} = require("../middleware/auth");
const { createError } = require("../middleware/errorHandler");

const router = express.Router();

// ── Rate limit: flag submissions ────────────────────────────────
// 30 flags per hour per establishment. A legitimate cashier would
// rarely flag more than a handful of IDs per shift. A high volume
// from one account is a sign of scripted abuse or a compromised credential.
const flagLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 30,
  keyGenerator: (req) => req.establishment?.id || req.ip,
  message: {
    error:
      "Too many fraud flag submissions from this account. Please contact your supervisor.",
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// ── POST /api/fraud-flags ──────────────────────────────────────
// Called by the Client Portal after a SUSPICIOUS or INVALID scan
router.post(
  "/",
  authenticateEstablishment,
  flagLimiter,
  [
    body("verification_log_id").isUUID(),
    body("id_number_flagged").notEmpty().trim().toUpperCase(),
    body("beneficiary_type").isIn(["senior_citizen", "pwd"]),
    body("establishment_notes").optional().isString().trim(),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const {
        verification_log_id,
        id_number_flagged: raw_id_number_flagged,
        beneficiary_type,
        establishment_notes,
      } = req.body;

      // Normalize the ID number to match how it is stored in beneficiaries
      // (uppercase, alphanumeric only). Without this, a flag from a card with
      // dashes (e.g. "12-3456-789") would fail to link to the beneficiary record
      // stored without dashes ("123456789").
      const id_number_flagged =
        String(raw_id_number_flagged || "")
          .toUpperCase()
          .replace(/[^A-Z0-9]/g, "")
          .trim() || raw_id_number_flagged;

      const establishment_id = req.establishment.id;

      // Find beneficiary_id if the record exists — use the normalized form
      // and the same expression index used by verification.js for consistency
      const bResult = await pool.query(
        `SELECT id FROM beneficiaries
         WHERE UPPER(REGEXP_REPLACE(id_number, '[^A-Za-z0-9]', '', 'g')) = $1`,
        [id_number_flagged],
      );
      const beneficiary_id = bResult.rows[0]?.id || null;

      // REQ-2.6.2: Fetch image_path and verification outcome from verification_logs
      const vLogResult = await pool.query(
        "SELECT image_path, result FROM verification_logs WHERE id = $1",
        [verification_log_id],
      );
      const image_path = vLogResult.rows[0]?.image_path || null;
      const verification_outcome = vLogResult.rows[0]?.result || null;

      // REQ-2.6.6: Check for existing active investigation on this ID
      const existingFlagResult = await pool.query(
        `SELECT id, flag_status FROM fraud_flags
         WHERE id_number_flagged = $1
         AND flag_status IN ('pending', 'reviewing')
         AND parent_flag_id IS NULL
         ORDER BY flagged_at DESC
         LIMIT 1`,
        [id_number_flagged],
      );

      const existingFlag = existingFlagResult.rows[0];
      const is_supplementary = !!existingFlag;
      const parent_flag_id = existingFlag?.id || null;

      const result = await pool.query(
        `INSERT INTO fraud_flags
         (verification_log_id, establishment_id, beneficiary_id,
          id_number_flagged, beneficiary_type, establishment_notes,
          image_path, verification_outcome, parent_flag_id, is_supplementary)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING *`,
        [
          verification_log_id,
          establishment_id,
          beneficiary_id,
          id_number_flagged,
          beneficiary_type,
          establishment_notes,
          image_path,
          verification_outcome,
          parent_flag_id,
          is_supplementary,
        ],
      );

      // ── Auto-suspend rule (adviser requirement) ──────────────
      // When a beneficiary's ID accumulates flags from 3 or more DISTINCT
      // establishments (all still pending/reviewing), automatically set their
      // status to 'suspended'. This causes future verification scans to return
      // SUSPICIOUS ("under investigation") without requiring manual admin action.
      // The beneficiary is restored to 'active' only when an OSCA/PDAO admin
      // dismisses the flag (existing /restore endpoint handles that).
      const FLAG_THRESHOLD = parseInt(
        process.env.AUTO_SUSPEND_FLAG_THRESHOLD || "3",
      );
      let autoSuspended = false;

      if (beneficiary_id) {
        const distinctFlagResult = await pool.query(
          `SELECT COUNT(DISTINCT establishment_id) AS distinct_flaggers
           FROM fraud_flags
           WHERE beneficiary_id = $1
             AND flag_status IN ('pending', 'reviewing')`,
          [beneficiary_id],
        );
        const distinctFlaggers = parseInt(
          distinctFlagResult.rows[0]?.distinct_flaggers || "0",
        );

        if (distinctFlaggers >= FLAG_THRESHOLD) {
          // Only suspend if currently active — don't override revoked status
          const benResult = await pool.query(
            "SELECT status FROM beneficiaries WHERE id = $1",
            [beneficiary_id],
          );
          if (benResult.rows[0]?.status === "active") {
            await pool.query(
              `UPDATE beneficiaries
               SET status = 'suspended',
                   status_reason = $1,
                   updated_at = NOW()
               WHERE id = $2`,
              [
                `Automatically suspended: flagged by ${distinctFlaggers} distinct establishment(s). Threshold is ${FLAG_THRESHOLD}.`,
                beneficiary_id,
              ],
            );

            await pool.query(
              `INSERT INTO audit_logs (action, target_table, target_id, metadata)
               VALUES ('flag_confirmed', 'beneficiaries', $1, $2)`,
              [
                beneficiary_id,
                JSON.stringify({
                  auto_suspended: true,
                  trigger: "flag_threshold_reached",
                  distinct_flaggers: distinctFlaggers,
                  threshold: FLAG_THRESHOLD,
                  triggering_flag_id: result.rows[0].id,
                  id_number: id_number_flagged,
                }),
              ],
            );

            autoSuspended = true;

            // Alert the relevant LGU portal staff (in-portal notification).
            // senior_citizen flags → osca_admin; pwd flags → pdao_admin.
            const alertRole =
              beneficiary_type === "senior_citizen"
                ? "osca_admin"
                : "pdao_admin";
            pool
              .query(
                `INSERT INTO staff_alerts (target_role, title, body, related_beneficiary_id)
                 VALUES ($1, $2, $3, $4)`,
                [
                  alertRole,
                  "⚠️ ID Auto-Suspended",
                  `ID ${id_number_flagged} was automatically suspended after flags from ${distinctFlaggers} distinct establishment(s). Please review the active fraud flags.`,
                  beneficiary_id,
                ],
              )
              .catch((err) =>
                console.error(
                  "⚠️  Staff alert insert failed (migration 022 applied?):",
                  err.message,
                ),
              );
          }
        }
      }

      // Notify the beneficiary of suspicious activity on their ID
      if (beneficiary_id) {
        const accountResult = await pool.query(
          "SELECT id FROM beneficiary_accounts WHERE beneficiary_id = $1 AND is_active = TRUE",
          [beneficiary_id],
        );
        if (accountResult.rows.length > 0) {
          const notifBody = autoSuspended
            ? "Your ID has been flagged by multiple establishments and is now under investigation. If this was not you, please file a dispute immediately."
            : "A business flagged your ID as suspicious. If this was not you, please file a dispute.";

          await pool.query(
            `INSERT INTO notifications
             (beneficiary_account_id, notification_type, title, body, channel)
           VALUES ($1, 'flag_confirmed', $2, $3, 'push')`,
            [
              accountResult.rows[0].id,
              autoSuspended
                ? "⚠️ Your ID is now under investigation"
                : "Suspicious activity on your ID",
              notifBody,
            ],
          );
        }
      }

      // Build response message
      let responseMessage =
        "Flag submitted successfully. The relevant LGU office has been notified.";
      if (is_supplementary) {
        const parentRefShort = parent_flag_id.substring(0, 8).toUpperCase();
        responseMessage = `This ID already has an active investigation (REF-${parentRefShort}). Your report has been added as supplementary evidence.`;
      }
      if (autoSuspended) {
        responseMessage +=
          " This ID has been automatically placed under investigation due to multiple flags.";
      }

      res.status(201).json({
        message: responseMessage,
        flag_id: result.rows[0].id,
        is_supplementary: is_supplementary,
        parent_flag_id: parent_flag_id,
        auto_suspended: autoSuspended,
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── GET /api/fraud-flags ───────────────────────────────────────
// OSCA sees only senior_citizen flags. PDAO sees only pwd flags.
router.get(
  "/",
  authenticate,
  requireRole(["osca_admin", "pdao_admin"]),
  async (req, res, next) => {
    try {
      // Determine which type this admin can see
      const typeMap = { osca_admin: "senior_citizen", pdao_admin: "pwd" };
      const beneficiary_type = typeMap[req.user.role];

      // status='' or omitted means "all"; otherwise filter by specific status
      const status = req.query.status || null;
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 20;
      const offset = (page - 1) * limit;

      let query = `
      SELECT
         ff.id,
         ff.reference_no,
         ff.establishment_id,
         ff.beneficiary_id,
         ff.id_number_flagged,
         ff.beneficiary_type,
         ff.flag_status        AS status,
         ff.establishment_notes AS notes,
         ff.staff_notes        AS review_notes,
         ff.reviewed_by,
         ff.flagged_at         AS created_at,
         ff.flagged_at,
         ff.reviewed_at,
         ff.verification_log_id,
         ff.image_path,
         ff.verification_outcome,
         ff.parent_flag_id,
         ff.is_supplementary,
         json_build_object(
           'id',            e.id,
           'business_name', e.business_name
         ) AS establishment,
         b.full_name AS beneficiary_name,
         vl.ocr_confidence_score,
         vl.ocr_raw_text,
         vl.verified_at    AS transaction_timestamp,
         vl.manually_entered
       FROM fraud_flags ff
       JOIN establishments e ON e.id = ff.establishment_id
       LEFT JOIN beneficiaries b ON b.id = ff.beneficiary_id
       LEFT JOIN verification_logs vl ON vl.id = ff.verification_log_id
       WHERE TRUE`;
      const params = [];
      let idx = 1;

      if (status) {
        query += ` AND ff.flag_status = $${idx}`;
        params.push(status);
        idx++;
      }

      if (beneficiary_type) {
        query += ` AND ff.beneficiary_type = $${idx}`;
        params.push(beneficiary_type);
        idx++;
      }

      query += ` ORDER BY ff.flagged_at DESC LIMIT $${idx} OFFSET $${idx + 1}`;
      params.push(limit, offset);

      const result = await pool.query(query, params);

      let countQuery = "SELECT COUNT(*) FROM fraud_flags WHERE TRUE";
      const countParams = [];
      let countIdx = 1;
      if (status) {
        countQuery += ` AND flag_status = $${countIdx}`;
        countParams.push(status);
        countIdx++;
      }
      if (beneficiary_type) {
        countQuery += ` AND beneficiary_type = $${countIdx}`;
        countParams.push(beneficiary_type);
      }

      const countResult = await pool.query(countQuery, countParams);

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
  },
);

// ── PATCH /api/fraud-flags/:id/review ─────────────────────────
// OSCA/PDAO confirms or dismisses a flag
router.patch(
  "/:id/review",
  authenticate,
  requireRole(["osca_admin", "pdao_admin"]),
  [
    body("decision").isIn(["confirmed", "dismissed"]),
    body("staff_notes").optional().isString().trim(),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const { id } = req.params;
      const { decision, staff_notes } = req.body;

      // OSCA/PDAO can only review their own type
      const typeMap = { osca_admin: "senior_citizen", pdao_admin: "pwd" };
      const allowedType = typeMap[req.user.role];

      let flagQuery = "SELECT * FROM fraud_flags WHERE id = $1";
      const flagParams = [id];
      flagQuery += " AND beneficiary_type = $2";
      flagParams.push(allowedType);

      const flagResult = await pool.query(flagQuery, flagParams);
      if (!flagResult.rows.length) throw createError(404, "Flag not found");

      const flag = flagResult.rows[0];

      // Update the flag
      await pool.query(
        `UPDATE fraud_flags
       SET flag_status = $1, staff_notes = $2, reviewed_by = $3, reviewed_at = NOW()
       WHERE id = $4`,
        [decision, staff_notes, req.user.id, id],
      );

      // If CONFIRMED — mark the beneficiary as revoked (confirmed fraudulent).
      // This propagates across the network immediately: future verifications
      // of this ID will return INVALID ("confirmed fraudulent").
      if (decision === "confirmed" && flag.beneficiary_id) {
        await pool.query(
          `UPDATE beneficiaries
         SET status = 'revoked', status_reason = $1, updated_by = $2
         WHERE id = $3`,
          [
            `Confirmed fraudulent ID. Flag ID: ${id}`,
            req.user.id,
            flag.beneficiary_id,
          ],
        );

        await pool.query(
          `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
         VALUES ($1, 'flag_confirmed', 'beneficiaries', $2, $3)`,
          [
            req.user.id,
            flag.beneficiary_id,
            JSON.stringify({ flag_id: id, decision }),
          ],
        );
      }

      // Auto-restore: if this flag was dismissed and the beneficiary was
      // auto-suspended (not manually revoked), check whether any active flags
      // remain. If none do, automatically restore the beneficiary to 'active'.
      // This prevents indefinite suspension caused by wrongful or expired flags.
      if (decision === "dismissed" && flag.beneficiary_id) {
        const remainingResult = await pool.query(
          `SELECT COUNT(*) AS cnt
           FROM fraud_flags
           WHERE beneficiary_id = $1
             AND flag_status IN ('pending', 'reviewing')`,
          [flag.beneficiary_id],
        );
        const remaining = parseInt(remainingResult.rows[0].cnt, 10);

        if (remaining === 0) {
          const benResult = await pool.query(
            "SELECT status, status_reason FROM beneficiaries WHERE id = $1",
            [flag.beneficiary_id],
          );
          const ben = benResult.rows[0];
          // Only auto-restore system-generated suspensions, not manual ones.
          const wasAutoSuspended =
            ben?.status === "suspended" &&
            ben?.status_reason?.includes("Automatically suspended");

          if (wasAutoSuspended) {
            await pool.query(
              `UPDATE beneficiaries
               SET status = 'active',
                   status_reason = NULL,
                   updated_at = NOW()
               WHERE id = $1`,
              [flag.beneficiary_id],
            );

            await pool.query(
              `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
               VALUES ($1, 'flag_dismissed', 'beneficiaries', $2, $3)`,
              [
                req.user.id,
                flag.beneficiary_id,
                JSON.stringify({
                  auto_restored: true,
                  trigger: "all_flags_dismissed",
                  dismissing_flag_id: id,
                }),
              ],
            );
          }
        }
      }

      res.json({ message: `Flag ${decision} successfully.` });
    } catch (err) {
      next(err);
    }
  },
);

// ── PATCH /api/fraud-flags/:id/restore ────────────────────────
// REQ-2.7.2: Restore a beneficiary to active status after a successful dispute.
// Only allowed on confirmed flags where the beneficiary is currently revoked.
router.patch(
  "/:id/restore",
  authenticate,
  requireRole(["osca_admin", "pdao_admin"]),
  [body("staff_notes").optional().isString().trim()],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const { id } = req.params;
      const { staff_notes } = req.body;

      // Scope to the admin's own type
      const typeMap = { osca_admin: "senior_citizen", pdao_admin: "pwd" };
      const allowedType = typeMap[req.user.role];

      const flagResult = await pool.query(
        `SELECT * FROM fraud_flags WHERE id = $1 AND beneficiary_type = $2`,
        [id, allowedType],
      );
      if (!flagResult.rows.length) throw createError(404, "Flag not found");

      const flag = flagResult.rows[0];
      if (flag.flag_status !== "confirmed") {
        throw createError(400, "Only confirmed flags can be restored.");
      }
      if (!flag.beneficiary_id) {
        throw createError(400, "No beneficiary linked to this flag.");
      }

      // Reopen flag as dismissed (the dispute resolved it)
      await pool.query(
        `UPDATE fraud_flags
         SET flag_status = 'dismissed',
             staff_notes = COALESCE($1, staff_notes),
             reviewed_by = $2,
             reviewed_at = NOW()
         WHERE id = $3`,
        [
          staff_notes
            ? `[RESTORED AFTER DISPUTE] ${staff_notes}`
            : "[RESTORED AFTER DISPUTE]",
          req.user.id,
          id,
        ],
      );

      // Restore beneficiary to active
      await pool.query(
        `UPDATE beneficiaries
         SET status = 'active', status_reason = NULL, updated_by = $1
         WHERE id = $2`,
        [req.user.id, flag.beneficiary_id],
      );

      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
         VALUES ($1, 'flag_restored', 'beneficiaries', $2, $3)`,
        [
          req.user.id,
          flag.beneficiary_id,
          JSON.stringify({ flag_id: id, restored_by: req.user.id }),
        ],
      );

      res.json({
        message:
          "Beneficiary status restored to active. Future verifications of this ID will return VALID (if the ID is not expired).",
      });
    } catch (err) {
      next(err);
    }
  },
);

module.exports = router;
