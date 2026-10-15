# How Push Notifications Work in iDetect

## The Big Picture

When something important happens (like an ID scan or a dispute update), the system automatically sends a notification to the beneficiary's phone — even if the app is closed.

This is powered by **Firebase Cloud Messaging (FCM)**, which is Google's free service for sending push notifications to Android devices.

---

## The Players

| Who                                  | What they do                                 |
| ------------------------------------ | -------------------------------------------- |
| **Flutter App** (beneficiary phone)  | Receives push notifications                  |
| **Firebase** (Google's servers)      | Delivers the notification to the right phone |
| **iDetect API** (our Node.js server) | Decides when and what to send                |

---

## How It Works — Step by Step

### Step 1: The app gets a "device token" on login

When a beneficiary logs in, Firebase gives their phone a unique ID called a **device token**. Think of it like a phone number specifically for push notifications.

The app immediately sends this token to our API:

```
PATCH /api/beneficiary-portal/device-token
```

The API saves the token in the `beneficiary_accounts` table.

### Step 2: Something happens that needs a notification

For example, an establishment scans a beneficiary's ID. The API processes the scan and determines the result (Valid / Denied).

### Step 3: The API sends a push via Firebase

The API calls Firebase using the saved device token:

```
API Server  →  Firebase  →  Beneficiary's Phone
```

Firebase handles all the delivery — even if the phone is asleep or the app is closed.

### Step 4: The phone shows the notification

The beneficiary sees a notification pop up on their phone like:

> **Discount Approved ✓**
> Your ID was verified at SM Supermarket on 4/21/2026. Outcome: Approved.

---

## What Triggers a Notification

| Event                          | Notification Sent                  |
| ------------------------------ | ---------------------------------- |
| ID scanned (valid)             | "Discount Approved ✓"              |
| ID scanned (denied/suspicious) | "Discount Denied ✗" + reason       |
| Dispute acknowledged by staff  | "Your dispute is now under review" |
| Dispute resolved/rejected      | "Your dispute has been resolved"   |

All notifications are also saved to the `notifications` table in the database, so the beneficiary can read them later inside the app.

---

## Staff Portal Alerts

Important events appear in the staff portal in real time through the notification
bell. These are separate from beneficiary mobile notifications and are targeted
by office:

| Event | Target office | Portal action |
| --- | --- | --- |
| Dispute submitted (any type) | Beneficiary's office (OSCA or PDAO) | Open the dispute queue |
| Business-refusal dispute submitted | BPLO, plus the beneficiary's office | BPLO opens Refusal Reports |
| Fraud flag created (establishment flag, unauthorized-use report, self-report) | OSCA or PDAO by beneficiary type | Open Fraud Flags |
| Establishment self-registration awaiting approval | BPLO | Open Establishments |
| ID auto-suspended after repeated flags | OSCA or PDAO | Open Fraud Flags |
| Dispute SLA breach (24h acknowledgment / 72h resolution) | Every office that can act on it | Open the dispute queue |
| Suspension ending or overdue | OSCA or PDAO | Open the beneficiary record |

**How delivery works.** Alerts are created by database triggers (and the existing
schedulers), then pushed to every signed-in portal session of the matching office
over a Server-Sent Events stream (`GET /api/staff/alerts/stream`, authenticated
with the staff token and scoped to the staff member's office). A new alert shows
a pop-up, increments the bell and the browser-tab title, and can raise a desktop
notification when the tab is in the background (opt in from the bell). Streams are
recycled every 10 minutes so they cannot outlive a token or a deactivated
account. If the stream is blocked, the portal falls back to checking every 30
seconds and catches up when it reconnects.

Alerts are deduplicated per event, can be marked read individually or all at once,
and contain only short, privacy-safe references — never ID numbers, birth dates,
or dispute explanations. Email and SMS escalation for high-priority events remain
future work.

---

## What Happens Without Firebase Credentials

The system is designed to work safely even without Firebase set up. If the `FIREBASE_KEY_PATH` is not configured in `.env`, the API simply logs the notification message to the server console instead of sending it to the phone. This is useful during development and demos.

---

## The Two Firebase Files

| File                                     | What it's for                                                   | Where it lives                  |
| ---------------------------------------- | --------------------------------------------------------------- | ------------------------------- |
| `google-services.json`                   | Tells the Flutter app which Firebase project to connect to      | `apps/beneficiary/android/app/` |
| `idetect-bc100-firebase-adminsdk-*.json` | Gives the API permission to send notifications through Firebase | `apps/api/`                     |

These are two different credentials for two different sides of the same system.

---

## Simple Analogy

Think of FCM like a postal service:

- The **device token** is the beneficiary's home address
- The **API** is the sender writing and mailing the letter
- **Firebase** is the postal service that delivers it
- The **Flutter app** is the mailbox that receives it
