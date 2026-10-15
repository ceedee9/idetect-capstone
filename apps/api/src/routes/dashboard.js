// src/routes/dashboard.js
// Dashboard analytics endpoints.
// Returns server-side aggregated stats based on the caller's role.
//
//   GET /api/dashboard/stats  — Role-aware dashboard statistics

const express = require("express");
const pool = require("../config/database");
const { authenticate, requireRole } = require("../middleware/auth");
const { maskIdNumber } = require("../utils/privacy");

const router = express.Router();

// ── GET /api/dashboard/stats ───────────────────────────────────
// Returns aggregated stats for the caller's portal.
//   osca_admin  → senior_citizen fraud flags, verifications, disputes
//   pdao_admin  → pwd fraud flags, verifications, disputes
//   bplo_admin  → establishment metrics, all verifications, business refusals
router.get(
  "/stats",
  authenticate,
  requireRole([
    "osca_admin",
    "pdao_admin",
    "bplo_admin",
    "osca_super_admin",
    "pdao_super_admin",
    "bplo_super_admin",
  ]),
  async (req, res, next) => {
    try {
      const role = req.user.role.replace("_super_admin", "_admin");

      if (role === "bplo_admin") {
        return res.json(await getBploStats());
      }

      // osca_admin or pdao_admin
      const beneficiaryType = role === "osca_admin" ? "senior_citizen" : "pwd";
      return res.json(await getBeneficiaryPortalStats(beneficiaryType));
    } catch (err) {
      next(err);
    }
  },
);

// ── OSCA / PDAO stats ─────────────────────────────────────────
async function getBeneficiaryPortalStats(beneficiaryType) {
  // 1. Fraud flag counts by status
  const fraudResult = await pool.query(
    `SELECT
       COUNT(*)::int                                          AS total,
       COUNT(*) FILTER (WHERE flag_status = 'pending')::int   AS pending,
       COUNT(*) FILTER (WHERE flag_status = 'reviewing')::int AS reviewing,
       COUNT(*) FILTER (WHERE flag_status = 'confirmed')::int AS confirmed,
       COUNT(*) FILTER (WHERE flag_status = 'dismissed')::int AS dismissed
     FROM fraud_flags
     WHERE beneficiary_type = $1`,
    [beneficiaryType],
  );

  // 2. Dispute counts by status
  const disputeResult = await pool.query(
    `SELECT
       COUNT(*)::int                                              AS total,
       COUNT(*) FILTER (WHERE d.status = 'submitted')::int        AS submitted,
       COUNT(*) FILTER (WHERE d.status = 'acknowledged')::int     AS acknowledged,
       COUNT(*) FILTER (WHERE d.status IN ('resolved','rejected'))::int AS closed
     FROM disputes d
     JOIN verification_logs vl ON d.verification_log_id = vl.id
     WHERE vl.beneficiary_type_detected = $1`,
    [beneficiaryType],
  );

  // 3. Verification result breakdown (last 30 days)
  const verificationResult = await pool.query(
    `SELECT
       COUNT(*)::int                                             AS total,
       COUNT(*) FILTER (WHERE result = 'valid')::int             AS valid,
       COUNT(*) FILTER (WHERE result = 'suspicious')::int        AS suspicious,
       COUNT(*) FILTER (WHERE result = 'invalid')::int           AS invalid,
       COUNT(*) FILTER (WHERE result = 'manual_review')::int     AS manual_review
     FROM verification_logs
     WHERE beneficiary_type_detected = $1
       AND verified_at >= NOW() - INTERVAL '30 days'`,
    [beneficiaryType],
  );

  // 4. Verification trend — daily counts for last 14 days
  const trendResult = await pool.query(
    `SELECT
       d::date AS date,
       COALESCE(c.cnt, 0)::int AS count
     FROM generate_series(
       CURRENT_DATE - INTERVAL '13 days',
       CURRENT_DATE,
       '1 day'
     ) AS d
     LEFT JOIN (
       SELECT DATE(verified_at) AS day, COUNT(*)::int AS cnt
       FROM verification_logs
       WHERE beneficiary_type_detected = $1
         AND verified_at >= CURRENT_DATE - INTERVAL '13 days'
       GROUP BY DATE(verified_at)
     ) c ON c.day = d::date
     ORDER BY d`,
    [beneficiaryType],
  );

  // 5. Top flagged beneficiaries (most fraud flags)
  const topFlaggedResult = await pool.query(
    `SELECT
       ff.id_number_flagged AS id_number,
       b.full_name,
       COUNT(*)::int AS flag_count,
       MAX(ff.flagged_at) AS last_flagged
     FROM fraud_flags ff
     LEFT JOIN beneficiaries b ON b.id = ff.beneficiary_id
     WHERE ff.beneficiary_type = $1
     GROUP BY ff.id_number_flagged, b.full_name
     ORDER BY flag_count DESC, last_flagged DESC
     LIMIT 5`,
    [beneficiaryType],
  );

  // 6. Registrations per month (last 12 months)
  const registrationTrend = await getRegistrationTrend(
    "beneficiaries",
    "AND beneficiary_type = $1",
    [beneficiaryType],
  );

  // 7. Tailored breakdown: OSCA → age bands, PDAO → disability types
  const breakdown =
    beneficiaryType === "senior_citizen"
      ? { ageBands: await getAgeBands() }
      : { disabilityTypes: await getDisabilityTypes() };

  return {
    fraudFlags: fraudResult.rows[0],
    disputes: disputeResult.rows[0],
    registrationTrend,
    ...breakdown,
    verifications: verificationResult.rows[0],
    verificationTrend: trendResult.rows.map((r) => ({
      date: r.date,
      count: r.count,
    })),
    topFlagged: topFlaggedResult.rows.map((row) => ({
      ...row,
      id_number: maskIdNumber(row.id_number),
    })),
  };
}

// ── Portal analytics helpers ──────────────────────────────────
// Registrations per calendar month for the last 12 months (oldest first).
// `table` and `whereSql` are internal constants, never user input.
async function getRegistrationTrend(table, whereSql = "", params = []) {
  const result = await pool.query(
    `SELECT to_char(m, 'YYYY-MM') AS month, COALESCE(c.cnt, 0)::int AS count
     FROM generate_series(
       date_trunc('month', CURRENT_DATE) - INTERVAL '11 months',
       date_trunc('month', CURRENT_DATE),
       INTERVAL '1 month'
     ) AS m
     LEFT JOIN (
       SELECT date_trunc('month', created_at) AS mon, COUNT(*)::int AS cnt
       FROM ${table}
       WHERE created_at >= date_trunc('month', CURRENT_DATE) - INTERVAL '11 months'
       ${whereSql}
       GROUP BY 1
     ) c ON c.mon = m
     ORDER BY m`,
    params,
  );
  return result.rows;
}

// OSCA: senior citizens by age band (fixed bands, zero-filled)
async function getAgeBands() {
  const result = await pool.query(
    `SELECT
       CASE WHEN a >= 90 THEN '90+'
            WHEN a >= 80 THEN '80-89'
            WHEN a >= 70 THEN '70-79'
            ELSE '60-69' END AS band,
       COUNT(*)::int AS count
     FROM (
       SELECT date_part('year', age(birthdate))::int AS a
       FROM beneficiaries
       WHERE beneficiary_type = 'senior_citizen' AND birthdate IS NOT NULL
     ) ages
     WHERE a >= 60
     GROUP BY 1`,
  );
  const counts = new Map(result.rows.map((r) => [r.band, r.count]));
  return ["60-69", "70-79", "80-89", "90+"].map((band) => ({
    label: band,
    count: counts.get(band) ?? 0,
  }));
}

// PDAO: PWD records grouped by disability type (top 6)
async function getDisabilityTypes() {
  const result = await pool.query(
    `SELECT
       INITCAP(LOWER(TRIM(COALESCE(NULLIF(TRIM(disability_type), ''), 'unspecified')))) AS label,
       COUNT(*)::int AS count
     FROM beneficiaries
     WHERE beneficiary_type = 'pwd'
     GROUP BY 1
     ORDER BY count DESC, label
     LIMIT 6`,
  );
  return result.rows;
}

// ── BPLO stats ────────────────────────────────────────────────
async function getBploStats() {
  // 1. Establishment status breakdown
  const estResult = await pool.query(
    `SELECT
       COUNT(*)::int                                          AS total,
       COUNT(*) FILTER (WHERE status = 'pending')::int        AS pending,
       COUNT(*) FILTER (WHERE status = 'approved')::int       AS approved,
       COUNT(*) FILTER (WHERE status = 'suspended')::int      AS suspended,
       COUNT(*) FILTER (WHERE status = 'revoked')::int        AS revoked
     FROM establishments`,
  );

  // 2. Verification result breakdown (last 30 days — all types)
  const verificationResult = await pool.query(
    `SELECT
       COUNT(*)::int                                             AS total,
       COUNT(*) FILTER (WHERE result = 'valid')::int             AS valid,
       COUNT(*) FILTER (WHERE result = 'suspicious')::int        AS suspicious,
       COUNT(*) FILTER (WHERE result = 'invalid')::int           AS invalid,
       COUNT(*) FILTER (WHERE result = 'manual_review')::int     AS manual_review
     FROM verification_logs
     WHERE verified_at >= NOW() - INTERVAL '30 days'`,
  );

  // 3. Verification trend — daily counts for last 14 days
  const trendResult = await pool.query(
    `SELECT
       d::date AS date,
       COALESCE(c.cnt, 0)::int AS count
     FROM generate_series(
       CURRENT_DATE - INTERVAL '13 days',
       CURRENT_DATE,
       '1 day'
     ) AS d
     LEFT JOIN (
       SELECT DATE(verified_at) AS day, COUNT(*)::int AS cnt
       FROM verification_logs
       WHERE verified_at >= CURRENT_DATE - INTERVAL '13 days'
       GROUP BY DATE(verified_at)
     ) c ON c.day = d::date
     ORDER BY d`,
  );

  // 4. Top scanning establishments (most active)
  const topEstResult = await pool.query(
    `SELECT
       e.business_name,
       COUNT(vl.id)::int AS scan_count,
       COUNT(*) FILTER (WHERE vl.result = 'valid')::int       AS valid_count,
       COUNT(*) FILTER (WHERE vl.result = 'suspicious')::int  AS suspicious_count
     FROM verification_logs vl
     JOIN establishments e ON e.id = vl.establishment_id
     WHERE vl.verified_at >= NOW() - INTERVAL '30 days'
     GROUP BY e.id, e.business_name
     ORDER BY scan_count DESC
     LIMIT 5`,
  );

  // 5. Business refusal disputes
  const disputeResult = await pool.query(
    `SELECT
       COUNT(*)::int                                              AS total,
       COUNT(*) FILTER (WHERE status = 'submitted')::int          AS submitted,
       COUNT(*) FILTER (WHERE status = 'acknowledged')::int       AS acknowledged,
       COUNT(*) FILTER (WHERE status IN ('resolved','rejected'))::int AS closed
     FROM disputes
     WHERE dispute_type = 'business_refusal'`,
  );

  const registrationTrend = await getRegistrationTrend("establishments");

  return {
    establishments: estResult.rows[0],
    registrationTrend,
    verifications: verificationResult.rows[0],
    verificationTrend: trendResult.rows.map((r) => ({
      date: r.date,
      count: r.count,
    })),
    topEstablishments: topEstResult.rows,
    disputes: disputeResult.rows[0],
  };
}

module.exports = router;
