# iDetect — DFD and Activity Diagram Generation Prompt

**System:** iDetect — OCR-Based Discount ID Verification System, Valenzuela City
**Generate:** Data Flow Diagram (Level 1 + Level 2) and 5 separate Activity Diagrams
**Format:** PlantUML code blocks, importable into draw.io via Extras > Edit Diagram

---

## SYSTEM CONTEXT (Brief)

iDetect allows food service establishments to verify Senior Citizen and PWD discount IDs using OCR. The system has four user types: Establishment Staff (mobile app), Beneficiary (mobile app), and three LGU web portal admins — BPLO (manages establishments), OSCA (manages Senior Citizen records and fraud), PDAO (manages PWD records and fraud).

Backend: Node.js/Express API + PostgreSQL. Mobile: Flutter (Android).

---

## PART 1 — DATA FLOW DIAGRAMS

### Rules for all DFDs

- External entities: use rectangle boxes
- Processes: use rounded rectangles or circles, labeled as "1.0 Process Name"
- Data stores: use open-ended rectangles (double bar notation), labeled "D1: Table Name"
- Every arrow must have a data label (noun phrase only, no verbs)
- Use standard Gane & Sarson or Yourdon notation

---

### DFD — Level 1 (All System Processes)

**IMPORTANT LAYOUT INSTRUCTION FOR THE DIAGRAM:**
The diagram must be arranged in THREE vertical columns:

- **LEFT COLUMN** — Data Stores only (D1 through D9), stacked vertically
- **CENTER COLUMN** — All 8 Processes (1.0 through 8.0), stacked vertically
- **RIGHT COLUMN** — All External Entities only, stacked vertically

Arrows between External Entities (right) and Processes (center) flow horizontally LEFT ← or RIGHT →.
Arrows between Processes (center) and Data Stores (left) flow horizontally LEFT ← or RIGHT →.
No entity or data store should be placed in the center column.
No process should be placed in the left or right column.

---

**LEFT COLUMN — Data Stores (9 total, stacked top to bottom):**

```
D1: Users
D2: Establishments
D3: Beneficiaries
D4: Beneficiary Accounts
D5: Verification Logs
D6: Fraud Flags
D7: Disputes
D8: Notifications
D9: Audit Logs
```

---

**CENTER COLUMN — Processes (8 total, stacked top to bottom):**

```
1.0 Authentication
2.0 ID Verification
3.0 Fraud Management
4.0 Beneficiary Record Management
5.0 Establishment Management
6.0 Dispute Resolution
7.0 Notification Dispatch
8.0 Reporting and Analytics
```

---

**RIGHT COLUMN — External Entities (7 total, stacked top to bottom):**

```
Establishment Staff
Beneficiary
BPLO Admin
OSCA Admin
PDAO Admin
FCM Service
SMS Service
```

---

**Data Flows — External Entities (RIGHT) ↔ Processes (CENTER):**

```
Establishment Staff  →  1.0  : Login Credentials
1.0  →  Establishment Staff  : Auth Token

Beneficiary          →  1.0  : ID Number + Birthdate
Beneficiary          →  1.0  : OTP Code
1.0  →  Beneficiary          : Session Token

BPLO Admin           →  1.0  : Login Credentials
OSCA Admin           →  1.0  : Login Credentials
PDAO Admin           →  1.0  : Login Credentials
1.0  →  BPLO Admin           : Auth Token
1.0  →  OSCA Admin           : Auth Token
1.0  →  PDAO Admin           : Auth Token

Establishment Staff  →  2.0  : Scanned ID Image + ID Type
2.0  →  Establishment Staff  : Verification Result

Establishment Staff  →  3.0  : Fraud Report
3.0  →  Establishment Staff  : Flag Status Update
OSCA Admin           →  3.0  : Flag Review Decision
PDAO Admin           →  3.0  : Flag Review Decision
3.0  →  OSCA Admin           : Fraud Flag Report
3.0  →  PDAO Admin           : Fraud Flag Report
3.0  →  Beneficiary          : Suspension Notification

OSCA Admin           →  4.0  : Beneficiary Record Data
OSCA Admin           →  4.0  : Status Change Decision
PDAO Admin           →  4.0  : Beneficiary Record Data
PDAO Admin           →  4.0  : Status Change Decision
4.0  →  OSCA Admin           : Beneficiary Records
4.0  →  PDAO Admin           : Beneficiary Records

BPLO Admin           →  5.0  : Establishment Account Data
BPLO Admin           →  5.0  : Bulk Import File
BPLO Admin           →  5.0  : Approval Decision
5.0  →  BPLO Admin           : Establishment Records
5.0  →  BPLO Admin           : Generated Credentials
5.0  →  BPLO Admin           : Verification Activity Logs

Beneficiary          →  6.0  : Dispute Submission
Beneficiary          →  6.0  : Supporting Document
OSCA Admin           →  6.0  : Resolution Decision
PDAO Admin           →  6.0  : Resolution Decision
6.0  →  Beneficiary          : Dispute Status
6.0  →  OSCA Admin           : Dispute List
6.0  →  PDAO Admin           : Dispute List

7.0  →  FCM Service          : Push Notification Payload
7.0  →  SMS Service          : SMS Payload
FCM Service          →  Beneficiary : Push Notification
SMS Service          →  Beneficiary : SMS Message

BPLO Admin           →  8.0  : Report Request
OSCA Admin           →  8.0  : Report Request
PDAO Admin           →  8.0  : Report Request
8.0  →  BPLO Admin           : Analytics Dashboard Data
8.0  →  BPLO Admin           : Exported CSV Report
8.0  →  OSCA Admin           : Analytics Dashboard Data
8.0  →  OSCA Admin           : Exported CSV Report
8.0  →  PDAO Admin           : Analytics Dashboard Data
8.0  →  PDAO Admin           : Exported CSV Report
```

---

**Data Flows — Processes (CENTER) ↔ Data Stores (LEFT):**

```
1.0  →  D1  : User Record Query
D1   →  1.0  : User Record
1.0  →  D2  : Establishment Record Query
D2   →  1.0  : Establishment Record
1.0  →  D4  : Account Record Query
D4   →  1.0  : Account Record
1.0  →  D9  : Login Audit Entry

2.0  →  D3  : Beneficiary Lookup
D3   →  2.0  : Beneficiary Record
2.0  →  D5  : Verification Log Entry
2.0  →  D8  : Notification Queue Entry

3.0  →  D5  : Verification Log Query
D5   →  3.0  : Verification Log
3.0  →  D3  : Beneficiary Status Query
D3   →  3.0  : Beneficiary Record
3.0  →  D6  : Flag Record Query
D6   →  3.0  : Flag Record
3.0  →  D6  : Flag Entry / Status Update
3.0  →  D3  : Beneficiary Status Update
3.0  →  D9  : Flag Audit Entry

4.0  →  D3  : Beneficiary Record Query
D3   →  4.0  : Beneficiary Record
4.0  →  D3  : Beneficiary Record Insert / Update
4.0  →  D9  : Record Audit Entry

5.0  →  D2  : Establishment Record Query
D2   →  5.0  : Establishment Record
5.0  →  D2  : Establishment Record Insert / Update
5.0  →  D5  : Verification Log Query
D5   →  5.0  : Verification Log
5.0  →  D9  : Establishment Audit Entry

6.0  →  D4  : Account Record Query
D4   →  6.0  : Account Record
6.0  →  D5  : Verification Log Query
D5   →  6.0  : Verification Log
6.0  →  D7  : Dispute Record Query
D7   →  6.0  : Dispute Record
6.0  →  D7  : Dispute Entry / Status Update
6.0  →  D9  : Dispute Audit Entry

7.0  →  D4  : Account / Device Token Query
D4   →  7.0  : Device Token
7.0  →  D8  : Notification Record Entry

8.0  →  D5  : Verification Log Query
D5   →  8.0  : Verification Log Data
8.0  →  D6  : Fraud Flag Query
D6   →  8.0  : Fraud Flag Data
8.0  →  D7  : Dispute Query
D7   →  8.0  : Dispute Data
8.0  →  D9  : Audit Log Query
D9   →  8.0  : Audit Log Data
```

---

### DFD — Level 2: Process 2.0 ID Verification (Exploded)

Break Process 2.0 into these sub-processes:

```
2.1 IMAGE CAPTURE AND QUALITY CHECK
  IN:  Raw ID Photo → from Establishment Staff
  OUT: Quality-Rejected Image → to Establishment Staff (retake prompt)
  OUT: Accepted Image → to 2.2

2.2 OCR PREPROCESSING
  IN:  Accepted Image → from 2.1
  PROCESS: OpenCV pipeline (perspective correction, deskew, CLAHE, denoise, sharpen)
  OUT: Preprocessed Image → to 2.3

2.3 TEXT EXTRACTION
  IN:  Preprocessed Image → from 2.2
  IN:  Original Image (for ML Kit layout) → from 2.1
  PROCESS: ML Kit (bounding box extraction) + Tesseract (zone OCR)
           If layout confidence < 70%, fallback to fuzzy text matching
  OUT: Extracted ID Fields (ID Number, Name, DOB / Disability Type) → to 2.4

2.4 DATABASE LOOKUP AND VALIDATION
  IN:  Extracted ID Fields → from 2.3
  IN:  Manually Entered ID Number (if OCR failed) → from Establishment Staff
  READS: D3 Beneficiaries
  PROCESS: Normalize ID number → query by ID number + beneficiary type
           Check status (active / suspended / revoked) and expiry date
           If not found: check other beneficiary type (cross-database conflict)
  OUT: Verification Result (VALID / SUSPICIOUS / INVALID) → to 2.5

2.5 RESULT LOGGING AND NOTIFICATION
  IN:  Verification Result → from 2.4
  WRITES: D5 Verification Logs
  OUT: Verification Result → to Establishment Staff
  OUT: Notification Request → to 7.0 Notification Dispatch
```

---

### DFD — Level 2: Process 3.0 Fraud Management (Exploded)

```
3.1 FLAG SUBMISSION
  IN:  Fraud Report → from Establishment Staff
  IN:  Captured ID Image → from D5 Verification Logs
  READS: D6 Fraud Flags (check for existing active investigation)
  PROCESS: If existing investigation found → mark as supplementary (linked to parent flag)
           If new → create primary flag
  WRITES: D6 Fraud Flags (new flag, status = pending)
  OUT: Flag Data → to 3.2

3.2 AUTO-SUSPEND CHECK
  IN:  Flag Data → from 3.1
  READS: D6 Fraud Flags (count distinct establishment_id with pending/reviewing flags)
  READS: D3 Beneficiaries (current status)
  PROCESS: If distinct flagging establishments >= 3 AND beneficiary is active
           → auto-suspend beneficiary
  WRITES: D3 Beneficiaries (status = suspended)
  WRITES: D9 Audit Logs (auto_suspended event)
  OUT: Suspension Notification Request → to 7.0 Notification Dispatch
  OUT: Flag Acknowledgment → to Establishment Staff

3.3 FLAG REVIEW (OSCA / PDAO)
  IN:  Flag Review Decision → from OSCA Admin or PDAO Admin
  READS: D6 Fraud Flags
  READS: D5 Verification Logs (ID image, scan history)
  PROCESS: Admin can: Open for Review / Confirm Fraud / Dismiss
  WRITES: D6 Fraud Flags (status update)
  OUT: Flag Decision → to 3.4

3.4 BENEFICIARY STATUS UPDATE
  IN:  Flag Decision → from 3.3
  READS: D6 Fraud Flags (all flags for this beneficiary)
  PROCESS: If Confirmed → set beneficiary status = revoked
           If Dismissed → recount active flags
             If all flags dismissed AND was auto-suspended → restore to active
  WRITES: D3 Beneficiaries (status = revoked OR active)
  WRITES: D9 Audit Logs
  OUT: Resolution Notification Request → to 7.0 Notification Dispatch
```

---

## PART 2 — ACTIVITY DIAGRAMS (5 Separate Diagrams)

**Rules for all Activity Diagrams:**

- Use swimlanes (partitions) where relevant
- Use filled circle for start, bullseye for end
- Use diamond for decisions
- Use rounded rectangles for activities
- Use fork/join bars for parallel actions
- Label every decision branch (Yes/No or condition)

---

### Activity Diagram 1 — ID Verification (Establishment Staff)

**Swimlanes:** Establishment Staff | iDetect Mobile App | iDetect API Server

**Flow:**

```
START

[Establishment Staff]
Open Mobile App
→ Log In with Business Credentials
→ Select ID Type (Senior Citizen OR PWD)
→ Capture ID Photo using Camera

[iDetect Mobile App]
→ Assess image quality (blur score, brightness)
→ DECISION: Image acceptable?
    NO → Display retake prompt → back to "Capture ID Photo"
    YES → Continue

→ Run OpenCV preprocessing
   (perspective correction, deskew, CLAHE, bilateral denoise, sharpen)

→ Run ML Kit text recognition (bounding boxes on original image)
→ DECISION: Layout confidence ≥ 70%?
    YES → Apply zone-based field extraction
    NO  → Run Tesseract OCR + fuzzy text matching

→ Extract: ID Number, Full Name, Date of Birth (Senior) or Disability Type (PWD)

→ DECISION: Internet connection available?
    NO  → Check local offline cache
          → DECISION: ID found in cache?
               NO  → Display "Cannot verify offline — ID not cached"
               YES → Display cached result (marked OFFLINE) → END
    YES → Send scan request to API (id_number, beneficiary_type, ocr_data, image)

[iDetect API Server]
→ Normalize ID number (strip non-alphanumeric, uppercase)
→ Query Beneficiaries table by normalized ID + type

→ DECISION: Record found?
    NO  → Query other beneficiary type
          → DECISION: Found in other type?
               YES → Result = SUSPICIOUS (cross-database conflict)
                   → Auto-create fraud flags for both portal types
               NO  → Result = INVALID (not found)
    YES → Check beneficiary status

→ DECISION: Status?
    active   → Check validity_end date
               → DECISION: Expired?
                    YES → Result = INVALID (expired)
                    NO  → Result = VALID
    suspended → Result = SUSPICIOUS (under investigation)
    revoked   → Result = INVALID (confirmed fraudulent)

→ Save to Verification Logs
→ Send push notification to beneficiary (if has app account)
→ Return result to Mobile App

[iDetect Mobile App]
→ Display result screen:
    VALID      → Green screen: beneficiary name + validity date
    SUSPICIOUS → Yellow screen: warning message
    INVALID    → Red screen: denial reason

[Establishment Staff]
→ DECISION: Result is VALID?
    YES → Grant discount → END
    NO  → Deny discount
        → DECISION: Staff chooses to report?
             YES → Submit fraud flag (add optional notes, tap Submit) → END
             NO  → END

END
```

---

### Activity Diagram 2 — Fraud Flag Investigation (OSCA / PDAO Admin)

**Swimlanes:** Establishment Staff | iDetect API Server | OSCA / PDAO Admin | Beneficiary App

**Flow:**

```
START

[Establishment Staff]
→ Submit fraud flag after SUSPICIOUS/INVALID scan result
  (verification_log_id, id_number, type, optional notes)

[iDetect API Server]
→ Check: existing active investigation for this ID?
    YES → Link as supplementary flag (parent_flag_id set, is_supplementary = true)
    NO  → Create primary flag (status = pending)

→ Insert into Fraud Flags

→ Count DISTINCT establishments with pending/reviewing flags for this beneficiary
→ DECISION: Count ≥ 3 AND beneficiary status = active?
    YES → Update beneficiary status = suspended
        → Write to Audit Logs (auto_suspended = true)
        → Send suspension push notification to Beneficiary App
    NO  → Continue without suspension

→ Send flag acknowledgment notification to Beneficiary App

[OSCA / PDAO Admin]
→ Log into web portal
→ View fraud flags list (filtered to their office: OSCA = senior_citizen, PDAO = pwd)
→ Open flag → Review: ID image, establishment notes, OCR text, scan history

→ DECISION: Open for investigation?
    YES → Set flag status = reviewing

→ DECISION: Fraud confirmed?
    YES → Set flag status = confirmed
        → [iDetect API Server] Update beneficiary status = revoked
        → Write to Audit Logs
        → Send revocation notification to Beneficiary App → END

    NO  → Dismiss flag → Set flag status = dismissed

[iDetect API Server]
→ Recount active flags for this beneficiary
→ DECISION: All flags now dismissed AND beneficiary was auto-suspended?
    YES → Restore beneficiary status = active
        → Write to Audit Logs (flag_restored)
        → Send restoration notification to Beneficiary App
    NO  → No status change

END
```

---

### Activity Diagram 3 — Beneficiary Dispute Submission

**Swimlanes:** Beneficiary | iDetect Mobile App | iDetect API Server | OSCA / PDAO Admin

**Flow:**

```
START

[Beneficiary]
→ Open Beneficiary Mobile App
→ Enter ID Number and Birthdate

[iDetect API Server]
→ Validate credentials
→ Generate OTP → Send OTP via SMS to registered mobile

[Beneficiary]
→ Enter OTP received via SMS

[iDetect API Server]
→ DECISION: OTP valid and not expired?
    NO  → Return error (invalid/expired OTP) → Beneficiary re-enters OTP
    YES → Create session → Return session token

[Beneficiary]
→ View verification history
→ Locate the denied/suspicious scan event
→ Tap "Dispute This"
→ Select dispute type:
    - Wrong Denial
    - Unauthorized Use
    - Business Refusal
    - Incorrect Database Info
→ Enter explanation text
→ DECISION: Upload supporting document?
    YES → Attach photo (barangay cert, secondary ID, etc.)
    NO  → Continue
→ Submit dispute

[iDetect API Server]
→ Save dispute to Disputes table (status = submitted)
→ Write to Audit Logs
→ Send dispute acknowledgment push notification to Beneficiary
→ Route dispute to OSCA (if senior_citizen) or PDAO (if pwd)

[OSCA / PDAO Admin]
→ View dispute in web portal
→ DECISION: Acknowledged within 24-hour SLA?
    NO  → Dispute escalated by system (SLA alert sent to admin)
    YES → Acknowledge dispute (status = acknowledged)
        → Send acknowledgment notification to Beneficiary

→ Investigate dispute
→ Set status = under_review

→ DECISION: Dispute valid?
    YES → Resolve with explanation (status = resolved)
        → Correct database record if needed
        → Update beneficiary status if applicable
    NO  → Reject with explanation (status = rejected)

[iDetect API Server]
→ Send resolution/rejection push notification to Beneficiary
→ Write to Audit Logs

END
```

---

### Activity Diagram 4 — Establishment Management (BPLO Admin)

**Swimlanes:** BPLO Admin | iDetect API Server

**Flow:**

```
START

[BPLO Admin]
→ Log into BPLO Web Portal

→ DECISION: Action?

  ── BRANCH A: Create Single Establishment ──
  → Fill in establishment form:
    (business name, permit number, owner, address, contact, business type)
  → DECISION: Provide custom email?
      YES → Use provided email
      NO  → System auto-generates email from permit number
  → System auto-generates secure 12-character password

  [iDetect API Server]
  → Validate: check for duplicate permit number and email
  → DECISION: Duplicate found?
      YES → Return validation error → Admin corrects and resubmits
      NO  → Insert into Establishments (status = pending)
          → Write to Audit Logs
  → Return generated credentials to BPLO Admin

  [BPLO Admin]
  → Save/download credentials → END (Branch A)

  ── BRANCH B: Bulk Import Establishments ──
  → Upload CSV or Excel file

  [iDetect API Server]
  → Parse file (up to 500 rows)
  → Validate each row (required fields: business_name, permit_no, owner_name, address, contact)
  → For each valid row:
      Auto-generate email (if blank) and secure password
      Hash password
      Check for duplicate permit_no and email
      Insert into Establishments (status = approved)
      Write per-row Audit Log
  → Write batch Audit Log (bulk_import event)
  → Return: summary (valid/skipped counts) + credentials list

  [BPLO Admin]
  → View import summary and preview table
  → Download credentials CSV (one-time — passwords shown only here) → END (Branch B)

  ── BRANCH C: Manage Existing Establishment ──
  → Search and select establishment
  → DECISION: Action?
      Approve   → Set status = approved → Write Audit Log
      Suspend   → Set status = suspended, enter reason → Write Audit Log
      Revoke    → Set status = revoked → Write Audit Log
      Reset PW  → Generate new password → Write Audit Log → Download new credentials
  → END (Branch C)

END
```

---

### Activity Diagram 5 — Beneficiary Record Management (OSCA / PDAO Admin)

**Swimlanes:** OSCA / PDAO Admin | iDetect API Server

**Flow:**

```
START

[OSCA / PDAO Admin]
→ Log into Web Portal
  (OSCA sees only senior_citizen records; PDAO sees only pwd records)

→ DECISION: Action?

  ── BRANCH A: Add New Beneficiary Record ──
  → Fill in beneficiary form:
    (ID number, full name, birthdate, issuing office, validity start, validity end)
  → For PWD: also select disability type
  → Submit form

  [iDetect API Server]
  → Normalize ID number
  → DECISION: Duplicate ID number or (name + birthdate) combination?
      YES → Return validation error → Admin corrects and resubmits
      NO  → Insert into Beneficiaries (status = active)
          → Write to Audit Logs (beneficiary_created)
  → Return success to Admin → END (Branch A)

  ── BRANCH B: Edit Existing Record ──
  → Search beneficiary by name or ID number
  → Select record → Edit fields (name, validity dates, contact, etc.)
  → Submit changes

  [iDetect API Server]
  → Validate changes
  → Update Beneficiaries record
  → Write to Audit Logs (beneficiary_updated)
  → Return success to Admin → END (Branch B)

  ── BRANCH C: Change Beneficiary Status ──
  → Search and select beneficiary
  → DECISION: New status?
      Suspend  → Enter reason text
               → Set status = suspended
               → Write to Audit Logs (beneficiary_status_changed)
               → Send notification to Beneficiary App (if has account)
      Revoke   → Enter reason text
               → Set status = revoked
               → Write to Audit Logs
               → Send notification to Beneficiary App
      Restore  → Set status = active, clear status_reason
               → Write to Audit Logs
               → Send notification to Beneficiary App
  → Return success to Admin → END (Branch C)

  ── BRANCH D: View Verification History ──
  → Search and select beneficiary
  → [iDetect API Server] Query Verification Logs for this beneficiary
  → Display: scan history (date, establishment, result, image)
  → DECISION: Export needed?
      YES → [iDetect API Server] Generate CSV → Download CSV
      NO  → END (Branch D)

END
```

---

## GENERATION INSTRUCTIONS

Generate all diagrams as **PlantUML code blocks** using:

- DFD Level 1: `@startuml` with `rectangle`, `database`, `actor`, labeled arrows
- DFD Level 2 (×2): same notation, smaller scope
- Activity Diagrams (×5): `@startuml` with `|Swimlane|` partitions, `start`, `stop`, `if/else`, `fork`, `:(activity);`

**Requirements:**

- Every arrow must have a label
- Every decision diamond must have labeled branches
- Every swimlane partition must be named
- Each diagram must be fully self-contained (do not reference other diagrams for context)
- Produce each diagram as a separate PlantUML code block with a clear heading above it

Generate all 8 diagrams (1 DFD Level 1, 2 DFD Level 2, 5 Activity Diagrams).
