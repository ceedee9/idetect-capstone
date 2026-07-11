// src/config/database.js
// PostgreSQL connection pool.
// All database queries go through this pool — never create
// individual connections directly.

const { Pool } = require("pg");
require("dotenv").config();

function getPoolConfig() {
  const connectionString = process.env.DATABASE_URL || process.env.POSTGRES_URL;

  if (connectionString) {
    return {
      connectionString,
      ssl: { rejectUnauthorized: false },
      max: 10,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 5000,
    };
  }

  return {
    host: process.env.DB_HOST || "localhost",
    port: parseInt(process.env.DB_PORT || "5432", 10),
    database: process.env.DB_NAME || "idetect",
    user: process.env.DB_USER || "postgres",
    password: process.env.DB_PASSWORD,
    max: 10,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 5000,
    ssl:
      process.env.NODE_ENV === "production"
        ? { rejectUnauthorized: false }
        : false,
  };
}

const pool = new Pool(getPoolConfig());

async function waitForDatabaseConnection(retries = 10, delayMs = 5000) {
  for (let attempt = 1; attempt <= retries; attempt += 1) {
    try {
      const result = await pool.query("SELECT 1");
      if (result?.rows?.length) {
        console.log("✅ Database connected successfully");
        return true;
      }
    } catch (err) {
      const message = err?.message || "Unknown database error";
      console.warn(
        `⚠️ Database connection attempt ${attempt}/${retries} failed: ${message}`,
      );
      if (attempt === retries) {
        console.error("❌ Database connection unavailable after retries");
        return false;
      }
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
  return false;
}

module.exports = pool;
module.exports.waitForDatabaseConnection = waitForDatabaseConnection;
