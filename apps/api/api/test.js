// apps/api/api/test.js
// Raw Vercel serverless function — no Express, no serverless-http,
// no dependencies at all. Pure isolation test.
module.exports = (req, res) => {
  res.status(200).json({ ok: true, time: new Date().toISOString() });
};
