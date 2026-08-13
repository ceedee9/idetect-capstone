// apps/api/api/ping2.js
const express = require("express");

const app = express();
app.get("/api/ping2", (req, res) => {
  res.status(200).json({ pong: true, time: new Date().toISOString() });
});

module.exports = app;
