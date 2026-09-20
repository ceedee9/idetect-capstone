// src/services/emailService.js
// Email delivery via Resend (https://resend.com).
// Uses the Resend REST API with RESEND_API_KEY.
// Falls back to console logging when the key is not set.

const RESEND_API_URL = "https://api.resend.com/emails";

async function sendEmail({ to, subject, text, html }) {
  const apiKey = process.env.RESEND_API_KEY;
  const fromEmail =
    process.env.EMAIL_FROM_ADDRESS ?? "notifications@idetect.it.com";
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

async function sendEstablishmentSetupLink({ business_name, email, setupUrl }) {
  const subject = "Your iDetect Establishment Account is Ready";
  const text = `Dear ${business_name},\n\nYour establishment account on the iDetect Client Portal has been created and approved by the Valenzuela City Business Permit and Licensing Office (BPLO).\n\nTo finish setting up your account, please set your password using the link below. This link expires in 24 hours.\n\n${setupUrl}\n\nOnce set, use your registered email and password to sign in to the Client Portal mobile app and begin scanning Senior Citizen and PWD IDs for discount validation.\n\nIf you did not expect this email, please contact your BPLO administrator.\n\niDetect OCR-Driven Discount ID Validity Checker System\nPamantasan ng Lungsod ng Valenzuela, College of Engineering and Information Technology\nThis is an automated notification; replies to this email are not monitored.`;
  const html = `<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;border:1px solid #e5e7eb;border-radius:8px;overflow:hidden;"><div style="background:#1e40af;padding:20px 24px;"><h2 style="color:#fff;margin:0;font-size:18px;">iDetect Establishment Account is Ready</h2><p style="color:#bfdbfe;margin:4px 0 0;font-size:13px;">Valenzuela City BPLO</p></div><div style="padding:24px;"><p style="margin-top:0;">Dear ${business_name},</p><p>Your establishment account on the iDetect Client Portal has been created and approved by the Valenzuela City Business Permit and Licensing Office (BPLO).</p><p>To finish setting up your account, please set your password using the button below. This link expires in 24 hours.</p><p style="text-align:center;margin:24px 0;"><a href="${setupUrl}" style="background:#1d4ed8;color:#fff;padding:12px 24px;border-radius:6px;text-decoration:none;font-weight:600;font-size:14px;">Set My Password</a></p><p>Once set, use your registered email and password to sign in to the Client Portal mobile app and begin scanning Senior Citizen and PWD IDs for discount validation.</p><p style="color:#6b7280;font-size:12px;">If you did not expect this email, please contact your BPLO administrator.</p><hr style="border:none;border-top:1px solid #e5e7eb;margin:20px 0;"/><p style="color:#6b7280;font-size:11px;margin:0 0 4px;">iDetect OCR-Driven Discount ID Validity Checker System</p><p style="color:#6b7280;font-size:11px;margin:0 0 4px;">Pamantasan ng Lungsod ng Valenzuela, College of Engineering and Information Technology</p><p style="color:#9ca3af;font-size:11px;margin:0;">This is an automated notification; replies to this email are not monitored.</p></div></div>`;
  return sendEmail({ to: email, subject, text, html });
}

module.exports = { sendEmail, sendEstablishmentSetupLink };
