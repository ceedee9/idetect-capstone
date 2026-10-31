# iDetect — Defense Preparation Guide

**Prepared:** May 20, 2026 — **Revised** against the current codebase (verification log in §21)  
**Purpose:** Comprehensive review guide for panel defense — covers all system components, design decisions, likely panelist questions with answers, mock-panel challenges (§19), and defense-day planning (§20).

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
19. [Mock Panel — Hard Questions and Honest Answers](#19-mock-panel--hard-questions-and-honest-answers)
20. [Defense Day Plan](#20-defense-day-plan)
21. [Verification Log and Pre-Defense Checklist](#21-verification-log-and-pre-defense-checklist)

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

Hosting (current):
  - Staff web portal (React/Vite) → Vercel, served at https://idetect.it.com
  - REST API (Express)            → Northflank, https://site--idetect--lr4dgpy2rvkq.code.run/api
  - Database + file storage       → Supabase (PostgreSQL pooler; buckets id-captures, dispute-docs)
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
| Hosting           | Vercel (portal), Northflank (API), Supabase (DB + storage) | Portal at `https://idetect.it.com`; API at the Northflank URL above |

### Why This Architecture?

- **Mobile app** handles OCR locally — faster, works offline, no image upload needed for OCR.
- **REST API** is the single source of truth — all apps talk to the same data.
- **One unified web portal URL** with role-based routing — OSCA cannot see PWD data and vice versa (data compartmentalization is enforced by RBAC, not by separate URLs).
- **PostgreSQL on Supabase** — managed cloud database with a connection pooler, no server to maintain yourself; Supabase Storage also holds ID/dispute images.
- **Vercel + Northflank split** — the static portal and the long-running API are hosted separately, so each can be redeployed independently. (Do not describe the API and portal as one combined service — that was the earlier setup.)

---

## 4. Technology Stack — What You Used and Why

### Mobile App (Flutter)

- **Dart + Flutter** — One codebase, runs on Android (and can be built for iOS). Chosen for rapid development and native performance.
- **Google ML Kit** (`google_mlkit_text_recognition`) — **Primary OCR on the live scan path.** Provides text with bounding boxes, which drive layout-based field extraction.
- **Tesseract OCR** (`flutter_tesseract_ocr`) — Used for **zone-level re-reads** of fields that ML Kit could not validate (on the enhanced grayscale image), and as the primary engine of the secondary `EnhancedOcrService` path. It runs fully offline. We have **no measured accuracy figure** for either engine; do not quote one (see §16).
- **OpenCV Dart** (`opencv_dart`) — Native OpenCV card detection and perspective normalization (`normalizeCard`) before OCR. Produces a fixed, upright card image in two copies: colour (for ML Kit) and enhanced grayscale (for Tesseract zones).
- **Google ML Kit Face Detection** — Used to verify that a face exists in the captured image before running OCR (prevents processing random photos).
- **Hive** — Local key-value store holding the **offline blocklist** (`blocked_ids`: revoked and suspended IDs only, stored as SHA-256 hashes), the offline scan replay queue (`pending_offline_scans_v2`), and the fraud-flag sync queue.
- **SQLite (sqflite)** — Local relational database for scan history.
- **Firebase Cloud Messaging (FCM)** — Receives push notifications on the beneficiary app.

### Backend API (Node.js)

- **Express.js** — REST API framework.
- **PostgreSQL + pg** — Relational database with complex queries.
- **JWT (JSON Web Token)** — Authentication for both staff (web portals) and establishments (mobile app).
- **bcryptjs** — Password hashing: 12 rounds for staff, establishment, and beneficiary passwords; 10 rounds for OTP and PIN codes.
- **express-rate-limit** — Rate limiting to prevent abuse (60 scans/min and 120 status syncs/min per establishment; 30 fraud flags/hour; 10 login attempts per 15 min per IP).
- **Multer** — File upload handling for ID card images and dispute documents.
- **Firebase Admin SDK** — Sends FCM push notifications to beneficiary devices.
- **Semaphore SMS Gateway** — Sends OTP codes and alerts via SMS.
- **Resend** — Sends transactional email (onboarding, notifications) from the verified `idetect.it.com` domain.
- **Scheduled jobs via `setInterval`** — ID expiry alerts (every 24 h), SLA escalation (every 30 min), and flag decay (daily). `node-cron` is **not** a dependency; do not name it.
- **Jaro-Winkler** — String similarity algorithm for cross-validating OCR-extracted names against database names.

### Staff Web Portal (React)

- **React.js + Vite** — Fast, modern web application framework.
- **Axios** — HTTP client for API calls.
- **Lucide React** — Icon library.
- **One unified React app** — serves BPLO, OSCA, and PDAO staff from the same build; role-based routing after login determines the dashboard shown.

### Database (PostgreSQL) & Storage

- **Migrations** applied incrementally — structured, version-controlled schema.
- **Supabase** — Managed PostgreSQL (via connection pooler) and object storage (`id-captures`, `dispute-docs` buckets).
- **Northflank** — Hosts the API (`https://site--idetect--lr4dgpy2rvkq.code.run/api`). Whether it auto-deploys from `main` is not confirmed (see §21).

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
- Logs in with their **ID number + date of birth** (first-time or quick login), receiving an **OTP** by SMS. Returning users can log in with their **4-digit PIN**; biometric (fingerprint) login via `local_auth` is also available. A remembered "welcome-back" option shows the PIN screen for returning users.
- The beneficiary app **locks after 5 minutes** of inactivity (`_lockTimeout`) and shows an app-lock screen (REQ-2.17.7).
- The app has English and Filipino ARB files (`app_en.arb` and `app_fil.arb`). Translation coverage has not been audited, so say "partially bilingual".

---

## 6. The Scan & Verification Flow (Most Important!)

This is the **core feature** of the system. Know this step by step.

```
Step 1: Cashier opens app → selects ID type (Senior / PWD / Auto-detect)
Step 2: Camera opens → 2 on-screen tips shown
Step 3: Photo taken → OpenCV finds the card and normalizes it (perspective-corrected, upright)
Step 4: Face detection check (ML Kit, heuristic) → warns if no face is detected; cashier may continue
Step 5: Card type auto-detected (if "Auto-detect") from header keywords
Step 6: ML Kit text recognition on the colour image (with bounding boxes); Tesseract re-reads zones on the enhanced grayscale image only for fields ML Kit could not validate
Step 7: Field extraction → Name, ID Number, Date of Birth (layout → keyword → fuzzy → validation)
Step 8: User reviews extracted data on screen, can correct errors
Step 9: Device checks its offline blocklist first (revoked/suspended IDs only; fast reject, never fast approve)
Step 10: App sends to API: POST /api/verification/scan
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

- **Name** is compared to the database name using **Jaro-Winkler string similarity** (threshold: `OCR_NAME_MATCH_THRESHOLD`, default 0.80). If score < 0.80, result downgrades to SUSPICIOUS.
- **Date of Birth** is compared exactly. A DOB mismatch also downgrades the result to SUSPICIOUS, and `fields_matched` is logged.
- If **both** name and DOB cannot be extracted at all (non-manual scan), result becomes MANUAL_REVIEW.
- This prevents someone using a valid ID number from a different person.

### Offline Mode

Offline behavior is narrower than a full cache. The device stores only a **blocklist**:

- The Hive box `blocked_ids` holds **only revoked and suspended IDs**, keyed by SHA-256 hash, refreshed by the status sync poll.
- If the scanned ID is on the blocklist, the device rejects it immediately (fast block). A miss or an active status is never approved on the device; it goes to the server.
- With no network, the scan is saved to a local replay queue (`pending_offline_scans_v2`) and returns **MANUAL_REVIEW** (`isOffline: true`). An offline result is **never VALID**. The queued scan is replayed to the server when connectivity returns.
- There is **no 6-hour TTL, no staleness limit, and no "[OFFLINE — synced X minutes ago]" banner** in the code. Do not describe these. The only age figure is the sync age used for diagnostics.

---

## 7. OCR: How the System Reads the ID Card

### Image Normalization (Live Scan Path)

The live scan uses the OpenCV **card normalization** step, not a 10-step filter chain:

1. **Card detection and perspective normalization** (`normalizeCard`, ~0.3–0.8 s) — finds the card and flattens it to a fixed, upright rectangle.
2. **Two copies are produced at the same size:** a colour copy (for ML Kit) and an enhanced grayscale copy (for Tesseract zone re-reads).
3. **Centre crop to the card ratio** (`cropCenterToCardRatio`) at capture time.

> **Honest note for the panel:** `OpenCVImageProcessor.preprocess()` (a 10-step pipeline: resize, deskew, bilateral filter, CLAHE, sharpening, thresholding, morphology) and `assessQuality()` exist in the code but have **no callers** in the live scan path. Do not present the 10-step pipeline as what runs in production. Also, the earlier rule that "ML Kit gets the original image" is no longer accurate. ML Kit gets the normalized colour image.

### OCR Engines in the Live Path

| Engine | Package | Role in the live scan |
| ------ | ------- | --------------------- |
| **ML Kit** | `google_mlkit_text_recognition` | Primary. Reads the colour image and returns text with bounding boxes for layout-based extraction. |
| **Tesseract** | `flutter_tesseract_ocr` | Zone-level re-reads of fields that ML Kit could not validate, run on the enhanced grayscale image. |

Both are used in one pipeline (`HybridParserService`), not as a race where the higher-confidence result wins. **We have no measured accuracy figure for either engine.** Do not quote "95–98%" or "85–90%". The live scan has a 35-second timeout; on timeout it falls back to an ML Kit-only parse.

`EnhancedOcrService` (Tesseract primary, ML Kit fallback) is a secondary path used only when the quality check is skipped. Its "confidence" is a keyword heuristic, not a real Tesseract confidence score.

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
- An alert is written to the LGU admin portal (`staff_alerts`).
- A `notifications` row with `channel = 'push'` is written for the beneficiary. Delivery is through the notification pipeline; the code path we reviewed records the push-channel row and does not show a direct FCM send, so do not claim guaranteed push delivery.
- Future scans of that ID return SUSPICIOUS ("ID is currently under investigation").

Threshold is configurable via `AUTO_SUSPEND_FLAG_THRESHOLD` environment variable (default 3).

### Auto-Restore

Auto-restore applies **only** to suspensions the system made automatically. When an admin dismisses the last pending/reviewing flag, and no active flags remain, the beneficiary is restored to `active`. The same check runs when flags decay. **Manual suspensions are never auto-cleared**, so an admin's manual decision is not overridden.

### Flag Decay

Fraud flags older than **180 days** with status `pending` (never reviewed) are automatically expired daily. This prevents old, forgotten flags from triggering new auto-suspensions.

### Rate Limiting

- Scan endpoint: **60 scans per minute** per establishment (prevents automated bulk scanning).
- Status sync endpoint: **120 requests per minute** per establishment. The device status sync polls every 8 seconds with a `since` cursor and pauses for **1 minute** if it receives HTTP 429.
- Fraud flag endpoint: **30 flags per hour** per establishment (prevents false-flag spam).
- Login endpoints: **10 attempts per 15 minutes** per IP.
- General API limit: **100 requests per 15 minutes per IP**. Authentication routes, staff alerts, the scan endpoint, and status-update routes are exempt from this IP-wide limit because they have their own limits, so offices sharing one IP are not locked out during normal scanning.
- Account lockout is separate from rate limiting: **3 failed attempts lock the account for 30 minutes** (staff, establishment, and beneficiary PIN).

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
| `other`             | Any other concern (added in migration 034)          |

Statuses are `submitted`, `acknowledged`, `under_review`, `resolved`, and `rejected`. Dispute SMS messages are sent through Semaphore at key stages (`disputes.js`).

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
- BPLO portal only sees **`business_refusal`** disputes.
- Establishment users can file on behalf of a beneficiary, but `business_refusal` disputes are excluded from that path.
- Staff notifications for new disputes come from database triggers (migrations 047–049).

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

**Role-based isolation** — The `user_role` enum drives access control. Staff roles are `osca_admin`, `pdao_admin`, `bplo_admin` (from migration 001), plus `super_admin` (038), and `bplo_super_admin`, `osca_super_admin`, `pdao_super_admin` (039). Every API endpoint checks the role and filters accordingly (e.g., OSCA queries only `WHERE beneficiary_type = 'senior_citizen'`). Establishments have Super User and Regular User roles (migrations 042–046).

**Audit log** — Every important action (login, beneficiary added, status changed, flag reviewed) writes a row to `audit_logs` with: which user, which action, which record, and timestamp. This provides a full accountability trail.

**Incremental migrations** — The schema is built through **59 numbered SQL migration files** (`001`–`059`), applied in order (`run_all.sql` is the bootstrap). Each migration is additive or guarded. This allows the schema to evolve safely.

**Normalized ID numbers** — ID numbers are stored as uppercase alphanumeric only (dashes and spaces stripped). This prevents verification mismatches when the same ID is scanned with/without dashes.

**Unique person index** — `(UPPER(full_name), birthdate, beneficiary_type)` must be unique (partial index: only when status ≠ 'revoked'). This prevents duplicate registrations while allowing re-registration after revocation.

**id_number expression index** — `UPPER(REGEXP_REPLACE(id_number, '[^A-Za-z0-9]', '', 'g'))` — ensures fast normalized lookups.

---

## 11. Security Features

### Authentication

- **Staff (Web Portal)**: JWT signed with `JWT_SECRET_STAFF`, 8-hour session. The client silently refreshes the token when fewer than 5 minutes remain, so no re-login is needed during normal use. Refresh stops at the **8-hour absolute limit** (`STAFF_ABSOLUTE_SESSION_SECONDS`), after which the user is sent to `/login?reason=absolute`.
- **Establishments (Mobile)**: JWT signed with `JWT_SECRET_ESTABLISHMENT`, lifetime from `JWT_EXPIRES_IN`. There is **no refresh path**; a user re-logs in when the token expires. This is a known limitation (§16).
- **Beneficiaries (Mobile)**: OTP for first-time or quick login (ID number + DOB → OTP by SMS); returning users log in with a **4-digit PIN** (3 failed attempts → 30-minute lockout) or biometric (`local_auth`). A JWT signed with `JWT_SECRET_BENEFICIARY` is issued for the session.
- **Step-up authentication**: sensitive actions (full ID reveal, CSV/PDF audit reports) require a short-lived **5-minute step-up token** (`X-Step-Up-Token`, enforced in `middleware/stepUp.js`).
- Each actor type has its **own signing secret**, so a token issued for one type (e.g., establishment) cannot be reused to authenticate as another (e.g., staff).

### Account Lockout

- **3 failed login attempts lock the account for 30 minutes** for staff, establishment, and beneficiary PIN logins (`auth.js` lines 22–23). Lockouts and unlocks are audit-logged.

### Password and PIN Hashing

- Passwords are hashed with **bcryptjs, 12 rounds** (staff, establishment, and beneficiary passwords).
- OTP codes and PINs are hashed with **bcryptjs, 10 rounds**.
- Staff can change their own password; admins can reset staff passwords.

### Rate Limiting

- Scan endpoint: 60 requests/minute per establishment.
- Fraud flag endpoint: 30 requests/hour per establishment.
- Login endpoints: 10 requests per 15 minutes per IP.
- Prevents automation attacks.

### Session Inactivity Timeout

- **Web portals**: 15-minute idle timeout, 2-minute countdown warning before automatic logout (`useSessionTimeout.js`).
- **Establishment mobile app**: 15-minute idle timeout with a warning before logout.
- **Beneficiary mobile app**: locks after **5 minutes** of inactivity and requires the PIN or biometric to resume. Verified in code; device acceptance testing is pending.
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

- The camera, card detection, and on-device OCR (ML Kit and Tesseract run on the phone) do not need internet.
- Viewing scan history stored locally in SQLite.
- Checking the **offline blocklist** (revoked and suspended IDs only).

### Offline Blocklist and Scan Replay

- The status sync poll (every 8 seconds, with a `since` cursor) keeps the Hive box `blocked_ids` current. It stores only **revoked and suspended** IDs, keyed by SHA-256 hash (`local_database.dart`).
- A scanned ID on the blocklist is rejected instantly on the device. A cache miss or active status is **never** approved locally; it goes to the server (`api_service.dart`, `verifyId`).
- When the network fails (`SocketException`, `TimeoutException`, or `ClientException`), the scan is saved to the replay queue (`pending_offline_scans_v2`) and the cashier sees **MANUAL_REVIEW** with `isOffline: true`. An offline result is **never VALID**.
- `OfflineScanSyncService` replays queued scans when connectivity returns, sending `offline_queued: true`, `client_scan_id`, and `scanned_at`. The server accepts these fields (migration `056_add_offline_scan_replay_columns.sql`). After 5 failures, a staff alert is raised.
- There is **no 6-hour cache TTL and no "[OFFLINE — synced X min ago]" banner.** Do not describe either.

### Offline Fraud Flag Queue

- Fraud flags submitted while offline are stored in a local queue (`FraudFlagSyncService`, initialized in `main.dart`).
- When connectivity is restored, the queue syncs the flags to the server.

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

### Expiry Alerts

- The expiry scheduler (`expiryAlertScheduler.js`) runs **every 24 hours** using `setInterval`.
- It alerts at **30, 7, and 1 days** before expiry. Each alert writes a `notifications` row and sends an FCM push.
- The portal shows an "expiring soon" banner for IDs within 30 days (red at 7 days or fewer).

### Notification Types Added Later

- `callback_request_handled` (migration 055): establishment callback requests.
- `fraud_report_received` (migration 057): staff are notified of new fraud reports.

### Foreground Notifications (In-App)

When the beneficiary app is in the foreground, Android doesn't show push notifications in the status bar automatically. The app listens for incoming FCM messages and shows a floating **SnackBar banner** at the bottom of the screen for 5 seconds.

---

## 14. Admin Portal Features

### All Three Portals Share

- **Dashboard** with analytics (fraud flags by status, verification trends, 14-day bar chart).
- **Audit Logs** — paginated view with search, date range, and action-category filters. CSV export (requires step-up).
- **Reports** — downloadable CSV exports for verification logs, fraud flags, and disputes.
- **Staff Management** — list, create, edit, activate/deactivate staff accounts. Reset passwords. Role changes are audit-logged (`staff_role_changed`).
- **Session Timeout** — 15-minute inactivity auto-logout with countdown warning.
- **Breach Report Generator** — NPC-formatted incident report (RA 10173; 72-hour NPC notification reminder), downloaded as `.txt`.

### OSCA Portal (Senior Citizen Specific)

- Beneficiary list/add/edit/bulk-import (senior citizens only).
- Expiring-soon banner (IDs expiring within 30 days — red if ≤7 days).
- Fraud Flags with captured ID card image viewer (authenticated).
- Disputes from senior citizen beneficiaries.

### PDAO Portal (PWD Specific)

- Same as OSCA but for PWD records.
- Disability type field on all beneficiary records (11 types in the portal's standard list, `disabilityTypes.js`; persisted from migration 011). Do not say the list is "per Philippine law" unless you have cited the law.
- Same fraud flag viewer and dispute handling.

### BPLO Portal

- Establishment account management (approve, suspend, revoke).
- Establishment registration: a **public API endpoint** (`POST /api/establishments/register`) creates an account in `pending` status, and BPLO approves it. We could not find a registration form in the web or mobile UI, so describe it as an API capability unless a UI is shown.
- Bulk credential generation for approved establishments. Credentials are returned **once**, through a 15-minute in-memory token that is lost on server restart. This is a limitation (§16).
- Verification activity for all ID types.
- Business refusal disputes.
- Manual entry badge in verification history (flags entries made without scanning).

---

## 15. Beneficiary Mobile App

A **separate Flutter app** from the establishment app (different package name: `idetect_beneficiary`).

### Authentication Flow

```
ID Number + Date of Birth
    → First-time or quick login: OTP sent via SMS → OTP verified → JWT issued
        → If no mobile registered: prompted to enter mobile number first
    → Returning user with a PIN: 4-digit PIN → JWT issued
        → 3 wrong PINs → 30-minute lockout
    → Biometric (fingerprint) login, where enabled on the device
    → App lock: after 5 minutes in the background, the app asks for PIN or biometric again
```

### Features

- **Status Tab** — shows current ID status (active/expired/suspended/revoked) with color badge.
- **History Tab** — list of all times their ID was scanned (verification logs).
- **Disputes Tab** — submit new disputes (with optional photo attachment), track existing disputes.
- **Language** — English and Filipino ARB files exist (`app_en.arb`, `app_fil.arb`). Translation coverage has not been audited, so do not claim full bilingual support.

### Push Notifications

- Device FCM token registered on login.
- Foreground notifications appear as a blue floating SnackBar banner.
- Background/killed notifications appear as standard Android notifications.
- Push delivery depends on the device token and Firebase setup. The demo should show it working on a real device before the defense.

---

## 16. Limitations You Should Acknowledge Honestly

Panelists respect honesty. Know these limitations and how you would address them:

### 1. Confidence Score Is Heuristic

The confidence value in the secondary `EnhancedOcrService` path is computed from keyword-presence bonuses, not Tesseract's per-character confidence API. The live scan path relies on ML Kit's text output plus layout and validation checks. **What you'd say:** "We use it as an extraction quality indicator. In future work, we would use Tesseract's HOCR output for true character-level confidence."

### 2. No Measured OCR Accuracy

We did not run a structured accuracy evaluation (labeled test set, precision and recall per field). Earlier drafts quoted "95–98%" and "85–90%" figures; **those were not measured and must not be quoted.** **What you'd say:** "A labeled OCR evaluation is the next step, and we are being upfront that it is not yet done."

### 3. Zone Coordinates Are Hardcoded for One Card Design

The layout-based extractor uses fixed percentage coordinates calibrated for the current Valenzuela OSCA card. If the card design changes, zones need recalibration. **What you'd say:** "The system is designed for the specific card formats used by Valenzuela City. A template versioning system is a planned improvement."

### 4. SMS OTP Requires Semaphore Credits

The Semaphore SMS integration is coded and working, but the account needs approved sender name and SMS credits for live use. OTPs are always logged to the API console for testing. **What you'd say:** "The integration is complete. We need the sender name 'iDetect' to be approved by Semaphore and credits loaded for full SMS delivery."

### 5. Automated Tests Cover the API Only

The API has **31 Jest suites with 181 tests, all passing**. The Flutter apps have only a few test files, and the web portal has no automated suite. Most end-to-end checks were manual. **What you'd say:** "The backend logic is covered by 181 automated tests. Mobile and portal UI testing was manual, and broader automated UI coverage is a next step."

### 6. Large Imports Are Synchronous

Bulk beneficiary imports are capped at **20,000 rows** (`BENEFICIARY_IMPORT_MAX_ROWS`) and processed synchronously in 500-row chunks. A progress bar is shown, but there is no background job queue. **What you'd say:** "For production scale, we would move large imports to a background job (e.g., a queue with Redis) with real-time progress."

### 7. Bilingual Support Is Partial

The beneficiary app has English and Filipino ARB files (`app_en.arb`, `app_fil.arb`). Translation coverage across every screen has not been audited. **What you'd say:** "The app is bilingual in English and Filipino. We have not yet audited every string for translation completeness."

### 8. Offline Verification Is Limited

Offline checks use a **blocklist of revoked and suspended IDs**, not a full cache. Offline results are MANUAL_REVIEW and are never VALID. **What you'd say:** "Offline mode prevents an approval on stale data. It can block known-bad IDs, but a cashier still has to check the card physically."

### 9. A Physical Counterfeit Check Is Not Performed

The system verifies the printed text and the database record. It does not check card security features (holograms, print), so a clear photocopy of a valid card could be read and matched. **What you'd say:** "iDetect is a database and identity cross-check tool. Physical authenticity still depends on the cashier's inspection, and that is why SUSPICIOUS and MANUAL_REVIEW exist."

### 10. Establishment Sessions Have No Refresh

Establishment JWTs use `JWT_EXPIRES_IN` and have no refresh path, so users re-login after expiry. Staff tokens do refresh (§11).

### 11. Bulk-Import Credential Tokens Are In Memory

Credential download tokens are held in server memory with a 15-minute TTL. A server restart invalidates pending tokens, and the credentials must be regenerated. **What you'd say:** "This is a known limitation for a single-instance deployment. Persisting the tokens in the database would fix it."

### 12. The Face Check Is a Heuristic

The ML Kit face check is a warning, not a gate. The cashier can continue after the warning. **What you'd say:** "It is a guard against obviously wrong photos, not a biometric check."

### 13. Some Code Is Not on the Live Path

`OpenCVImageProcessor.preprocess()` and `assessQuality()` are implemented but unused by the live scan. Be ready to say this if asked about "the 10-step pipeline."

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

**A:** We use two OCR engines in one pipeline, not a race between them. Google ML Kit is the primary engine on the colour image, and it returns text with bounding boxes that drive layout-based extraction. Tesseract re-reads only the fields ML Kit could not validate, on an enhanced grayscale copy. We chose this so that the layout information from ML Kit is kept, and Tesseract is used where it helps. **We have no measured accuracy numbers for either engine, so do not quote any.** If asked, say that a labeled accuracy evaluation is the next step.

---

### Q: What is CLAHE and why did you use it?

**A:** CLAHE stands for Contrast Limited Adaptive Histogram Equalization. It improves local contrast by working on small regions rather than the whole image, which suits ID cards with uneven light. It is implemented in `OpenCVImageProcessor.preprocess()`, but that method is **not on the live scan path**. If asked, say the live path relies on card normalization and ML Kit's layout detection, and that the CLAHE chain is not used in the current build. Confirm the reason with your team before the defense.

---

### Q: How does the system prevent someone from using a fake ID?

**A:** Three database checks, plus a physical check by the cashier:

1. The ID number must exist in the official LGU database (uploaded by OSCA/PDAO staff).
2. The name extracted by OCR must match the database name with ≥0.80 Jaro-Winkler similarity.
3. The date of birth extracted by OCR must exactly match the database record.

If any of these fail, the result is SUSPICIOUS or MANUAL_REVIEW, not VALID. The card photo is stored with a fraud flag when the cashier flags a scan, which creates an evidence trail for the admin. Routine scans do not store the card image.

---
### Q: What is Jaro-Winkler and why did you choose it for name matching?

**A:** Jaro-Winkler is a string similarity algorithm that measures how similar two strings are, scoring from 0.0 (completely different) to 1.0 (identical). We chose it for name matching because:

1. OCR commonly produces minor errors (a letter misread, a space added/removed).
2. It gives extra weight to characters at the beginning of strings — which is useful for names since first characters are usually read correctly.
3. It handles common OCR substitutions (e.g., "REYES" vs "REVES") better than exact matching.
   We set the threshold at 0.80 — if the similarity score is below 0.80, the system considers it a potential name mismatch and downgrades the result to SUSPICIOUS.

---

### Q: How does the fraud auto-suspension work?

**A:** When a fraud flag is submitted, the system counts how many distinct (different) establishments have flagged that same ID. If that count reaches 3 (`AUTO_SUSPEND_FLAG_THRESHOLD`), the system automatically suspends the beneficiary and changes their status to `suspended`. This requires at least 3 separate businesses to independently flag the same ID, reducing the chance of a single malicious actor abusing the flag system. The beneficiary receives a notification record (channel `push`), and the action is recorded for LGU admins. Automatic restoration applies only to system suspensions.

---

### Q: How is user data protected?

**A:** Multiple layers:

- Passwords are hashed with bcrypt (12 rounds). Beneficiary PINs and OTPs are hashed with bcrypt (10 rounds).
- JWTs are signed with separate secrets for staff, establishment, and beneficiary actors.
- Role-based access: OSCA can only access senior citizen data, PDAO can only access PWD data.
- ID card images are not publicly accessible — only authenticated staff can retrieve them.
- Inputs are validated with express-validator. Do not claim more than this without checking the query layer.
- Staff and establishment sessions time out after 15 minutes of inactivity. Staff sessions also have an 8-hour absolute limit. The beneficiary app locks after 5 minutes.
- Login is rate-limited (10 attempts per 15 minutes), and accounts lock after 3 failed password attempts for 30 minutes.
- Significant actions are logged in the audit_logs table.

---

### Q: What happens when the phone has no internet connection?

**A:** The phone keeps a local copy of blocked IDs (a Hive blocklist, keyed by SHA-256 hash). Offline, the app rejects a scan only if the ID is on that list. Any other ID is returned as MANUAL_REVIEW with an `isOffline` flag, never as VALID. The scan is saved to a local replay queue, and the queue syncs to the server when connectivity returns. Offline fraud flags are queued the same way. The offline blocklist depends on the last sync, so it can be out of date. This is a limitation we state openly (§16).

---

### Q: What is a dispute and how does it work?

**A:** A dispute is submitted by a beneficiary through their mobile app when they disagree with a verification outcome or want to report an issue. There are five types: wrong denial, unauthorized use of their ID, a business refusing them despite a valid result (`business_refusal`), incorrect information in their record, and `other`. The workflow statuses are submitted → acknowledged → under_review → resolved or rejected. SLA timers run every 30 minutes: acknowledgement is due in 24 hours and resolution in 72 hours. Escalation notifications are sent when the deadline is missed. BPLO sees only `business_refusal` disputes.

---

### Q: Why is there one staff portal instead of separate ones per office?

**A:** Data compartmentalization and role separation are enforced through RBAC rather than through physically separate deployments. OSCA staff should never see PWD records, and PDAO staff should never see senior citizen records — these are different LGU offices with different legal mandates. BPLO handles establishment management, not beneficiary data. The staff portal is a single deployed web app at one URL; after login, each account is routed to the dashboard matching its role, and the API enforces that a token for one role cannot fetch another role's data. This keeps one codebase/deployment to maintain while still guaranteeing the same access boundaries as separate portals would.

---

### Q: How does the establishment registration work?

**A:** Establishments are created by BPLO staff in the staff portal, and the mobile app then uses the credentials. The API also has a public self-registration endpoint (`POST /api/establishments/register`). We found no self-registration form in the web or mobile UI, so do not describe a self-service form unless it is demonstrated. Credentials are issued through a short-lived 15-minute download token. The token is held in server memory, so it is lost if the server restarts. Do not describe it as a one-time CSV link unless you have verified that behavior.

---

### Q: What is the audit log and why is it important?

**A:** The audit log records significant actions: logins, lockouts, beneficiary changes, establishment status changes, fraud flag reviews, role changes, and audit exports. Each row has the actor, action, the affected record, and timestamp. It supports accountability for a government system. The breach report feature produces a `.txt` report from the same records. We do not claim it meets a specific legal standard unless you have checked the requirement yourself.

---

### Q: How does the beneficiary log in to the mobile app?

**A:** The beneficiary app uses the ID number and date of birth first. Then:

- **First-time or quick login:** an OTP is sent by SMS to the registered mobile number, and the OTP completes login.
- **Returning user with a PIN:** a 4-digit PIN completes login. Three wrong PINs lock the account for 30 minutes.
- **Biometric:** fingerprint login, where the device supports it.

The app also locks after 5 minutes in the background.

---

### Q: What are the system's limitations?

**A:** The main ones are in §16. In short: the OCR confidence score is a keyword heuristic, not a measured accuracy. We have no labeled OCR accuracy evaluation. Zone coordinates for Tesseract re-reads are hardcoded for the current Valenzuela card design. SMS OTP needs an approved sender name and loaded credits. Bulk imports are synchronous and capped at 20,000 rows by default. Bilingual coverage is partial. Offline mode can only reject IDs already on the local blocklist. The system does not check physical security features, so a photocopy may not be caught; we have not tested this. The establishment token has no refresh path.
---

### Q: How did you handle the case where a PWD ID is accidentally scanned as a Senior Citizen ID?

**A:** The system has cross-database conflict detection. When a scan returns INVALID because the ID was not found in the selected type's database, the API also checks the other database. If the ID is found there, it returns SUSPICIOUS instead of INVALID, signals a cross-type mismatch, and inserts fraud flags in both the OSCA and PDAO portals so both offices are aware. The new auto-detect feature also helps prevent this — it identifies the card type from keywords found on the card by OCR (`detectCardType`).
---

### Q: What database did you use and why PostgreSQL?

**A:** PostgreSQL, hosted on Supabase (accessed via its connection pooler). We chose it because:

- It supports **enum types**, which enforce valid values at the database level (no invalid statuses possible).
- It supports **JSONB** for flexible metadata storage in audit logs.
- It supports **expression indexes** (a unique index on the normalized ID number, migration 021).
- It supports **partial indexes** (the unique person constraint excludes revoked records, migration 025).
- It's production-grade, ACID-compliant, and well-supported by the `pg` library in Node.js.
- Supabase provides managed hosting, automatic backups, and doubles as the object storage for ID/dispute images.

---

### Q: How many functional requirements did you implement?

**A:** The functional requirements are in the April 2026 matrix, `documentation/FUNCTIONAL_REQUIREMENTS_REVIEW_GUIDE.md`. We have not confirmed the exact total in this review, so count it from that matrix before the defense and quote that number. For each requirement, state its status honestly: implemented, partially implemented, or not implemented. Bilingual support is partial: English and Filipino ARB files exist, but translation coverage has not been audited, so do not claim full bilingual support.

---

## 18. Numbers and Metrics to Know

| Metric                                     | Value                                                                                             |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| Live OCR engines                           | ML Kit (primary, colour image) + Tesseract (zone re-reads, grayscale)                             |
| OCR accuracy                               | Not measured. Do not quote a figure.                                                              |
| Live card preprocessing                    | `normalizeCard` (OpenCV). The CLAHE chain in `preprocess()` is not on the live path.              |
| Database tables                            | Confirm with `\dt` before the defense. Not counted in this review.                                |
| Database migrations                        | 59 numbered files (001–059), plus `run_all.sql` and `dev_seed.sql`                                |
| Name match threshold                       | 0.80 Jaro-Winkler (`OCR_NAME_MATCH_THRESHOLD`). A mismatch returns SUSPICIOUS.                    |
| Auto-suspend threshold                     | 3 distinct establishments (`AUTO_SUSPEND_FLAG_THRESHOLD`)                                         |
| Flag decay period                          | 180 days (pending flags)                                                                          |
| Dispute types                              | 5 (including `other`)                                                                             |
| Dispute acknowledgment SLA                 | 24 hours                                                                                          |
| Dispute resolution SLA                     | 72 hours                                                                                          |
| SLA escalation check interval              | Every 30 minutes                                                                                  |
| Scan rate limit                            | 60 per minute per establishment                                                                   |
| Status sync rate limit                     | 120 per minute per establishment                                                                  |
| Fraud flag rate limit                      | 30 per hour per establishment                                                                     |
| General API rate limit                     | 100 per 15 minutes per IP. Login: 10 per 15 minutes.                                              |
| Staff session inactivity timeout           | 15 minutes, with a 2-minute warning                                                               |
| Staff absolute session limit               | 8 hours (`STAFF_ABSOLUTE_SESSION_SECONDS`)                                                        |
| Staff JWT refresh trigger                  | Under 5 minutes before expiry                                                                     |
| Establishment mobile session timeout       | 15 minutes (no JWT refresh path)                                                                  |
| Beneficiary app lock                       | 5 minutes in the background                                                                       |
| Account lockout                            | 3 failed attempts → 30 minutes (passwords and beneficiary PINs)                                   |
| Password hashing                           | bcrypt, 12 rounds (PINs and OTPs: 10 rounds)                                                      |
| Step-up token                              | 5 minutes                                                                                         |
| Offline cache TTL                          | None. Offline mode uses the blocklist and replay queue only.                                      |
| Bulk import max rows                       | 20,000 (`BENEFICIARY_IMPORT_MAX_ROWS`)                                                            |
| Bulk import chunk size                     | 500 rows per SQL INSERT                                                                           |
| Web app                                    | 1 staff web app (`apps/web`) with 3 role-based portals (OSCA, PDAO, BPLO)                         |
| Flutter apps                               | 2 (Establishment, Beneficiary)                                                                    |
| Disability types recognized                | 11 canonical types                                                                                |
| Staff roles                                | osca_admin, pdao_admin, bplo_admin, plus super-admin roles (migrations 038–039)                   |
| SLA escalation check interval              | Every 30 minutes                                                                                  |
| Expiry alerts                              | 30, 7, and 1 days before expiry, checked every 24 hours (`setInterval`)                           |
| Flag decay scheduler                       | Every 24 hours (`setInterval`)                                                                    |
| Credential token TTL                       | 15 minutes, held in server memory                                                                 |
| Automated API tests                        | 31 Jest suites, 181 tests, all passing (API only). Flutter tests were not run for this review.    |

---

## 19. Mock Panel — Hard Questions and Honest Answers

These are the questions a strict panel is most likely to press on. For each one, answer what the system actually does, then state the limitation. Do not defend a claim the code does not support.

### 1. "How do you know the OCR works? What is the accuracy?"

**Answer:** We have no measured OCR accuracy for either engine, so we will not quote a figure. OCR is one input. A scan is valid only when the ID exists in the LGU database and the name and date of birth agree with it. A labeled evaluation on a sample of cards is the next step.

### 2. "Would a photocopy of a valid card pass?"

**Answer:** The system checks the printed text against the database. It does not check security features such as holograms or print patterns. A photocopy could be read and matched, and we have not tested this. The cashier's physical check remains part of the process. Future work: a QR or other machine-readable security element on the card.

### 3. "Can a revoked or suspended card be used offline?"

**Answer:** Only if its status is already on the phone's blocklist from the last sync. A card revoked after the last sync is not blocked offline. An offline scan never returns VALID. It returns MANUAL_REVIEW with an offline flag and goes to the replay queue. This is a real limitation, and we state it openly.

### 4. "Why do you keep ID images? Is this compatible with privacy law?"

**Answer:** Card images are stored with fraud flags, in a private storage bucket (`id-captures`), and staff retrieve them only when authenticated. Routine scans do not store the card image. We do not claim legal compliance. The breach report feature supports incident handling. A formal retention policy and a privacy impact assessment are outside what we verified, so say so if asked.

### 5. "Could an establishment wrongly suspend a senior citizen?"

**Answer:** Yes, in principle. Auto-suspension needs three distinct establishments to flag the same ID. Pending flags decay after 180 days. Staff review flags, and automatic restoration applies only to system suspensions. Malicious or mistaken flags are a risk we acknowledge.

### 6. "Is the Firebase service key in the repository?"

**Answer:** It is kept locally and listed in `.gitignore`, so it is not committed. Before the defense, confirm with `git ls-files` that no key file is tracked. Never show the key on screen.

### 7. "Your establishment app has no token refresh. Why?"

**Answer:** The establishment JWT uses a fixed lifetime (`JWT_EXPIRES_IN`) and has no refresh path. The mobile app's 15-minute inactivity timeout signs the user out. This is a known gap, and the fix is to add a refresh flow.

### 8. "What happens to credential download tokens if the server restarts?"

**Answer:** They are held in server memory with a 15-minute TTL, so they are lost on restart. The admin must generate them again. This is a known limitation of the current design.

### 9. "You described a ten-step preprocessing pipeline. Is it used?"

**Answer:** No. The live path uses card normalization, ML Kit with bounding boxes, and Tesseract zone re-reads. The CLAHE and assessment methods in `OpenCVImageProcessor` are not called from the live flow. Do not describe them as part of the live system.

### 10. "What does the confidence score mean?"

**Answer:** It is a keyword-based heuristic. It is not calibrated and is not a probability. It is used to order and flag results, not as a measured confidence.

### 11. "How reliable is the face check?"

**Answer:** It is a heuristic guard on the scan screen. The cashier can continue past it. We do not claim it detects fake photos.

### 12. "Your survey only has 37 respondents. Is that enough?"

**Answer:** The sample is small and uneven across groups: 3 IT experts, 20 establishment staff, 4 OSCA/PDAO staff, and 10 beneficiaries. The BPLO survey was not done. Present the results as indicative, and name the sample limits before the panel does.

### 13. "How much of the system is tested?"

**Answer:** The API has 31 Jest suites and 181 tests, all passing. The Flutter tests (4 files) were not run for this review, and the web app has no test script. State these numbers exactly.

### 14. "Can this run at real LGU scale?"

**Answer:** The bulk import is synchronous and capped at 20,000 rows by default, in 500-row chunks. Load testing has not been done. Hosting is Vercel (web), Northflank (API), and Supabase (database and storage). Scale is a future-work item, not a proven claim.

### 15. "Why is the establishment self-registration not in the UI?"

**Answer:** The API exposes a public registration endpoint, but we did not find a form in the web or mobile UI. Establishments are normally created by BPLO staff. Do not describe a self-service form unless you demonstrate one.

### 16. "What if a new card design appears?"

**Answer:** The Tesseract zone coordinates are hardcoded for the current Valenzuela card design. A new design needs recalibration. The ML Kit layout path is less dependent on fixed zones, but it is not zone-free.

---

## 20. Defense Day Plan

### Before the day

- Run the full demo twice, end to end, on the same devices you will use.
- Wake the API before the session. Northflank may cold-start, so send a test request to the API and load the staff portal login page about 10 minutes early.
- Charge two Android devices. Install the beneficiary app and the establishment app. Log in to each with test accounts only.
- Prepare printed or on-screen test cards using dev seed data. Do not use real residents' personal data on slides or screens.
- Log in to the staff portal in two separate browser profiles, one for an OSCA account and one for a PDAO account, so role switching is quick.
- Keep a recorded screen video of the full demo as a backup.
- Keep one device in airplane mode with an already-synced blocklist, for the optional offline demo.

### Demo script (about 8 minutes)

1. **Establishment app:** log in, then scan a valid senior citizen card. Show VALID, the verification log, and the reference number.
2. **Cross-type case:** scan a PWD card under the senior citizen type. Show SUSPICIOUS, and explain the cross-database check.
3. **Fraud flag:** flag a card from the app. Show the flag in the staff portal, and explain the 3-establishment threshold.
4. **Beneficiary app:** log in with OTP or PIN, show the status tab, and submit a dispute.
5. **Staff side:** show the dispute, its SLA timer, and the status workflow. Show the audit log entry.
6. **Optional offline scan:** show MANUAL_REVIEW with the offline flag, and explain the replay queue.

### Roles

- **Presenter:** tells the story and leads the demo.
- **Demo operator:** runs the devices and portal, and has the backup video ready.
- **Q&A lead:** answers the technical questions, including §19.
- **Limits owner:** answers questions about OCR accuracy, testing, and privacy, using §16 and §21.

### Do not overclaim

- OCR accuracy figures (none were measured).
- Full bilingual support.
- Legal compliance with the Data Privacy Act.
- Physical counterfeit detection.
- Establishment self-registration in the UI, unless demonstrated.
- The ten-step preprocessing pipeline as part of the live system.

---

## 21. Verification Log and Pre-Defense Checklist

### What was verified in this revision

- The API Jest suite was run: **31 suites, 181 tests, all passing**.
- Claims in §§3–16 were checked against the code. Each correction cites a file, and the main ones are listed in the table below.
- The web app has no test script. The Flutter tests were not run in this revision.

### Main corrections from the May 20 version

| Area                        | Earlier claim                                 | Verified state                                                                  |
| --------------------------- | --------------------------------------------- | ------------------------------------------------------------------------------- |
| OCR                         | Two engines raced; accuracy 95–98% / 85–90%   | ML Kit primary, Tesseract zone re-reads; no measured accuracy                   |
| Preprocessing               | Ten-step pipeline                             | `normalizeCard` live; CLAHE chain unused                                        |
| Offline                     | 6-hour cache with a banner                    | Blocklist and replay queue only; never VALID offline                            |
| Account lockout             | 5 attempts, 15 minutes                        | 3 attempts, 30 minutes                                                          |
| Database migrations         | 25                                            | 59 numbered files                                                               |
| Hosting                     | Single combined service                       | Vercel (web), Northflank (API), Supabase (database and storage)                 |
| Dispute types               | 4                                             | 5 (`other` added in migration 034)                                              |
| Expiry alerts               | Daily cron                                    | 30, 7, and 1 days, `setInterval` every 24 hours                                 |
| Credential tokens           | One-time CSV link                             | 15-minute in-memory token                                                       |

### Open items before the defense

- [ ] Run `\dt` on the live database and update the table count (§18).
- [ ] Count the functional requirements from `documentation/FUNCTIONAL_REQUIREMENTS_REVIEW_GUIDE.md` and state the total and status for each one.
- [ ] Check the IMRaD abstract against the table. The abstract's "Moderate" list does not match the starred cells (Recoverability 2.67 and 3.00).
- [ ] Disclose that the BPLO survey was not done.
- [ ] Confirm that establishment self-registration has no UI. Otherwise, demonstrate it.
- [ ] Confirm whether Northflank auto-deploys from `main`.
- [ ] Check the Android minimum SDK in the Flutter Android build file and add it to the manual.
- [ ] Run the Flutter tests (4 files) and record the result.
- [ ] Test a photocopied card and record what happens.
- [ ] Audit the bilingual ARB coverage, or state that it is partial.
- [ ] Update `documentation/DEPLOYMENT_GUIDE.md`. It still describes the old combined service. This needs your decision before editing.
- [ ] Refresh the readiness table in `documentation/RESEARCH_ADVISER_CRITIQUE.md`, which is stale. Open items: M-1, M-5, R-2, the face-guard heuristic, photocopy-as-VALID, and the establishment JWT refresh.
- [ ] Add screenshots to the user manual and replace the support contact placeholder.
- [ ] Confirm that `apps/web/.env.local` and the Firebase key are not tracked by git.

---

## Quick Reference: Key File Locations

| Feature                              | Key File                                                                       |
| ------------------------------------ | ------------------------------------------------------------------------------ |
| OCR pipeline (live)                  | `lib/services/hybrid_parser_service.dart`                                      |
| Scan flow, timeout, face guard       | `lib/presentation/screens/scan/processing_screen.dart`                         |
| Secondary OCR (heuristic confidence) | `lib/services/enhanced_ocr_service.dart`                                       |
| Card normalization (live)            | `lib/services/opencv_image_processor.dart`                                     |
| Field extraction                     | `lib/services/parser_service.dart`                                             |
| Auto-detect card type                | `lib/services/hybrid_parser_service.dart` (`sniffCardType`, `detectCardType`)  |
| Verification API                     | `apps/api/src/routes/verification.js`                                          |
| Fraud flags API                      | `apps/api/src/routes/fraudFlags.js`                                            |
| Disputes API                         | `apps/api/src/routes/disputes.js`                                              |
| Notifications API                    | `apps/api/src/routes/notifications.js`                                         |
| Beneficiary portal API               | `apps/api/src/routes/beneficiaryPortal.js`                                     |
| Rate limits and exemptions           | `apps/api/src/app.js`                                                          |
| SLA escalation scheduler             | `apps/api/src/services/slaEscalationScheduler.js`                              |
| Flag decay scheduler                 | `apps/api/src/services/flagDecayScheduler.js`                                  |
| Offline blocklist (Hive)             | `lib/data/datasources/local/local_database.dart`                               |
| Offline replay queue                 | `lib/services/offline_scan_sync_service.dart`                                  |
| Session timeout (staff web)          | `apps/web/src/hooks/useSessionTimeout.js`                                      |
| Session timeout (establishment app)  | `lib/services/session_timeout_service.dart`                                    |
| Session timeout (beneficiary app)    | `apps/beneficiary/lib/services/session_timeout_service.dart`                   |

---

_Good luck tomorrow. You built something genuinely impressive — a full-stack, multi-platform government system with OCR, fraud detection, dispute management, and real security practices. Be confident — you know this system better than anyone in that room._
