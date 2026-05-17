// src/services/fcmService.js
// Firebase Cloud Messaging (FCM) push notification dispatcher.
// Uses the Firebase Admin SDK — free, no per-message cost.
//
// Credential priority (first match wins):
//   1. FIREBASE_SERVICE_ACCOUNT_JSON  — full service-account JSON as a string.
//      Paste the entire JSON file contents as a Railway/Render env var.
//      This is the recommended production approach (no file on disk needed).
//   2. FIREBASE_KEY_PATH  — path to a service-account JSON file on disk.
//      Useful for local development.
//
// Falls back to console logging when neither variable is configured
// (safe for dev/demo without Firebase credentials).

let admin = null;

function getAdmin() {
  if (admin) return admin;

  const firebase = require("firebase-admin");

  // ── Priority 1: JSON string in env var (preferred for Railway/Render) ──
  const jsonEnv = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (jsonEnv) {
    try {
      const serviceAccount = JSON.parse(jsonEnv);
      if (!firebase.apps.length) {
        firebase.initializeApp({
          credential: firebase.credential.cert(serviceAccount),
        });
      }
      admin = firebase;
      console.log(
        "🔥 Firebase Admin SDK initialized via FIREBASE_SERVICE_ACCOUNT_JSON",
      );
      return admin;
    } catch (err) {
      console.error(
        "🔥 Firebase Admin SDK init failed (FIREBASE_SERVICE_ACCOUNT_JSON):",
        err.message,
      );
      return null;
    }
  }

  // ── Priority 2: file path env var (local dev) ──
  const keyPath = process.env.FIREBASE_KEY_PATH;
  if (!keyPath || keyPath === "path/to/firebase-service-account.json") {
    return null; // dev fallback — no credentials configured
  }

  try {
    const serviceAccount = require(require("path").resolve(keyPath));

    if (!firebase.apps.length) {
      firebase.initializeApp({
        credential: firebase.credential.cert(serviceAccount),
      });
    }

    admin = firebase;
    console.log("🔥 Firebase Admin SDK initialized via FIREBASE_KEY_PATH");
    return admin;
  } catch (err) {
    console.error("🔥 Firebase Admin SDK init failed:", err.message);
    return null;
  }
}

/**
 * Send a push notification to a single FCM device token.
 * @param {string} deviceToken  — FCM registration token from the Flutter app
 * @param {string} title        — Notification title
 * @param {string} body         — Notification body
 * @param {object} [data]       — Optional key-value payload for the app to handle
 * @returns {Promise<{success: boolean, message: string}>}
 */
async function sendPushNotification(deviceToken, title, body, data = {}) {
  if (!deviceToken) {
    return { success: false, message: "No device token" };
  }

  const firebase = getAdmin();

  // Dev fallback — log to console instead of sending
  if (!firebase) {
    console.log(
      `🔔 [FCM-DEV] To: ${deviceToken.slice(0, 20)}... | Title: ${title} | Body: ${body}`,
    );
    return { success: true, message: "Logged to console (no Firebase key)" };
  }

  try {
    const message = {
      token: deviceToken,
      notification: { title, body },
      data: Object.fromEntries(
        // FCM data values must all be strings
        Object.entries(data).map(([k, v]) => [k, String(v)]),
      ),
      android: {
        priority: "high",
        notification: {
          channelId: "idetect_alerts",
          sound: "default",
        },
      },
    };

    const response = await firebase.messaging().send(message);
    console.log(`🔔 FCM push sent: ${response}`);
    return { success: true, message: "Push sent", messageId: response };
  } catch (err) {
    // Token no longer valid — caller should clear it from DB
    if (
      err.code === "messaging/registration-token-not-registered" ||
      err.code === "messaging/invalid-registration-token"
    ) {
      console.warn(
        `🔔 FCM invalid token (${deviceToken.slice(0, 20)}...): clearing recommended`,
      );
      return { success: false, message: "Invalid token", invalidToken: true };
    }
    console.error("🔔 FCM send error:", err.message);
    return { success: false, message: err.message };
  }
}

/**
 * Send push notifications to multiple tokens at once.
 * Silently skips null/undefined tokens.
 * @param {string[]} tokens
 * @param {string}   title
 * @param {string}   body
 * @param {object}   [data]
 */
async function sendMulticastPush(tokens, title, body, data = {}) {
  const validTokens = tokens.filter(Boolean);
  if (!validTokens.length) return;

  await Promise.allSettled(
    validTokens.map((token) => sendPushNotification(token, title, body, data)),
  );
}

module.exports = { sendPushNotification, sendMulticastPush };
