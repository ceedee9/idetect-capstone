# iDetect ID Validation Criteria - Simple Guide

This guide explains how iDetect decides whether a scanned ID is **VALID**, **SUSPICIOUS**, **INVALID**, or **MANUAL REVIEW**. It was checked against the code in `apps/api/src/routes/verification.js` and the app code in `lib/services/`.

---

## 1. The short answer

An ID number match alone is **not** enough to return VALID. A VALID result needs all of these:

1. The ID number exists in the records **for the same beneficiary type** (for example, Senior Citizen).
2. The record is **active** and **not expired**.
3. If the scan read a name or date of birth, both **agree with the record**.
4. The scan was **clear enough**: OCR quality is 75% or higher, and a new-format ID has its seal detected.

If any of these fail, the result is downgraded or changed.

---

## 2. What the scan sends to the server

The app sends one scan with:

| Field | Meaning |
|---|---|
| ID number | The ID number read from the card (normalized before matching) |
| Beneficiary type | The type the staff member selected or the app detected |
| Extracted name | Name read by OCR (optional) |
| Extracted date of birth | DOB read by OCR (optional) |
| OCR confidence | Quality score from 0 to 100 (the app converts 0 to 1 values to 0 to 100) |
| Seal detected | Whether the government seal was found (new-format IDs only) |
| Manually entered | True if staff typed the data in instead of scanning |

---

## 3. The steps, in order

### Step 1 - Normalize and match the ID number

The ID number is converted to uppercase and all symbols and spaces are removed. So `ab-12 34` and `AB1234` are the same ID.

The system then looks for that ID in the records **of the same beneficiary type**.

### Step 2 - ID not found for this type

- If the ID exists under **another** beneficiary type, the result is **SUSPICIOUS**. The message starts with "Cross-database conflict", which means the card is being used as a different type of beneficiary.
- If the ID exists nowhere, the result is **INVALID**.

### Step 3 - ID found: check the status

| Record status | Result |
|---|---|
| Active, not expired | Continue to the next steps (may end as VALID) |
| Active, but expired | **INVALID** (the validity end date has passed) |
| Suspended | **SUSPICIOUS** |
| Revoked | **INVALID** |
| Any other status | **INVALID** |

### Step 4 - Name and date of birth check

- **No name and no DOB read by OCR, and not manually entered:** the result becomes **MANUAL REVIEW**. The system has nothing to compare, so staff must check the card.
- **Name and/or DOB read by OCR:** the system compares them with the record.
  - **Name:** the Jaro-Winkler similarity score must be **0.80 or higher**. This tolerates small OCR mistakes, such as one wrong letter. The comparison ignores capital letters.
  - **DOB:** must match the record **exactly**.
  - If either check fails, the result is **SUSPICIOUS**, with a message that says which field did not match.

### Step 5 - OCR quality check

- If OCR confidence is **below 75%** and the data was **not** manually entered, a VALID result becomes **MANUAL REVIEW**.
- The threshold can be changed with the `OCR_CONFIDENCE_THRESHOLD` setting on the server. The default is 75.

### Step 6 - Seal check (new-format IDs only)

- Staff also see a "Government seal not detected" warning on the review screen. It appears only for new-format IDs. For old-format IDs, no seal is expected, so no warning is shown.

---

## 4. The four results and what staff should do

| Result | Meaning | What staff should do |
|---|---|---|
| **VALID** | Record matches, active, not expired, and all checks pass | Apply the discount |
| **MANUAL REVIEW** | Nothing could be checked, or the scan was not clear enough | Look at the physical ID and decide |
| **SUSPICIOUS** | Something does not match: wrong type, name or DOB mismatch, or suspended | Do not apply the discount until checked. Escalate if needed |
| **INVALID** | ID not found, expired, or revoked | Do not apply the discount |

---

## 5. Example scenarios

These results apply once the date-of-birth check is working. The check was fixed as part of this review (see section 6).

| Scenario | Result |
|---|---|
| ID found, active, name and DOB match, OCR 90% | VALID |
| ID found, active, name and DOB match, OCR 60% | MANUAL REVIEW |
| ID found, active, OCR read no name or DOB | MANUAL REVIEW |
| ID found, active, OCR name is very different | SUSPICIOUS |
| ID found, active, DOB differs by one day | SUSPICIOUS |
| ID found, suspended | SUSPICIOUS |
| ID found, revoked | INVALID |
| ID found, validity end date has passed | INVALID |
| ID found under a different beneficiary type | SUSPICIOUS (Cross-database conflict) |
| ID not in any record | INVALID |

---

## 6. Fixed during this review, and remaining limits

**Fixed:**

1. **Date-of-birth check crashed.** The scan query did not select `birthdate`, so a DOB read by OCR caused `new Date(undefined).toISOString()` to throw, and the scan returned a server error. The query now selects `birthdate`.
2. **Date-of-birth check was off by one day on some servers.** The database returns a DATE as local midnight. On a server in UTC+8, converting that with `toISOString()` gives the previous day, so a correct DOB would be SUSPICIOUS. The comparison now reads the local calendar date, which gives the same result in any timezone.

**Remaining limits:**

1. **Wording.** The server message says "Cross-database conflict", but the system and manuscript call this a cross-type check. The server checks this exact text, so the wording should be changed in both places together.
2. **Name matching is similarity-based.** A score of 0.80 allows small OCR errors. It is not proof of identity, which is why a name mismatch gives SUSPICIOUS instead of INVALID.
3. **The OCR threshold is enforced on the server only.** The device has OCR confidence constants (70% and 50%), but nothing on the phone uses them to block a scan. The 75% rule in Step 5 is the one that decides the result.

---

## 7. Summary

- ID number match **plus** same type **plus** active **plus** not expired is the minimum for a result.
- Name and DOB are compared when OCR reads them, so a valid number on the wrong person is caught.
- Unclear scans are sent to **MANUAL REVIEW**, never silently accepted.
- Staff always have the final word on MANUAL REVIEW.
