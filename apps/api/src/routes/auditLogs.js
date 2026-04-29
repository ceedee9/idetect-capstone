// src/routes/auditLogs.js
// Immutable audit trail viewer for OSCA, PDAO, and BPLO admins.
//
//   GET  /api/audit-logs          — List with filtering (action, date range, search)
//   GET  /api/audit-logs/export   — CSV download

const express = require("express");
const pool = require("../config/database");
const { authenticate, requireRole } = require("../middleware/auth");

const router = express.Router();

router.use(authenticate);
router.use(requireRole(["osca_admin", "pdao_admin", "bplo_admin"]));

// ── GET /api/audit-logs ────────────────────────────────────────
router.get("/", async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = Math.min(parseInt(req.query.limit) || 30, 100);
    const offset = (page - 1) * limit;
    const { action, search, start_date, end_date } = req.query;

    let query = `
      SELECT al.id, al.action, al.target_table, al.target_id,
             al.metadata, al.ip_address, al.created_at,
             u.full_name AS user_name,
             u.role AS user_role,
             e.business_name AS establishment_name
      FROM audit_logs al
      LEFT JOIN users u ON u.id = al.user_id
      LEFT JOIN establishments e ON e.id = al.establishment_id
      WHERE 1=1
    `;
    const params = [];
    let idx = 1;

    if (action) {
      query += ` AND al.action = $${idx}`;
      params.push(action);
      idx++;
    }

    if (start_date) {
      query += ` AND al.created_at >= $${idx}::date`;
      params.push(start_date);
      idx++;
    }

    if (end_date) {
      query += ` AND al.created_at < ($${idx}::date + INTERVAL '1 day')`;
      params.push(end_date);
      idx++;
    }

    if (search) {
      query += ` AND (
        al.target_table ILIKE $${idx}
        OR al.action::text ILIKE $${idx}
        OR u.full_name ILIKE $${idx}
        OR e.business_name ILIKE $${idx}
        OR al.metadata::text ILIKE $${idx}
      )`;
      params.push(`%${search}%`);
      idx++;
    }

    // Count
    const countQuery = query.replace(
      /SELECT .+? FROM/s,
      "SELECT COUNT(*) FROM",
    );
    const countResult = await pool.query(countQuery, params);
    const total = parseInt(countResult.rows[0].count);

    // Data
    query += ` ORDER BY al.created_at DESC LIMIT $${idx} OFFSET $${idx + 1}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);

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

// ── GET /api/audit-logs/export ─────────────────────────────────
router.get("/export", async (req, res, next) => {
  try {
    const { action, start_date, end_date, search } = req.query;

    let query = `
      SELECT al.action, al.target_table, al.target_id,
             al.metadata, al.ip_address, al.created_at,
             u.full_name AS user_name,
             u.role AS user_role,
             e.business_name AS establishment_name
      FROM audit_logs al
      LEFT JOIN users u ON u.id = al.user_id
      LEFT JOIN establishments e ON e.id = al.establishment_id
      WHERE 1=1
    `;
    const params = [];
    let idx = 1;

    if (action) {
      query += ` AND al.action = $${idx}`;
      params.push(action);
      idx++;
    }
    if (start_date) {
      query += ` AND al.created_at >= $${idx}::date`;
      params.push(start_date);
      idx++;
    }
    if (end_date) {
      query += ` AND al.created_at < ($${idx}::date + INTERVAL '1 day')`;
      params.push(end_date);
      idx++;
    }
    if (search) {
      query += ` AND (al.target_table ILIKE $${idx} OR al.action::text ILIKE $${idx} OR al.metadata::text ILIKE $${idx})`;
      params.push(`%${search}%`);
      idx++;
    }

    query += ` ORDER BY al.created_at DESC LIMIT 10000`;

    const result = await pool.query(query, params);

    // Log the export action
    await pool.query(
      `INSERT INTO audit_logs (user_id, action, target_table, metadata)
       VALUES ($1, 'data_export', 'audit_logs', $2)`,
      [
        req.user.id,
        JSON.stringify({
          format: "csv",
          filters: { action, start_date, end_date, search },
          row_count: result.rows.length,
        }),
      ],
    );

    const header =
      "Date,Action,User,Role,Establishment,Target Table,Target ID,Details\n";
    const csvRows = result.rows.map((r) => {
      const meta =
        typeof r.metadata === "object"
          ? JSON.stringify(r.metadata).replace(/"/g, '""')
          : String(r.metadata || "");
      return [
        r.created_at ? new Date(r.created_at).toISOString() : "",
        r.action || "",
        (r.user_name || "System").replace(/,/g, " "),
        r.user_role || "",
        (r.establishment_name || "").replace(/,/g, " "),
        r.target_table || "",
        r.target_id || "",
        `"${meta}"`,
      ].join(",");
    });

    const csv = header + csvRows.join("\n");

    res.setHeader("Content-Type", "text/csv");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="audit_logs_${new Date().toISOString().slice(0, 10)}.csv"`,
    );
    res.send(csv);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
