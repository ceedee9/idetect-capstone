// src/services/smsService.js
// SMS delivery via Semaphore (https://semaphore.co)
// Falls back to console logging when no API key is configured.

const SMS_API_URL = "https://api.semaphore.co/api/v4/messages";
// Dedicated OTP-routing endpoint — same price as a normal message, but
// routed away from Semaphore's general/bulk message queue specifically
// for time-sensitive one-time-code traffic. Use this for all OTPs instead
// of the generic /messages endpoint.
const OTP_API_URL = "https://api.semaphore.co/api/v4/otp";

/**
 * Send an SMS message.
 * @param {string} to   — Philippine mobile number (09XXXXXXXXX or +639XXXXXXXXX)
 * @param {string} body — Message text (max ~160 chars recommended)
 * @returns {Promise<{success: boolean, message: string}>}
 */
async function sendSms(to, body) {
  const apiKey = process.env.SMS_API_KEY;
  const senderName = process.env.SMS_SENDER_NAME ?? "";

  // No key configured → dev fallback
  if (!apiKey || apiKey === "your_sms_api_key_here") {
    console.log(`📱 [SMS-DEV] To: ${to} | Message: ${body}`);
    return { success: true, message: "Logged to console (no SMS key)" };
  }

  try {
    const params = new URLSearchParams({
      apikey: apiKey,
      number: to,
      message: body,
    });
    if (senderName) params.append("sendername", senderName);

    const response = await fetch(SMS_API_URL, {
      method: "POST",
      body: params,
    });

    const data = await response.json();

    if (response.ok && Array.isArray(data) && data.length > 0) {
      console.log(`📱 SMS sent to ${to} (message_id: ${data[0].message_id})`);
      return { success: true, message: "SMS sent" };
    }

    console.error("📱 SMS send failed:", data);
    // In dev mode, remind that the OTP is logged to console
    if (process.env.NODE_ENV === "development") {
      console.log(
        "📱 ⚠️  SMS failed — check the OTP in the console log above.",
      );
    }
    return { success: false, message: data?.message || "SMS failed" };
  } catch (err) {
    console.error("📱 SMS error:", err.message);
    if (process.env.NODE_ENV === "development") {
      console.log("📱 ⚠️  SMS error — check the OTP in the console log above.");
    }
    return { success: false, message: err.message };
  }
}

/**
 * Send an OTP message via Semaphore's dedicated OTP-routing endpoint.
 * Routed separately from general SMS traffic — same cost as a normal
 * message, but avoids queuing behind bulk/marketing sends.
 * @param {string} to  — Philippine mobile number
 * @param {string} otp — The 6-digit code
 */
async function sendOtp(to, otp) {
  const apiKey = process.env.SMS_API_KEY;
  const senderName = process.env.SMS_SENDER_NAME ?? "";
  const message = `Your iDETECT verification code is: ${otp}. Valid for 10 minutes. Do not share this code.`;

  // No key configured → dev fallback (same behavior as sendSms)
  if (!apiKey || apiKey === "your_sms_api_key_here") {
    console.log(`📱 [OTP-DEV] To: ${to} | Message: ${message}`);
    return { success: true, message: "Logged to console (no SMS key)" };
  }

  try {
    const params = new URLSearchParams({
      apikey: apiKey,
      number: to,
      message,
      code: otp,
    });
    if (senderName) params.append("sendername", senderName);

    const response = await fetch(OTP_API_URL, {
      method: "POST",
      body: params,
    });

    const data = await response.json();

    if (response.ok && Array.isArray(data) && data.length > 0) {
      console.log(`📱 OTP sent to ${to} (message_id: ${data[0].message_id})`);
      return { success: true, message: "OTP sent" };
    }

    console.error("📱 OTP send failed:", data);
    if (process.env.NODE_ENV === "development") {
      console.log(
        "📱 ⚠️  OTP send failed — check the OTP in the console log above.",
      );
    }
    return { success: false, message: data?.message || "OTP send failed" };
  } catch (err) {
    console.error("📱 OTP error:", err.message);
    if (process.env.NODE_ENV === "development") {
      console.log("📱 ⚠️  OTP error — check the OTP in the console log above.");
    }
    return { success: false, message: err.message };
  }
}

module.exports = { sendSms, sendOtp };
