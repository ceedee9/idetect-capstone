# iDetect — Defense Preparation Guide

**Prepared:** May 20, 2026  
**Purpose:** Comprehensive review guide for panel defense — covers all system components, design decisions, and likely panelist questions with answers.

---

## Table of Contents

1. [What Is iDetect? (Your Elevator Pitch)](#1-what-is-idetect-your-elevator-pitch)
2. [The Problem You Are Solving](#2-the-problem-you-are-solving)
3. [System Architecture (Big Picture)](#3-system-architecture-big-picture)
4. [Technology Stack — What You Used and Why](#4-technology-stack--what-you-used-and-why)
5. [The Five User Types](#5-the-five-user-types)
6. [The Scan & Verification Flow (Most Important!)](#6-the-scan--verification-flow-most-important)
7. [OCR: How the System Reads the ID Card](#7-ocr-how-the-system-reads-the-id-card)
8. [The Fraud Detection System](#8-the-fraud-detection-system)
9. [The Dispute Resolution System](#9-the-dispute-resolution-system)
10. [The Database Design](#10-the-database-design)
11. [Security Features](#11-security-features)
12. [Offline Capability](#12-offline-capability)
13. [Notifications System](#13-notifications-system)
14. [Admin Portal Features](#14-admin-portal-features)
15. [Beneficiary Mobile App](#15-beneficiary-mobile-app)
16. [Limitations You Should Acknowledge Honestly](#16-limitations-you-should-acknowledge-honestly)
17. [Panelist Q&A — Most Likely Questions and Your Answers](#17-panelist-qa--most-likely-questions-and-your-answers)
18. [Numbers and Metrics to Know](#18-numbers-and-metrics-to-know)

---

## 1. What Is iDetect? (Your Elevator Pitch)

**iDetect** is a mobile-based ID verification system for Philippine local government units (LGUs) that automates the scanning and validation of **Senior Citizen IDs** (OSCA) and **PWD IDs** (PDAO) at businesses that offer senior/PWD discounts.

When a senior citizen or PWD presents their ID at a store, the cashier opens the iDetect app, takes a photo of the card, and within seconds the system confirms: is this ID real, active, and in the government database? If something is wrong, the cashier is guided to flag the ID for investigation.

**In one sentence:** iDetect replaces manual, error-prone ID inspection with automated OCR-based verification connected to an LGU-managed database.

---

## 2. The Problem You Are Solving

### The Real-World Gap

Senior Citizens and PWDs in the Philippines are entitled to a **20% discount** on medicines, food, and services. However, this discount system is vulnerable to fraud:

- Expired, revoked, or fake IDs being used to claim discounts.
- Businesses have no reliable way to verify ID authenticity on the spot.
- LGU offices (OSCA, PDAO) have no centralized digital record of all issued IDs.
- There is no feedback mechanism when suspicious IDs are detected.

### What iDetect Does About It

1. **Cashiers** use the mobile app to scan IDs in seconds — no manual lookup.
2. **LGU staff** manage the beneficiary database through secure web portals.
3. **Business owners** register through BPLO to get access to the verification system.
4. **The system flags** suspicious IDs and automatically escalates to the right office (OSCA for seniors, PDAO for PWDs).

---

## 3. System Architecture (Big Picture)

### Three-Tier Architecture

```
[Flutter Mobile App]  ←→  [Node.js REST API]  ←→  [PostgreSQL Database]
(Establishment App)         (Express.js)            (Supabase, pooled)
(Beneficiary App)            ↕
                     [React Staff Web Portal]
              (one URL, role-routed: BPLO | OSCA | PDAO)

API + staff portal are deployed together as one combined service on
Northflank (https://idetect.it.com). Image/document uploads go to
Supabase Storage (id-captures, dispute-docs buckets).
```

### The Five Components

| Component         | Technology                         | Who Uses It                                                   |
| ----------------- | ---------------------------------- | ------------------------------------------------------------- |
| Establishment App | Flutter (Android/iOS)              | Cashiers at stores                                            |
| Beneficiary App   | Flutter (Android/iOS)              | Senior citizens / PWDs                                        |
| REST API          | Node.js + Express.js               | All apps communicate through this                             |
| Staff Web Portal  | React.js (one unified URL)         | OSCA, PDAO, and BPLO staff — routed by role after login       |
| Database          | PostgreSQL (Supabase)              | Backend data storage                                          |
| File Storage      | Supabase Storage                   | ID card images (`id-captures`), dispute docs (`dispute-docs`) |
| Hosting           | Northflank (US-Central, port 3000) | Combined API + staff portal service, `https://idetect.it.com` |

### Why This Architecture?

- **Mobile app** handles OCR locally — faster, works offline, no image upload needed for OCR.
- **REST API** is the single source of truth — all apps talk to the same data.
- **One unified web portal URL** with role-based routing — OSCA cannot see PWD data and vice versa (data compartmentalization is enforced by RBAC, not by separate URLs).
- **PostgreSQL on Supabase** — managed cloud database with a connection pooler, no server to maintain yourself; Supabase Storage also holds ID/dispute images.
- **Northflank** — hosts the combined API + staff portal service, with automatic HTTPS/TLS and GitHub-triggered CI/CD on every push to `main`.

---

## 4. Technology Stack — What You Used and Why

### Mobile App (Flutter)

- **Dart + Flutter** — One codebase, runs on Android (and can be built for iOS). Chosen for rapid development and native performance.
- **Tesseract OCR** (`flutter_tesseract_ocr`) — Primary OCR engine. Google-maintained, industry standard, works fully offline. 95-98% accuracy with proper image preprocessing.
- **Google ML Kit** (`google_mlkit_text_recognition`) — Fallback OCR engine. Faster but slightly less accurate (85-90%). Also provides spatial/bounding box data used for layout-based extraction.
- **OpenCV Dart** (`opencv_dart`) — Computer vision library for image preprocessing (10-step pipeline before OCR).
- **Google ML Kit Face Detection** — Used to verify that a face exists in the captured image before running OCR (prevents processing random photos).
- **Hive** — Local NoSQL database for caching verification results offline.
- **SQLite (sqflite)** — Local relational database for scan history.
- **Firebase Cloud Messaging (FCM)** — Receives push notifications on the beneficiary app.

### Backend API (Node.js)

- **Express.js** — REST API framework.
- **PostgreSQL + pg** — Relational database with complex queries.
- **JWT (JSON Web Token)** — Authentication for both staff (web portals) and establishments (mobile app).
- **bcrypt** — Password hashing (12 rounds).
- **express-rate-limit** — Rate limiting to prevent abuse (60 scans/min per establishment, 30 fraud flags/hour).
- **Multer** — File upload handling for ID card images and dispute documents.
- **Firebase Admin SDK** — Sends FCM push notifications to beneficiary devices.
- **Semaphore SMS Gateway** — Sends OTP codes and alerts via SMS.
- **Resend** — Sends transactional email (onboarding, notifications) from the verified `idetect.it.com` domain.
- **node-cron** — Scheduled background jobs (ID expiry alerts, SLA escalation, flag decay).
- **Jaro-Winkler** — String similarity algorithm for cross-validating OCR-extracted names against database names.

### Staff Web Portal (React)

- **React.js + Vite** — Fast, modern web application framework.
- **Axios** — HTTP client for API calls.
- **Lucide React** — Icon library.
- **One unified React app** — serves BPLO, OSCA, and PDAO staff from the same build; role-based routing after login determines the dashboard shown.

### Database (PostgreSQL) & Storage

- **Migrations** applied incrementally — structured, version-controlled schema.
- **Supabase** — Managed PostgreSQL (via connection pooler) and object storage (`id-captures`, `dispute-docs` buckets).
- **Northflank** — Hosts the combined API + staff portal service (US-Central, port 3000), deployed automatically from GitHub on every push to `main`.

---

## 5. The Five User Types

### 1. Establishment Cashier (Mobile App)

- Works at a store (pharmacy, restaurant, etc.) registered with BPLO.
- Uses the Flutter establishment app to scan IDs.
- Can flag suspicious IDs.
- Can submit fraud reports.
- Session auto-logs out after 15 minutes of inactivity.

### 2. BPLO Admin (Web Portal)

- Business Permit and Licensing Office staff.
- Approves, suspends, or revokes establishment accounts.
- Reviews verification activity for all establishment types.
- Handles "business refusal" disputes (when a store refuses a valid ID).
- Cannot see beneficiary personal data.

### 3. OSCA Admin (Web Portal)

- Office of Senior Citizens Affairs staff.
- Manages **senior citizen** beneficiary records only.
- Reviews fraud flags for senior citizen IDs.
- Handles disputes from senior citizen beneficiaries.
- Cannot see PWD data.

### 4. PDAO Admin (Web Portal)

- Persons with Disability Affairs Office staff.
- Manages **PWD** beneficiary records only.
- Reviews fraud flags for PWD IDs.
- Handles disputes from PWD beneficiaries.
- Cannot see senior citizen data.

### 5. Beneficiary (Mobile App)

- The senior citizen or PWD ID holder.
- Uses the Flutter beneficiary app (separate from establishment app).
- Can check their ID status, view verification history, and submit disputes.
- Logs in via ID number + date of birth → OTP sent to registered mobile number.
- Can also set a 4-digit PIN for faster login, and enable biometric (fingerprint) login.

---

## 6. The Scan & Verification Flow (Most Important!)

This is the **core feature** of the system. Know this step by step.

```
Step 1: Cashier opens app → selects ID type (Senior / PWD / Auto-detect)
Step 2: Camera opens → 6 photography tips shown
Step 3: Photo taken → Quality assessment (resolution, brightness, sharpness, contrast)
Step 4: Face detection check (ML Kit) → alerts if no face detected
Step 5: Image preprocessing (10-step OpenCV pipeline)
Step 6: Dual OCR → Tesseract (primary) + ML Kit (parallel) → best result selected
Step 7: Field extraction → Name, ID Number, Date of Birth extracted
Step 8: User reviews extracted data on screen, can correct errors
Step 9: App sends to API: POST /api/verification/scan
Step 10: API checks local Hive cache for suspended/revoked status first
Step 11: API looks up ID in PostgreSQL database
Step 12: API cross-validates: name (Jaro-Winkler ≥ 0.80) + date of birth exact match
Step 13: API returns: VALID / SUSPICIOUS / INVALID / MANUAL_REVIEW
Step 14: Result shown with color-coded guidance panel
Step 15: If suspicious/invalid → cashier can submit fraud flag
```

### The Four Verification Results

| Result            | Color     | Meaning                                 | Cashier Action                                 |
| ----------------- | --------- | --------------------------------------- | ---------------------------------------------- |
| **VALID**         | Green     | ID found, active, name/DOB match        | Approve the discount                           |
| **SUSPICIOUS**    | Amber     | Found but flagged, or name/DOB mismatch | Do NOT approve. Ask for secondary ID. Flag it. |
| **INVALID**       | Red       | ID not found, expired, or revoked       | Do NOT approve. Flag it.                       |
| **MANUAL_REVIEW** | Blue-Grey | OCR couldn't read name/DOB clearly      | Physically check the card. Can flag if wrong.  |

### Cross-Validation (Key Technical Feature)

When the OCR extracts the name and date of birth from the card:

- **Name** is compared to the database name using **Jaro-Winkler string similarity** (threshold: 0.80). If score < 0.80, result downgrades to SUSPICIOUS.
- **Date of Birth** is compared exactly. A mismatch sets `fields_matched = false` in logs.
- If **both** name and DOB cannot be extracted at all (non-manual scan), result downgrades to MANUAL_REVIEW.
- This prevents someone using a valid ID number from a different person.

### Offline Mode

If the phone has no internet:

- App checks the local **Hive cache** for the last known status of that ID.
- Returns cached result with `[OFFLINE — synced X minutes ago]` message.
- Cache expires after **6 hours** — stale cache returns an error instead of a potentially wrong result.

---

## 7. OCR: How the System Reads the ID Card

### Image Preprocessing (10 Steps via OpenCV)

Before OCR, the image goes through a pipeline to maximize text clarity:

1. **Resize** to 2000px width — standardizes scale for OCR
2. **Border removal** — removes the ID card border frame
3. **Perspective correction** — straightens tilted cards
4. **Deskew** (Hough Transform) — corrects rotation
5. **Grayscale conversion** — removes color noise
6. **Bilateral filter** — removes noise while preserving text edges
7. **CLAHE** (Contrast Limited Adaptive Histogram Equalization) — improves contrast in dark areas
8. **Sharpening** (unsharp mask) — makes text edges crisp
9. **Adaptive thresholding** — converts to black/white for OCR
10. **Morphological operations** — removes tiny noise specks

> **Important:** OpenCV preprocessing is only applied before **Tesseract** OCR. ML Kit receives the **original image** because CLAHE/sharpening can merge text regions and break ML Kit's spatial/bounding-box detection.

### Dual OCR Engines

| Engine        | Package                         | Accuracy | Use                                  |
| ------------- | ------------------------------- | -------- | ------------------------------------ |
| **Tesseract** | `flutter_tesseract_ocr`         | 95-98%   | Primary — runs on preprocessed image |
| **ML Kit**    | `google_mlkit_text_recognition` | 85-90%   | Fallback + layout detection          |

Both engines run on the image. The result with higher confidence is selected.

### Multi-Layer Field Extraction

For each field (Name, ID Number, DOB), extraction tries layers in order:

1. **Layout-based** — uses ML Kit bounding boxes to find text near known label positions (e.g., text directly below "NAME:" label)
2. **Keyword-based** — searches for text near keywords ("SURNAME:", "BORN:")
3. **Fuzzy matching** — pattern matching with tolerance for OCR errors
4. **Validation** — checks extracted value against expected format (date formats, ID number regex)

### OCR Post-Processing

After raw text is extracted:

- Context-aware character fixes: `|`→`I` only in name context, `0`→`O` only in letter context
- Date standardization to MM/DD/YYYY
- ID number format correction
- Name title-casing

### Auto-Detect ID Type

If the cashier selects "Auto-detect," the system runs an ML Kit pass and scores keywords:

- "OSCA", "SENIOR", "CITIZEN" → identifies as Senior Citizen ID
- "PWD", "DISABILITY", "PDAO" → identifies as PWD ID
- If unclear → prompts cashier to confirm the type

### Face Detection Guard

Before OCR runs, ML Kit's face detector checks if a face is present in the image. If no face is found, a dialog appears:

- "No face detected in image. Continue anyway?" or "Retake photo."
  This prevents scanning random objects or blank images.

---

## 8. The Fraud Detection System

### How Fraud Flagging Works

1. Cashier gets SUSPICIOUS or INVALID result.
2. The result screen shows a pre-filled fraud flag form.
3. Cashier submits — app sends: ID number, beneficiary type, verification log ID, optional notes, and the captured ID card image (as base64 → saved to server).
4. API inserts a fraud_flag record and stores the card image URL.
5. LGU admin (OSCA or PDAO) reviews the flag in their web portal.
6. Admin sees the captured image, OCR data, and establishment info.
7. Admin marks: **Confirmed Fraud** or **Dismissed**.

### Auto-Suspend (Threshold-Based)

If **3 or more distinct establishments** flag the same ID (with no repeat counting from the same shop):

- Beneficiary status automatically changes to `suspended`.
- Reason is recorded: "Automatically suspended due to multiple fraud flags."
- An alert is sent to the LGU admin portal (staff_alerts).
- A push notification is sent to the beneficiary.
- Future scans of that ID return SUSPICIOUS ("ID is currently under investigation").

Threshold is configurable via `AUTO_SUSPEND_FLAG_THRESHOLD` environment variable.

### Auto-Restore

If an admin reviews and dismisses all pending/reviewing flags for a beneficiary, and the beneficiary was automatically suspended (not manually), the system **automatically restores** the beneficiary to `active` status.

### Flag Decay

Fraud flags older than **180 days** with status `pending` (never reviewed) are automatically expired daily. This prevents old, forgotten flags from triggering new auto-suspensions.

### Rate Limiting

- Scan endpoint: **60 scans per minute** per establishment (prevents automated bulk scanning).
- Status sync endpoint: **120 requests per minute** per establishment. The Client Portal polls every 8 seconds and pauses for 1 minute if it receives HTTP 429.
- Fraud flag endpoint: **30 flags per hour** per establishment (prevents false-flag spam).
- All other API routes share a **100 requests per 15 minutes per IP** limit. Scan and status-sync routes are exempt from this IP-wide limit because they have their own per-establishment limits, so offices sharing one IP are not locked out during normal scanning.

### Cross-Database Conflict Detection

If a cashier scans a PWD ID but selects "Senior Citizen" type (wrong type):

- The API detects the mismatch (ID exists in the other database).
- Returns "suspicious" instead of "invalid."
- **Auto-inserts fraud flags in BOTH the OSCA and PDAO portals** so both offices can see the conflict.
- Logs the conflict in audit_logs with the full metadata.

---

## 9. The Dispute Resolution System

### What Is a Dispute?

A beneficiary can submit a dispute through the beneficiary mobile app when:

| Type                | Meaning                                             |
| ------------------- | --------------------------------------------------- |
| `wrong_denial`      | They are valid but were denied a discount           |
| `unauthorized_use`  | Someone else used their ID without their permission |
| `business_refusal`  | A store refused them despite system showing VALID   |
| `incorrect_db_info` | Their record in the database has wrong information  |

### Dispute Workflow

```
Beneficiary submits dispute (+ optional photo attachment)
    → notification sent: "Dispute Received"
    → dispute status: submitted

LGU Admin acknowledges (within 24-hour SLA)
    → notification sent: "Dispute Acknowledged"
    → dispute status: acknowledged

LGU Admin investigates
    → dispute status: under_review

LGU Admin resolves or rejects
    → notification sent: "Dispute Resolved" / "Dispute Rejected"
    → dispute status: resolved / rejected
```

### SLA Tracking

- **24-hour SLA**: Admin must acknowledge within 24 hours.
- **72-hour SLA**: Admin must resolve within 72 hours of submission.
- SLA indicators shown in the admin portal (red if overdue, amber if close).
- Automated escalation: A background job runs **every 30 minutes** and sends an escalation notification if SLA is breached without action.

### Data Compartmentalization

- OSCA portal only sees disputes from **senior citizen** beneficiaries.
- PDAO portal only sees disputes from **PWD** beneficiaries.
- BPLO portal only sees **business_refusal** type disputes.

---

## 10. The Database Design

### Tables Overview

| Table                  | Purpose                                                 |
| ---------------------- | ------------------------------------------------------- |
| `users`                | Staff accounts (OSCA/PDAO/BPLO admins)                  |
| `establishments`       | Registered businesses                                   |
| `beneficiaries`        | Senior citizen and PWD ID records                       |
| `beneficiary_accounts` | Login credentials for the beneficiary mobile app        |
| `verification_logs`    | Every single ID scan is recorded here                   |
| `fraud_flags`          | Fraud reports submitted by establishments               |
| `disputes`             | Disputes submitted by beneficiaries                     |
| `notifications`        | Push/SMS notification records                           |
| `audit_logs`           | Every admin action is logged here                       |
| `staff_alerts`         | In-app alerts for LGU staff (e.g., auto-suspend events) |

### Key Design Decisions

**Enum types** — PostgreSQL enums enforce valid values at the database level. For example, `verification_result` can only be: `valid`, `suspicious`, `invalid`, `manual_review`. This prevents garbage data.

**Role-based isolation** — The `user_role` enum (`osca_admin`, `pdao_admin`, `bplo_admin`) drives access control. Every API endpoint checks the role and filters accordingly (e.g., OSCA queries only `WHERE beneficiary_type = 'senior_citizen'`).

**Audit log** — Every important action (login, beneficiary added, status changed, flag reviewed) writes a row to `audit_logs` with: which user, which action, which record, and timestamp. This provides a full accountability trail.

**Incremental migrations** — The schema is built through 25 numbered SQL migration files. Each migration is additive (no destructive changes). This allows the schema to evolve safely.

**Normalized ID numbers** — ID numbers are stored as uppercase alphanumeric only (dashes and spaces stripped). This prevents verification mismatches when the same ID is scanned with/without dashes.

**Unique person index** — `(UPPER(full_name), birthdate, beneficiary_type)` must be unique (partial index: only when status ≠ 'revoked'). This prevents duplicate registrations while allowing re-registration after revocation.

**id_number expression index** — `UPPER(REGEXP_REPLACE(id_number, '[^A-Za-z0-9]', '', 'g'))` — ensures fast normalized lookups.

---

## 11. Security Features

### Authentication

- **Staff (Web Portal)**: JWT (JSON Web Token) signed with `JWT_SECRET_STAFF`. Tokens auto-refresh silently when < 5 minutes from expiry. No re-login required mid-session.
- **Establishments (Mobile)**: JWT signed with `JWT_SECRET_ESTABLISHMENT`.
- **Beneficiaries (Mobile)**: OTP-based (ID number + DOB → OTP to registered mobile); once verified, a JWT signed with `JWT_SECRET_BENEFICIARY` is issued for the session. Can also use PIN (4-digit, max 5 attempts, 15-min lockout) or biometric (fingerprint via `local_auth`).
- Each actor type has its **own signing secret**, so a token issued for one type (e.g., establishment) cannot be reused to authenticate as another (e.g., staff).

### Password Security

- All passwords hashed with **bcrypt, 12 rounds** (very strong — cost-effective but resistant to brute force).
- Staff can change their own password; admins can reset staff passwords.

### Rate Limiting

- Scan endpoint: 60 requests/minute per establishment.
- Fraud flag endpoint: 30 requests/hour per establishment.
- Prevents automation attacks.

### Session Inactivity Timeout

- **Web portals**: 15-minute idle timeout, 2-minute countdown warning before automatic logout.
- **Mobile apps**: After 5 minutes of inactivity the beneficiary app locks and requires the PIN or biometric to resume (the 15-minute idle logout still applies). Verified in code; device acceptance testing is pending.
- Prevents unattended sessions being exploited.

### Authenticated File Serving

- ID card images and dispute documents are stored in **Supabase Storage** (`id-captures`, `dispute-docs` buckets) — the buckets are **not publicly accessible**.
- Only authenticated staff (valid JWT) can retrieve them via `GET /api/uploads/*`, which proxies the download from Supabase Storage.
- The API validates the bucket/object path to prevent directory traversal attacks.

### CORS

- API configured to only accept requests from known origins (web portal domains).

### Input Validation

- All API endpoints use `express-validator` to validate and sanitize inputs before processing.
- SQL queries use **parameterized queries** (pg library) — prevents SQL injection.

### Breach Incident Reporting

- All three portals have a "Generate Breach Report" feature.
- If a data breach is suspected, staff fill a form describing the incident.
- The system generates an NPC (National Privacy Commission)-ready formatted report.
- The report is downloadable as a `.txt` file and logged in audit_logs.

---

## 12. Offline Capability

### What Works Without Internet

- Full OCR pipeline (Tesseract + ML Kit are on-device, no internet needed).
- Viewing scan history stored locally in SQLite.
- Checking the Hive cache for previously verified IDs (up to 6 hours old).

### Hive Offline Cache

- Every successful verification is cached in Hive (key-value store).
- On connectivity loss: `ApiService.verifyId()` catches `SocketException` / `ClientException` / `TimeoutException` → calls `_tryOfflineCache()`.
- Cache age is shown in the result: `[OFFLINE — synced Xm ago]`.
- Stale cache (> 6 hours) returns an error instead of potentially wrong VALID result.
- Cache sync cursor is persisted to disk — survives app cold restarts.

### Offline Fraud Flag Queue

- Fraud flags submitted while offline are stored in a local queue (`FraudFlagSyncService`).
- When connectivity is restored, the queue automatically syncs the flags to the server.

---

## 13. Notifications System

### Two Channels

| Channel        | Technology               | When Used                                    |
| -------------- | ------------------------ | -------------------------------------------- |
| **Push (FCM)** | Firebase Cloud Messaging | App is installed and has data connection     |
| **SMS**        | Semaphore Gateway        | Backup for beneficiaries without smartphones |

### When Notifications Are Sent (to Beneficiary)

- When a verification scan is performed on their ID.
- When a fraud flag is submitted against their ID.
- When their ID is auto-suspended (strong warning notification).
- When a dispute they submitted is acknowledged, resolved, or rejected.
- When their ID is about to expire (expiry alert).

### Foreground Notifications (In-App)

When the beneficiary app is in the foreground, Android doesn't show push notifications in the status bar automatically. The app listens for incoming FCM messages and shows a floating **SnackBar banner** at the bottom of the screen for 5 seconds.

---

## 14. Admin Portal Features

### All Three Portals Share

- **Dashboard** with analytics (fraud flags by status, verification trends, 14-day bar chart).
- **Audit Logs** — paginated view with search, date range, and action-category filters. CSV export.
- **Reports** — downloadable CSV exports for verification logs, fraud flags, and disputes.
- **Staff Management** — list, create, edit, activate/deactivate staff accounts. Reset passwords.
- **Session Timeout** — 15-minute inactivity auto-logout with countdown warning.
- **Breach Report Generator** — NPC-formatted incident report.

### OSCA Portal (Senior Citizen Specific)

- Beneficiary list/add/edit/bulk-import (senior citizens only).
- Expiring-soon banner (IDs expiring within 30 days — red if ≤7 days).
- Fraud Flags with captured ID card image viewer (authenticated).
- Disputes from senior citizen beneficiaries.

### PDAO Portal (PWD Specific)

- Same as OSCA but for PWD records.
- Disability type field on all beneficiary records (11 canonical types per Philippine law).
- Same fraud flag viewer and dispute handling.

### BPLO Portal

- Establishment account management (approve, suspend, revoke).
- Establishment self-registration review (establishments register themselves, BPLO approves).
- Bulk credential generation for approved establishments (credentials delivered as one-time-download CSV token — not plain text in response).
- Verification activity for all ID types.
- Business refusal disputes.
- Manual entry badge in verification history (flags entries made without scanning).

---

## 15. Beneficiary Mobile App

A **separate Flutter app** from the establishment app (different package name: `idetect_beneficiary`).

### Authentication Flow

```
ID Number + Date of Birth
    → If no mobile registered: prompted to enter mobile number
    → OTP sent via SMS to mobile number
    → OTP verified → JWT issued
    → Optional: set 4-digit PIN for next login
    → Optional: enable fingerprint login
```

### Features

- **Status Tab** — shows current ID status (active/expired/suspended/revoked) with color badge.
- **History Tab** — list of all times their ID was scanned (verification logs).
- **Disputes Tab** — submit new disputes (with optional photo attachment), track existing disputes.

### Push Notifications

- Device FCM token registered on login.
- Foreground notifications appear as a blue floating SnackBar banner.
- Background/killed notifications appear as standard Android notifications.

---

## 16. Limitations You Should Acknowledge Honestly

Panelists respect honesty. Know these limitations and how you would address them:

### 1. Confidence Score Is Heuristic

The OCR confidence score shown internally is computed using keyword presence bonuses, not Tesseract's actual per-character confidence API. **What you'd say:** "We use it as an extraction quality indicator. In future work, we would use Tesseract's HOCR output for true character-level confidence."

### 2. Zone Coordinates Are Hardcoded for One Card Design

The layout-based extractor uses fixed percentage coordinates calibrated for the current Valenzuela OSCA card. If the card design changes, zones need recalibration. **What you'd say:** "The system is designed for the specific card formats used by Valenzuela City. A template versioning system is a planned improvement."

### 3. SMS OTP Requires Semaphore Credits

The Semaphore SMS integration is coded and working, but the account needs approved sender name and SMS credits for live use. OTPs are always logged to the API console for testing. **What you'd say:** "The integration is complete. We need the sender name 'iDetect' to be approved by Semaphore and credits loaded for full SMS delivery."

### 4. No Automated Test Suite

No Jest unit tests for the API. **What you'd say:** "The system was tested manually end-to-end. Automated test coverage is a next step."

### 5. Large Imports Are Synchronous

Bulk imports of 20,000+ rows run synchronously. A progress bar with estimated time is shown, but there is no background job queue. **What you'd say:** "For production scale, we would move large imports to a background job (e.g., Bull queue with Redis) with real-time progress via WebSocket."

### 6. Bilingual Support Not Implemented

The app is English-only. Philippine Senior Citizens and PWDs may prefer Filipino. **What you'd say:** "REQ-2.18.2 (bilingual English/Filipino) was deprioritized due to scope. It would be implemented using Flutter's `.arb` localization files."

### 7. Offline and Online Scans Are Different

Online verification hits the central database. Offline verification hits the local 6-hour cache. Both show the same result screen with a small text difference. **What you'd say:** "We acknowledge this distinction should be more visually prominent. In production, an offline result would show a large OFFLINE banner to help cashiers make the right call."

---

## 17. Panelist Q&A — Most Likely Questions and Your Answers

---

### Q: What is the main objective of your study?

**A:** iDetect aims to reduce fraudulent discount claims on Senior Citizen and PWD IDs by providing a fast, automated ID verification system for Philippine LGUs. Establishments scan the ID, the system verifies it against an LGU database, and flags suspicious cards for investigation — replacing unreliable manual inspection.

---

### Q: Why did you choose Flutter for the mobile app?

**A:** Flutter allows a single codebase to run on both Android and iOS, reducing development time. It uses Dart, which compiles to native ARM code — giving us near-native performance for image processing tasks. It also has strong packages for OCR (Tesseract, ML Kit) and computer vision (OpenCV) that we needed.

---

### Q: Why did you use two OCR engines?

**A:** Tesseract is more accurate (95-98%) for document scanning but is slower and sensitive to image quality. Google ML Kit is faster and more robust but slightly less accurate (85-90%). By running both in parallel and selecting the result with higher confidence, we get the best of both — high accuracy with a reliable fallback. ML Kit also provides bounding box coordinates, which we use for layout-based field extraction.

---

### Q: What is CLAHE and why did you use it?

**A:** CLAHE stands for Contrast Limited Adaptive Histogram Equalization. It improves image contrast by working on small local regions of the image rather than the whole image at once. This is important for ID cards where one area might be in bright light while another is in shadow. Standard histogram equalization would over-amplify the bright areas, but CLAHE limits the amplification in each region, preserving details in both light and dark areas.

---

### Q: How does the system prevent someone from using a fake ID?

**A:** Three layers:

1. The ID number must exist in the official LGU database (uploaded by OSCA/PDAO staff).
2. The name extracted by OCR must match the database name with ≥80% Jaro-Winkler similarity.
3. The date of birth extracted by OCR must exactly match the database record.

If any of these fail, the result is SUSPICIOUS or MANUAL_REVIEW, not VALID. Additionally, the system captures and stores the ID card photo for each scan, creating an evidence trail.

---

### Q: What is Jaro-Winkler and why did you choose it for name matching?

**A:** Jaro-Winkler is a string similarity algorithm that measures how similar two strings are, scoring from 0.0 (completely different) to 1.0 (identical). We chose it for name matching because:

1. OCR commonly produces minor errors (a letter misread, a space added/removed).
2. It gives extra weight to characters at the beginning of strings — which is useful for names since first characters are usually read correctly.
3. It handles common OCR substitutions (e.g., "REYES" vs "REVES") better than exact matching.
   We set the threshold at 0.80 — if the similarity score is below 0.80, the system considers it a potential name mismatch and downgrades the result to SUSPICIOUS.

---

### Q: How does the fraud auto-suspension work?

**A:** When a fraud flag is submitted, the system counts how many distinct (different) establishments have flagged that same ID. If that count reaches 3 (configurable), the system automatically suspends the beneficiary — changes their status to `suspended`. This requires at least 3 separate businesses to independently flag the same ID, reducing the chance of a single malicious actor abusing the flag system. The auto-suspend also sends a push notification to the beneficiary and an alert to the LGU admin portal.

---

### Q: How is user data protected?

**A:** Multiple layers:

- All passwords are hashed with bcrypt (12 rounds) — irreversible, brute-force resistant.
- JWTs are signed with separate secrets for staff vs. establishments.
- Role-based access: OSCA can only access senior citizen data, PDAO can only access PWD data.
- ID card images are not publicly accessible — only authenticated staff can retrieve them.
- All inputs are validated and sanitized to prevent SQL injection.
- Sessions auto-expire after 15 minutes of inactivity.
- Every important action is logged in the audit_logs table.

---

### Q: What happens when the phone has no internet connection?

**A:** The OCR runs entirely on the device — no internet needed for that. For verification, the app falls back to a local Hive cache that stores the last known status of previously scanned IDs. The cache result clearly shows how old it is (e.g., "[OFFLINE — synced 32m ago]"). If the cache is older than 6 hours, it is considered too stale and the app returns an error instead of potentially wrong data. Fraud flags submitted offline are queued locally and automatically synced to the server when connectivity is restored.

---

### Q: What is a dispute and how does it work?

**A:** A dispute is submitted by a beneficiary through their mobile app when they disagree with a verification outcome or want to report an issue. There are four types: wrong denial, unauthorized use of their ID, a business refusing them despite a valid result, or incorrect information in their record. The dispute goes through a workflow: submitted → acknowledged (within 24 hours) → under review → resolved/rejected. SLA timers track compliance. Automated escalation notifications are sent if the LGU misses the deadline.

---

### Q: Why is there one staff portal instead of separate ones per office?

**A:** Data compartmentalization and role separation are enforced through RBAC rather than through physically separate deployments. OSCA staff should never see PWD records, and PDAO staff should never see senior citizen records — these are different LGU offices with different legal mandates. BPLO handles establishment management, not beneficiary data. The staff portal is a single deployed web app at one URL; after login, each account is routed to the dashboard matching its role, and the API enforces that a token for one role cannot fetch another role's data. This keeps one codebase/deployment to maintain while still guaranteeing the same access boundaries as separate portals would.

---

### Q: How does the establishment registration work?

**A:** Businesses register themselves through a self-registration form in the BPLO portal (no need for BPLO staff to manually enter them). The registration creates an account with status `pending`. A BPLO admin reviews and approves it. Only approved establishments can use the mobile scanning app. Credentials (username/password for the mobile app) are delivered as a one-time-download CSV — after one download, the link expires for security.

---

### Q: What is the audit log and why is it important?

**A:** The audit log records every significant action in the system: who logged in, who added a beneficiary, who changed an establishment's status, who reviewed a fraud flag, and more. Every row has the user ID, action type, the affected record, and timestamp. This is critical for accountability, especially for a government system — you can always trace back who did what and when. It also supports the breach incident reporting feature, which is required by the National Privacy Commission guidelines.

---

### Q: How does the beneficiary log in to the mobile app?

**A:** Through a 3-step process:

1. Enter their ID number and date of birth.
2. An OTP (One-Time Password) is sent to their registered mobile number via SMS.
3. Enter the OTP to complete login and receive a JWT token.

For subsequent logins, they can set a 4-digit PIN (faster) or enable biometric (fingerprint) login. The PIN has a maximum of 5 incorrect attempts before a 15-minute lockout, preventing brute force.

---

### Q: What are the system's limitations?

**A:** Honestly, there are a few: (1) The OCR confidence score is a heuristic indicator, not a true Tesseract confidence score. (2) Zone coordinates for field extraction are calibrated for the current Valenzuela card design and would need recalibration for different designs. (3) SMS OTP delivery requires the Semaphore sender name to be approved and credits loaded. (4) Large bulk imports are synchronous. (5) Bilingual (English/Filipino) support was not implemented within the project scope.

---

### Q: How did you handle the case where a PWD ID is accidentally scanned as a Senior Citizen ID?

**A:** The system has cross-database conflict detection. When a scan returns INVALID because the ID was not found in the selected type's database, the API also checks the other database. If the ID is found there, it returns SUSPICIOUS instead of INVALID, signals a cross-type mismatch, and inserts fraud flags in both the OSCA and PDAO portals so both offices are aware. The new auto-detect feature also helps prevent this — it automatically identifies the card type from header keywords.

---

### Q: What database did you use and why PostgreSQL?

**A:** PostgreSQL, hosted on Supabase (accessed via its connection pooler). We chose it because:

- It supports **enum types**, which enforce valid values at the database level (no invalid statuses possible).
- It supports **JSONB** for flexible metadata storage in audit logs.
- It has powerful **expression indexes** (used for normalized ID number lookups).
- It supports **partial indexes** (used for the unique person constraint that excludes revoked records).
- It's production-grade, ACID-compliant, and well-supported by the `pg` library in Node.js.
- Supabase provides managed hosting, automatic backups, and doubles as the object storage for ID/dispute images.

---

### Q: How many functional requirements did you implement?

**A:** The system covers approximately 80 functional requirements across 18 categories (REQ-2.1 through REQ-2.18). Key areas: establishment management, beneficiary management, ID scanning and verification, fraud flag management, dispute resolution, notifications, audit logging, report generation, staff management, dashboard analytics, session security, and breach incident reporting. The only unimplemented requirement is REQ-2.18.2 (bilingual support), which was deprioritized due to scope.

---

## 18. Numbers and Metrics to Know

| Metric                                     | Value                                  |
| ------------------------------------------ | -------------------------------------- |
| OCR accuracy (Tesseract)                   | 95–98%                                 |
| OCR accuracy (ML Kit fallback)             | 85–90%                                 |
| Image preprocessing steps                  | 10                                     |
| Database tables                            | 10                                     |
| Database migrations                        | 25                                     |
| OCR confidence threshold for manual_review | < 0.80 Jaro-Winkler                    |
| Auto-suspend threshold                     | 3 distinct establishments              |
| Flag decay period                          | 180 days                               |
| Dispute acknowledgment SLA                 | 24 hours                               |
| Dispute resolution SLA                     | 72 hours                               |
| Scan rate limit                            | 60 per minute per establishment        |
| Fraud flag rate limit                      | 30 per hour per establishment          |
| Session inactivity timeout                 | 15 minutes                             |
| Session countdown warning                  | 2 minutes                              |
| Offline cache TTL                          | 6 hours                                |
| JWT silent refresh trigger                 | < 5 minutes before expiry              |
| PIN max attempts                           | 5 (then 15-minute lockout)             |
| Bulk import max rows                       | 20,000 (configurable)                  |
| Bulk import chunk size                     | 500 rows per SQL INSERT                |
| Web portals                                | 3 (OSCA, PDAO, BPLO)                   |
| Flutter apps                               | 2 (Establishment, Beneficiary)         |
| Disability types recognized                | 11 canonical types                     |
| User roles in system                       | 3 (osca_admin, pdao_admin, bplo_admin) |
| SLA escalation check interval              | Every 30 minutes                       |
| ID expiry alert scheduler                  | Daily cron                             |
| Flag decay scheduler                       | Daily cron                             |
| BCrypt rounds                              | 12                                     |
| Credential token TTL                       | 15 minutes                             |

---

## Quick Reference: Key File Locations

| Feature                  | Key File                                          |
| ------------------------ | ------------------------------------------------- |
| OCR pipeline             | `lib/services/enhanced_ocr_service.dart`          |
| Image preprocessing      | `lib/services/opencv_image_processor.dart`        |
| Field extraction         | `lib/services/parser_service.dart`                |
| Auto-detect card type    | `lib/services/hybrid_parser_service.dart`         |
| Verification API         | `apps/api/src/routes/verification.js`             |
| Fraud flags API          | `apps/api/src/routes/fraudFlags.js`               |
| Disputes API             | `apps/api/src/routes/disputes.js`                 |
| Notifications API        | `apps/api/src/routes/notifications.js`            |
| Beneficiary portal       | `apps/api/src/routes/beneficiaryPortal.js`        |
| SLA escalation scheduler | `apps/api/src/services/slaEscalationScheduler.js` |
| Flag decay scheduler     | `apps/api/src/services/flagDecayScheduler.js`     |
| Offline cache            | `lib/data/datasources/local/local_database.dart`  |
| Session timeout (web)    | `apps/web-osca/src/hooks/useSessionTimeout.js`    |
| Session timeout (mobile) | `lib/services/session_timeout_service.dart`       |

---

_Good luck tomorrow. You built something genuinely impressive — a full-stack, multi-platform government system with OCR, fraud detection, dispute management, and real security practices. Be confident — you know this system better than anyone in that room._
