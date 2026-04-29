// src/middleware/auth.js
// JWT verification middleware.
// Attach to any route that requires a logged-in user.
// Usage: router.get('/protected', authenticate, (req, res) => {...})

const jwt = require("jsonwebtoken");

// Verifies token and attaches the decoded user to req.user
const authenticate = (req, res, next) => {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1]; // Bearer <token>

  if (!token) {
    return res.status(401).json({ error: "Access token required" });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET_STAFF);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(403).json({ error: "Invalid or expired token" });
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
    if (!req.user || !allowed.includes(req.user.role)) {
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
};
