// src/services/emailService.js
// Email delivery via Resend (https://resend.com).
// Uses the Resend REST API with RESEND_API_KEY.
// Falls back to console logging when the key is not set.

const RESEND_API_URL = "https://api.resend.com/emails";

async function sendEmail({ to, subject, text, html }) {
  const apiKey = process.env.RESEND_API_KEY;
  const fromEmail = process.env.EMAIL_FROM_ADDRESS ?? "no-reply@idetect.it.com";
  const fromName = process.env.EMAIL_FROM_NAME ?? "iDetect BPLO";

  if (!apiKey) {
    console.log(
      `📧 [EMAIL-DEV] No RESEND_API_KEY set.\nTo: ${to}\nSubject: ${subject}\n${text}`,
    );
    return { success: true, message: "Logged to console (no API key)" };
  }

  try {
    const res = await fetch(RESEND_API_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: `${fromName} <${fromEmail}>`,
        to: [to],
        subject,
        text,
        html,
      }),
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

async function sendEstablishmentCredentials({
  business_name,
  email,
  plain_password,
}) {
  const subject = "Your iDetect Establishment Account is Ready";
  const text = `Dear ${business_name},\n\nYour establishment account on the iDetect Client Portal has been created and approved by the Valenzuela City Business Permit and Licensing Office (BPLO).\n\nHere are your login credentials for the iDetect Client Portal mobile app:\n\n  Email:    ${email}\n  Password: ${plain_password}\n\nIMPORTANT: Please log in and change your password immediately after first use.\n\nOnce signed in, you can begin scanning Senior Citizen and PWD IDs for discount validation.\n\nIf you did not expect this email, or believe your establishment was registered in error, please contact your BPLO administrator.\n\n—\niDetect OCR-Driven Discount ID Validity Checker System\nPamantasan ng Lungsod ng Valenzuela — College of Engineering and Information Technology\nThis is an automated message from no-reply@idetect.it.com. Please do not reply directly to this email.`;
  const html = `<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;border:1px solid #e5e7eb;border-radius:8px;overflow:hidden;"><div style="background:#1e40af;padding:20px 24px;"><h2 style="color:#fff;margin:0;font-size:18px;">iDetect Establishment Account is Ready</h2><p style="color:#bfdbfe;margin:4px 0 0;font-size:13px;">Valenzuela City BPLO</p></div><div style="padding:24px;"><p style="margin-top:0;">Dear <strong>${business_name}</strong>,</p><p>Your establishment account on the iDetect Client Portal has been <strong>created and approved</strong> by the Valenzuela City Business Permit and Licensing Office (BPLO).</p><div style="background:#f1f5f9;border-radius:6px;padding:16px;margin:16px 0;"><p style="margin:0 0 8px;font-size:13px;color:#64748b;text-transform:uppercase;letter-spacing:.05em;">Login Credentials</p><p style="margin:0 0 6px;"><strong>Email:</strong> ${email}</p><p style="margin:0;"><strong>Password:</strong> <code style="background:#fff;padding:2px 6px;border-radius:4px;border:1px solid #e2e8f0;">${plain_password}</code></p></div><p style="color:#dc2626;font-size:13px;"><strong>⚠ Important:</strong> Please log in and change your password immediately after first use.</p><p>Once signed in, use these credentials in the Client Portal mobile app to begin scanning Senior Citizen and PWD IDs for discount validation.</p><p style="color:#6b7280;font-size:12px;">If you did not expect this email, or believe your establishment was registered in error, please contact your BPLO administrator.</p><hr style="border:none;border-top:1px solid #e5e7eb;margin:20px 0;"/><p style="color:#6b7280;font-size:11px;margin:0 0 4px;">iDetect OCR-Driven Discount ID Validity Checker System</p><p style="color:#6b7280;font-size:11px;margin:0 0 4px;">Pamantasan ng Lungsod ng Valenzuela — College of Engineering and Information Technology</p><p style="color:#9ca3af;font-size:11px;margin:0;">This is an automated message from no-reply@idetect.it.com. Please do not reply directly to this email.</p></div></div>`;
  return sendEmail({ to: email, subject, text, html });
}

module.exports = { sendEmail, sendEstablishmentCredentials };
