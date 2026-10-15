const jwt = require("jsonwebtoken");

function requireStepUp(req, res, next) {
  const token = req.headers["x-step-up-token"];
  if (!token) {
    return res.status(401).json({
      error: "Reauthentication required for this sensitive action",
    });
  }

  try {
    const proof = jwt.verify(token, process.env.JWT_SECRET_STAFF);
    if (
      proof.step_up !== true ||
      proof.id !== req.user.id ||
      proof.exp <= Math.floor(Date.now() / 1000)
    ) {
      return res.status(401).json({
        error: "Reauthentication required for this sensitive action",
      });
    }
    next();
  } catch {
    return res.status(401).json({
      error: "Reauthentication required for this sensitive action",
    });
  }
}

// Previews (format=json) stay open; only file downloads need fresh proof.
function requireStepUpForDownload(req, res, next) {
  if (req.query.format === "json") return next();
  return requireStepUp(req, res, next);
}

module.exports = { requireStepUp, requireStepUpForDownload };
