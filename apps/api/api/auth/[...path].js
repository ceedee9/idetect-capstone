// apps/api/api/auth/[...path].js
// Dedicated catch-all specifically for /api/auth/* — splitting this out
// from the top-level catch-all reduces the number of segments this
// function's own dynamic parameter needs to capture, to test whether
// that's what's causing Vercel to fail to match OPTIONS preflight
// requests on deeply nested paths.
const app = require("../../src/app");

module.exports = (req, res) => {
  if (req.method === "OPTIONS") {
    const allowedOrigins = (process.env.ALLOWED_ORIGINS || "")
      .split(",")
      .map((o) => o.trim())
      .filter(Boolean);
    const origin = req.headers.origin;
    if (origin && allowedOrigins.includes(origin)) {
      res.setHeader("Access-Control-Allow-Origin", origin);
    }
    res.setHeader(
      "Access-Control-Allow-Methods",
      "GET,POST,PUT,PATCH,DELETE,OPTIONS",
    );
    res.setHeader(
      "Access-Control-Allow-Headers",
      "Content-Type, Authorization",
    );
    res.statusCode = 204;
    return res.end();
  }
  return app(req, res);
};
