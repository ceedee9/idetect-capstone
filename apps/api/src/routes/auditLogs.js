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
router.use(requireRole([
  "bplo_super_admin",
  "osca_super_admin",
  "pdao_super_admin",
  "osca_admin",
  "pdao_admin",
  "bplo_admin",
]));

// ── GET /api/audit-logs ────────────────────────────────────────
router.get("/", async (req, res, next) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = Math.min(parseInt(req.query.limit) || 30, 100);
    const offset = (page - 1) * limit;
    const { action, search, start_date, end_date } = req.query;

    let query = `
      SELECT al.id, al.action, al.target_table, al.target_id,
             CASE al.target_table
               WHEN 'establishments' THEN te.reference_no
               WHEN 'beneficiaries' THEN tb.reference_no
               WHEN 'disputes' THEN td.reference_no
               WHEN 'fraud_flags' THEN tf.reference_no
               WHEN 'verification_logs' THEN tv.reference_no
               ELSE NULL
             END AS target_reference,
             CASE al.target_table
               WHEN 'establishments' THEN te.business_name
               WHEN 'beneficiaries' THEN tb.full_name
               ELSE NULL
             END AS target_name,
             al.metadata, al.ip_address, al.created_at,
             u.full_name AS user_name,
             u.role AS user_role,
             e.business_name AS establishment_name
      FROM audit_logs al
      LEFT JOIN users u ON u.id = al.user_id
      LEFT JOIN establishments e ON e.id = al.establishment_id
      LEFT JOIN establishments te
        ON al.target_table = 'establishments' AND te.id = al.target_id
      LEFT JOIN beneficiaries tb
        ON al.target_table = 'beneficiaries' AND tb.id = al.target_id
      LEFT JOIN disputes td
        ON al.target_table = 'disputes' AND td.id = al.target_id
      LEFT JOIN fraud_flags tf
        ON al.target_table = 'fraud_flags' AND tf.id = al.target_id
      LEFT JOIN verification_logs tv
        ON al.target_table = 'verification_logs' AND tv.id = al.target_id
      WHERE 1=1
    `;
    const params = [];
    let idx = 1;

    const agencyAdminRole = {
      bplo_super_admin: "bplo_admin",
      osca_super_admin: "osca_admin",
      pdao_super_admin: "pdao_admin",
    }[req.user.role];
    if (agencyAdminRole) {
      query += ` AND u.role IN ($${idx}, $${idx + 1})`;
      params.push(agencyAdminRole, req.user.role);
      idx += 2;
    } else {
      query += ` AND u.role = $${idx}`;
      params.push(req.user.role);
      idx++;
    }

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
             CASE al.target_table
               WHEN 'establishments' THEN te.reference_no
               WHEN 'beneficiaries' THEN tb.reference_no
               WHEN 'disputes' THEN td.reference_no
               WHEN 'fraud_flags' THEN tf.reference_no
               WHEN 'verification_logs' THEN tv.reference_no
               ELSE NULL
             END AS target_reference,
             CASE al.target_table
               WHEN 'establishments' THEN te.business_name
               WHEN 'beneficiaries' THEN tb.full_name
               ELSE NULL
             END AS target_name,
             al.metadata, al.ip_address, al.created_at,
             u.full_name AS user_name,
             u.role AS user_role,
             e.business_name AS establishment_name
      FROM audit_logs al
      LEFT JOIN users u ON u.id = al.user_id
      LEFT JOIN establishments e ON e.id = al.establishment_id
      LEFT JOIN establishments te
        ON al.target_table = 'establishments' AND te.id = al.target_id
      LEFT JOIN beneficiaries tb
        ON al.target_table = 'beneficiaries' AND tb.id = al.target_id
      LEFT JOIN disputes td
        ON al.target_table = 'disputes' AND td.id = al.target_id
      LEFT JOIN fraud_flags tf
        ON al.target_table = 'fraud_flags' AND tf.id = al.target_id
      LEFT JOIN verification_logs tv
        ON al.target_table = 'verification_logs' AND tv.id = al.target_id
      WHERE 1=1
    `;
    const params = [];
    let idx = 1;

    const agencyAdminRole = {
      bplo_super_admin: "bplo_admin",
      osca_super_admin: "osca_admin",
      pdao_super_admin: "pdao_admin",
    }[req.user.role];
    query += agencyAdminRole
      ? ` AND u.role IN ($${idx}, $${idx + 1})`
      : ` AND u.role = $${idx}`;
    params.push(...(agencyAdminRole ? [agencyAdminRole, req.user.role] : [req.user.role]));
    idx += agencyAdminRole ? 2 : 1;

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

    const header = [
      "Date",
      "Action",
      "User",
      "Role",
      "Establishment",
      "Affected Record",
      "Target Table",
      "Target ID",
      "Details",
    ];
    const csvRows = result.rows.map((r) => {
      return csvLine([
        r.created_at ? new Date(r.created_at).toISOString() : "",
        r.action || "",
        r.user_name || "System",
        r.user_role || "",
        r.establishment_name || "",
        r.target_reference || r.target_name || "",
        r.target_table || "",
        r.target_id || "",
        r.metadata,
      ]);
    });

    const csv = [csvLine(header), ...csvRows].join("\n");

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
const REPORT_ROLES = new Set([
  "bplo_super_admin",
  "osca_super_admin",
  "pdao_super_admin",
  "osca_admin",
  "pdao_admin",
  "bplo_admin",
]);

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
    if (q.role && !REPORT_ROLES.has(String(q.role))) {
      return res.status(400).json({ error: "Invalid role" });
    }
    const format = q.format === "json" ? "json" : "csv";

    const params = [period.start, period.end];
    let where = `al.created_at >= $1::date AND al.created_at < ($2::date + INTERVAL '1 day')`;
    const agencyAdminRole = {
      bplo_super_admin: "bplo_admin",
      osca_super_admin: "osca_admin",
      pdao_super_admin: "pdao_admin",
    }[req.user.role];
    params.push(...(agencyAdminRole ? [agencyAdminRole, req.user.role] : [req.user.role]));
    where += agencyAdminRole
      ? ` AND u.role IN ($${params.length - 1}, $${params.length})`
      : ` AND u.role = $${params.length}`;

    let actions = def.actions;
    if (q.action) {
      const asked = String(q.action)
        .split(",")
        .map((a) => a.trim())
        .filter(Boolean);
      if (def.actions && asked.some((action) => !def.actions.includes(action))) {
        return res.status(400).json({ error: "Invalid action for this report type" });
      }
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
      if (agencyAdminRole && ![agencyAdminRole, req.user.role].includes(String(q.role))) {
        return res.status(403).json({ error: "Role is outside your agency scope" });
      }
      params.push(String(q.role));
      where += ` AND u.role::text = $${params.length}`;
    }

    const from = `FROM audit_logs al
      LEFT JOIN users u ON u.id = al.user_id
      LEFT JOIN establishments e ON e.id = al.establishment_id
      LEFT JOIN establishments te
        ON al.target_table = 'establishments' AND te.id = al.target_id
      LEFT JOIN beneficiaries tb
        ON al.target_table = 'beneficiaries' AND tb.id = al.target_id
      LEFT JOIN disputes td
        ON al.target_table = 'disputes' AND td.id = al.target_id
      LEFT JOIN fraud_flags tf
        ON al.target_table = 'fraud_flags' AND tf.id = al.target_id
      LEFT JOIN verification_logs tv
        ON al.target_table = 'verification_logs' AND tv.id = al.target_id
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
                CASE al.target_table
                  WHEN 'establishments' THEN te.reference_no
                  WHEN 'beneficiaries' THEN tb.reference_no
                  WHEN 'disputes' THEN td.reference_no
                  WHEN 'fraud_flags' THEN tf.reference_no
                  WHEN 'verification_logs' THEN tv.reference_no
                  ELSE NULL
                END AS target_reference,
                CASE al.target_table
                  WHEN 'establishments' THEN te.business_name
                  WHEN 'beneficiaries' THEN tb.full_name
                  ELSE NULL
                END AS target_name,
                al.ip_address, al.metadata
         ${from} ORDER BY al.created_at DESC LIMIT ${limit}`,
        params,
      );
      columns = [
        "Date",
        "Action",
        "User",
        "Role",
        "Establishment",
        "Affected Record",
        "Target Table",
        "Target ID",
        "IP Address",
        "Details",
      ];
      rows = r.rows.map((x) => [
        x.created_at ? new Date(x.created_at).toISOString() : "",
        x.action,
        x.user_name || "System",
        x.user_role || "",
        x.establishment_name || "",
        x.target_reference || x.target_name || "",
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
          row_count: total,
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

// ── GET /api/audit-logs/case?ref=DSP-2026-000123 ───────────────
// Court-case file: the record, related records and the full audit timeline.
// format=json for preview, csv (default) to download. ID numbers are masked.
const REF_RE = /^(DSP|FLG|EST|BEN|VER)-\d{4}-\d{6}$/;
const maskId = (v) =>
  v ? "*".repeat(Math.max(String(v).length - 2, 0)) + String(v).slice(-2) : "";
const iso = (d) => (d ? new Date(d).toISOString() : "");

router.get("/case", async (req, res, next) => {
  try {
    const ref = String(req.query.ref || "").trim().toUpperCase();
    if (!REF_RE.test(ref)) {
      return res.status(400).json({
        error: "Enter a reference number like DSP-2026-000123",
      });
    }
    const format = req.query.format === "json" ? "json" : "csv";
    const prefix = ref.slice(0, 3);
    const role = req.user.role;
    const scopeType =
      role === "osca_admin" ? "senior_citizen" : role === "pdao_admin" ? "pwd" : null;
    const denied = () =>
      res.status(404).json({ error: "No record found for that reference number" });

    const sections = [];
    const ids = []; // record ids whose audit entries are included
    let establishmentId = null;
    let logId = null;

    const q = async (sql, p) => (await pool.query(sql, p)).rows;

    if (prefix === "DSP") {
      const [d] = await q(
        `SELECT d.id, d.reference_no, d.dispute_type, d.status, d.explanation, d.staff_response,
                d.submitted_at, d.acknowledged_at, d.resolved_at, d.verification_log_id,
                u.full_name AS handled_by, vl.beneficiary_type_detected AS btype
         FROM disputes d
         LEFT JOIN users u ON u.id = d.handled_by
         LEFT JOIN verification_logs vl ON vl.id = d.verification_log_id
         WHERE d.reference_no = $1`,
        [ref],
      );
      if (!d || (scopeType && d.btype !== scopeType)) return denied();
      ids.push(d.id);
      logId = d.verification_log_id;
      sections.push({
        title: "Dispute",
        columns: ["Reference", "Type", "Status", "Explanation", "Staff response", "Handled by", "Submitted", "Acknowledged", "Resolved"],
        rows: [[d.reference_no, d.dispute_type, d.status, d.explanation, d.staff_response, d.handled_by, iso(d.submitted_at), iso(d.acknowledged_at), iso(d.resolved_at)]],
      });
    } else if (prefix === "FLG") {
      const [f] = await q(
        `SELECT ff.id, ff.reference_no, ff.flag_status, ff.beneficiary_type, ff.id_number_flagged,
                ff.establishment_notes, ff.staff_notes, ff.flagged_at, ff.reviewed_at,
                ff.verification_log_id, ff.establishment_id, u.full_name AS reviewer
         FROM fraud_flags ff LEFT JOIN users u ON u.id = ff.reviewed_by
         WHERE ff.reference_no = $1`,
        [ref],
      );
      if (!f || (scopeType && f.beneficiary_type !== scopeType)) return denied();
      ids.push(f.id);
      logId = f.verification_log_id;
      establishmentId = f.establishment_id;
      sections.push({
        title: "Fraud flag",
        columns: ["Reference", "Status", "Beneficiary type", "ID number", "Establishment notes", "Staff notes", "Reviewed by", "Flagged", "Reviewed"],
        rows: [[f.reference_no, f.flag_status, f.beneficiary_type, maskId(f.id_number_flagged), f.establishment_notes, f.staff_notes, f.reviewer, iso(f.flagged_at), iso(f.reviewed_at)]],
      });
    } else if (prefix === "VER") {
      const [v] = await q(`SELECT id FROM verification_logs WHERE reference_no = $1`, [ref]);
      if (!v) return denied();
      logId = v.id;
    } else if (prefix === "EST") {
      const [e] = await q(
        `SELECT id, reference_no, business_name, created_at FROM establishments WHERE reference_no = $1`,
        [ref],
      );
      if (!e) return denied();
      ids.push(e.id);
      establishmentId = e.id;
      sections.push({
        title: "Establishment",
        columns: ["Reference", "Business name", "Registered"],
        rows: [[e.reference_no, e.business_name, iso(e.created_at)]],
      });
    } else {
      const [b] = await q(
        `SELECT id, reference_no, full_name, id_number, beneficiary_type, created_at
         FROM beneficiaries WHERE reference_no = $1`,
        [ref],
      );
      if (!b || (scopeType && b.beneficiary_type !== scopeType)) return denied();
      ids.push(b.id);
      sections.push({
        title: "Beneficiary",
        columns: ["Reference", "Name", "ID number", "Type", "Registered"],
        rows: [[b.reference_no, b.full_name, maskId(b.id_number), b.beneficiary_type, iso(b.created_at)]],
      });
    }

    // Related scan, flags and disputes (for DSP / FLG / VER)
    if (logId) {
      const [v] = await q(
        `SELECT vl.id, vl.reference_no, vl.result, vl.id_number_scanned, vl.beneficiary_type_detected AS btype,
                vl.verified_at, vl.establishment_id, e.business_name
         FROM verification_logs vl JOIN establishments e ON e.id = vl.establishment_id
         WHERE vl.id = $1`,
        [logId],
      );
      if (v) {
        if (scopeType && v.btype !== scopeType) return denied();
        ids.push(v.id);
        establishmentId = establishmentId || v.establishment_id;
        sections.push({
          title: "Related verification scan",
          columns: ["Reference", "Result", "ID number scanned", "Establishment", "Scanned"],
          rows: [[v.reference_no, v.result, maskId(v.id_number_scanned), v.business_name, iso(v.verified_at)]],
        });
      }
      const flags = await q(
        `SELECT id, reference_no, flag_status, flagged_at FROM fraud_flags WHERE verification_log_id = $1 ORDER BY flagged_at`,
        [logId],
      );
      const disputes = await q(
        `SELECT id, reference_no, dispute_type, status, submitted_at FROM disputes WHERE verification_log_id = $1 ORDER BY submitted_at`,
        [logId],
      );
      flags.forEach((r) => ids.push(r.id));
      disputes.forEach((r) => ids.push(r.id));
      if (flags.length) {
        sections.push({
          title: "Related fraud flags",
          columns: ["Reference", "Status", "Flagged"],
          rows: flags.map((r) => [r.reference_no, r.flag_status, iso(r.flagged_at)]),
        });
      }
      if (disputes.length) {
        sections.push({
          title: "Related disputes",
          columns: ["Reference", "Type", "Status", "Submitted"],
          rows: disputes.map((r) => [r.reference_no, r.dispute_type, r.status, iso(r.submitted_at)]),
        });
      }
    }

    // Audit timeline (oldest first). Establishment files include everything for that establishment.
    const tl = await q(
      `SELECT al.created_at, al.action, u.full_name AS user_name, u.role AS user_role,
              al.target_table, al.target_id, al.ip_address, al.metadata
       FROM audit_logs al LEFT JOIN users u ON u.id = al.user_id
       WHERE al.target_id = ANY($1::uuid[])
          OR ($2::uuid IS NOT NULL AND $3::text = 'EST' AND al.establishment_id = $2::uuid)
       ORDER BY al.created_at ASC LIMIT ${DETAIL_LIMIT}`,
      [ids, establishmentId, prefix],
    );
    sections.push({
      title: "Audit timeline (oldest first)",
      columns: ["Date", "Action", "User", "Role", "Target table", "Target ID", "IP address", "Details"],
      rows: tl.map((r) => [iso(r.created_at), r.action, r.user_name || "System", r.user_role || "", r.target_table || "", r.target_id || "", r.ip_address || "", r.metadata]),
    });

    const meta = { reference_no: ref, generated_at: new Date().toISOString(), audit_entries: tl.length };
    if (format === "json") return res.json({ meta, sections });

    await pool.query(
      `INSERT INTO audit_logs (user_id, action, target_table, metadata)
       VALUES ($1, 'data_export', 'audit_logs', $2)`,
      [req.user.id, JSON.stringify({ format: "csv", report_type: "case_file", reference_no: ref, row_count: tl.length })],
    );

    const lines = [
      ["Case file", ref],
      ["Generated by", req.user.full_name || req.user.id],
      ["Generated at", meta.generated_at],
      ["Note", "ID numbers are masked except the last 2 characters"],
      [],
    ];
    for (const s of sections) {
      lines.push([s.title], s.columns, ...s.rows, []);
    }
    res.setHeader("Content-Type", "text/csv; charset=utf-8");
    res.setHeader("Content-Disposition", `attachment; filename="case_${ref}.csv"`);
    res.send(lines.map(csvLine).join("\n"));
  } catch (err) {
    next(err);
  }
});

module.exports = router;
