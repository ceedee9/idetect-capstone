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

// Establishment equivalent: the proof must come from /auth/establishment/reauth
// and belong to the same establishment user that is calling the route.
function requireEstablishmentStepUp(req, res, next) {
  const reauthRequired = () =>
    res.status(401).json({
      error: "Reauthentication required for this sensitive action",
    });

  const token = req.headers["x-step-up-token"];
  if (!token) return reauthRequired();

  try {
    const proof = jwt.verify(token, process.env.JWT_SECRET_ESTABLISHMENT);
    if (
      proof.step_up !== true ||
      proof.id !== req.establishment.id ||
      (proof.establishment_user_id ?? null) !==
        (req.establishment.establishment_user_id ?? null)
    ) {
      return reauthRequired();
    }
    next();
  } catch {
    return reauthRequired();
  }
}

module.exports = {
  requireStepUp,
  requireStepUpForDownload,
  requireEstablishmentStepUp,
};
