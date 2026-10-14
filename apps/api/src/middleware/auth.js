// src/middleware/auth.js
// JWT verification middleware.
// Attach to any route that requires a logged-in user.
// Usage: router.get('/protected', authenticate, (req, res) => {...})

const jwt = require("jsonwebtoken");
const pool = require("../config/database");

const normalizeStaffRole = (role) =>
  typeof role === "string" && role.endsWith("_super_admin")
    ? role.replace("_super_admin", "_admin")
    : role;

// Verifies token, checks signature, AND confirms the account is still active
// in the database. This ensures deactivated staff accounts lose access
// immediately rather than waiting for the JWT to expire naturally.
const authenticate = async (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1]; // Bearer <token>

  if (!token) {
    return res.status(401).json({ error: "Access token required" });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET_STAFF);

    // Confirm the user still exists and is active in the DB.
    // This invalidates tokens for deactivated/deleted accounts immediately.
    const result = await pool.query(
      "SELECT id, is_active, role, full_name FROM users WHERE id = $1",
      [decoded.id],
    );
    if (!result.rows.length || !result.rows[0].is_active) {
      return res.status(401).json({ error: "Account not found or inactive" });
    }

    const currentUser = result.rows[0];
    req.user = {
      ...decoded,
      role: currentUser.role,
      full_name: currentUser.full_name || decoded.full_name,
      portalRole: normalizeStaffRole(currentUser.role),
    };
    next();
  } catch (err) {
    if (err.name === "JsonWebTokenError" || err.name === "TokenExpiredError") {
      return res.status(403).json({ error: "Invalid or expired token" });
    }
    next(err);
  }
};

// Verifies establishment token (Client Portal mobile app)
const authenticateEstablishment = (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];

  if (!token) {
    return res.status(401).json({ error: "Access token required" });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET_ESTABLISHMENT);
    req.establishment = decoded;
    next();
  } catch (err) {
    return res.status(403).json({ error: "Invalid or expired token" });
  }
};

// Verifies beneficiary token (Beneficiary mobile app)
const authenticateBeneficiary = (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];

  if (!token) {
    return res.status(401).json({ error: "Access token required" });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET_BENEFICIARY);
    // Normalize: always expose account id as both .id and .accountId
    decoded.id = decoded.id || decoded.accountId;
    decoded.accountId = decoded.id;
    req.beneficiary = decoded;
    next();
  } catch (err) {
    return res.status(403).json({ error: "Invalid or expired token" });
  }
};

// Role check — use AFTER authenticate
// Usage: requireRole('osca_admin') or requireRole(['osca_admin', 'pdao_admin'])
const requireRole = (roles) => {
  const allowed = Array.isArray(roles) ? roles : [roles];
  return (req, res, next) => {
    const allowedWithSuperAdmins = new Set([
      ...allowed,
      ...allowed
        .filter((role) => role.endsWith("_admin"))
        .map((role) => role.replace("_admin", "_super_admin")),
    ]);
    if (!req.user || !allowedWithSuperAdmins.has(req.user.role)) {
      return res.status(403).json({ error: "Insufficient permissions" });
    }
    next();
  };
};

module.exports = {
  authenticate,
  authenticateEstablishment,
  authenticateBeneficiary,
  requireRole,
  normalizeStaffRole,
};
