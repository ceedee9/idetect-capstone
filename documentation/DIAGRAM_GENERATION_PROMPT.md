# iDetect System — Diagram Generation Prompt

**Purpose:** Upload this entire file to Claude to generate PlantUML diagrams for Chapter 3.
**Diagrams needed:** Context Diagram, Data Flow Diagram (DFD), Use Case Diagram, Entity Relationship Diagram (ERD), Activity Diagram.
**Format:** Generate all diagrams as PlantUML code so they can be imported into draw.io (diagrams.net supports PlantUML import under Extras > Edit Diagram).

---

## SYSTEM OVERVIEW

**System Name:** iDetect — OCR-Based Discount ID Verification System
**Location:** Valenzuela City, Philippines
**Purpose:** Allows food service establishments (sari-sari stores, restaurants, pharmacies, etc.) to verify whether a Senior Citizen ID or PWD (Person with Disability) ID is legitimate before granting mandatory government discounts. This replaces manual checking, which is prone to fraud and human error.

### System Actors

| Actor                             | Description                                                                                 | Interface Used                            |
| --------------------------------- | ------------------------------------------------------------------------------------------- | ----------------------------------------- |
| **Establishment Staff** (Cashier) | Employee at a food service business who scans IDs during transactions                       | Mobile App (Flutter, Android)             |
| **Beneficiary**                   | Senior Citizen or PWD who presents their ID at a business                                   | Beneficiary Mobile App (Flutter, Android) |
| **BPLO Admin**                    | Bureau of Permits and Licensing Office — manages establishment accounts                     | Web Portal (React)                        |
| **OSCA Admin**                    | Office for Senior Citizen Affairs — manages Senior Citizen records and fraud investigations | Web Portal (React)                        |
| **PDAO Admin**                    | Persons with Disability Affairs Office — manages PWD records and fraud investigations       | Web Portal (React)                        |
| **iDetect System**                | Central system: Node.js/Express API + PostgreSQL database                                   | Backend only                              |

### External Services

- **FCM (Firebase Cloud Messaging):** Push notifications to the Beneficiary App
- **Semaphore SMS:** SMS notifications to registered mobile numbers

---

## DATABASE SCHEMA (Complete — use for ERD)

### Table: `users`

Stores staff/admin accounts for all three LGU web portals.

```
users
- id: UUID (PK)
- email: VARCHAR(255) UNIQUE NOT NULL
- password_hash: VARCHAR(255) NOT NULL
- full_name: VARCHAR(255) NOT NULL
- role: ENUM('bplo_admin', 'osca_admin', 'pdao_admin') NOT NULL
- is_active: BOOLEAN NOT NULL DEFAULT true
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ
```

### Table: `establishments`

Business accounts created and managed by BPLO. One account per food service establishment.

```
establishments
- id: UUID (PK)
- email: VARCHAR(255) UNIQUE NOT NULL
- password_hash: VARCHAR(255) NOT NULL
- business_name: VARCHAR(255) NOT NULL
- business_permit_no: VARCHAR(100) UNIQUE NOT NULL
- owner_name: VARCHAR(255) NOT NULL
- address: TEXT NOT NULL
- contact_number: VARCHAR(20) NOT NULL
- business_type: VARCHAR(100) NOT NULL
- status: ENUM('pending', 'approved', 'suspended', 'revoked') NOT NULL DEFAULT 'pending'
- approved_by: UUID (FK → users.id) NULLABLE
- approved_at: TIMESTAMPTZ
- suspended_reason: TEXT
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ
```

### Table: `beneficiaries`

Official government records for Senior Citizens and PWDs. OSCA manages senior_citizen rows; PDAO manages pwd rows.

```
beneficiaries
- id: UUID (PK)
- id_number: VARCHAR(50) UNIQUE NOT NULL   ← The ID number printed on the physical card
- full_name: VARCHAR(255) NOT NULL
- birthdate: DATE NOT NULL
- beneficiary_type: ENUM('senior_citizen', 'pwd') NOT NULL
- issuing_office: VARCHAR(255) NOT NULL
- validity_start: DATE NOT NULL
- validity_end: DATE NOT NULL
- status: ENUM('active', 'expired', 'suspended', 'revoked') NOT NULL DEFAULT 'active'
- status_reason: TEXT
- registered_mobile: VARCHAR(20)
- created_by: UUID (FK → users.id) NULLABLE
- updated_by: UUID (FK → users.id) NULLABLE
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ
```

### Table: `beneficiary_accounts`

Mobile app accounts for beneficiaries. A beneficiary exists in the system even without an app account.

```
beneficiary_accounts
- id: UUID (PK)
- beneficiary_id: UUID UNIQUE NOT NULL (FK → beneficiaries.id, CASCADE DELETE)
- device_token: VARCHAR(255)   ← FCM push token
- last_login: TIMESTAMPTZ
- is_active: BOOLEAN NOT NULL DEFAULT true
- otp_hash: VARCHAR(255)       ← Hashed OTP, cleared after use
- otp_expires_at: TIMESTAMPTZ
- otp_attempts: SMALLINT NOT NULL DEFAULT 0
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ
```

### Table: `verification_logs`

Immutable log of every ID scan. Never deleted.

```
verification_logs
- id: UUID (PK)
- establishment_id: UUID NOT NULL (FK → establishments.id)
- beneficiary_id: UUID NULLABLE (FK → beneficiaries.id)   ← NULL when ID not found
- id_number_scanned: VARCHAR(50) NOT NULL
- beneficiary_type_detected: ENUM('senior_citizen', 'pwd')
- result: ENUM('valid', 'suspicious', 'invalid', 'manual_review') NOT NULL
- ocr_confidence_score: NUMERIC(5,2)   ← 0.00 to 100.00
- ocr_raw_text: TEXT
- image_path: VARCHAR(500)             ← URL of the captured ID image
- manually_entered: BOOLEAN NOT NULL DEFAULT false
- verified_at: TIMESTAMPTZ NOT NULL DEFAULT NOW()
```

### Table: `fraud_flags`

Suspicious ID reports submitted by establishment staff, routed to OSCA or PDAO.

```
fraud_flags
- id: UUID (PK)
- verification_log_id: UUID NOT NULL (FK → verification_logs.id)
- establishment_id: UUID NOT NULL (FK → establishments.id)
- beneficiary_id: UUID NULLABLE (FK → beneficiaries.id)
- id_number_flagged: VARCHAR(50) NOT NULL
- beneficiary_type: ENUM('senior_citizen', 'pwd') NOT NULL
- flag_status: ENUM('pending', 'reviewing', 'confirmed', 'dismissed') NOT NULL DEFAULT 'pending'
- establishment_notes: TEXT
- staff_notes: TEXT
- reviewed_by: UUID NULLABLE (FK → users.id)
- image_path: TEXT
- verification_outcome: VARCHAR(50)
- parent_flag_id: UUID NULLABLE (FK → fraud_flags.id)   ← For supplementary flags
- is_supplementary: BOOLEAN NOT NULL DEFAULT false
- flagged_at: TIMESTAMPTZ NOT NULL DEFAULT NOW()
- reviewed_at: TIMESTAMPTZ
```

### Table: `disputes`

Beneficiary-submitted challenges to incorrect denials or database errors.

```
disputes
- id: UUID (PK)
- beneficiary_account_id: UUID NOT NULL (FK → beneficiary_accounts.id)
- verification_log_id: UUID NULLABLE (FK → verification_logs.id)
- dispute_type: ENUM('wrong_denial', 'unauthorized_use', 'business_refusal', 'incorrect_db_info') NOT NULL
- explanation: TEXT NOT NULL
- supporting_doc_path: VARCHAR(500)   ← Uploaded document URL
- status: ENUM('submitted', 'acknowledged', 'under_review', 'resolved', 'rejected') NOT NULL DEFAULT 'submitted'
- staff_response: TEXT
- handled_by: UUID NULLABLE (FK → users.id)
- submitted_at: TIMESTAMPTZ NOT NULL DEFAULT NOW()
- acknowledged_at: TIMESTAMPTZ
- resolved_at: TIMESTAMPTZ
```

### Table: `notifications`

Push and SMS notifications sent to beneficiaries.

```
notifications
- id: UUID (PK)
- beneficiary_account_id: UUID NOT NULL (FK → beneficiary_accounts.id)
- notification_type: ENUM('verification_approved', 'verification_denied', 'flag_confirmed', 'dispute_submitted', 'dispute_acknowledged', 'dispute_escalated', 'dispute_resolved', 'id_expiring') NOT NULL
- title: VARCHAR(255) NOT NULL
- body: TEXT NOT NULL
- channel: ENUM('push', 'sms') NOT NULL DEFAULT 'push'
- is_read: BOOLEAN NOT NULL DEFAULT false
- verification_log_id: UUID NULLABLE (FK → verification_logs.id)
- created_at: TIMESTAMPTZ NOT NULL DEFAULT NOW()
```

### Table: `audit_logs`

Immutable record of every administrative action. Never deleted or updated.

```
audit_logs
- id: UUID (PK)
- user_id: UUID NULLABLE (FK → users.id)         ← NULL for system-generated actions
- establishment_id: UUID NULLABLE (FK → establishments.id)
- action: ENUM('login', 'logout', 'password_changed', 'otp_requested', 'otp_verified',
               'beneficiary_created', 'beneficiary_updated', 'beneficiary_status_changed',
               'establishment_approved', 'establishment_suspended', 'establishment_revoked',
               'establishment_created', 'establishment_bulk_import',
               'flag_created', 'flag_reviewed', 'flag_confirmed', 'flag_dismissed', 'flag_restored',
               'dispute_submitted', 'dispute_acknowledged', 'dispute_resolved', 'dispute_rejected',
               'verification_performed', 'data_export', 'report_generated') NOT NULL
- target_table: VARCHAR(100)
- target_id: UUID
- metadata: JSONB NOT NULL DEFAULT '{}'
- created_at: TIMESTAMPTZ NOT NULL DEFAULT NOW()
```

---

## KEY PROCESSES (use for DFD and Activity Diagram)

### Process 1 — ID Verification (Core Flow)

**Trigger:** Establishment staff opens the mobile app to verify a customer's ID.

**Steps:**

1. Staff selects ID type (Senior Citizen or PWD) from the home screen.
2. Staff captures a photo of the physical ID using the in-app camera.
3. The app performs quality assessment on the captured image (blur score, brightness check). If the image is too blurry or too dark, the staff is prompted to retake.
4. Accepted image goes through the OCR pipeline on-device:
   a. OpenCV preprocessing: perspective correction, deskew, CLAHE contrast, bilateral denoise, sharpen.
   b. ML Kit (Google) extracts text with bounding box positions (for layout-based zone extraction).
   c. The system applies zone-based extraction using hardcoded layout zones calibrated to the Valenzuela OSCA/PDAO ID card format: extracts ID number, full name, date of birth (Senior), disability type (PWD).
   d. If zone confidence is below 70%, falls back to Tesseract OCR + fuzzy text matching.
5. The extracted ID number (and optionally name/DOB) is sent to the API server via `POST /api/verification/scan` with: `id_number`, `beneficiary_type`, `ocr_confidence_score`, `ocr_raw_text`, `image_data` (base64), `manually_entered` flag.
6. The API server:
   a. Normalizes the ID number (strips non-alphanumeric, uppercases).
   b. Queries `beneficiaries` table by normalized ID number and beneficiary type.
   c. If not found: checks the other beneficiary type (cross-database conflict). If found in the other type → SUSPICIOUS. If not found at all → INVALID.
   d. If found: checks `status` field.
   - `active` and not expired → **VALID**
   - `active` but past `validity_end` → **INVALID** (expired)
   - `suspended` → **SUSPICIOUS**
   - `revoked` → **INVALID**
     e. Logs the scan to `verification_logs`.
     f. If the beneficiary has a `beneficiary_account`, sends a push notification (via FCM) and logs an SMS notification.
7. API returns result object to the app: `{ result: 'valid'|'suspicious'|'invalid', message, beneficiary_name, validity_end, log_id }`.
8. App displays a color-coded result screen: green (VALID), yellow (SUSPICIOUS), red (INVALID).
9. If result is SUSPICIOUS or INVALID, staff has the option to submit a fraud flag.

**Offline mode:** If no internet, the app checks a local Hive cache of the last-synced beneficiary statuses. Results from offline cache are marked as such in the UI.

### Process 2 — Fraud Flag Submission

**Trigger:** Staff taps "Report Suspicious ID" after a SUSPICIOUS or INVALID result.

**Steps:**

1. Staff adds optional notes and taps Submit.
2. App sends `POST /api/fraud-flags` with: `verification_log_id`, `id_number_flagged`, `beneficiary_type`, `establishment_notes`.
3. API checks if an existing active investigation exists for this ID number. If yes, the new flag is marked as `is_supplementary = true` and linked via `parent_flag_id`.
4. Flag is inserted into `fraud_flags` with `flag_status = 'pending'`.
5. **Auto-suspend check:** The API counts `DISTINCT establishment_id` across all `pending` or `reviewing` flags for this `beneficiary_id`. If count ≥ 3 (configurable via `AUTO_SUSPEND_FLAG_THRESHOLD` environment variable) AND the beneficiary is currently `active`, the system:
   a. Updates `beneficiaries.status` to `suspended`.
   b. Writes to `audit_logs` with `action = 'flag_confirmed'` and metadata `{ auto_suspended: true }`.
   c. Sends a push notification to the beneficiary: "Your ID is now under investigation."
6. API returns `{ flag_id, auto_suspended: true/false }`.

### Process 3 — OSCA/PDAO Fraud Investigation

**Trigger:** OSCA or PDAO admin views pending fraud flags in their web portal.

**Steps:**

1. Admin logs into the web portal.
2. Views the list of pending flags filtered to their office type.
3. Opens a flag — sees: captured ID image, establishment notes, OCR text, verification result.
4. Admin can:
   - Mark as `reviewing` (opens the case).
   - Confirm fraud: sets `flag_status = 'confirmed'`, manually updates `beneficiaries.status` to `revoked`, writes to `audit_logs`.
   - Dismiss: sets `flag_status = 'dismissed'`, writes to `audit_logs`. If all pending flags for this beneficiary are now dismissed AND the beneficiary was auto-suspended, the system restores status to `active`.

### Process 4 — Beneficiary Dispute Submission

**Trigger:** A beneficiary whose ID was denied opens their mobile app and submits a dispute.

**Steps:**

1. Beneficiary opens the Beneficiary App and logs in (OTP via SMS to registered mobile).
2. Views their verification history — sees the denial event.
3. Taps "Dispute This" on the denial.
4. Selects dispute type: Wrong Denial, Unauthorized Use, Business Refusal, or Incorrect DB Info.
5. Types an explanation and optionally uploads a supporting document photo.
6. App sends `POST /api/disputes`.
7. OSCA/PDAO receives the dispute in their portal. SLA: 24h to acknowledge, 48–72h to resolve.

### Process 5 — Establishment Management (BPLO)

**Trigger:** BPLO admin manages food service establishments in their portal.

**Key actions:**

- Create a new establishment account (single form or bulk CSV/Excel import).
- Bulk import: Upload `.xlsx` or `.csv` file; system auto-generates email and secure password for each row. Credentials are displayed once on-screen and downloadable as CSV.
- Approve, suspend, or revoke an establishment account.
- Reset an establishment's password.
- View all verification activity (logs) per establishment.
- View analytics dashboard: scan volume, VALID/SUSPICIOUS/INVALID breakdown, top flagging establishments.

### Process 6 — Beneficiary Record Management (OSCA / PDAO)

**Key actions (OSCA manages senior_citizen; PDAO manages pwd):**

- Add, edit, or deactivate beneficiary records.
- Upload bulk beneficiary records.
- View a beneficiary's full verification history.
- Manually change a beneficiary's status (suspend, revoke, restore).
- Review and resolve disputes.
- View analytics dashboard.

---

## SPECIFIC DIAGRAM INSTRUCTIONS

### 1. CONTEXT DIAGRAM

- Show the iDetect System as one central process bubble.
- Show 5 external entities: **Establishment** (Business), **Beneficiary**, **BPLO Office**, **OSCA Office**, **PDAO Office**.
- Optionally show 2 external services: **FCM Service**, **SMS Service** (as external entities with outgoing arrows only from iDetect).
- Use **noun phrases only** on arrows — no verbs. Label what DATA or DOCUMENT is flowing, not the action.
- Example correct: "Scanned ID Image" | "Verification Result" | "Fraud Report" | "Senior Citizen Records"
- Example wrong: "Sends image" | "Returns result"

**Data flows to include:**

FROM Establishment TO iDetect:

- Scanned ID Image
- Fraud Report
- Staff Login Credentials

FROM iDetect TO Establishment:

- Verification Result
- Verification History

FROM Beneficiary TO iDetect:

- Registration Request
- OTP Code
- Dispute Submission
- Supporting Document

FROM iDetect TO Beneficiary:

- OTP Code
- Verification Notification
- Dispute Status Update
- ID Expiry Alert

FROM BPLO Office TO iDetect:

- Establishment Account Data
- Staff Account Data
- Approval Decision

FROM iDetect TO BPLO Office:

- Verification Reports
- Establishment Activity Logs
- Analytics Data

FROM OSCA Office TO iDetect:

- Senior Citizen Records
- Flag Review Decision
- Dispute Resolution

FROM iDetect TO OSCA Office:

- Fraud Flag Reports
- Verification Analytics
- Dispute Submissions
- SLA Alerts

FROM PDAO Office TO iDetect:

- PWD Records
- Flag Review Decision
- Dispute Resolution

FROM iDetect TO PDAO Office:

- Fraud Flag Reports
- Verification Analytics
- Dispute Submissions
- SLA Alerts

FROM iDetect TO FCM Service:

- Push Notification Payload

FROM iDetect TO SMS Service:

- SMS Notification Payload

---

### 2. DATA FLOW DIAGRAM (Level 1)

Processes:

- **1.0 Authentication** — Handles login for establishments (JWT), LGU staff (JWT), and beneficiaries (OTP-based).
- **2.0 ID Verification** — Core verification: OCR result in, database lookup, result out. Includes cross-database conflict detection and offline cache fallback.
- **3.0 Fraud Management** — Flag submission, duplicate detection (parent/supplementary), auto-suspend threshold check, OSCA/PDAO review flow.
- **4.0 Beneficiary Management** — OSCA and PDAO CRUD on beneficiary records, status management, bulk upload.
- **5.0 Establishment Management** — BPLO CRUD on establishment accounts, single and bulk import, approval workflow.
- **6.0 Dispute Resolution** — Beneficiary dispute submission, SLA tracking, OSCA/PDAO resolution.
- **7.0 Notification Dispatch** — Push via FCM and SMS via Semaphore. Triggered by verifications, flags, dispute events, and ID expiry.
- **8.0 Reporting & Analytics** — Dashboard statistics, CSV export, audit log queries.

Data Stores (use standard DFD double-bar notation):

- **D1: Users** — LGU staff accounts (users table)
- **D2: Establishments** — Business accounts (establishments table)
- **D3: Beneficiaries** — Official government ID records (beneficiaries table)
- **D4: Beneficiary Accounts** — Beneficiary app accounts (beneficiary_accounts table)
- **D5: Verification Logs** — Immutable scan history (verification_logs table)
- **D6: Fraud Flags** — Suspicious ID reports (fraud_flags table)
- **D7: Disputes** — Beneficiary challenges (disputes table)
- **D8: Notifications** — Notification queue/history (notifications table)
- **D9: Audit Logs** — Administrative action trail (audit_logs table)

---

### 3. USE CASE DIAGRAM

**Actors:**

- Establishment Staff
- Beneficiary
- BPLO Admin
- OSCA Admin
- PDAO Admin
- System (for scheduled/automated use cases — shown as a separate actor)

**Use Cases by Actor:**

Establishment Staff:

- Scan ID Card
- View Verification History
- Submit Fraud Flag
- Log In / Log Out

Beneficiary:

- Register Beneficiary Account
- Verify OTP Code
- View Verification Notifications
- View Verification History
- Submit Dispute
- Upload Supporting Document

BPLO Admin:

- Log In / Log Out
- Manage Establishment Accounts (create, view, edit, approve, suspend, revoke)
- Bulk Import Establishments
- Download Credentials Report
- Reset Establishment Password
- Manage Staff Accounts
- View Verification Logs
- View Analytics Dashboard
- Export Reports

OSCA Admin (extends LGU Admin — share the common ones):

- Log In / Log Out
- Manage Senior Citizen Records (add, edit, view)
- Review Fraud Flags
- Confirm Fraud / Revoke ID
- Dismiss Fraud Flag
- Acknowledge Dispute
- Resolve Dispute
- Manage Staff Accounts
- View Analytics Dashboard
- Export Reports

PDAO Admin (mirrors OSCA Admin but for PWD):

- Log In / Log Out
- Manage PWD Records (add, edit, view)
- Review Fraud Flags
- Confirm Fraud / Revoke ID
- Dismiss Fraud Flag
- Acknowledge Dispute
- Resolve Dispute
- Manage Staff Accounts
- View Analytics Dashboard
- Export Reports

System (automated):

- Auto-Suspend Beneficiary on Flag Threshold
- Send Push Notification (FCM)
- Send SMS Notification
- Escalate Overdue Disputes (SLA cron)
- Send ID Expiry Alerts (daily cron)

**Include relationships:**

- "Submit Fraud Flag" <<extends>> "Scan ID Card" (flag is optional after scan)
- "Upload Supporting Document" <<extends>> "Submit Dispute"
- "Confirm Fraud / Revoke ID" <<includes>> "Auto-Suspend Beneficiary on Flag Threshold"
- "Send Push Notification" <<includes>> "Scan ID Card"
- "Verify OTP Code" <<includes>> "Register Beneficiary Account"

---

### 4. ENTITY RELATIONSHIP DIAGRAM (ERD)

Use crow's foot notation (Chen or crow's foot, your choice — crow's foot is more readable in draw.io).

**Entities and their primary keys:**

1. **USERS** (id PK, email, password_hash, full_name, role, is_active)
2. **ESTABLISHMENTS** (id PK, email, password_hash, business_name, business_permit_no, owner_name, address, contact_number, business_type, status, approved_by FK, approved_at)
3. **BENEFICIARIES** (id PK, id_number UNIQUE, full_name, birthdate, beneficiary_type, issuing_office, validity_start, validity_end, status, status_reason, registered_mobile, created_by FK, updated_by FK)
4. **BENEFICIARY_ACCOUNTS** (id PK, beneficiary_id FK UNIQUE, device_token, last_login, is_active, otp_hash, otp_expires_at, otp_attempts)
5. **VERIFICATION_LOGS** (id PK, establishment_id FK, beneficiary_id FK nullable, id_number_scanned, beneficiary_type_detected, result, ocr_confidence_score, ocr_raw_text, image_path, manually_entered, verified_at)
6. **FRAUD_FLAGS** (id PK, verification_log_id FK, establishment_id FK, beneficiary_id FK nullable, id_number_flagged, beneficiary_type, flag_status, establishment_notes, staff_notes, reviewed_by FK nullable, image_path, verification_outcome, parent_flag_id FK nullable self-ref, is_supplementary, flagged_at, reviewed_at)
7. **DISPUTES** (id PK, beneficiary_account_id FK, verification_log_id FK nullable, dispute_type, explanation, supporting_doc_path, status, staff_response, handled_by FK nullable, submitted_at, acknowledged_at, resolved_at)
8. **NOTIFICATIONS** (id PK, beneficiary_account_id FK, notification_type, title, body, channel, is_read, verification_log_id FK nullable, created_at)
9. **AUDIT_LOGS** (id PK, user_id FK nullable, establishment_id FK nullable, action, target_table, target_id, metadata, created_at)

**Relationships (use these exactly):**

| From                 | Cardinality | To                        | Description                                                |
| -------------------- | ----------- | ------------------------- | ---------------------------------------------------------- |
| USERS                | 1           | 0..\* ESTABLISHMENTS      | approves (via approved_by FK)                              |
| USERS                | 1           | 0..\* BENEFICIARIES       | creates (via created_by FK)                                |
| USERS                | 1           | 0..\* BENEFICIARIES       | updates (via updated_by FK)                                |
| BENEFICIARIES        | 1           | 0..1 BENEFICIARY_ACCOUNTS | has one optional app account                               |
| ESTABLISHMENTS       | 1           | 1..\* VERIFICATION_LOGS   | performs verifications                                     |
| BENEFICIARIES        | 1           | 0..\* VERIFICATION_LOGS   | is verified by                                             |
| ESTABLISHMENTS       | 1           | 0..\* FRAUD_FLAGS         | submits                                                    |
| BENEFICIARIES        | 1           | 0..\* FRAUD_FLAGS         | is subject of                                              |
| VERIFICATION_LOGS    | 1           | 0..\* FRAUD_FLAGS         | is basis for                                               |
| FRAUD_FLAGS          | 1           | 0..\* FRAUD_FLAGS         | has supplementary flags (self-referencing, parent_flag_id) |
| USERS                | 1           | 0..\* FRAUD_FLAGS         | reviews (via reviewed_by FK)                               |
| BENEFICIARY_ACCOUNTS | 1           | 1..\* DISPUTES            | submits                                                    |
| VERIFICATION_LOGS    | 1           | 0..\* DISPUTES            | is disputed by                                             |
| USERS                | 1           | 0..\* DISPUTES            | handles (via handled_by FK)                                |
| BENEFICIARY_ACCOUNTS | 1           | 0..\* NOTIFICATIONS       | receives                                                   |
| VERIFICATION_LOGS    | 1           | 0..\* NOTIFICATIONS       | triggers                                                   |
| USERS                | 1           | 0..\* AUDIT_LOGS          | generates                                                  |
| ESTABLISHMENTS       | 1           | 0..\* AUDIT_LOGS          | generates                                                  |

---

### 5. ACTIVITY DIAGRAM

Create **one detailed activity diagram** for the **ID Verification and Fraud Response** end-to-end flow. This is the core process of the system.

**Swimlanes (use swimlanes/partitions):**

1. **Establishment Staff** (Mobile App)
2. **iDetect Mobile App** (on-device processing)
3. **iDetect API Server** (backend)
4. **OSCA / PDAO Admin** (web portal)
5. **Beneficiary** (Beneficiary App)

**Activity flow:**

```
START

[Establishment Staff]
  → Open Mobile App
  → Select ID Type (Senior Citizen OR PWD)
  → Capture ID Photo using Camera

[iDetect Mobile App]
  → Assess Image Quality (blur, brightness)
  → DECISION: Image quality acceptable?
      NO → Show retake prompt → Go back to "Capture ID Photo"
      YES → Continue

  → OpenCV Preprocessing
    (perspective correction, deskew, CLAHE, denoise, sharpen)

  → ML Kit Text Recognition (with bounding boxes)
  → DECISION: ML Kit extraction confidence ≥ 70%?
      YES → Use layout-based zone extraction
      NO  → Use Tesseract OCR + fuzzy text matching

  → Extract fields: ID Number, Full Name, Date of Birth / Disability Type
  → DECISION: Internet available?
      NO  → Check local offline cache
           → DECISION: ID found in cache?
                NO  → Display "Cannot verify offline — ID not in cache"
                YES → Return cached result (marked as offline) → Go to Display Result
      YES → Send to API Server

[iDetect API Server]
  → Receive scan request (id_number, beneficiary_type, ocr_data, image)
  → Normalize ID number (strip non-alphanumeric, uppercase)
  → Query beneficiaries table by normalized ID + beneficiary_type

  → DECISION: Beneficiary record found?
      NO → Query other beneficiary_type for same ID number
           → DECISION: Found in other type?
                YES → Result = SUSPICIOUS (cross-database conflict)
                    → Auto-create fraud flag for both portal types
                NO  → Result = INVALID ("ID not found")
      YES → Check beneficiary.status:
           → DECISION: Status?
                'active'   → Check validity_end date
                             → DECISION: Expired?
                                  YES → Result = INVALID ("ID has expired")
                                  NO  → Result = VALID
                'suspended' → Result = SUSPICIOUS ("ID under investigation")
                'revoked'   → Result = INVALID ("ID confirmed fraudulent")

  → Save to verification_logs
  → DECISION: Beneficiary has app account?
      YES → Insert push notification to notifications table
          → Send push via FCM
          → Log SMS notification (Semaphore)
      NO  → Skip notification

  → Return result to Mobile App

[iDetect Mobile App]
  → Display result screen:
      VALID     → Green screen with beneficiary name and validity date
      SUSPICIOUS → Yellow screen with warning message
      INVALID   → Red screen with denial reason

[Establishment Staff]
  → DECISION: Result is SUSPICIOUS or INVALID?
      NO  → Grant discount → END (this branch)
      YES → DECISION: Staff chooses to report?
               NO  → Deny discount → END (this branch)
               YES → Submit Fraud Flag (add optional notes, tap Submit)

[iDetect API Server — Fraud Flag Processing]
  → Receive fraud flag submission
  → Check: existing active investigation for this ID number?
      YES → Link as supplementary flag (is_supplementary = true, parent_flag_id set)
      NO  → Create primary flag

  → Insert into fraud_flags (status = 'pending')

  → Count DISTINCT establishment_id with pending/reviewing flags for this beneficiary
  → DECISION: Count ≥ 3 (threshold) AND beneficiary status = 'active'?
      YES → Update beneficiaries.status = 'suspended'
          → Write to audit_logs (auto_suspended: true)
          → Send push notification to beneficiary: "Your ID is under investigation"
      NO  → Continue without suspension

  → Send routine flag notification to beneficiary (if has account)

[OSCA / PDAO Admin]
  → Log into web portal
  → View fraud flags list (filtered to their office type)
  → Open flag → Review: ID image, notes, OCR text, verification history

  → DECISION: Fraud confirmed?
      YES → Set flag_status = 'confirmed'
          → Update beneficiaries.status = 'revoked'
          → Write to audit_logs
          → END investigation branch
      NO  → Dismiss flag → Set flag_status = 'dismissed'
          → DECISION: All flags for this beneficiary now dismissed?
               YES → DECISION: Beneficiary was auto-suspended?
                         YES → Restore beneficiaries.status = 'active'
                              → Write to audit_logs (flag_restored)
                         NO  → No change to status
               NO  → Keep status as is

[Beneficiary — parallel track if SUSPICIOUS result]
  → Receive push notification: "Your ID has been flagged"
  → Open Beneficiary App
  → View verification history → See the denial event
  → Tap "Dispute This"
  → Select dispute type (Wrong Denial / Unauthorized Use / Business Refusal / Incorrect DB Info)
  → Enter explanation
  → Optionally upload supporting document
  → Submit dispute

[OSCA / PDAO Admin — Dispute Resolution track]
  → Receive dispute in web portal
  → Acknowledge within 24 hours (SLA)
  → Investigate
  → Resolve or Reject dispute with explanation

END
```

---

## GENERATION INSTRUCTIONS FOR CLAUDE

Please generate all 5 diagrams as **PlantUML code blocks**. Use these PlantUML diagram types:

- Context Diagram → use `@startuml` with `rectangle`, `actor`, and `-->` arrows with labels
- DFD → use `@startuml` with `rectangle` for processes, `database` for data stores, `actor` for external entities
- Use Case Diagram → use `@startuml` with `usecase`, `actor`, `-->`, `..>`, `--|>`
- ERD → use `@startuml` with `entity`, `||--|{`, `|o--|{`, `||--o{` crow's foot notation
- Activity Diagram → use `@startuml` with `|Swimlane|`, `start`, `stop`, `:activity;`, `if/else`, `fork`

Make each diagram complete and self-contained. Every entity, process, data store, actor, and relationship described in this document should appear in the appropriate diagram. Do not omit any of them.

For the ERD, show all 9 tables with their key columns and all 16 relationships listed above.

For the Activity Diagram, use swimlanes for all 5 partitions and include every decision point and branch shown in the flow above.

Label every arrow. No unlabeled connections.
