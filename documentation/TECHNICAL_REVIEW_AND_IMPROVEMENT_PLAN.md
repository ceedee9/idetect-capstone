# iDetect — Technical Review & Improvement Plan

**Reviewed:** April 29, 2026  
**Status:** Pending Implementation

---

## I. EXECUTIVE SUMMARY

iDetect is a well-structured system with a solid database schema, a sophisticated OCR pipeline, and a complete fraud reporting workflow. However, there is a **fundamental design gap that undermines the core verification premise**: the system confirms only that an ID number exists in the database. It does not confirm that the person holding the ID is the legitimate owner of that ID.

Everything else is built correctly — but the lookup itself is insufficient.

---

## II. THE CENTRAL PROBLEM: ID Number Lookup Is Not Enough

### What the system currently does

When an establishment scans an ID, the entire decision reduces to:

> "Does this ID number exist in `beneficiaries` with `status = active` and not expired?"

If yes → **VALID**. Discount granted.

### How this is exploitable

| Scenario                    | How it works                                    | Result               |
| --------------------------- | ----------------------------------------------- | -------------------- |
| Shared ID number            | Person copies a number from a friend's card     | System returns VALID |
| Printed/photocopied replica | Any replica with a legible ID number passes OCR | System returns VALID |
| Manual entry abuse          | Dishonest cashier types a number they know      | System returns VALID |

### What the OCR pipeline extracts but the verification endpoint NEVER uses

| Field           | Senior Citizen | PWD              | In DB? | Compared to DB? |
| --------------- | -------------- | ---------------- | ------ | --------------- |
| ID Number       | `controlNo`    | `idNumber`       | ✅     | ✅              |
| Full Name       | `fullName`     | `fullName`       | ✅     | ❌ **NEVER**    |
| Date of Birth   | `dateOfBirth`  | ❌ Not extracted | ✅     | ❌ **NEVER**    |
| Disability Type | —              | `disabilityType` | ✅     | ❌ **NEVER**    |
| Date Issued     | `dateIssued`   | —                | ✅     | ❌ **NEVER**    |

The mobile app sends only `id_number` and `beneficiary_type` to the server. All other OCR-extracted fields are discarded. This means a card with any valid ID number printed on it returns VALID regardless of whose name or photo appears.

### Fix

After the ID number lookup returns a beneficiary record, **cross-validate the extracted fields against the stored record** before returning VALID:

1. Fuzzy-match `ocr_name` against `beneficiaries.full_name` (Jaro-Winkler ≥ 0.80 threshold).
2. Exact-match `ocr_dob` (date of birth) against `beneficiaries.birthdate`.
3. If either check fails → return **SUSPICIOUS**, not VALID.

**What to change:**

- Flutter: Send `extracted_name` and `extracted_dob` fields in the `/scan` request body.
- API (`verification.js`): Accept and validate these fields; compare them to the DB record. Add a `name_match_score` and `dob_match` to the verification log.
- DB (`verification_logs`): Add columns `extracted_name VARCHAR(255)`, `extracted_dob DATE`, `name_match_score NUMERIC(4,3)`, `fields_matched BOOLEAN`.

---

## III. OCR PIPELINE — ISSUES

### 1. Layout zones are hardcoded to one ID design

`layout_based_field_extractor.dart` has constants like `NAME_TOP = 0.24`, `CTRL_LEFT = 0.65` calibrated for the current Valenzuela OSCA card. If the LGU updates the card design, all zones break silently.

**Fix:** Version-stamp the zone definitions. If the template validation score drops below threshold, fall back to the fuzzy parser and flag the scan for staff review, rather than silently returning a low-confidence extraction.

### 2. PWD ID number regex is fragile

`\b\d{2}-\d{4}-\d{3}-\d{4,8}\b` — if OCR misreads a single digit as a letter (`0→O`, `1→I`, `5→S`), the regex fails. No secondary recovery exists for PWD ID number extraction.

**Fix:** Before running the regex, apply a character substitution pass: replace `O→0`, `I→1`, `l→1`, `S→5` in the candidate string, then retry the regex.

### 3. `manually_entered` flag is an unmonitored loophole

Manual entries bypass the entire OCR pipeline. A dishonest staff member can type any number they know. Manual entries look identical to scanned entries in dashboards.

**Fix:**

- In the BPLO dashboard, visually distinguish manual entries (different icon/color).
- Log manual entries to `audit_logs` with a separate action type `verification_manual`.
- Consider requiring a supervisor confirmation tap before a manual entry is accepted.

### 4. Accuracy claims describe text extraction, not verification accuracy

The "97% accuracy" refers to how accurately fields are extracted from the card image — not how accurately an impostor is detected. These must be communicated as different metrics in any documentation or defense presentation.

---

## IV. FRAUD FLAG SYSTEM — ISSUES

### 1. Auto-suspend is not automatically reversed

When 3 distinct establishments flag an ID, it is auto-suspended. If all 3 flags are later dismissed (legitimate ID, wrongful reports), the beneficiary remains suspended until an admin manually clicks restore. There is no logic that says "all active flags dismissed → restore to active."

**Fix:** In the `/fraud-flags/:id/review` (dismiss) handler, after setting a flag to `dismissed`, recount pending/reviewing flags for that `beneficiary_id`. If count is 0 AND the beneficiary's `status_reason` contains `auto_suspended: true` in the audit log, automatically set status back to `active` and log the restoration.

### 2. No LGU alert when auto-suspend fires

The beneficiary gets a push notification. OSCA/PDAO portal staff do not. Staff must manually notice the new flag or check the beneficiary's status.

**Fix:** When auto-suspend triggers in `fraudFlags.js`, use `fcmService` to also send a push notification to all active staff accounts for the relevant LGU portal (OSCA for `senior_citizen`, PDAO for `pwd`).

### 3. Collusion between establishments is not detected

Three establishments under the same owner can coordinate to auto-suspend any beneficiary. The system counts `DISTINCT establishment_id`, not `DISTINCT owner`.

**Fix (long-term):** Add an `owner_id` or `establishment_group_id` column to the `establishments` table. Count `DISTINCT owner_id` instead of (or in addition to) `DISTINCT establishment_id` for the threshold check.

### 4. Two-step flag submission reduces real-world compliance

After a SUSPICIOUS result, staff must navigate to a separate Flag screen to submit a report. In busy cashier environments, most staff will not do this second step.

**Fix:** When the scan result is SUSPICIOUS or INVALID, automatically pre-fill and open the flag submission form with the verification log ID, image, and detected ID number already attached. Staff only needs to tap "Confirm Report."

### 5. No time-decay on pending flags

A flag from 18 months ago, never reviewed, still counts toward the auto-suspend threshold indefinitely.

**Fix:** Add a scheduled job (the cron scheduler already exists in the API) that runs daily and sets flags older than 180 days with `flag_status = 'pending'` to `dismissed`, with `staff_notes = 'Auto-expired: exceeded review window'`.

---

## V. DATABASE DESIGN — ISSUES

### 1. ID number uniqueness is on raw string, not normalized form

`beneficiaries.id_number` has a `UNIQUE` constraint on the raw value. Verification normalizes at query time (`REGEXP_REPLACE(..., '[^A-Za-z0-9]', '', 'g')`). Storing `OSC-2024-001` and `OSC2024001` passes the UNIQUE constraint but both match the same verification query — creating duplicate records for the same ID.

**Fix:** Normalize on insert at the API layer (`beneficiaries.js` create route). Strip all non-alphanumeric characters and uppercase before insertion. Add a unique index on the normalized form or add a `GENERATED ALWAYS AS` column with the normalized value.

### 2. No uniqueness constraint on (full_name, birthdate, beneficiary_type)

The same person can be registered multiple times with different ID numbers. No DB-level protection exists.

**Fix (medium-term):** Add a partial unique index:

```sql
CREATE UNIQUE INDEX idx_beneficiaries_unique_person
  ON beneficiaries (UPPER(full_name), birthdate, beneficiary_type);
```

This prevents accidental duplicate registration of the same person.

### 3. Manual status changes may not be in audit_logs

The auto-suspend writes to `audit_logs`. It is unclear whether manual admin status changes (OSCA/PDAO suspending or revoking a beneficiary from the portal) also write to `audit_logs`. If not, manual changes are untracked.

**Fix:** Verify that the OSCA/PDAO beneficiary update routes (`PATCH /beneficiaries/:id/status`) include an `INSERT INTO audit_logs` call. Add it if missing.

### 4. Offline cache has no documented or enforced TTL

`status_sync_service.dart` exists but the cache invalidation window is not documented. A beneficiary suspended at 10am can still pass as VALID on a device that last synced at 9am.

**Fix:** Define and enforce a maximum cache age (recommendation: 6 hours for beneficiary status). On the sync service, reject cached records older than the TTL and require a fresh fetch before returning a result. Display "Offline mode — last synced X hours ago" to the cashier.

---

## VI. SECURITY ISSUES

### 1. ID images are served as unauthenticated static files

Images saved to `uploads/` are accessible to anyone with the URL — no authentication required. These images contain full PII: name, photo, ID number, birthdate.

**Fix:** Remove static file serving for `uploads/`. Create an authenticated route `GET /api/uploads/:filename` that validates the requesting user's JWT before streaming the file.

### 2. No rate limiting on `/scan`

A compromised establishment account can enumerate valid IDs by calling `/scan` in a loop.

**Fix:** Add `express-rate-limit` to the scan endpoint:

```js
// 60 scans per minute per establishment
rateLimit({
  windowMs: 60_000,
  max: 60,
  keyGenerator: (req) => req.establishment.id,
});
```

### 3. Bulk import returns plaintext passwords in API response

Intentional (one-time display), but the plaintext credential is in the API response body and could be captured by logs or proxies.

**Fix (long-term):** Return a one-time download token from the API instead of the passwords directly. The token resolves to the credentials CSV from an authenticated endpoint that expires after first download or after 15 minutes.

### 4. No JWT refresh mechanism

When a token expires mid-session, all unsaved portal work is lost. No proactive refresh or revocation exists.

**Fix:** Add a response interceptor in each React portal (`axios` interceptor) that checks the token expiry (`exp` claim) before each request. If expiry is within 5 minutes, silently call `POST /auth/refresh` before the main request.

---

## VII. REAL-WORLD PROCESS GAPS

### 1. ID type must be selected before scanning

Cashiers must know (or guess) if the customer is Senior Citizen or PWD before scanning. Selecting the wrong type returns `invalid` even for a valid ID. The cross-database conflict detection only helps if the same number appears in both databases.

**Fix:** Auto-detect the ID type from OCR. The header text on the card contains "OSCA" or "SENIOR CITIZEN" vs "PWD." Use the already-extracted header keyword list (`HEADER_KEYWORDS` in `layout_based_field_extractor.dart`) to infer the type and pre-select it, requiring only confirmation from the cashier.

### 2. No basic face presence check

ML Kit's `FaceDetector` is already available in the dependency tree. A completely blank or non-ID image should not produce a VALID result.

**Fix:** Before sending to the OCR pipeline, run `FaceDetector` on the captured image. If no face is detected, require the cashier to recapture. This costs nothing additional to integrate and closes the "scan a blank card" vector.

### 3. SUSPICIOUS result gives no action guidance

The scan result screen shows a color and a message but no instruction to the cashier. In practice, cashiers will be uncertain what to do.

**Fix:** Add a contextual action panel to the SUSPICIOUS result screen:

- "Ask the customer for a secondary ID"
- "Call your manager"
- "Tap below to report this ID"
- Do not approve the discount

---

## VIII. PRIORITY IMPLEMENTATION ORDER

### Phase 1 — Must Fix Before Defense

| #   | Item                                                            | Files to Change                                                                     |
| --- | --------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| 1   | Cross-validate extracted name + DOB against DB record           | `verification.js`, Flutter scan flow, migration for new `verification_logs` columns |
| 2   | Normalize `id_number` before storage; unique on normalized form | `beneficiaries.js` (create route), new migration                                    |
| 3   | Rate-limit `/scan` endpoint                                     | `verification.js` + install `express-rate-limit`                                    |
| 4   | Auto-restore beneficiary when all flags dismissed               | `fraudFlags.js` (review/dismiss handler)                                            |

### Phase 2 — Fix After Defense / Before Production

| #   | Item                                                | Files to Change                                                    |
| --- | --------------------------------------------------- | ------------------------------------------------------------------ |
| 5   | Authenticate uploads (remove public static serving) | `app.js` or main Express entry, new `GET /api/uploads/:file` route |
| 6   | LGU push notification on auto-suspend               | `fraudFlags.js` POST, `fcmService.js`                              |
| 7   | One-tap flag on SUSPICIOUS result                   | Flutter `result_screen.dart`                                       |
| 8   | Flag time-decay cron job                            | New scheduled task in `apps/api/src/`                              |
| 9   | PWD ID regex with character substitution fallback   | `pwd_layout_field_extractor.dart`                                  |
| 10  | Manual entry audit log + dashboard indicator        | `verification.js`, BPLO portal history view                        |

### Phase 3 — Long-Term / Production Hardening

| #   | Item                                                                  | Files to Change                                        |
| --- | --------------------------------------------------------------------- | ------------------------------------------------------ |
| 11  | JWT refresh (silent, via interceptor)                                 | Each React portal's `api.js` or Axios setup            |
| 12  | Bulk import: one-time download token instead of plaintext in response | `establishments.js`, new token endpoint                |
| 13  | Establishment group / owner-level flag collusion detection            | New migration + `fraudFlags.js` threshold query        |
| 14  | Offline cache TTL enforcement                                         | `status_sync_service.dart`                             |
| 15  | Auto-detect ID type from card header                                  | Flutter scan flow, `layout_based_field_extractor.dart` |
| 16  | SUSPICIOUS result action guidance panel                               | Flutter `result_screen.dart`                           |

---

## IX. KEY QUESTIONS FOR PANEL DEFENSE

These are the questions most likely to come from a technically-minded panel member, and the expected answers based on the current system state:

| Question                                                    | Current Answer                               | Target Answer After Fixes                           |
| ----------------------------------------------------------- | -------------------------------------------- | --------------------------------------------------- |
| "What stops someone from using another person's ID number?" | Only the fraud flag system (reactive)        | OCR name + DOB cross-validation (proactive)         |
| "What happens if someone presents a printed replica?"       | Returns VALID if ID number is correct        | Returns SUSPICIOUS if name or DOB doesn't match     |
| "How does the system know who is holding the card?"         | It doesn't                                   | Fuzzy name match + DOB match against DB record      |
| "Can a cashier just type in a random valid number?"         | Yes, undetected                              | Yes, but flagged in audit log for supervisor review |
| "What if the 3 flags are all wrong?"                        | Beneficiary stays suspended until admin acts | Auto-restores when all flags are dismissed          |
| "Are the ID images protected?"                              | No — anyone with the URL can view them       | Behind authenticated endpoint only                  |
