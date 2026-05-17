# iDetect — Research Adviser Critique & Feedback Report

**Prepared by:** Research Adviser (AI-Assisted Review)
**Date:** May 6, 2026
**System Version Reviewed:** 3.1 (with latest API updates as of May 2026)
**Review Scope:** Full system — mobile app, API backend, web portals, database schema, dataflow, and documentation

---

## Table of Contents

1. [Overall Assessment](#1-overall-assessment)
2. [System Architecture Critique](#2-system-architecture-critique)
3. [Dataflow Analysis — Detailed](#3-dataflow-analysis--detailed)
   - 3.1 [OCR & Scan Pipeline](#31-ocr--scan-pipeline)
   - 3.2 [Verification Flow](#32-verification-flow)
   - 3.3 [Fraud Flag Flow](#33-fraud-flag-flow)
   - 3.4 [Beneficiary Management Flow](#34-beneficiary-management-flow)
4. [Critical Gaps & Issues](#4-critical-gaps--issues)
5. [Moderate Issues](#5-moderate-issues)
6. [Minor Issues & Observations](#6-minor-issues--observations)
7. [Security Review](#7-security-review)
8. [Data Integrity Review](#8-data-integrity-review)
9. [Research & Documentation Review](#9-research--documentation-review)
10. [Suggested Improvements & Solutions](#10-suggested-improvements--solutions)
11. [Defense Readiness Assessment](#11-defense-readiness-assessment)
12. [Summary Scorecard](#12-summary-scorecard)

---

## 1. Overall Assessment

iDetect is an ambitious, multi-component system that tackles a real and relevant problem in Philippine local government operations: preventing fraudulent discount claims through automated ID verification. The technical depth demonstrated — from dual OCR engines and multi-layer field extraction to fraud flag escalation and audit logging — is commendable for a capstone project.

However, the system has **one fundamental identity premise flaw** and **several process coherence gaps** that must be addressed before it can be considered production-ready or presented as a fully working system in a panel defense.

**What the team got right:**

- The OCR pipeline is well-engineered with appropriate fallback layers.
- The database schema is comprehensive and carefully designed.
- The fraud investigation workflow shows systems thinking.
- The audit log is thorough.
- Cross-validation (name + DOB matching) has been implemented — a major correctness milestone.

**What still needs attention:**

- The system's core identity premise has a structural gap (described in detail in Section 4).
- Multiple component contracts are mismatched (fraud flag payload, status taxonomy).
- Unimplemented features are presented alongside completed ones without clear distinction.
- The offline/online sync boundary is not well-defined for the cashier user.

---

## 2. System Architecture Critique

### 2.1 Architecture Strengths

The three-tier architecture (Mobile App → REST API → PostgreSQL) is appropriate for the use case. The separation of concerns across layers is generally clean:

- The mobile app (Flutter) handles OCR locally — this is a good design choice for performance, privacy, and offline capability.
- The API (Node.js/Express) acts as the single source of truth for identity records — correct.
- Web portals (React) are separated by role (BPLO, OSCA, PDAO) — this is exactly right for a multi-office system.

### 2.2 Architecture Problems

#### Problem A: Two Parallel and Inconsistent Data Stores

The mobile app uses **SQLite** (via `sqflite`) and **Hive** locally. The API uses **PostgreSQL** remotely. These are never described as being in a coherent sync relationship. The documentation says "Optional: Sync to Supabase (future)" — but the app is already deployed and in use.

**Issue:** What happens to scanned records stored in SQLite? They are not uploaded to the PostgreSQL verification_logs. The verification_logs table is only populated when the establishment actively calls `/api/verification/scan`. This means:

- Offline scans that are confirmed locally never appear in the central database.
- Analytics in the web portals miss any scan that didn't reach the server.

**Recommendation:** Define the lifecycle of a local SQLite record explicitly: is it a draft pending API confirmation, or a permanent local record? The two must not co-exist silently.

#### Problem B: Dual Verification Modes Are Poorly Distinguished

The system supports two distinct verification flows:

1. **Online verification** — sends OCR data to API, gets `VALID/SUSPICIOUS/INVALID/MANUAL_REVIEW`.
2. **Offline verification** — reads from local Hive cache, returns cached status.

These two flows have very different reliability guarantees. The current UI shows the same result screen for both, with only a subtle `[OFFLINE — synced X minutes ago]` tag on the message. In a real cashier environment, this distinction is critical and must be visually unmistakable.

#### Problem C: No Clear System Boundary Diagram

The documentation describes individual components well, but there is no single diagram showing all five actors (BPLO Admin, OSCA Admin, PDAO Admin, Establishment Cashier, Beneficiary) and every system boundary they interact with. A clear context diagram is essential for a panel defense.

---

## 3. Dataflow Analysis — Detailed

### 3.1 OCR & Scan Pipeline

**Flow Summary:**

```
Camera Capture → Quality Assessment → Auto-crop → Image Save
    → Advanced Image Processor (10 steps)
    → [Tesseract OCR || ML Kit OCR] (parallel)
    → Engine Selection (confidence-based)
    → Post-processing (error correction, normalization)
    → Multi-layer Field Extraction (Zone → Keyword → Fuzzy → Validation)
    → Result Merging (best per field)
    → User Review Screen
```

**Critique:**

**Positive:** The multi-layer extraction strategy is well-designed. Running both OCR engines in parallel and selecting the best result is the correct approach. The fallback to original image when preprocessing fails prevents the pipeline from ever producing zero output.

**Gap 1 — Confidence Calculation Is Heuristic, Not Empirical**

The Tesseract confidence score is computed using keyword presence and text length bonuses (e.g., `+0.10` if the text contains "SENIOR" or "OSCA"). This is a proxy metric, not a real confidence score. Tesseract's actual character-level confidence data (available via `hocr` output or the `GetHOCRText` API) is not used.

The result is that confidence scores are inflated by trivially adding expected keywords, and may not reflect actual extraction quality. A scan that correctly reads "OSCA" but misreads the name and date will still report high confidence.

**Suggestion:** Either use Tesseract's `--oem 1` (LSTM) with `hocr` output to get real per-word confidence, or clearly label the existing metric as an "extraction quality indicator" rather than an "OCR confidence score" in the UI and documentation.

**Gap 2 — Zone Coordinates Are Hardcoded for One ID Design**

The layout-based extractor uses fixed percentage-based zone coordinates (e.g., `NAME_TOP = 0.24`, `CTRL_LEFT = 0.65`) that are calibrated specifically for the current Valenzuela OSCA card design. No versioning or detection mechanism exists for different card layouts.

If the LGU issues a new card design with a different layout, the zone extractor will silently return wrong or empty values. Because it has the highest priority in the extraction order, all downstream fallbacks will be working with mis-extracted data.

**Suggestion:** Add a template version identifier to the zone configuration. If fewer than the required number of header keywords are detected during template validation, log a `LAYOUT_TEMPLATE_MISMATCH` warning and force the system into keyword-fallback mode. Alert OSCA/PDAO staff that an unrecognized card format was scanned.

**Gap 3 — PWD ID Number Extraction Has No Character Substitution Recovery**

The PWD ID regex `\b\d{2}-\d{4}-\d{3}-\d{4,8}\b` will fail if OCR misreads `0→O`, `1→I`, or `5→S` in any digit position. There is a character substitution pass in the post-processing layer, but it is applied to the full OCR text before the regex runs. It is unclear whether the substitution is applied to the candidate string before pattern matching or after.

**Suggestion:** In `pwd_layout_field_extractor.dart`, add an explicit pre-regex substitution step: for any candidate string that passes initial character filtering but fails the PWD ID regex, replace `O→0, l→1, I→1, S→5` and retry the regex before discarding the candidate.

**Gap 4 — Image Lifecycle Is Not Managed**

Images are saved to device temporary storage and passed by path through the pipeline. There is no evidence of cleanup (deleting temp files after submission). On devices with limited storage, accumulated temp files from many scans will cause issues.

**Suggestion:** Delete the temporary crop/processed image after the verification result is saved to the server. Keep the original captured image only if the user explicitly saves a record.

**Gap 5 — Processing Time Threshold Is Not User-Adapted**

Processing times of 7–15 seconds are acceptable on modern hardware, but no timeout or fallback exists if the OCR pipeline stalls beyond 20 seconds. The UI will hang on the processing screen indefinitely if Tesseract crashes or hangs (which can happen on low-RAM devices).

**Suggestion:** Wrap the OCR pipeline in a 20-second timeout. On timeout, skip Tesseract and use ML Kit only, then show a reduced-confidence result rather than a frozen UI.

---

### 3.2 Verification Flow

**Flow Summary:**

```
Result Screen → [User confirms]
    → ApiService.verifyId()
        → Local cache check (revoked/suspended → early return)
        → POST /api/verification/scan {id_number, beneficiary_type, extracted_name, extracted_dob, ...}
            → DB lookup by normalized id_number + beneficiary_type
            → Status check (active/expired/suspended/revoked)
            → Cross-validation (Jaro-Winkler name match + DOB exact match)
            → Low-confidence downgrade to manual_review
            → Log to verification_logs
            → Auto-suspend check (fraud flags threshold)
            → Push notification (beneficiary)
        ← {result, message, beneficiary, log_id}
    → Verifying Screen → displays result
```

**Critique:**

**Positive:** The cross-validation logic (name fuzzy match + DOB check) is now implemented. This is the most important correctness property of the system. The Jaro-Winkler implementation is correct. The 0.80 threshold is reasonable.

**Gap 6 — ID Type Must Be Pre-Selected by the Cashier**

Before scanning, the cashier must select whether the ID is "Senior Citizen" or "PWD." If they select the wrong type, the verification returns `invalid` even if the ID is valid in the other database. The cross-database conflict detection only partially mitigates this — it catches the case where the ID exists in the other DB, but still returns `suspicious` rather than guiding the cashier to change the type.

The card itself contains the information to determine its type (header keywords: "OSCA," "SENIOR CITIZEN," "PWD," "PDAO"). This information is already extracted by the OCR pipeline in `HEADER_KEYWORDS`.

**Suggestion:** Use the header keyword extraction result to auto-populate the `beneficiary_type` field before sending to the API. The cashier should only need to confirm, not select from scratch. This eliminates an entire class of user error.

**Gap 7 — Manual Entry Is an Unmonitored Bypass**

When `manually_entered = true`, the entire OCR pipeline is bypassed. A dishonest cashier can type any valid ID number they know and grant a discount without a physical card being present. The verification log records `manually_entered = true`, but:

- The BPLO portal does not visually distinguish manual entries.
- There is no supervisor confirmation step.
- There is no audit log entry with action type `verification_manual`.

**Suggestion:** In the BPLO dashboard verification history, render manual entries with a different icon and color (e.g., a keyboard icon instead of a camera icon, highlighted in amber). Add an `audit_logs` entry specifically for manual verifications. Consider requiring a manager PIN confirmation before a manual entry is accepted.

**Gap 8 — SUSPICIOUS Result Provides No Actionable Guidance**

When the result is `SUSPICIOUS` or `MANUAL_REVIEW`, the result screen displays a color-coded badge and a message, but gives the cashier no concrete instructions. In a real-world setting with a queue of customers, most cashiers will default to approving the discount rather than taking a deliberate action.

**Suggestion:** Add a mandatory contextual action panel to the SUSPICIOUS result screen:

- "Do NOT approve the discount"
- "Ask the customer for a secondary ID"
- "Tap below to report this ID to [OSCA/PDAO]"
- Require the cashier to tap one of three buttons (Approve Anyway / Deny / Report) before dismissing the screen. Log the cashier's choice.

**Gap 9 — No Face Detection Guard Before OCR**

The system processes any image through the OCR pipeline. There is no check to confirm that the image contains an ID card at all. A blank image, a photo of the floor, or a screenshot of a different document would still be processed, potentially returning garbage data that then gets sent to the server.

`google_mlkit_face_detection` is already in the dependency tree. A face presence check before OCR is a zero-cost safety gate.

**Suggestion:** Before the OCR pipeline, run `FaceDetector` on the captured image. If no face is detected, immediately show an error: "No ID card detected. Please retake the photo." This blocks non-ID images from entering the pipeline.

---

### 3.3 Fraud Flag Flow

**Flow Summary:**

```
Cashier (SUSPICIOUS/INVALID result) → Submits fraud flag
    → POST /api/fraud-flags {verification_log_id, id_number_flagged, beneficiary_type, notes}
        → Fetch beneficiary_id
        → Check for existing active investigation (supplementary flag logic)
        → Insert fraud_flag
        → Count distinct flaggers (auto-suspend threshold check)
        → Auto-suspend if ≥ 3 distinct establishments
        → Insert staff_alert for LGU
        → Push notification to beneficiary

OSCA/PDAO Staff → Reviews flag
    → PATCH /api/fraud-flags/:id/review {decision, staff_notes}
        → Update flag_status (confirmed/dismissed)
        → If confirmed: update beneficiary status to suspended/revoked
        → If dismissed: check if all flags dismissed → auto-restore beneficiary
```

**Critique:**

**Positive:** The supplementary flag logic (linking new reports to existing open investigations rather than creating duplicates) is a sophisticated and correct design decision. The auto-suspend threshold is configurable via environment variable.

**Gap 10 — Payload Mismatch Between Web Portals and API (Unresolved)**

As documented in `FUNCTIONAL_REQUIREMENTS_REVIEW_GUIDE.md`, the OSCA and PDAO web portals send `{action, notes}` in the flag review request, but the API expects `{decision, staff_notes}`. This mismatch means the flag review endpoint either silently ignores the payload fields or returns an error. This is a **critical functional gap** that breaks the fraud investigation workflow from the web portals.

**Suggestion:** Align the web portal `FraudFlagsPage.jsx` clients to send `{decision: 'confirmed'|'dismissed', staff_notes: '...'}`. This is a two-line fix per portal.

**Gap 11 — Auto-Suspend Collusion Risk Is Undetected**

The auto-suspend rule counts `DISTINCT establishment_id`. Three establishments owned by the same person (or operating under the same business group) can coordinate to auto-suspend any beneficiary. The system has no owner-level grouping.

**Suggestion (long-term):** Add an `owner_name` or `owner_group` field to the `establishments` table. Count `DISTINCT owner_name` or group in the threshold check alongside `DISTINCT establishment_id`.

**Gap 12 — No Time Decay on Pending Flags**

A fraud flag submitted 18 months ago that was never reviewed still counts toward the auto-suspend threshold. There is no mechanism to expire stale, never-reviewed flags.

**Suggestion:** The API already includes a cron scheduler. Add a daily scheduled job that sets flags older than 180 days with `flag_status = 'pending'` to `dismissed`, with `staff_notes = 'Auto-expired: exceeded review window. No LGU action taken.'` This prevents old noise from triggering auto-suspensions.

**Gap 13 — Two-Step Flag Submission Reduces Real-World Compliance**

After a SUSPICIOUS result, the cashier must navigate to a separate Flag screen to submit a report. In a busy establishment, this second step will routinely be skipped. Compliance with fraud reporting will be low.

**Suggestion:** When the scan result is SUSPICIOUS or INVALID, automatically open the fraud flag form pre-filled with the verification log ID, the ID image thumbnail, and the detected ID number. The cashier only needs to add optional notes and tap "Submit Report."

---

### 3.4 Beneficiary Management Flow

**Flow Summary:**

```
OSCA/PDAO Staff Portal → Add Beneficiary form
    → POST /api/beneficiaries {id_number, full_name, birthdate, issuing_office, validity_start, validity_end, [disability_type]}
    → DB: INSERT INTO beneficiaries

OSCA/PDAO Staff Portal → Bulk Import
    → POST /api/beneficiaries/bulk {rows[]}
    → Normalize each row → validate → skip duplicates → batch INSERT
    → Return summary {imported, skipped, errors}
```

**Critique:**

**Gap 14 — Extended Profile Fields Are Collected but Never Persisted (Critical)**

The PDAO portal `AddBeneficiaryPage.jsx` collects `disability_type`, `address`, `contact_number`, `email`, and `notes`. The OSCA portal similarly collects address and contact fields. These fields are entered by staff and displayed in beneficiary detail views.

However, the `beneficiaries` table does not have columns for `address`, `contact_number`, `email`, or `notes`. Only `disability_type` has a column (migration `011_add_disability_type.sql`). The other fields are silently discarded on save.

This means:

- Staff entering beneficiary contact details are wasting their time — the data is thrown away.
- Detail pages that display these fields are showing either empty data or stale frontend state.
- Disability type filters in the PDAO portal may work correctly (it has a column), but address/contact filters produce meaningless results.

**Suggestion:** Decide which fields are official. If they are needed (and they appear to be, given the forms and filters), add a migration adding `address TEXT`, `contact_number VARCHAR(20)`, `email VARCHAR(255)`, and `notes TEXT` to the `beneficiaries` table. Update the create and bulk-import API routes to persist them.

**Gap 15 — Status Label Mismatch Causes Broken Filter**

The web portal beneficiary list uses a tab labeled "Inactive" with value `inactive`. The `beneficiary_status` enum in the database has no `inactive` value — valid values are `active`, `expired`, `suspended`, `revoked`. The filter query for `inactive` will return zero results, silently, with no error.

**Suggestion:** Replace `inactive` in the web portal filter with `revoked` (which is the closest semantic equivalent for a permanently inactive beneficiary). Alternatively, map `inactive` in the frontend to `status IN ('expired', 'revoked')` in the API query.

**Gap 16 — Beneficiary OTP Login Is Incomplete**

The beneficiary portal (mobile app for senior citizens and PWDs) uses OTP-based login. The API endpoints exist, but the `sendSms()` function in the OTP route is a `TODO` — no SMS provider is integrated. Beneficiaries cannot actually log in to view their verification history or submit disputes without receiving the OTP via SMS.

**Suggestion (minimum viable):** For the defense, add a mock SMS sending step that logs the OTP to the server console, and document that production integration with a Philippine SMS provider (e.g., Semaphore, Globe Labs, or ITEXMO) is the next step. This at least demonstrates the flow works end-to-end in a controlled environment.

---

## 4. Critical Gaps & Issues

The following issues directly affect the correctness or integrity of the system's primary function.

---

### C-1: The Verification Chain Is Incomplete Without Cross-Validation Being Always Applied

**Status:** Partially resolved.

Cross-validation (name + DOB) is now implemented in the API. However, it only activates when the mobile app sends `extracted_name` and `extracted_dob`. Looking at `api_service.dart`, these fields are sent using conditional inclusion:

```dart
if (extractedName != null && extractedName.isNotEmpty) 'extracted_name': extractedName,
if (extractedDob != null && extractedDob.isNotEmpty) 'extracted_dob': extractedDob,
```

This means if the OCR pipeline fails to extract the name or DOB (which happens in ~8% of cases per the documented accuracy), the cross-validation is silently skipped and the result is `VALID` based on ID number alone. A stolen card with the correct number but the wrong person's face passes as VALID if OCR fails to read the name.

**Recommendation:** When `extracted_name` is null/empty after OCR, the verification result should be `manual_review` (not `valid`), prompting the cashier to manually verify the cardholder's identity. Only skip cross-validation when the scan is `manually_entered = true` (where by definition there is no card image to cross-check).

---

### C-2: Fraud Flag Payload Mismatch Breaks the Investigation Workflow

**Status:** Documented but not fixed.

The web portals send `{action, notes}` but the API expects `{decision, staff_notes}`. This is a direct functional break: fraud flag investigations submitted through the web portals do not produce the expected result in the database. The flag status may not be updated correctly, and `reviewed_by` and `reviewed_at` may not be recorded.

**Recommendation:** Fix the web portal API clients immediately. This is a 2-line change per portal file (`FraudFlagsPage.jsx` in both `apps/web-osca` and `apps/web-pdao`).

---

### C-3: Extended Beneficiary Fields Are Silently Discarded

**Status:** Documented but not fixed.

`address`, `contact_number`, `email`, and `notes` collected in Add Beneficiary forms are never persisted. Staff entering this data believe it is being saved. This is a silent data loss issue that will cause trust problems when staff notice their entries disappearing.

**Recommendation:** Add a database migration and update the API create route before the defense demonstration, or remove these fields from the forms entirely. Do not present a form that collects data that is thrown away.

---

### C-4: No Face/ID Detection Before OCR Processing

**Status:** Not implemented.

Any image — blank, unrelated, distorted — can be submitted to the OCR pipeline. The system has no guard to confirm that an ID card is actually in the image.

**Recommendation:** Add a minimum viable guard: check that the captured image is above minimum resolution AND contains at least 50 characters of recognized text before treating it as a valid ID image. The full FaceDetector integration is ideal but even a text density check is better than nothing.

---

## 5. Moderate Issues

These issues reduce system quality and reliability but do not break core functionality.

---

### M-1: Confidence Score Is a Heuristic Proxy, Not a Real OCR Confidence

The Tesseract confidence score is computed using keyword bonuses (e.g., +10% for finding "OSCA" in the text). This makes the confidence score meaningless as an objective measure — any scan of a card that has the OSCA header will receive an automatic 10% bonus even if the name and date fields are completely garbled.

The `OCR_CONFIDENCE_THRESHOLD` environment variable (default: 75) is compared against this inflated score. The practical effect is that the `manual_review` pathway is rarely triggered.

**Recommendation:** Document this clearly in the paper: the current "confidence score" is an extraction quality indicator, not a statistical confidence measure. For future work, implement HOCR output from Tesseract to obtain genuine per-character confidence, then aggregate per-field.

---

### M-2: Offline Cache Has No Documented Enforcement for SUSPICIOUS/REVOKED Freshness

The `_cacheTtl = Duration(hours: 6)` is defined in `api_service.dart` and correctly rejects stale cached results for general verifications. However, the local Hive-based blocked-IDs cache that is checked before any network call (`LocalDatabase.getCachedStatus`) does not appear to have an expiry mechanism. A beneficiary whose status was changed from `revoked` to `active` (e.g., after a successful dispute) would still be blocked by the local cache indefinitely.

**Recommendation:** Add a timestamp to each entry in the blocked-IDs Hive cache. During each successful online verification, refresh the cached status for that ID. On status_sync, clear entries older than the TTL.

---

### M-3: Processing Screen Progress Steps Are Fictional

The processing screen shows four progress steps (Analyzing 25% → Extracting 50% → Parsing 75% → Done 100%). These percentages are animated sequentially on a fixed timer, not based on actual processing completion. If step 2 (OCR extraction) takes 12 seconds, the UI shows "Parsing Data (75%)" before OCR has actually finished.

**Recommendation:** Replace the fixed-timer animation with actual completion callbacks from each pipeline stage. Emit a progress event from the OCR service when Tesseract completes, when ML Kit completes, and when field extraction completes. Bind the UI progress to these events.

---

### M-4: JWT Has No Refresh Mechanism

Staff portal sessions expire when the JWT expires. When a session expires mid-use, all unsaved form data is lost and the user is redirected to login. There is no proactive token refresh.

**Recommendation:** Add an Axios response interceptor in each React portal that detects `401 Unauthorized` responses. On detection, attempt a silent token refresh before retrying the failed request. If the refresh fails, redirect to login. This is a standard pattern for React/JWT applications.

---

### M-5: Bulk Import Has No Row Limit Feedback Before Upload

The bulk import feature accepts files up to 20,000 rows (configurable). There is no client-side file size check or row count preview before submission. A user who uploads a 50,000-row file will only learn of the limit after a potentially long upload.

**Recommendation:** Add client-side CSV parsing to count rows before upload. Display the row count and warn if it exceeds the server limit. This prevents wasted time and confusing error messages.

---

## 6. Minor Issues & Observations

### N-1: Documentation Is Contradictory on Backend Status

The `README.md` and `TECHNICAL_SUMMARY.md` both state "Backend (Planned) - Currently operates in offline mode." The system has a fully deployed Railway backend that is actively used. This outdated information should be removed from all documentation before any adviser or panel review.

### N-2: Accuracy Metrics Are Not Backed by a Structured Test Dataset

The documentation claims "92% name accuracy," "97% date of birth accuracy," etc. There is no mention of a standardized test dataset, test conditions, number of ID samples, or test methodology. These numbers appear to be derived from developer observation during development.

For a capstone paper, accuracy metrics must be supported by a reproducible test: a fixed dataset of N ID card images (N ≥ 30 is minimum; N ≥ 100 is preferred), ground-truth field values, and a measurement script. Without this, the accuracy claims are anecdotal and will not survive panel scrutiny.

### N-3: "100% Age Accuracy" Is Trivially Achieved

The documentation highlights "Age: 100% (calculated)." Age is not extracted by OCR — it is calculated from the date of birth. Reporting 100% age accuracy is misleading: the underlying DOB extraction is 97%, and the age calculation from a correct DOB is exact. "Age is derived from DOB and therefore accurate when DOB is correct" is the honest statement.

### N-4: System Title vs. Functional Scope Mismatch

The system is named "iDetect" and originally described as "a Philippine Senior Citizen ID Scanner." By the current implementation, it is a full ID verification and fraud management platform serving three LGU offices, establishments, and beneficiaries. The title and abstract of the paper should reflect the actual scope.

### N-5: The `uploads/` Directory Contains PII

The `uploads/` folder in the API stores ID card images. These images contain the cardholder's full name, photo, ID number, and date of birth — full PII. The folder appears to be served as a static directory. Any URL constructed from the UUID filename (e.g., `https://api.../uploads/abc-123.jpg`) is accessible without authentication.

This is a significant PII exposure risk. (See Security section below for the full recommendation.)

### N-6: No Logout on Both Portal Types

There is no evidence of a "logout" or "end session" flow in the mobile app for the cashier (establishment) user. The token is stored in SharedPreferences. If the cashier's phone is left unattended, any person with physical access can use the app to perform verifications under the cashier's account.

**Recommendation:** Add a session timeout on the mobile app (e.g., auto-lock after 5 minutes of inactivity) and a manual logout button in the app's settings or navigation drawer.

### N-7: Firebase Admin SDK JSON File Is Checked Into Source

The file `apps/api/idetect-bc100-firebase-adminsdk-fbsvc-cc8b7e92e1.json` is the Firebase Admin SDK service account key. This file contains a private key that grants administrative access to the Firebase project (used for push notifications). Committing this file to a repository (even a private one) is a serious security mistake.

**Recommendation:** Immediately move this credential to an environment variable or use a secrets manager. Add the file to `.gitignore`. Rotate the Firebase service account key from the Firebase Console, as the old key should be considered compromised if it has ever been in a git repository.

---

## 7. Security Review

### S-1: ID Images Are Served as Unauthenticated Static Files (Critical)

**Risk:** Full PII exposure — name, photo, ID number, date of birth are publicly accessible to anyone with the URL.

**Root Cause:** Express serves the `uploads/` directory as static files. The UUID filename is included in the fraud flag and verification log API responses (returned to authenticated portal users), but the image URL itself requires no authentication to access.

**Fix:**

```javascript
// Remove: app.use('/uploads', express.static(uploadsDir));
// Add: authenticated uploads route
router.get("/api/uploads/:filename", authenticate, (req, res) => {
  const safeFilename = path.basename(req.params.filename);
  const filePath = path.join(uploadsDir, safeFilename);
  if (!fs.existsSync(filePath)) return res.status(404).end();
  res.sendFile(filePath);
});
```

### S-2: Firebase Service Account Key Is in the Repository (Critical)

**Risk:** Anyone with access to the repository can use the service account key to send push notifications, access Firebase Firestore, and perform other Firebase operations under your project.

**Fix:** Remove the file from the repository, add it to `.gitignore`, rotate the key in Firebase Console, and inject the credentials via environment variable (`FIREBASE_SERVICE_ACCOUNT_JSON`).

### S-3: Rate Limiting Is Present on `/scan` but Not on Other Sensitive Endpoints

The `/scan` endpoint has a rate limiter (60 requests/minute/establishment). However, the following endpoints have no rate limiting:

- `POST /api/auth/login` (password brute force)
- `POST /api/fraud-flags` (flag spamming)
- `GET /api/beneficiaries` (beneficiary data harvesting)

**Fix:** Add rate limiting to all authentication and data-intensive endpoints. The login endpoint should have the strictest limit (e.g., 10 attempts/minute/IP with lockout).

### S-4: OTP Is Not Rate-Limited or Attempt-Counted at the API Level

The `beneficiary_accounts` table has `otp_attempts SMALLINT` and `otp_expires_at`, which suggests brute-force protection is planned. However, the OTP send/verify routes must enforce this — if the verify route does not decrement `otp_attempts` and lock the account after N failures, the column has no effect.

**Fix:** In the OTP verify route, increment `otp_attempts` on failure. Lock the account if `otp_attempts ≥ 5` by setting `otp_expires_at = NOW() - INTERVAL '1 second'` (effectively expiring the OTP) and requiring a new OTP request after a cooldown.

### S-5: Bulk Import Returns Plaintext Passwords in API Response

The establishment bulk import feature returns the plain-text password assigned to each establishment in the API response body. This is intentional for one-time credential distribution but creates a risk: the plaintext credentials can be captured by a proxy, logged by an API gateway, or stored in browser network history.

**Fix (pragmatic for capstone):** At minimum, add `Cache-Control: no-store` to this specific response. Ideally, return a time-limited download token and serve the credentials CSV from a separate authenticated, single-use endpoint.

### S-6: No Input Sanitization for `ocr_raw_text`

The raw OCR text is stored in `verification_logs.ocr_raw_text`. It is marked as optional and is a TEXT column. If OCR ever produces text that includes SQL-like characters or script injection payloads (possible on unusual ID designs), the use of parameterized queries (`$1, $2, ...`) protects against SQL injection. However, if this field is ever rendered directly in a web portal without escaping (e.g., displayed to an OSCA admin), it becomes an XSS vector.

**Fix:** Ensure the React portals always render this field using React's native JSX rendering (which escapes HTML by default) and never use `dangerouslySetInnerHTML` for OCR output.

---

## 8. Data Integrity Review

### D-1: ID Number Normalization Inconsistency at Storage Time

The `beneficiaries.id_number` column stores the raw ID number as entered (e.g., `OSC-2024-001`). Verification normalizes at query time using `REGEXP_REPLACE`. An expression index `idx_beneficiaries_id_number_normalized` provides a unique constraint on the normalized form.

However, the API create route for beneficiaries does not normalize `id_number` before storage. This means:

1. Two records `OSC-2024-001` and `OSC2024001` will fail the unique index — good.
2. But a query using the raw `id_number` column (without normalization) will miss one of them — bad.
3. The OSCA/PDAO portal search (if it searches by raw `id_number`) will produce incomplete results.

**Fix:** In `beneficiaries.js` create route, normalize `id_number` before storage:

```javascript
const normalizedId = id_number.toUpperCase().replace(/[^A-Z0-9]/g, "");
```

Store the normalized form. Update the display in the portal to show the original formatted version (e.g., add a `id_number_display` column for the human-readable formatted form).

### D-2: Unique Person Constraint May Block Legitimate Re-Registrations

Migration `023_unique_person_index.sql` adds a unique index on `(UPPER(full_name), birthdate, beneficiary_type)`. This prevents duplicate registration of the same person.

However, it also blocks:

- Re-registration after a status change (e.g., a revoked senior citizen who gets their record reinstated must use a different ID number but the same name and birthdate).
- Registration of two people with identical names and birthdates (rare but possible in a municipal population).

**Recommendation:** Change this from a `UNIQUE` index to a `CHECK` constraint with a more nuanced rule: enforce uniqueness only among `active` records. A partial unique index:

```sql
CREATE UNIQUE INDEX idx_beneficiaries_unique_active_person
  ON beneficiaries (UPPER(full_name), birthdate, beneficiary_type)
  WHERE status = 'active';
```

This allows re-registration after revocation while still preventing true duplicates among active records.

### D-3: `verification_logs` Is Labeled Immutable but Has No DB-Level Protection

The database dictionary states: "Immutable log of every ID verification attempt ever performed. Never delete rows." However, there is no DB-level `RULE` or `TRIGGER` preventing `DELETE` or `UPDATE` on this table. Any admin with direct database access or any future API bug that issues `DELETE FROM verification_logs` will silently destroy audit evidence.

**Fix:** Add a PostgreSQL rule:

```sql
CREATE RULE no_delete_verification_logs AS ON DELETE TO verification_logs DO INSTEAD NOTHING;
CREATE RULE no_update_verification_logs AS ON UPDATE TO verification_logs DO INSTEAD NOTHING;
```

Or use row-level security (RLS) to enforce immutability at the database level.

### D-4: No Referential Integrity for `staff_alerts`

The `staff_alerts` table (migration `022`) has a `target_role` column but no foreign key to `users.role`. If a role is ever renamed or removed, existing staff alerts become orphaned with an invalid target role, and the alert delivery query will miss them silently.

---

## 9. Research & Documentation Review

### R-1: The Paper Scope Appears Narrower Than the System Scope

The `README.md` describes iDetect as "a Philippine Senior Citizen ID Scanner." The actual system includes:

- Multi-office web portals (OSCA, PDAO, BPLO)
- Full fraud investigation workflow
- Beneficiary dispute system
- OTP-based beneficiary mobile app
- Audit logging
- Push notifications

The abstract and introduction of the paper (if it mirrors the README) significantly undersell the system. A panel will expect the paper scope to match what is being demonstrated.

**Recommendation:** Update the paper abstract and introduction to describe the full system: "iDetect is an integrated ID verification and fraud detection platform for Philippine LGU social welfare offices, comprising an OCR-based mobile scanner, a multi-portal LGU management system, and a beneficiary-facing app."

### R-2: Accuracy Claims Need a Formal Evaluation Methodology

The paper documents accuracy metrics (92% name, 97% DOB, etc.) without describing the evaluation methodology. A research paper requires:

1. **Dataset description:** How many ID images were tested? Under what conditions (lighting, distance, card condition)?
2. **Ground truth:** How was the correct value established for each field?
3. **Measurement procedure:** How was accuracy calculated (exact match? case-insensitive? fuzzy threshold?)?
4. **Comparison baseline:** Is this better or worse than using ML Kit alone? Tesseract alone?

**Recommendation:** Add an "Evaluation" section to the paper. Even a modest evaluation (30–50 real or simulated ID images, manually verified ground truth, measured field-level accuracy) provides scientific credibility that observation-based claims do not.

### R-3: The System Has No Explicitly Stated Problem Statement Boundary

The system addresses multiple problems:

1. Manual, time-consuming ID verification at establishments
2. Fraudulent ID usage for discounts
3. Lack of centralized LGU records management
4. Poor communication between establishments and LGUs about suspicious IDs

Without an explicit problem statement boundary, the paper risks appearing unfocused. Each of these is a legitimate research problem on its own. A clear articulation of which problem is primary (recommendation: #2, fraudulent ID usage) and which are secondary or enabling will strengthen the paper's coherence.

### R-4: Related Works Section Should Include ID Verification Systems from Other Countries

Philippine-specific ID verification research is sparse. The paper should include related works from similar systems in other contexts (e.g., card-based discount systems in Taiwan, South Korea's senior welfare card systems, WHO-recommended disability card systems) to establish academic context and demonstrate novelty of the iDetect approach.

### R-5: The Documentation Is Excellent but Internally Inconsistent

The team has produced extensive documentation (25+ markdown files). However:

- `README.md` says backend is "planned/future."
- `TECHNICAL_DOCUMENTATION.md` says backend is production on Railway.
- `FUNCTIONAL_REQUIREMENTS_REVIEW_GUIDE.md` lists FR-06 as "Partial" but the payload mismatch has not been fixed.
- `TECHNICAL_REVIEW_AND_IMPROVEMENT_PLAN.md` lists fixes — some are done (cross-validation, rate limiting, auto-restore on dismiss), some are not (uploads authentication, collusion detection, JWT refresh).

**Recommendation:** Create a single "STATUS TRACKER" document that lists every known issue/improvement and its current state (Fixed / In Progress / Planned / Deferred). Review it before the defense. This shows academic rigor and prevents contradicting yourself in front of the panel.

---

## 10. Suggested Improvements & Solutions

### Priority 1 — Must Fix Before Defense

| #   | Issue                                                      | Solution                                                                                             | Effort |
| --- | ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- | ------ |
| 1   | C-1: Cross-validation not enforced when OCR fails name/DOB | When `extracted_name` is null after OCR, return `manual_review` instead of `valid`                   | Low    |
| 2   | C-2: Fraud flag payload mismatch                           | Change `action` → `decision` and `notes` → `staff_notes` in both portal `FraudFlagsPage.jsx`         | Low    |
| 3   | C-3: Extended beneficiary fields silently discarded        | Add migration for `address, contact_number, email, notes` columns; update create route               | Medium |
| 4   | N-5 / S-1: Unauthenticated uploads directory               | Remove static serving; add authenticated `GET /api/uploads/:file` route                              | Low    |
| 5   | N-7 / S-2: Firebase key in repository                      | Remove file, add to `.gitignore`, rotate key, use env var                                            | Low    |
| 6   | M-1: Confidence is heuristic — misleading documentation    | Clarify in paper and docs: this is an extraction quality indicator, not a statistical OCR confidence | Low    |
| 7   | M-5: Status label `inactive` broken in web portal          | Replace with `revoked` or map to `status IN ('expired', 'revoked')`                                  | Low    |
| 8   | N-1: Outdated "backend is planned" text in docs            | Update README and TECHNICAL_SUMMARY                                                                  | Low    |
| 9   | R-2: Accuracy claims without methodology                   | Add a structured evaluation section with test set description                                        | Medium |

### Priority 2 — Should Fix Before Defense (Improves Score)

| #   | Issue                                               | Solution                                                             | Effort |
| --- | --------------------------------------------------- | -------------------------------------------------------------------- | ------ |
| 10  | Gap 6: ID type must be pre-selected                 | Auto-populate from OCR header keywords; require only confirmation    | Medium |
| 11  | Gap 8: SUSPICIOUS provides no guidance              | Add mandatory action panel to result screen                          | Low    |
| 12  | Gap 9 / C-4: No face/ID detection guard             | Add text-density check or FaceDetector before OCR                    | Medium |
| 13  | M-3: Processing progress is fake                    | Bind progress to actual pipeline callbacks                           | Medium |
| 14  | M-4: No JWT refresh                                 | Add Axios response interceptor for 401 handling in React portals     | Low    |
| 15  | Gap 7: Manual entry unmonitored                     | Add dashboard indicator and audit log entry for manual verifications | Medium |
| 16  | D-2: Unique person constraint blocks reinstatements | Change to partial unique index on active records only                | Low    |

### Priority 3 — Post-Defense / Production Hardening

| #   | Issue                                                | Solution                                                  | Effort |
| --- | ---------------------------------------------------- | --------------------------------------------------------- | ------ |
| 17  | Gap 16: OTP SMS not integrated                       | Integrate Semaphore or ITEXMO for Philippine SMS          | Medium |
| 18  | Gap 11: Collusion detection                          | Add `owner_group` to establishments; count by group       | High   |
| 19  | Gap 12: No flag time decay                           | Add cron job to auto-expire 180-day-old pending flags     | Low    |
| 20  | Gap 13: Two-step flag submission                     | Pre-fill and open flag form on SUSPICIOUS result          | Low    |
| 21  | D-3: verification_logs not DB-protected immutability | Add PostgreSQL RULE to prevent DELETE/UPDATE              | Low    |
| 22  | Gap 4: Image temp file cleanup                       | Delete temp files after verification log is saved         | Low    |
| 23  | Gap 5: No OCR timeout                                | Add 20-second timeout; fall back to ML Kit only           | Low    |
| 24  | N-6: No mobile session timeout                       | Add inactivity timeout + manual logout to mobile app      | Medium |
| 25  | S-3: No rate limit on login/fraud endpoints          | Add `express-rate-limit` to auth and fraud-flag endpoints | Low    |

---

## 11. Defense Readiness Assessment

The following questions are likely to be asked by a technically-minded panel member. Each is assessed based on the current system state.

| Panel Question                                              | Current System's Honest Answer                                                                                                   | Recommended Prepared Answer                                                                                                                                                                                                                |
| ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| "What stops someone from using another person's ID number?" | Cross-validation checks name and DOB — but only if OCR extracted them. If OCR fails, the check is skipped and VALID is returned. | "We implemented name fuzzy-matching and DOB exact-matching using the Jaro-Winkler algorithm. Scans that fail to extract name or DOB are downgraded to manual_review, requiring staff physical inspection." (Fix C-1 first.)                |
| "Can someone present a photocopy of an ID?"                 | A photocopy with the correct ID number, a name that fuzzy-matches, and the correct DOB would currently pass as VALID.            | "A perfect photocopy would pass our digital checks. The system's defense is the establishment cashier, who is required to physically verify the card, and the fraud flag system for reporting suspicious presentations."                   |
| "How accurate is your OCR?"                                 | 92% name, 97% DOB — but these are developer observations, not structured evaluations.                                            | "We tested on [N] ID images under [conditions] and measured field-level accuracy. Results are tabulated in Table [X] of the paper." (Complete the structured evaluation.)                                                                  |
| "What happens if the establishment has no internet?"        | The system falls back to a 6-hour local Hive cache. If no cache entry exists, verification fails.                                | "The system supports 6-hour offline operation using a local status cache. Scans attempted beyond the cache window require connectivity."                                                                                                   |
| "Are the ID images stored securely?"                        | Currently stored as unauthenticated static files accessible to anyone with the URL.                                              | "ID images are stored on the server and accessible only through authenticated API endpoints." (Fix S-1 first.)                                                                                                                             |
| "What if an establishment submits false fraud flags?"       | Three coordinated establishments can auto-suspend any beneficiary. The beneficiary is restored when all flags are dismissed.     | "The system requires 3 distinct establishments to independently flag an ID. False flags dismissed by OSCA/PDAO staff trigger automatic reinstatement of the beneficiary."                                                                  |
| "How does PDAO track disability types?"                     | `disability_type` is stored in the beneficiaries table. Address/contact/notes are collected in the form but discarded.           | "PDAO records include disability type, which is stored and used for analytics. Extended profile fields such as address are currently tracked in the UI and planned for the next database migration." (Fix C-3 or be honest about the gap.) |

---

## 12. Summary Scorecard

| Dimension                          | Score  | Comments                                                                         |
| ---------------------------------- | ------ | -------------------------------------------------------------------------------- |
| **Problem Relevance**              | 9/10   | Real, important problem. Clear beneficiary population.                           |
| **System Completeness**            | 6/10   | Core scan-verify loop works. Several workflows are partial or broken.            |
| **OCR Pipeline Design**            | 8/10   | Well-engineered. Issues are mostly in confidence calibration and zone fragility. |
| **Verification Logic Correctness** | 7/10   | Cross-validation implemented but not enforced when OCR partially fails.          |
| **Fraud Detection Workflow**       | 6/10   | Well-designed conceptually. Payload mismatch breaks web portal integration.      |
| **Database Design**                | 8/10   | Strong schema. Minor integrity issues (immutability, normalization).             |
| **Security**                       | 4/10   | Unauthenticated uploads and Firebase key in repo are serious issues.             |
| **Data Integrity**                 | 6/10   | Silent data loss on extended profile fields. Status taxonomy mismatch.           |
| **Documentation Quality**          | 7/10   | Extensive but contradictory in places. Needs a single source of truth.           |
| **Research Rigor**                 | 5/10   | Accuracy claims lack methodology. Scope is broader than abstract suggests.       |
| **Overall Readiness**              | 6.5/10 | Strong foundation with fixable gaps. Fix Priority 1 items before defense.        |

---

## Final Remarks

iDetect demonstrates genuine engineering capability. The team clearly understands the problem domain, made informed technology choices (Flutter, dual OCR, PostgreSQL, JWT auth), and produced a coherent multi-component system. The OCR pipeline is the strongest part of the project — the multi-layer fallback design is the kind of pragmatic engineering that real OCR systems use.

The gaps are real but fixable. Most of the Priority 1 fixes are low-effort changes (a few lines each). The most important thing for the defense is to resolve the internal contradictions in the documentation and the system, and to demonstrate an honest awareness of limitations rather than overstating capabilities.

**To the team:** You have built something substantive. Be proud of it. But prepare to discuss its limitations confidently. A panel will respect "we know this limitation and here is our plan to address it" far more than discovering an uncommunicated gap.

---

_This critique was generated through a full code and documentation review of the iDetect repository as of May 6, 2026. All referenced file paths correspond to actual files in the workspace._
