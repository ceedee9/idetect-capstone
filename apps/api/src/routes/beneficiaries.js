// src/routes/beneficiaries.js
// Beneficiary record management for OSCA and PDAO portals.
//
//   GET    /api/beneficiaries         — List records (filtered by role)
//   GET    /api/beneficiaries/:id     — Get single record
//   POST   /api/beneficiaries         — Create new record
//   PATCH  /api/beneficiaries/:id     — Update record
//   PATCH  /api/beneficiaries/:id/status — Change status (active/suspended/revoked)

const express = require("express");
const { body, param, validationResult } = require("express-validator");
const pool = require("../config/database");
const { authenticate, requireRole } = require("../middleware/auth");
const { createError } = require("../middleware/errorHandler");
const { maskBeneficiary } = require("../utils/privacy");

const router = express.Router();
const DEFAULT_MAX_IMPORT_ROWS = 20000;
const parsedMaxImportRows = parseInt(
  process.env.BENEFICIARY_IMPORT_MAX_ROWS || "",
  10,
);
const MAX_IMPORT_ROWS =
  Number.isFinite(parsedMaxImportRows) && parsedMaxImportRows > 0
    ? parsedMaxImportRows
    : DEFAULT_MAX_IMPORT_ROWS;
const IMPORT_INSERT_CHUNK_SIZE = 500;

// All routes require staff authentication
router.use(authenticate);
router.use(requireRole(["osca_admin", "pdao_admin"]));

// Helper: get the beneficiary_type this admin can access
const getTypeForRole = (role) => {
  return role === "osca_admin" || role === "osca_super_admin"
    ? "senior_citizen"
    : "pwd";
};

const PWD_ID_PATTERN = /^\d{2}-\d{4}-\d{3}-\d{7}$/;

const normalizeDate = (value) => {
  if (!value) return null;
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (!trimmed) return null;
    const parsed = new Date(trimmed);
    if (Number.isNaN(parsed.getTime())) return null;
    return parsed.toISOString().slice(0, 10);
  }
  if (value instanceof Date && !Number.isNaN(value.getTime())) {
    return value.toISOString().slice(0, 10);
  }
  return null;
};

const normalizeMobile = (value) => {
  if (!value) return null;
  const cleaned = String(value)
    .replace(/[^\d+]/g, "")
    .trim();
  return cleaned || null;
};

const normalizeImportRecord = (raw, type) => {
  const id_number = String(raw.id_number || "")
    .trim()
    .toUpperCase();
  const full_name = String(raw.full_name || "")
    .trim()
    .replace(/\s+/g, " ");
  const birthdate = normalizeDate(raw.birthdate);
  const validity_start =
    normalizeDate(raw.validity_start) || new Date().toISOString().slice(0, 10);

  let validity_end = normalizeDate(raw.validity_end);
  if (!validity_end) {
    const nextYear = new Date(validity_start);
    nextYear.setFullYear(nextYear.getFullYear() + 1);
    validity_end = nextYear.toISOString().slice(0, 10);
  }

  const issuing_office =
    String(raw.issuing_office || "").trim() ||
    (type === "senior_citizen" ? "OSCA Valenzuela" : "PDAO Valenzuela");
  const registered_mobile = normalizeMobile(raw.registered_mobile);
  const disability_type =
    type === "pwd" ? String(raw.disability_type || "").trim() || null : null;

  if (!id_number) return { error: "id_number is required" };
  if (type === "pwd" && !PWD_ID_PATTERN.test(id_number)) {
    return { error: "id_number must match PWD format 00-0000-000-0000000" };
  }
  if (!full_name) return { error: "full_name is required" };
  if (!birthdate) return { error: "birthdate must be a valid date" };
  if (!validity_start) return { error: "validity_start must be a valid date" };
  if (!validity_end) return { error: "validity_end must be a valid date" };
  if (new Date(validity_end) < new Date(validity_start)) {
    return { error: "validity_end must not be earlier than validity_start" };
  }

  return {
    record: {
      // Normalize id_number for storage: strip all non-alphanumeric characters
      // and uppercase. Matches the normalization applied at verification query
      // time in verification.js so lookups are always consistent.
      id_number: id_number.replace(/[^A-Z0-9]/g, ""),
      full_name,
      birthdate,
      issuing_office,
      validity_start,
      validity_end,
      registered_mobile,
      disability_type,
    },
  };
};

// ── GET /api/beneficiaries ─────────────────────────────────────
router.get("/", async (req, res, next) => {
  try {
    const type = getTypeForRole(req.user.role);
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const search = req.query.search || "";
    const status = req.query.status || null;

    let query = `
      SELECT id, reference_no, id_number, full_name, birthdate, beneficiary_type,
             issuing_office, validity_start, validity_end, status,
             disability_type, created_at
      FROM beneficiaries
      WHERE beneficiary_type = $1
    `;
    const params = [type];
    let paramIdx = 2;

    if (search) {
      query += ` AND (full_name ILIKE $${paramIdx} OR id_number ILIKE $${paramIdx} OR reference_no ILIKE $${paramIdx})`;
      params.push(`%${search}%`);
      paramIdx++;
    }
    if (status) {
      query += ` AND status = $${paramIdx}`;
      params.push(status);
      paramIdx++;
    }

    query += ` ORDER BY full_name ASC LIMIT $${paramIdx} OFFSET $${paramIdx + 1}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);

    const countParams = [type];
    let countQuery =
      "SELECT COUNT(*) FROM beneficiaries WHERE beneficiary_type = $1";
    if (search) {
      countQuery += ` AND (full_name ILIKE $2 OR id_number ILIKE $2 OR reference_no ILIKE $2)`;
      countParams.push(`%${search}%`);
    }

    const countResult = await pool.query(countQuery, countParams);

    res.json({
      data: result.rows.map(maskBeneficiary),
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

// ── GET /api/beneficiaries/:id ─────────────────────────────────
router.get("/:id([0-9a-fA-F-]{36})/sensitive", async (req, res, next) => {
  try {
    const type = getTypeForRole(req.user.role);
    const result = await pool.query(
      `SELECT id, id_number, beneficiary_type
       FROM beneficiaries
       WHERE id = $1 AND beneficiary_type = $2`,
      [req.params.id, type],
    );

    if (!result.rows.length) throw createError(404, "Beneficiary not found");

    res.json({ id_number: result.rows[0].id_number });
  } catch (err) {
    next(err);
  }
});

router.get("/:id([0-9a-fA-F-]{36})/sensitive-detail", async (req, res, next) => {
  try {
    const type = getTypeForRole(req.user.role);
    const result = await pool.query(
      `SELECT *
       FROM beneficiaries
       WHERE id = $1 AND beneficiary_type = $2`,
      [req.params.id, type],
    );

    if (!result.rows.length) throw createError(404, "Beneficiary not found");

    const detail = maskBeneficiary(result.rows[0]);
    delete detail.age_band;
    detail.birthdate = result.rows[0].birthdate;

    await pool.query(
      `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
       VALUES ($1, 'sensitive_data_revealed', 'beneficiaries', $2, $3)`,
      [
        req.user.id,
        req.params.id,
        JSON.stringify({
          fields: ["beneficiary_detail", "birthdate"],
          beneficiary_type: result.rows[0].beneficiary_type,
        }),
      ],
    );

    res.json(detail);
  } catch (err) {
    next(err);
  }
});

router.get("/:id([0-9a-fA-F-]{36})", async (req, res, next) => {
  try {
    const type = getTypeForRole(req.user.role);

    const result = await pool.query(
      "SELECT * FROM beneficiaries WHERE id = $1 AND beneficiary_type = $2",
      [req.params.id, type],
    );

    if (!result.rows.length) throw createError(404, "Beneficiary not found");
    res.json(maskBeneficiary(result.rows[0]));
  } catch (err) {
    next(err);
  }
});

// ── DELETE /api/beneficiaries/:id ─────────────────────────────
// Only revoked records can be permanently deleted.
router.delete(
  "/:id([0-9a-fA-F-]{36})",
  param("id").isUUID(),
  async (req, res, next) => {
    const client = await pool.connect();
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const type = getTypeForRole(req.user.role);
      await client.query("BEGIN");

      const existing = await client.query(
        `SELECT id, id_number, full_name, beneficiary_type, status
         FROM beneficiaries
         WHERE id = $1 AND beneficiary_type = $2
         FOR UPDATE`,
        [req.params.id, type],
      );

      if (!existing.rows.length)
        throw createError(404, "Beneficiary not found");
      if (existing.rows[0].status !== "revoked") {
        throw createError(
          400,
          "Only revoked beneficiaries can be deleted. Revoke the record first.",
        );
      }

      await client.query("DELETE FROM beneficiaries WHERE id = $1", [
        req.params.id,
      ]);
      await client.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
         VALUES ($1, 'beneficiary_deleted', 'beneficiaries', $2, $3)`,
        [
          req.user.id,
          req.params.id,
          JSON.stringify({ ...existing.rows[0], deleted_by: req.user.id }),
        ],
      );

      await client.query("COMMIT");
      res.json({
        message: `Beneficiary "${existing.rows[0].full_name}" has been permanently deleted.`,
      });
    } catch (err) {
      await client.query("ROLLBACK").catch(() => {});
      if (err.code === "23503") {
        return next(
          createError(
            409,
            "This beneficiary has linked dispute records and cannot be permanently deleted.",
          ),
        );
      }
      next(err);
    } finally {
      client.release();
    }
  },
);

// ── POST /api/beneficiaries/import ─────────────────────────────
router.post("/import", async (req, res, next) => {
  try {
    const type = getTypeForRole(req.user.role);
    const rows = Array.isArray(req.body?.records) ? req.body.records : null;

    if (!rows || rows.length === 0) {
      return res
        .status(400)
        .json({ message: "records must be a non-empty array" });
    }

    if (rows.length > MAX_IMPORT_ROWS) {
      return res
        .status(400)
        .json({ message: `Maximum ${MAX_IMPORT_ROWS} rows per import.` });
    }

    const invalidRows = [];
    const validRows = [];

    rows.forEach((row, index) => {
      const normalized = normalizeImportRecord(row, type);
      if (normalized.error) {
        invalidRows.push({ row: index + 1, error: normalized.error });
      } else {
        validRows.push(normalized.record);
      }
    });

    if (validRows.length === 0) {
      return res.status(400).json({
        message: "No valid rows found in import payload.",
        summary: {
          total: rows.length,
          valid: 0,
          inserted: 0,
          duplicates: 0,
          invalid: invalidRows.length,
        },
        invalidRows,
      });
    }

    let inserted = 0;
    let duplicates = 0;

    // Split rows into 500-row chunks
    const chunks = [];
    for (let i = 0; i < validRows.length; i += IMPORT_INSERT_CHUNK_SIZE) {
      chunks.push(validRows.slice(i, i + IMPORT_INSERT_CHUNK_SIZE));
    }

    const insertSql = `INSERT INTO beneficiaries
        (id_number, full_name, birthdate, beneficiary_type,
         issuing_office, validity_start, validity_end,
         registered_mobile, disability_type, created_by, updated_by)
       VALUES %VALUES%
       ON CONFLICT DO NOTHING
       RETURNING id_number`;

    // Process chunks in parallel batches of 5 (respects the pool size of 10).
    // Each chunk runs in its own transaction on its own connection, so no
    // single connection is held open for the full import duration.
    const PARALLEL_WORKERS = 5;
    try {
      for (let b = 0; b < chunks.length; b += PARALLEL_WORKERS) {
        const batch = chunks.slice(b, b + PARALLEL_WORKERS);
        const batchResults = await Promise.all(
          batch.map(async (chunk) => {
            const c = await pool.connect();
            try {
              await c.query("BEGIN");

              const values = [];
              const placeholders = [];
              chunk.forEach((row, idx) => {
                const base = idx * 11;
                placeholders.push(
                  `($${base + 1},$${base + 2},$${base + 3},$${base + 4},$${base + 5},$${base + 6},$${base + 7},$${base + 8},$${base + 9},$${base + 10},$${base + 11})`,
                );
                values.push(
                  row.id_number,
                  row.full_name,
                  row.birthdate,
                  type,
                  row.issuing_office,
                  row.validity_start,
                  row.validity_end,
                  row.registered_mobile,
                  row.disability_type,
                  req.user.id,
                  req.user.id,
                );
              });

              const result = await c.query(
                insertSql.replace("%VALUES%", placeholders.join(",")),
                values,
              );

              await c.query("COMMIT");
              return {
                ins: result.rowCount,
                dup: chunk.length - result.rowCount,
              };
            } catch (chunkErr) {
              await c.query("ROLLBACK");
              throw chunkErr;
            } finally {
              c.release();
            }
          }),
        );

        for (const r of batchResults) {
          inserted += r.ins;
          duplicates += r.dup;
        }
      }

      // Audit log written after all chunks complete
      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, metadata)
         VALUES ($1, 'beneficiary_bulk_import', 'beneficiaries', $2)`,
        [
          req.user.id,
          JSON.stringify({
            beneficiary_type: type,
            total: rows.length,
            valid: validRows.length,
            inserted,
            duplicates,
            invalid: invalidRows.length,
          }),
        ],
      );
    } catch (dbErr) {
      throw dbErr;
    }

    return res.status(200).json({
      message: "Bulk import processed.",
      summary: {
        total: rows.length,
        valid: validRows.length,
        inserted,
        duplicates,
        invalid: invalidRows.length,
      },
      invalidRows,
    });
  } catch (err) {
    next(err);
  }
});

// ── GET /api/beneficiaries/recently-auto-suspended ─────────────
// Returns beneficiaries that were automatically suspended in the last N hours
// (default 24h) due to flag threshold being reached. Used by OSCA/PDAO
// BeneficiariesPage to show a staff-facing alert banner.
router.get("/recently-auto-suspended", async (req, res, next) => {
  try {
    const type = getTypeForRole(req.user.role);
    const hours = Math.min(parseInt(req.query.hours) || 24, 168); // max 7 days

    const result = await pool.query(
      `SELECT
         b.id, b.id_number, b.full_name, b.beneficiary_type,
         al.created_at AS suspended_at,
         (al.metadata->>'distinct_flaggers')::int AS distinct_flaggers,
         (al.metadata->>'threshold')::int         AS threshold
       FROM audit_logs al
       JOIN beneficiaries b ON b.id = al.target_id
       WHERE al.action = 'flag_confirmed'
         AND al.target_table = 'beneficiaries'
         AND (al.metadata->>'auto_suspended')::boolean = true
         AND al.created_at >= NOW() - ($1::int * INTERVAL '1 hour')
         AND b.beneficiary_type = $2
         AND b.status = 'suspended'
       ORDER BY al.created_at DESC
       LIMIT 20`,
      [hours, type],
    );

    res.json({
      data: result.rows.map(maskBeneficiary),
      total: result.rows.length,
      window_hours: hours,
    });
  } catch (err) {
    next(err);
  }
});

// ── GET /api/beneficiaries/expiring-soon ───────────────────────
router.get("/expiring-soon", async (req, res, next) => {
  try {
    const type = getTypeForRole(req.user.role);
    const days = parseInt(req.query.days) || 30;
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);

    const result = await pool.query(
      `SELECT id, id_number, full_name, beneficiary_type,
              validity_end, status, registered_mobile,
              (validity_end - CURRENT_DATE) AS days_remaining
       FROM beneficiaries
       WHERE beneficiary_type = $1
         AND status = 'active'
         AND validity_end BETWEEN CURRENT_DATE AND (CURRENT_DATE + $2::int)
       ORDER BY validity_end ASC
       LIMIT $3`,
      [type, days, limit],
    );

    res.json({
      data: result.rows.map(maskBeneficiary),
      total: result.rows.length,
      window_days: days,
    });
  } catch (err) {
    next(err);
  }
});

// ── POST /api/beneficiaries ────────────────────────────────────
router.post(
  "/",
  [
    body("id_number").notEmpty().trim().toUpperCase(),
    body("full_name").notEmpty().trim(),
    body("birthdate").isDate(),
    body("issuing_office").notEmpty().trim(),
    body("validity_start").isDate(),
    body("validity_end").isDate(),
    body("registered_mobile").optional().isMobilePhone(),
    body("disability_type").optional().isString().trim(),
    body("address").optional().isString().trim(),
    body("contact_number").optional().isString().trim(),
    body("email").optional().isEmail().normalizeEmail(),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const type = getTypeForRole(req.user.role);
      const {
        id_number,
        full_name,
        birthdate,
        issuing_office,
        validity_start,
        validity_end,
        registered_mobile,
        disability_type,
        address,
        contact_number,
        email,
      } = req.body;

      if (type === "pwd" && !PWD_ID_PATTERN.test(String(id_number || ""))) {
        return res.status(400).json({
          message: "PWD ID format must be 00-0000-000-0000000",
        });
      }

      // Normalize id_number for storage: strip punctuation, uppercase.
      // Matches the normalization in normalizeIdNumber() used at verification
      // query time, so the unique expression index on the normalized form works.
      const storedIdNumber = id_number.replace(/[^A-Z0-9]/g, "");

      const result = await pool.query(
        `INSERT INTO beneficiaries
         (id_number, full_name, birthdate, beneficiary_type,
          issuing_office, validity_start, validity_end,
          registered_mobile, disability_type,
          address, contact_number, email,
          created_by, updated_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$13)
       RETURNING *`,
        [
          storedIdNumber,
          full_name,
          birthdate,
          type,
          issuing_office,
          validity_start,
          validity_end,
          registered_mobile || null,
          type === "pwd" ? disability_type || null : null,
          address || null,
          contact_number || null,
          email || null,
          req.user.id,
        ],
      );

      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
       VALUES ($1, 'beneficiary_created', 'beneficiaries', $2, $3)`,
        [req.user.id, result.rows[0].id, JSON.stringify({ id_number })],
      );

      res.status(201).json(maskBeneficiary(result.rows[0]));
    } catch (err) {
      next(err);
    }
  },
);

// ── PUT /api/beneficiaries/:id ────────────────────────────────
// REQ-2.7.4: Update record fields (corrections from dispute resolutions)
router.put(
  "/:id([0-9a-fA-F-]{36})",
  [
    body("full_name").optional().trim().notEmpty(),
    body("birthdate").optional().isDate(),
    body("issuing_office").optional().trim().notEmpty(),
    body("registered_mobile").optional({ nullable: true }).isMobilePhone(),
    body("disability_type").optional({ nullable: true }).isString().trim(),
    body("address").optional({ nullable: true }).isString().trim(),
    body("contact_number").optional({ nullable: true }).isString().trim(),
    body("email").optional({ nullable: true }).isEmail().normalizeEmail(),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const type = getTypeForRole(req.user.role);
      const existing = await pool.query(
        "SELECT * FROM beneficiaries WHERE id = $1 AND beneficiary_type = $2",
        [req.params.id, type],
      );
      if (!existing.rows.length)
        throw createError(404, "Beneficiary not found");

      const old = existing.rows[0];
      const {
        full_name,
        birthdate,
        issuing_office,
        registered_mobile,
        disability_type,
        address,
        contact_number,
        email,
      } = req.body;

      const updated = await pool.query(
        `UPDATE beneficiaries
         SET full_name         = COALESCE($1, full_name),
             birthdate         = COALESCE($2, birthdate),
             issuing_office    = COALESCE($3, issuing_office),
             registered_mobile = COALESCE($4, registered_mobile),
             disability_type   = COALESCE($5, disability_type),
             address           = COALESCE($6, address),
             contact_number    = COALESCE($7, contact_number),
             email             = COALESCE($8, email),
             updated_by        = $9
         WHERE id = $10
         RETURNING *`,
        [
          full_name || null,
          normalizeDate(birthdate) || null,
          issuing_office || null,
          registered_mobile !== undefined
            ? normalizeMobile(registered_mobile)
            : null,
          disability_type !== undefined ? disability_type || null : null,
          address !== undefined ? address || null : null,
          contact_number !== undefined ? contact_number || null : null,
          email !== undefined ? email || null : null,
          req.user.id,
          req.params.id,
        ],
      );

      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
         VALUES ($1, 'beneficiary_updated', 'beneficiaries', $2, $3)`,
        [
          req.user.id,
          req.params.id,
          JSON.stringify({
            old: {
              full_name: old.full_name,
              birthdate: old.birthdate,
              issuing_office: old.issuing_office,
            },
            new: { full_name, birthdate, issuing_office },
          }),
        ],
      );

      res.json(maskBeneficiary(updated.rows[0]));
    } catch (err) {
      next(err);
    }
  },
);

// ── POST /api/beneficiaries/:id/renew ─────────────────────────
// REQ-2.7.4: Process ID renewal — extend validity period
router.post(
  "/:id([0-9a-fA-F-]{36})/renew",
  [
    body("validity_end")
      .isDate()
      .withMessage("validity_end must be a valid date (YYYY-MM-DD)"),
    body("validity_start").optional().isDate(),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const type = getTypeForRole(req.user.role);
      const existing = await pool.query(
        "SELECT * FROM beneficiaries WHERE id = $1 AND beneficiary_type = $2",
        [req.params.id, type],
      );
      if (!existing.rows.length)
        throw createError(404, "Beneficiary not found");

      const old = existing.rows[0];
      const validity_end = normalizeDate(req.body.validity_end);
      const validity_start =
        normalizeDate(req.body.validity_start) ||
        new Date().toISOString().slice(0, 10);

      if (new Date(validity_end) <= new Date(validity_start)) {
        return res
          .status(400)
          .json({ message: "validity_end must be after validity_start" });
      }

      // Activate the record if it was expired
      const newStatus = old.status === "expired" ? "active" : old.status;

      await pool.query(
        `UPDATE beneficiaries
         SET validity_start = $1, validity_end = $2, status = $3,
             status_reason = NULL, updated_by = $4
         WHERE id = $5`,
        [validity_start, validity_end, newStatus, req.user.id, req.params.id],
      );

      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
         VALUES ($1, 'beneficiary_renewed', 'beneficiaries', $2, $3)`,
        [
          req.user.id,
          req.params.id,
          JSON.stringify({
            old_validity_end: old.validity_end,
            new_validity_end: validity_end,
            old_status: old.status,
            new_status: newStatus,
          }),
        ],
      );

      res.json({
        message: `ID renewed successfully. New validity: ${validity_start} to ${validity_end}.`,
        validity_start,
        validity_end,
        status: newStatus,
      });
    } catch (err) {
      next(err);
    }
  },
);

// ── PATCH /api/beneficiaries/:id/status ───────────────────────
router.patch(
  "/:id/status",
  [
    body("status").isIn(["active", "suspended", "revoked", "expired"]),
    body("status_reason").optional().isString().trim(),
  ],
  async (req, res, next) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const type = getTypeForRole(req.user.role);
      const { status, status_reason } = req.body;

      const existing = await pool.query(
        "SELECT * FROM beneficiaries WHERE id = $1 AND beneficiary_type = $2",
        [req.params.id, type],
      );
      if (!existing.rows.length)
        throw createError(404, "Beneficiary not found");

      const old_status = existing.rows[0].status;

      await pool.query(
        `UPDATE beneficiaries
       SET status = $1, status_reason = $2, updated_by = $3
       WHERE id = $4`,
        [status, status_reason || null, req.user.id, req.params.id],
      );

      await pool.query(
        `INSERT INTO audit_logs (user_id, action, target_table, target_id, metadata)
       VALUES ($1, 'beneficiary_status_changed', 'beneficiaries', $2, $3)`,
        [
          req.user.id,
          req.params.id,
          JSON.stringify({ old_status, new_status: status, status_reason }),
        ],
      );

      res.json({ message: `Status updated to ${status}` });
    } catch (err) {
      next(err);
    }
  },
);

module.exports = router;
