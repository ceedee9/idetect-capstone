// src/routes/disputes.js
// Dispute endpoints for beneficiary-submitted challenges.
//
//   POST  /api/disputes                 — Beneficiary submits a dispute
//   POST  /api/disputes/upload-doc      — Upload supporting document (image)
//   GET   /api/disputes                 — OSCA/PDAO lists disputes in their queue
//   GET   /api/disputes/mine            — Beneficiary views their own disputes
//   PATCH /api/disputes/:id/acknowledge — OSCA/PDAO acknowledges a dispute (24h SLA)
//   PATCH /api/disputes/:id/resolve     — OSCA/PDAO resolves a dispute

const path = require("path");
const fs = require("fs");
const express = require("express");
const multer = require("multer");
const { body, validationResult } = require("express-validator");
const pool = require("../config/database");
const {
  authenticate,
  authenticateBeneficiary,
  requireRole,
} = require("../middleware/auth");
const { createError } = require("../middleware/errorHandler");
const { sendPushNotification } = require("../services/fcmService");

const router = express.Router();

// ── Multer setup for supporting document uploads ───────────────
const storage = multer.diskStorage({
  destination: path.join(__dirname, "../../uploads/dispute-docs"),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    cb(
      null,
      `dispute-doc-${Date.now()}-${Math.random().toString(36).slice(2)}${ext}`,
    );
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 8 * 1024 * 1024 }, // 8 MB max
  fileFilter: (req, file, cb) => {
    const allowed = [".jpg", ".jpeg", ".png", ".pdf"];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowed.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error("Only JPG, PNG, and PDF files are allowed."));
    }
  },
});

// ── Magic-bytes MIME validation ────────────────────────────────
// Extension spoofing (e.g. malware.php renamed to malware.jpg) bypasses
// extension-only checks. Reading the first 8 bytes of the saved file and
// comparing against known file signatures catches these attacks.
// If the file does not match any allowed signature it is deleted before
// the response is sent so no invalid file ever persists on disk.
const MAGIC_BYTES = {
  jpg: [0xff, 0xd8, 0xff], // JPEG
  png: [0x89, 0x50, 0x4e, 0x47], // PNG
  pdf: [0x25, 0x50, 0x44, 0x46], // PDF (%PDF)
};

function validateFileMagicBytes(req, res, next) {
  if (!req.file) return next();

  const fd = fs.openSync(req.file.path, "r");
  const buf = Buffer.alloc(8);
  fs.readSync(fd, buf, 0, 8, 0);
  fs.closeSync(fd);

  const valid = Object.values(MAGIC_BYTES).some((sig) =>
    sig.every((byte, i) => buf[i] === byte),
  );

  if (!valid) {
    // Delete the file — it has a spoofed extension
    try {
      fs.unlinkSync(req.file.path);
    } catch (_) {}
    return res.status(400).json({
      error:
        "Invalid file type. Only genuine JPG, PNG, and PDF files are accepted.",
    });
  }

  next();
}

// ── POST /api/disputes/upload-doc ──────────────────────────────
// REQ-2.13.3: Upload supporting documentation before dispute submission
router.post(
  "/upload-doc",
  authenticateBeneficiary,
  upload.single("document"),
  validateFileMagicBytes,
  (req, res, next) => {
    if (!req.file) {
      return res.status(400).json({ error: "No file uploaded." });
    }
    // Return a relative URL path the client includes as supporting_doc_path
    const docPath = `/api/uploads/dispute-docs/${req.file.filename}`;
    res.json({ path: docPath });
  },
);

// ── POST /api/disputes ─────────────────────────────────────────
// REQ-2.13.1 through 2.13.4: Beneficiary submits a dispute
router.post(
  "/",
  authenticateBeneficiary,
  [
    body("verification_log_id").optional().isUUID(),
    body("dispute_type").isIn([
      "wrong_denial",
      "unauthorized_use",
      "business_refusal",
      "incorrect_db_info",
    ]),
    body("explanation").isString().trim().notEmpty(),
    body("supporting_doc_path").optional().isString().trim(),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const accountId = req.beneficiary.id || req.beneficiary.accountId;
      const {
        verification_log_id,
        dispute_type,
        explanation,
        supporting_doc_path,
      } = req.body;

      const result = await pool.query(
        `INSERT INTO disputes
         (beneficiary_account_id, verification_log_id, dispute_type, explanation, supporting_doc_path)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
        [
          accountId,
          verification_log_id || null,
          dispute_type,
          explanation,
          supporting_doc_path || null,
        ],
      );

      const dispute = result.rows[0];

      // Notify beneficiary of receipt (submission confirmation)
      await pool.query(
        `INSERT INTO notifications
         (beneficiary_account_id, notification_type, title, body, channel, dispute_id)
       VALUES ($1, 'dispute_submitted', $2, $3, 'push', $4)`,
        [
          accountId,
          "Dispute Received",
          `Your dispute (Ref: ${dispute.id.slice(0, 8).toUpperCase()}) has been received. We will acknowledge it within 24 hours.`,
          dispute.id,
        ],
      );

      // Log the audit trail
      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
       VALUES ($1, 'dispute_submitted', 'disputes', $2, $3)`,
        [
          null,
          dispute.id,
          JSON.stringify({ dispute_type, beneficiary_account_id: accountId }),
        ],
      );

      res.status(201).json({
        message:
          "Dispute submitted successfully. You will receive acknowledgment within 24 hours.",
        dispute_id: dispute.id,
        reference: dispute.id.slice(0, 8).toUpperCase(),
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── GET /api/disputes/mine ─────────────────────────────────────
// REQ-2.13.5: Beneficiary tracks their disputes
router.get("/mine", authenticateBeneficiary, async (req, res, next) => {
  try {
    const accountId = req.beneficiary.id || req.beneficiary.accountId;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    const result = await pool.query(
      `SELECT
         d.*,
         vl.result            AS verification_result,
         e.business_name      AS establishment_name
       FROM disputes d
       LEFT JOIN verification_logs vl ON vl.id = d.verification_log_id
       LEFT JOIN establishments e ON e.id = vl.establishment_id
       WHERE d.beneficiary_account_id = $1
       ORDER BY d.submitted_at DESC
       LIMIT $2 OFFSET $3`,
      [accountId, limit, offset],
    );

    const countResult = await pool.query(
      "SELECT COUNT(*) FROM disputes WHERE beneficiary_account_id = $1",
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

// ── GET /api/disputes ──────────────────────────────────────────
// OSCA sees senior_citizen disputes. PDAO sees pwd disputes.
// BPLO sees business_refusal disputes only.
router.get(
  "/",
  authenticate,
  requireRole(["osca_admin", "pdao_admin", "bplo_admin"]),
  async (req, res, next) => {
    try {
      const status = req.query.status;
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 20;
      const offset = (page - 1) * limit;

      // Build WHERE clause based on admin role
      let typeFilter;
      if (req.user.role === "bplo_admin") {
        // BPLO only sees business refusal disputes (REQ-2.14.2)
        typeFilter = `d.dispute_type = 'business_refusal'`;
      } else {
        // OSCA/PDAO see disputes that match their beneficiary type
        const typeMap = { osca_admin: "senior_citizen", pdao_admin: "pwd" };
        const beneficiaryType = typeMap[req.user.role];
        typeFilter = `b.beneficiary_type = '${beneficiaryType}'`;
      }

      const statusClause = status ? `AND d.status = $1` : "";
      const params = status ? [status, limit, offset] : [limit, offset];
      const paramOffset = status ? 1 : 0;

      const result = await pool.query(
        `SELECT
         d.*,
         ba.beneficiary_id,
         b.full_name         AS beneficiary_name,
         b.id_number         AS beneficiary_id_number,
         b.beneficiary_type,
         vl.result            AS verification_result,
         e.business_name      AS establishment_name,
         u.email              AS handled_by_email
       FROM disputes d
       JOIN beneficiary_accounts ba ON ba.id = d.beneficiary_account_id
       JOIN beneficiaries b ON b.id = ba.beneficiary_id
       LEFT JOIN verification_logs vl ON vl.id = d.verification_log_id
       LEFT JOIN establishments e ON e.id = vl.establishment_id
       LEFT JOIN users u ON u.id = d.handled_by
       WHERE ${typeFilter} ${statusClause}
       ORDER BY
         CASE d.status
           WHEN 'submitted' THEN 1
           WHEN 'acknowledged' THEN 2
           WHEN 'under_review' THEN 3
           WHEN 'resolved' THEN 4
           WHEN 'rejected' THEN 5
         END,
         d.submitted_at DESC
       LIMIT $${paramOffset + 1} OFFSET $${paramOffset + 2}`,
        params,
      );

      const countResult = await pool.query(
        `SELECT COUNT(*) FROM disputes d
       JOIN beneficiary_accounts ba ON ba.id = d.beneficiary_account_id
       JOIN beneficiaries b ON b.id = ba.beneficiary_id
       WHERE ${typeFilter} ${statusClause}`,
        status ? [status] : [],
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
  },
);

// ── PATCH /api/disputes/:id/acknowledge ────────────────────────
// REQ-2.13.6: 24h acknowledgment SLA
router.patch(
  "/:id/acknowledge",
  authenticate,
  requireRole(["osca_admin", "pdao_admin", "bplo_admin"]),
  async (req, res, next) => {
    try {
      const { id } = req.params;

      const disputeResult = await pool.query(
        `SELECT d.*, b.beneficiary_type
       FROM disputes d
       JOIN beneficiary_accounts ba ON ba.id = d.beneficiary_account_id
       JOIN beneficiaries b ON b.id = ba.beneficiary_id
       WHERE d.id = $1`,
        [id],
      );
      if (!disputeResult.rows.length)
        throw createError(404, "Dispute not found");

      const dispute = disputeResult.rows[0];

      // Enforce data compartmentalization
      if (
        req.user.role === "osca_admin" &&
        dispute.beneficiary_type !== "senior_citizen"
      ) {
        throw createError(403, "OSCA can only handle senior citizen disputes");
      }
      if (
        req.user.role === "pdao_admin" &&
        dispute.beneficiary_type !== "pwd"
      ) {
        throw createError(403, "PDAO can only handle PWD disputes");
      }
      if (
        req.user.role === "bplo_admin" &&
        dispute.dispute_type !== "business_refusal"
      ) {
        throw createError(
          403,
          "BPLO can only handle business refusal disputes",
        );
      }

      if (dispute.status !== "submitted") {
        throw createError(400, "Dispute has already been acknowledged");
      }

      await pool.query(
        `UPDATE disputes SET status = 'acknowledged', acknowledged_at = NOW(), handled_by = $1 WHERE id = $2`,
        [req.user.id, id],
      );

      // Notify the beneficiary
      const notifTitle = "Dispute Acknowledged";
      const notifBody = `Your dispute (Ref: ${id.slice(0, 8).toUpperCase()}) has been acknowledged and is now under review.`;

      await pool.query(
        `INSERT INTO notifications
         (beneficiary_account_id, notification_type, title, body, channel, dispute_id)
       VALUES ($1, 'dispute_acknowledged', $2, $3, 'push', $4)`,
        [dispute.beneficiary_account_id, notifTitle, notifBody, id],
      );

      // Send FCM push (fire-and-forget)
      const tokenResult = await pool.query(
        "SELECT device_token FROM beneficiary_accounts WHERE id = $1",
        [dispute.beneficiary_account_id],
      );
      const deviceToken = tokenResult.rows[0]?.device_token;
      if (deviceToken) {
        sendPushNotification(deviceToken, notifTitle, notifBody, {
          type: "dispute_acknowledged",
          dispute_id: id,
        })
          .then((fcmResult) => {
            if (fcmResult.invalidToken) {
              pool
                .query(
                  "UPDATE beneficiary_accounts SET device_token = NULL WHERE id = $1",
                  [dispute.beneficiary_account_id],
                )
                .catch(() => {});
            }
          })
          .catch(() => {});
      }

      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
       VALUES ($1, 'dispute_acknowledged', 'disputes', $2, $3)`,
        [req.user.id, id, JSON.stringify({ previous_status: "submitted" })],
      );

      res.json({ message: "Dispute acknowledged successfully." });
    } catch (err) {
      next(err);
    }
  },
);

// ── PATCH /api/disputes/:id/resolve ────────────────────────────
// REQ-2.13.6: Resolution with staff response
router.patch(
  "/:id/resolve",
  authenticate,
  requireRole(["osca_admin", "pdao_admin", "bplo_admin"]),
  [
    body("decision").isIn(["resolved", "rejected"]),
    body("staff_response").isString().trim().isLength({ min: 1, max: 2000 }),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const { id } = req.params;
      const { decision, staff_response } = req.body;

      const disputeResult = await pool.query(
        `SELECT d.*, b.beneficiary_type
       FROM disputes d
       JOIN beneficiary_accounts ba ON ba.id = d.beneficiary_account_id
       JOIN beneficiaries b ON b.id = ba.beneficiary_id
       WHERE d.id = $1`,
        [id],
      );
      if (!disputeResult.rows.length)
        throw createError(404, "Dispute not found");

      const dispute = disputeResult.rows[0];

      // Enforce data compartmentalization
      if (
        req.user.role === "osca_admin" &&
        dispute.beneficiary_type !== "senior_citizen"
      ) {
        throw createError(403, "OSCA can only handle senior citizen disputes");
      }
      if (
        req.user.role === "pdao_admin" &&
        dispute.beneficiary_type !== "pwd"
      ) {
        throw createError(403, "PDAO can only handle PWD disputes");
      }
      if (
        req.user.role === "bplo_admin" &&
        dispute.dispute_type !== "business_refusal"
      ) {
        throw createError(
          403,
          "BPLO can only handle business refusal disputes",
        );
      }

      if (!["acknowledged", "under_review"].includes(dispute.status)) {
        throw createError(
          400,
          "Dispute must be acknowledged before it can be resolved",
        );
      }

      await pool.query(
        `UPDATE disputes
       SET status = $1, staff_response = $2, handled_by = $3, resolved_at = NOW()
       WHERE id = $4`,
        [decision, staff_response, req.user.id, id],
      );

      // If the dispute is resolved in favor of the beneficiary and it was a wrong denial,
      // consider restoring their status
      if (decision === "resolved" && dispute.dispute_type === "wrong_denial") {
        const baResult = await pool.query(
          "SELECT beneficiary_id FROM beneficiary_accounts WHERE id = $1",
          [dispute.beneficiary_account_id],
        );
        if (baResult.rows.length) {
          await pool.query(
            `UPDATE beneficiaries SET status = 'active', status_reason = $1, updated_by = $2 WHERE id = $3`,
            [
              `Restored via dispute resolution. Dispute ID: ${id}`,
              req.user.id,
              baResult.rows[0].beneficiary_id,
            ],
          );
        }
      }

      // Notify the beneficiary of the resolution
      const resolveTitle =
        decision === "resolved" ? "Dispute Resolved" : "Dispute Decision";
      const resolveBody = `Your dispute (Ref: ${id.slice(0, 8).toUpperCase()}) has been ${decision}. ${staff_response}`;

      await pool.query(
        `INSERT INTO notifications
         (beneficiary_account_id, notification_type, title, body, channel, dispute_id)
       VALUES ($1, 'dispute_resolved', $2, $3, 'push', $4)`,
        [dispute.beneficiary_account_id, resolveTitle, resolveBody, id],
      );

      // Send FCM push (fire-and-forget)
      const resolveTokenResult = await pool.query(
        "SELECT device_token FROM beneficiary_accounts WHERE id = $1",
        [dispute.beneficiary_account_id],
      );
      const resolveToken = resolveTokenResult.rows[0]?.device_token;
      if (resolveToken) {
        sendPushNotification(resolveToken, resolveTitle, resolveBody, {
          type: "dispute_resolved",
          dispute_id: id,
          decision,
        })
          .then((fcmResult) => {
            if (fcmResult.invalidToken) {
              pool
                .query(
                  "UPDATE beneficiary_accounts SET device_token = NULL WHERE id = $1",
                  [dispute.beneficiary_account_id],
                )
                .catch(() => {});
            }
          })
          .catch(() => {});
      }

      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
       VALUES ($1, 'dispute_resolved', 'disputes', $2, $3)`,
        [
          req.user.id,
          id,
          JSON.stringify({ decision, dispute_type: dispute.dispute_type }),
        ],
      );

      res.json({ message: `Dispute ${decision} successfully.` });
    } catch (err) {
      next(err);
    }
  },
);

module.exports = router;
