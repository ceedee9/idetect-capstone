// src/middleware/errorHandler.js
// Central error handler — attach as the LAST middleware in server.js.
// All unhandled errors fall through to this.

const errorHandler = (err, req, res, next) => {
  // Log full error in development
  if (process.env.NODE_ENV === 'development') {
    console.error('❌ Error:', err);
  } else {
    console.error('❌ Error:', err.message);
  }

  // PostgreSQL errors
  if (err.code === '23505') {
    return res.status(409).json({
      error: 'Duplicate entry',
      detail: err.detail || 'A record with this value already exists'
    });
  }

  if (err.code === '23503') {
    return res.status(400).json({
      error: 'Invalid reference',
      detail: err.detail || 'Referenced record does not exist'
    });
  }

  // JWT errors (shouldn't reach here but just in case)
  if (err.name === 'JsonWebTokenError') {
    return res.status(403).json({ error: 'Invalid token' });
  }

  if (err.name === 'TokenExpiredError') {
    return res.status(403).json({ error: 'Token expired' });
  }

  // Custom app errors (thrown with err.statusCode)
  if (err.statusCode) {
    return res.status(err.statusCode).json({ error: err.message });
  }

  // Default: 500
  res.status(500).json({
    error: 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && { detail: err.message })
  });
};

// Helper to create clean app errors anywhere in the code
// Usage: throw createError(404, 'Beneficiary not found')
const createError = (statusCode, message) => {
  const err = new Error(message);
  err.statusCode = statusCode;
  return err;
};

module.exports = { errorHandler, createError };
