// src/routes/reports.js
// CSV export endpoints for verifications, fraud flags, disputes.
//
//   GET /api/reports/verifications/export
//   GET /api/reports/fraud-flags/export
//   GET /api/reports/disputes/export

const express = require("express");
const pool = require("../config/database");
const { authenticate, requireRole } = require("../middleware/auth");
const { maskIdNumber } = require("../utils/privacy");

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

const getTypeForRole = (role) =>
  role === "osca_admin" || role === "osca_super_admin"
    ? "senior_citizen"
    : "pwd";

const isBploRole = (role) =>
  role === "bplo_admin" || role === "bplo_super_admin";
const isOscaRole = (role) =>
  role === "osca_admin" || role === "osca_super_admin";

const escCsv = (val) => {
  if (val == null) return "";
  const s = String(val).replace(/"/g, '""');
  return s.includes(",") || s.includes('"') || s.includes("\n") ? `"${s}"` : s;
};

const logExport = async (userId, table, filters, rowCount) => {
  await pool.query(
    `INSERT INTO audit_logs (user_id, action, target_table, metadata)
     VALUES ($1, 'data_export', $2, $3)`,
    [
      userId,
      table,
      JSON.stringify({ format: "csv", filters, row_count: rowCount }),
    ],
  );
};

// ── GET /api/reports/verifications/export ──────────────────────
router.get("/verifications/export", async (req, res, next) => {
  try {
    const { start_date, end_date, result: resultFilter } = req.query;
    const role = req.user.role;

    let query = `
      SELECT vl.reference_no, vl.id_number_scanned, vl.beneficiary_type_detected, vl.result,
             vl.ocr_confidence_score, vl.manually_entered, vl.verified_at,
             b.full_name AS beneficiary_name,
             e.business_name AS establishment_name
      FROM verification_logs vl
      LEFT JOIN beneficiaries b ON b.id = vl.beneficiary_id
      LEFT JOIN establishments e ON e.id = vl.establishment_id
      WHERE 1=1
    `;
    const params = [];
    let idx = 1;

    // Role filtering
    if (isOscaRole(role)) {
      query += ` AND vl.beneficiary_type_detected = 'senior_citizen'`;
    } else if (!isBploRole(role)) {
      query += ` AND vl.beneficiary_type_detected = 'pwd'`;
    }
    // bplo_admin sees all types

    if (start_date) {
      query += ` AND vl.verified_at >= $${idx}::date`;
      params.push(start_date);
      idx++;
    }
    if (end_date) {
      query += ` AND vl.verified_at < ($${idx}::date + INTERVAL '1 day')`;
      params.push(end_date);
      idx++;
    }
    if (resultFilter) {
      query += ` AND vl.result = $${idx}`;
      params.push(resultFilter);
      idx++;
    }

    query += ` ORDER BY vl.verified_at DESC LIMIT 50000`;

    const result = await pool.query(query, params);
    await logExport(
      req.user.id,
      "verification_logs",
      { start_date, end_date, result: resultFilter },
      result.rows.length,
    );

    const header =
      "Reference No,Date,ID Number,Beneficiary Name,Type,Result,Confidence,Manual Entry,Establishment\n";
    const rows = result.rows.map((r) =>
      [
        escCsv(r.reference_no),
        r.verified_at ? new Date(r.verified_at).toISOString() : "",
        escCsv(maskIdNumber(r.id_number_scanned)),
        escCsv(r.beneficiary_name),
        r.beneficiary_type_detected || "",
        r.result || "",
        r.ocr_confidence_score != null ? r.ocr_confidence_score : "",
        r.manually_entered ? "Yes" : "No",
        escCsv(r.establishment_name),
      ].join(","),
    );

    res.setHeader("Content-Type", "text/csv");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="verifications_${new Date().toISOString().slice(0, 10)}.csv"`,
    );
    res.send(header + rows.join("\n"));
  } catch (err) {
    next(err);
  }
});

// ── GET /api/reports/fraud-flags/export ────────────────────────
router.get("/fraud-flags/export", async (req, res, next) => {
  try {
    const { start_date, end_date, status } = req.query;
    const role = req.user.role;

    let query = `
      SELECT ff.id_number_flagged, ff.beneficiary_type, ff.flag_status,
             ff.establishment_notes, ff.staff_notes,
             ff.flagged_at, ff.reviewed_at,
             b.full_name AS beneficiary_name,
             e.business_name AS establishment_name,
             u.full_name AS reviewer_name
      FROM fraud_flags ff
      LEFT JOIN beneficiaries b ON b.id = ff.beneficiary_id
      LEFT JOIN establishments e ON e.id = ff.establishment_id
      LEFT JOIN users u ON u.id = ff.reviewed_by
      WHERE 1=1
    `;
    const params = [];
    let idx = 1;

    if (isOscaRole(role)) {
      query += ` AND ff.beneficiary_type = 'senior_citizen'`;
    } else if (!isBploRole(role)) {
      query += ` AND ff.beneficiary_type = 'pwd'`;
    }

    if (start_date) {
      query += ` AND ff.flagged_at >= $${idx}::date`;
      params.push(start_date);
      idx++;
    }
    if (end_date) {
      query += ` AND ff.flagged_at < ($${idx}::date + INTERVAL '1 day')`;
      params.push(end_date);
      idx++;
    }
    if (status) {
      query += ` AND ff.flag_status = $${idx}`;
      params.push(status);
      idx++;
    }

    query += ` ORDER BY ff.flagged_at DESC LIMIT 50000`;

    const result = await pool.query(query, params);
    await logExport(
      req.user.id,
      "fraud_flags",
      { start_date, end_date, status },
      result.rows.length,
    );

    const header =
      "Date Flagged,ID Number,Beneficiary,Type,Status,Establishment,Establishment Notes,Reviewer,Staff Notes,Reviewed At\n";
    const rows = result.rows.map((r) =>
      [
        r.flagged_at ? new Date(r.flagged_at).toISOString() : "",
        escCsv(maskIdNumber(r.id_number_flagged)),
        escCsv(r.beneficiary_name),
        r.beneficiary_type || "",
        r.flag_status || "",
        escCsv(r.establishment_name),
        escCsv(r.establishment_notes),
        escCsv(r.reviewer_name),
        escCsv(r.staff_notes),
        r.reviewed_at ? new Date(r.reviewed_at).toISOString() : "",
      ].join(","),
    );

    res.setHeader("Content-Type", "text/csv");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="fraud_flags_${new Date().toISOString().slice(0, 10)}.csv"`,
    );
    res.send(header + rows.join("\n"));
  } catch (err) {
    next(err);
  }
});

// ── GET /api/reports/disputes/export ──────────────────────────
router.get("/disputes/export", async (req, res, next) => {
  try {
    const { start_date, end_date, status: statusFilter } = req.query;
    const role = req.user.role;

    let query = `
      SELECT d.dispute_type, d.status, d.description, d.staff_response,
             d.created_at, d.acknowledged_at, d.resolved_at,
             b.full_name AS beneficiary_name,
             b.id_number AS beneficiary_id_number,
             e.business_name AS establishment_name,
             u.full_name AS resolver_name
      FROM disputes d
      LEFT JOIN beneficiaries b ON b.id = d.beneficiary_id
      LEFT JOIN establishments e ON e.id = d.establishment_id
      LEFT JOIN users u ON u.id = d.resolved_by
      WHERE 1=1
    `;
    const params = [];
    let idx = 1;

    if (isBploRole(role)) {
      query += ` AND d.dispute_type = 'business_refusal'`;
    } else {
      const bType = getTypeForRole(role);
      query += ` AND d.dispute_type != 'business_refusal' AND b.beneficiary_type = $${idx}`;
      params.push(bType);
      idx++;
    }

    if (start_date) {
      query += ` AND d.created_at >= $${idx}::date`;
      params.push(start_date);
      idx++;
    }
    if (end_date) {
      query += ` AND d.created_at < ($${idx}::date + INTERVAL '1 day')`;
      params.push(end_date);
      idx++;
    }
    if (statusFilter) {
      query += ` AND d.status = $${idx}`;
      params.push(statusFilter);
      idx++;
    }

    query += ` ORDER BY d.created_at DESC LIMIT 50000`;

    const result = await pool.query(query, params);
    await logExport(
      req.user.id,
      "disputes",
      { start_date, end_date, status: statusFilter },
      result.rows.length,
    );

    const header =
      "Date Submitted,Type,Status,Beneficiary,ID Number,Establishment,Description,Staff Response,Acknowledged At,Resolved At,Resolver\n";
    const rows = result.rows.map((r) =>
      [
        r.created_at ? new Date(r.created_at).toISOString() : "",
        r.dispute_type || "",
        r.status || "",
        escCsv(r.beneficiary_name),
        escCsv(maskIdNumber(r.beneficiary_id_number)),
        escCsv(r.establishment_name),
        escCsv(r.description),
        escCsv(r.staff_response),
        r.acknowledged_at ? new Date(r.acknowledged_at).toISOString() : "",
        r.resolved_at ? new Date(r.resolved_at).toISOString() : "",
        escCsv(r.resolver_name),
      ].join(","),
    );

    res.setHeader("Content-Type", "text/csv");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="disputes_${new Date().toISOString().slice(0, 10)}.csv"`,
    );
    res.send(header + rows.join("\n"));
  } catch (err) {
    next(err);
  }
});

module.exports = router;
