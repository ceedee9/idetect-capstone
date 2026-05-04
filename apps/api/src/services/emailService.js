// src/services/emailService.js
// Email delivery via Resend HTTP API (https://resend.com).
// Railway blocks outbound SMTP — Resend uses HTTPS so it works everywhere.
// Falls back to console logging when RESEND_API_KEY is not set.

async function sendEmail({ to, subject, text, html }) {
  const apiKey = process.env.RESEND_API_KEY;
  const from = process.env.EMAIL_FROM ?? "iDetect BPLO <noreply@idetect.it.com>";

  if (!apiKey) {
    console.log(`📧 [EMAIL-DEV] No RESEND_API_KEY set.\nTo: ${to}\nSubject: ${subject}\n${text}`);
    return { success: true, message: "Logged to console (no API key)" };
  }

  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ from, to: [to], subject, text, html }),
    });

    const data = await res.json();

    if (!res.ok) {
      const errMsg = data?.message ?? JSON.stringify(data);
      console.error(`📧 [EMAIL] Resend error for ${to}: ${errMsg}`);
      return { success: false, error: errMsg };
    }

    console.log(`📧 [EMAIL] Sent to ${to}: ${data.id}`);
    return { success: true, messageId: data.id };
  } catch (err) {
    console.error(`📧 [EMAIL] Network error sending to ${to}:`, err.message);
    return { success: false, error: err.message };
  }
}

async function sendEstablishmentCredentials({ business_name, email, plain_password }) {
  const subject = "Your iDetect Client Portal Account Credentials";
  const text = `Dear ${business_name},\n\nYour establishment account on the iDetect Client Portal has been created and approved by the Valenzuela City BPLO.\n\nHere are your login credentials for the iDetect mobile app:\n\n  Email:    ${email}\n  Password: ${plain_password}\n\nIMPORTANT: Please log in and change your password immediately after first use.\n\nIf you have questions, please contact the Valenzuela City BPLO office.\n\n— iDetect System`;
  const html = `<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;border:1px solid #e5e7eb;border-radius:8px;overflow:hidden;"><div style="background:#1e40af;padding:20px 24px;"><h2 style="color:#fff;margin:0;font-size:18px;">iDetect Client Portal</h2><p style="color:#bfdbfe;margin:4px 0 0;font-size:13px;">Valenzuela City BPLO</p></div><div style="padding:24px;"><p style="margin-top:0;">Dear <strong>${business_name}</strong>,</p><p>Your establishment account has been <strong>created and approved</strong> by the Valenzuela City BPLO. You can now use the iDetect mobile app to verify discount IDs.</p><div style="background:#f1f5f9;border-radius:6px;padding:16px;margin:16px 0;"><p style="margin:0 0 8px;font-size:13px;color:#64748b;text-transform:uppercase;letter-spacing:.05em;">Login Credentials</p><p style="margin:0 0 6px;"><strong>Email:</strong> ${email}</p><p style="margin:0;"><strong>Password:</strong> <code style="background:#fff;padding:2px 6px;border-radius:4px;border:1px solid #e2e8f0;">${plain_password}</code></p></div><p style="color:#dc2626;font-size:13px;"><strong>⚠ Important:</strong> Please log in and change your password immediately after first use.</p><p style="color:#6b7280;font-size:12px;margin-bottom:0;">If you have questions, contact the Valenzuela City BPLO office.</p></div></div>`;
  return sendEmail({ to: email, subject, text, html });
}

module.exports = { sendEmail, sendEstablishmentCredentials };
