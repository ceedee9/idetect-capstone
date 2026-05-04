// src/services/emailService.js
// Email delivery via SMTP (Gmail App Password recommended).
// Falls back to console logging when no SMTP config is provided.

const nodemailer = require("nodemailer");

let _transporter = null;

function getTransporter() {
  if (_transporter) return _transporter;

  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;

  if (!user || !pass) {
    console.warn(
      "📧 [EMAIL] SMTP_USER or SMTP_PASS not set — emails will be logged only.",
    );
    return null;
  }

  const isGmail =
    user.endsWith("@gmail.com") ||
    (process.env.SMTP_HOST ?? "").includes("gmail");

  if (isGmail) {
    // Gmail App Password via smtp.gmail.com:587 (STARTTLS, IPv4 forced)
    // Railway blocks IPv6 → Gmail SMTP, so we must use explicit host + family:4
    _transporter = nodemailer.createTransport({
      host: "smtp.gmail.com",
      port: 587,
      secure: false,
      requireTLS: true,
      family: 4, // force IPv4
      auth: { user, pass },
      tls: { rejectUnauthorized: false },
    });
    console.log(`📧 [EMAIL] Gmail SMTP transporter ready for ${user} (IPv4, port 587)`);
  } else {
    const host = process.env.SMTP_HOST;
    const port = parseInt(process.env.SMTP_PORT ?? "587", 10);
    _transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      requireTLS: port === 587,
      auth: { user, pass },
      tls: { rejectUnauthorized: false },
    });
    console.log(`📧 [EMAIL] SMTP transporter ready (${host}:${port})`);
  }

  return _transporter;
}

/**
 * Send an email.
 * @param {object} opts
 * @param {string}   opts.to      - Recipient address
 * @param {string}   opts.subject - Email subject
 * @param {string}   opts.text    - Plain-text body
 * @param {string}  [opts.html]   - Optional HTML body
 */
async function sendEmail({ to, subject, text, html }) {
  const transporter = getTransporter();
  const from =
    process.env.SMTP_FROM ??
    process.env.SMTP_USER ??
    "no-reply@idetect-bplo.ph";

  if (!transporter) {
    console.log(`📧 [EMAIL-DEV] To: ${to}\nSubject: ${subject}\n${text}`);
    return { success: true, message: "Logged to console (no SMTP config)" };
  }

  try {
    const info = await transporter.sendMail({ from, to, subject, text, html });
    console.log(`📧 [EMAIL] Sent to ${to}: ${info.messageId}`);
    return { success: true, messageId: info.messageId };
  } catch (err) {
    console.error(`📧 [EMAIL] Failed to send to ${to}:`, err.message);
    return { success: false, error: err.message };
  }
}

/**
 * Send establishment login credentials to the business contact email.
 */
async function sendEstablishmentCredentials({
  business_name,
  email,
  plain_password,
}) {
  const subject = "Your iDetect Client Portal Account Credentials";

  const text = `
Dear ${business_name},

Your establishment account on the iDetect Client Portal has been created and approved by the Valenzuela City BPLO.

Here are your login credentials for the iDetect mobile app:

  Email:    ${email}
  Password: ${plain_password}

IMPORTANT: Please log in and change your password immediately after first use.

If you have questions, please contact the Valenzuela City BPLO office.

— iDetect System
`.trim();

  const html = `
<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;border:1px solid #e5e7eb;border-radius:8px;overflow:hidden;">
  <div style="background:#1e40af;padding:20px 24px;">
    <h2 style="color:#fff;margin:0;font-size:18px;">iDetect Client Portal</h2>
    <p style="color:#bfdbfe;margin:4px 0 0;font-size:13px;">Valenzuela City BPLO</p>
  </div>
  <div style="padding:24px;">
    <p style="margin-top:0;">Dear <strong>${business_name}</strong>,</p>
    <p>Your establishment account has been <strong>created and approved</strong> by the Valenzuela City BPLO. You can now use the iDetect mobile app to verify discount IDs.</p>
    <div style="background:#f1f5f9;border-radius:6px;padding:16px;margin:16px 0;">
      <p style="margin:0 0 8px;font-size:13px;color:#64748b;text-transform:uppercase;letter-spacing:.05em;">Login Credentials</p>
      <p style="margin:0 0 6px;"><strong>Email:</strong> ${email}</p>
      <p style="margin:0;"><strong>Password:</strong> <code style="background:#fff;padding:2px 6px;border-radius:4px;border:1px solid #e2e8f0;">${plain_password}</code></p>
    </div>
    <p style="color:#dc2626;font-size:13px;"><strong>⚠ Important:</strong> Please log in and change your password immediately after first use.</p>
    <p style="color:#6b7280;font-size:12px;margin-bottom:0;">If you have questions, contact the Valenzuela City BPLO office.</p>
  </div>
</div>
`;

  return sendEmail({ to: email, subject, text, html });
}

module.exports = { sendEmail, sendEstablishmentCredentials };
