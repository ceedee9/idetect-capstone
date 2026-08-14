// apps/api/api/foo/bar/baz.js
// Pure isolation test: fully static (no dynamic segments, no catch-all)
// route, 3 levels deep, to test whether Vercel's OPTIONS handling
// breaks based on URL depth alone.
module.exports = (req, res) => {
  res.status(200).json({ ok: true });
};
