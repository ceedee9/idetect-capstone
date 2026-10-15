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

Important beneficiary and workflow events can also appear in the relevant staff
portal through the in-portal alert bell. These alerts are separate from
beneficiary mobile notifications and are targeted by office:

| Event | Target office | Portal action |
| --- | --- | --- |
| Business-refusal dispute submitted | BPLO | Open the dispute queue |
| Senior-citizen dispute submitted | OSCA | Open the dispute queue |
| PWD dispute submitted | PDAO | Open the dispute queue |

Staff alerts are polled while the portal is open, show an unread count, and can
be marked read individually or all at once. They are deduplicated by the
underlying event so retries do not create duplicate alerts. The alert body
contains only a short, privacy-safe reference; sensitive explanations and
personal details remain in the protected workflow.

The current phase intentionally uses in-portal alerts only. Browser push and
email escalation can be added later for high-priority events without changing
the beneficiary FCM flow.

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
