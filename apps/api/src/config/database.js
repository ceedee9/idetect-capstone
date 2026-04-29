// src/config/database.js
// PostgreSQL connection pool.
// All database queries go through this pool — never create
// individual connections directly.

const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host:     process.env.DB_HOST,
  port:     parseInt(process.env.DB_PORT),
  database: process.env.DB_NAME,
  user:     process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  // Keep up to 10 connections open at once
  max: 10,
  // Close idle connections after 30s
  idleTimeoutMillis: 30000,
  // Fail fast if can't connect within 2s
  connectionTimeoutMillis: 2000,
});

// Test the connection on startup
pool.connect((err, client, release) => {
  if (err) {
    console.error('❌ Database connection failed:', err.message);
    process.exit(1);
  }
  release();
  console.log('✅ Database connected successfully');
});

module.exports = pool;
