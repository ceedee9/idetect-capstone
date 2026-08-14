const app = require("../src/app");

module.exports = (req, res) => {
  // Handle CORS preflight directly, before Express routing —
  // bypasses a Vercel edge-routing quirk affecting OPTIONS requests
  // on deeply nested catch-all API paths.
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
