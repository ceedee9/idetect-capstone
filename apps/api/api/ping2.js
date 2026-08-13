// apps/api/api/ping2.js
// Isolation test: Express + serverless-http, but as a DEDICATED
// (non-catch-all) function, to test that specific combination.
const serverless = require("serverless-http");
const express = require("express");

const app = express();
app.get("/api/ping2", (req, res) => {
  res.status(200).json({ pong: true, time: new Date().toISOString() });
});

module.exports = serverless(app);
