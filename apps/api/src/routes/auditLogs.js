// src/routes/auditLogs.js
// Immutable audit trail viewer for OSCA, PDAO, and BPLO admins.
//
//   GET  /api/audit-logs          — List with filtering (action, date range, search)
//   GET  /api/audit-logs/export   — CSV download

const express = require("express");
const pool = require("../config/database");
const { authenticate, requireRole } = require("../middleware/auth");

const {
  REPORT_TYPES,
  DETAIL_LIMIT,
  resolvePeriod,
  csvLine,
} = require("../services/auditReports");

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

// ── GET /api/audit-logs/report ─────────────────────────────────
// Filtered, period-based reports.
//   type=summary|staff|security|exports   period=month|quarter|half|year|custom
//   mode=summary|detail   group_by=month|action|user (summary mode)
//   user_id, role, action (comma list), format=csv|json (json = preview)
const GROUP_EXPR = {
  month: "to_char(date_trunc('month', al.created_at), 'YYYY-MM')",
  action: "al.action::text",
  user: "COALESCE(u.full_name, 'System')",
};
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

router.get("/report", async (req, res, next) => {
  try {
    const q = req.query;
    const type = q.type || "summary";
    const def = REPORT_TYPES[type];
    if (!def) return res.status(400).json({ error: "Invalid report type" });

    const period = resolvePeriod(q);
    if (period.error) return res.status(400).json({ error: period.error });

    const mode = q.mode || (type === "summary" ? "summary" : "detail");
    if (!["summary", "detail"].includes(mode)) {
      return res.status(400).json({ error: "Invalid mode" });
    }
    const groupBy = q.group_by || "month";
    if (!GROUP_EXPR[groupBy]) {
      return res.status(400).json({ error: "Invalid group_by" });
    }
    if (q.user_id && !UUID_RE.test(q.user_id)) {
      return res.status(400).json({ error: "Invalid user_id" });
    }
    const format = q.format === "json" ? "json" : "csv";

    const params = [period.start, period.end];
    let where = `al.created_at >= $1::date AND al.created_at < ($2::date + INTERVAL '1 day')`;

    let actions = def.actions;
    if (q.action) {
      const asked = String(q.action)
        .split(",")
        .map((a) => a.trim())
        .filter(Boolean);
      actions = actions ? asked.filter((a) => actions.includes(a)) : asked;
    }
    if (actions) {
      params.push(actions);
      where += ` AND al.action::text = ANY($${params.length}::text[])`;
    }
    if (q.user_id) {
      params.push(q.user_id);
      where += ` AND al.user_id = $${params.length}`;
    }
    if (q.role) {
      params.push(String(q.role));
      where += ` AND u.role::text = $${params.length}`;
    }

    const from = `FROM audit_logs al
      LEFT JOIN users u ON u.id = al.user_id
      LEFT JOIN establishments e ON e.id = al.establishment_id
      WHERE ${where}`;

    let columns;
    let rows;
    let total;
    if (mode === "summary") {
      const g = GROUP_EXPR[groupBy];
      const r = await pool.query(
        `SELECT ${g} AS grp, al.action::text AS action, COUNT(*)::int AS count
         ${from} GROUP BY 1, 2 ORDER BY 1, 2`,
        params,
      );
      columns = [groupBy === "user" ? "User" : groupBy === "month" ? "Month" : "Action", "Action", "Count"];
      rows = r.rows.map((x) => [x.grp, x.action, x.count]);
      total = rows.reduce((s, x) => s + x[2], 0);
      rows.push(["TOTAL", "", total]);
    } else {
      const limit = format === "json" ? 100 : DETAIL_LIMIT;
      const cnt = await pool.query(`SELECT COUNT(*)::int AS n ${from}`, params);
      total = cnt.rows[0].n;
      const r = await pool.query(
        `SELECT al.created_at, al.action, u.full_name AS user_name, u.role AS user_role,
                e.business_name AS establishment_name, al.target_table, al.target_id,
                al.ip_address, al.metadata
         ${from} ORDER BY al.created_at DESC LIMIT ${limit}`,
        params,
      );
      columns = ["Date", "Action", "User", "Role", "Establishment", "Target Table", "Target ID", "IP Address", "Details"];
      rows = r.rows.map((x) => [
        x.created_at ? new Date(x.created_at).toISOString() : "",
        x.action,
        x.user_name || "System",
        x.user_role || "",
        x.establishment_name || "",
        x.target_table || "",
        x.target_id || "",
        x.ip_address || "",
        x.metadata,
      ]);
    }

    const meta = {
      report: def.label,
      mode,
      period: period.label,
      start_date: period.start,
      end_date: period.end,
      total,
    };

    if (format === "json") return res.json({ meta, columns, rows });

    await pool.query(
      `INSERT INTO audit_logs (user_id, action, target_table, metadata)
       VALUES ($1, 'data_export', 'audit_logs', $2)`,
      [
        req.user.id,
        JSON.stringify({
          format: "csv",
          report_type: type,
          mode,
          period: period.label,
          filters: { action: q.action, user_id: q.user_id, role: q.role },
          row_count: rows.length,
        }),
      ],
    );

    const cover = [
      ["Report", def.label],
      ["Mode", mode],
      ["Period", `${period.start} to ${period.end}`],
      ["Filters", [q.action && `action=${q.action}`, q.user_id && `user=${q.user_id}`, q.role && `role=${q.role}`].filter(Boolean).join("; ") || "none"],
      ["Generated by", req.user.full_name || req.user.id],
      ["Generated at", new Date().toISOString()],
      ["Records", total],
      [],
    ];
    if (mode === "detail" && total > rows.length) {
      cover.splice(7, 0, ["Note", `Truncated to the newest ${rows.length} records`]);
    }
    const csv = [...cover, columns, ...rows].map(csvLine).join("\n");

    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="audit_${type}_${mode}_${period.label.replace(/\s+/g, "_")}.csv"`,
    );
    res.send(csv);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
