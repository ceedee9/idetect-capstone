# Database Dictionary

**Project:** iDetect  
**Database:** PostgreSQL  
**Last Updated:** May 4, 2026

This document describes every table, column, enumerated type, and index in the iDetect database. The schema is built incrementally through 23 migration files located in `apps/api/migrations/`.

---

## Table of Contents

1. [Enumerated Types](#1-enumerated-types)
2. [Tables](#2-tables)
   - [users](#21-users)
   - [establishments](#22-establishments)
   - [beneficiaries](#23-beneficiaries)
   - [beneficiary_accounts](#24-beneficiary_accounts)
   - [verification_logs](#25-verification_logs)
   - [fraud_flags](#26-fraud_flags)
   - [disputes](#27-disputes)
   - [notifications](#28-notifications)
   - [audit_logs](#29-audit_logs)
   - [staff_alerts](#210-staff_alerts)
3. [Indexes Summary](#3-indexes-summary)
4. [Entity Relationships](#4-entity-relationships)

---

## 1. Enumerated Types

### `user_role`

Controls which admin portal a staff account can access.

| Value        | Description                                          |
| ------------ | ---------------------------------------------------- |
| `bplo_admin` | Business Permit and Licensing Office administrator   |
| `osca_admin` | Office for Senior Citizens Affairs administrator     |
| `pdao_admin` | Persons with Disability Affairs Office administrator |

---

### `establishment_status`

Lifecycle state of a business account.

| Value       | Description                        |
| ----------- | ---------------------------------- |
| `pending`   | Registered, awaiting BPLO approval |
| `approved`  | Active; can perform verifications  |
| `suspended` | Temporarily blocked by BPLO        |
| `revoked`   | Permanently removed                |

---

### `beneficiary_type`

Determines which LGU office owns a beneficiary record.

| Value            | Description     |
| ---------------- | --------------- |
| `senior_citizen` | Managed by OSCA |
| `pwd`            | Managed by PDAO |

---

### `beneficiary_status`

Current validity state of a beneficiary record.

| Value       | Description                               |
| ----------- | ----------------------------------------- |
| `active`    | Valid; verifications return `valid`       |
| `expired`   | Past `validity_end` date                  |
| `suspended` | Temporarily flagged pending investigation |
| `revoked`   | Confirmed fraudulent or cancelled by LGU  |

---

### `verification_result`

Outcome of a single ID verification attempt.

| Value           | Description                                                                        |
| --------------- | ---------------------------------------------------------------------------------- |
| `valid`         | ID found in DB, status active, not expired                                         |
| `suspicious`    | ID found but status is flagged/suspended, or cross-validation fields did not match |
| `invalid`       | ID not found in DB, or status is `revoked`/`expired`                               |
| `manual_review` | OCR confidence too low; staff reviewed manually                                    |

---

### `flag_status`

Investigation state of a fraud flag.

| Value       | Description                                      |
| ----------- | ------------------------------------------------ |
| `pending`   | Flagged by establishment, awaiting LGU review    |
| `reviewing` | LGU admin has opened the case                    |
| `confirmed` | Confirmed fraudulent; beneficiary record updated |
| `dismissed` | Investigated and found to be legitimate          |

---

### `dispute_type`

Category of a beneficiary-submitted dispute.

| Value               | Description                                       |
| ------------------- | ------------------------------------------------- |
| `wrong_denial`      | Beneficiary claims they are valid but were denied |
| `unauthorized_use`  | Beneficiary's ID was used without their knowledge |
| `business_refusal`  | Business refused despite system approval          |
| `incorrect_db_info` | Beneficiary's record contains wrong information   |

---

### `dispute_status`

Resolution state of a dispute.

| Value          | Description                             |
| -------------- | --------------------------------------- |
| `submitted`    | Just received                           |
| `acknowledged` | LGU confirmed receipt (within 24 h SLA) |
| `under_review` | Staff actively investigating            |
| `resolved`     | Closed with explanation                 |
| `rejected`     | Dispute found to be invalid             |

---

### `notification_channel`

Delivery mechanism for a notification.

| Value  | Description                                                              |
| ------ | ------------------------------------------------------------------------ |
| `push` | Firebase FCM / APNs push notification (requires app and data connection) |
| `sms`  | SMS (works without smartphone or data connection)                        |

---

### `notification_type`

Category of event that triggered a notification.

| Value                   | Description                                                       |
| ----------------------- | ----------------------------------------------------------------- |
| `verification_approved` | ID was scanned and returned `valid`                               |
| `verification_denied`   | ID was scanned and returned `suspicious` or `invalid`             |
| `dispute_acknowledged`  | LGU acknowledged the beneficiary's dispute                        |
| `dispute_resolved`      | Dispute has been closed                                           |
| `flag_confirmed`        | Beneficiary's ID was confirmed fraudulent (unauthorized use case) |
| `id_expiring_soon`      | Upcoming expiration reminder                                      |
| `general`               | Miscellaneous system message                                      |

---

### `audit_action`

Complete set of tracked administrative events.

| Value                           | Category                 |
| ------------------------------- | ------------------------ |
| `login`                         | Auth                     |
| `logout`                        | Auth                     |
| `password_changed`              | Auth                     |
| `otp_requested`                 | Auth                     |
| `otp_verified`                  | Auth                     |
| `account_locked`                | Auth                     |
| `account_unlocked`              | Auth                     |
| `beneficiary_created`           | Beneficiary management   |
| `beneficiary_updated`           | Beneficiary management   |
| `beneficiary_status_changed`    | Beneficiary management   |
| `establishment_created`         | Establishment management |
| `establishment_approved`        | Establishment management |
| `establishment_suspended`       | Establishment management |
| `establishment_revoked`         | Establishment management |
| `establishment_self_registered` | Establishment management |
| `establishment_bulk_import`     | Establishment management |
| `flag_created`                  | Fraud flag actions       |
| `flag_reviewed`                 | Fraud flag actions       |
| `flag_confirmed`                | Fraud flag actions       |
| `flag_dismissed`                | Fraud flag actions       |
| `flag_restored`                 | Fraud flag actions       |
| `dispute_submitted`             | Dispute actions          |
| `dispute_acknowledged`          | Dispute actions          |
| `dispute_resolved`              | Dispute actions          |
| `dispute_rejected`              | Dispute actions          |
| `staff_created`                 | Staff management         |
| `staff_updated`                 | Staff management         |
| `staff_activated`               | Staff management         |
| `staff_deactivated`             | Staff management         |
| `staff_password_reset`          | Staff management         |
| `verification_performed`        | Verification             |
| `data_export`                   | System                   |
| `report_generated`              | System                   |

---

## 2. Tables

### 2.1 `users`

**Description:** Admin staff accounts for BPLO, OSCA, and PDAO portals.  
**Source migration:** `001_create_users.sql`, `016_add_login_lockout.sql`

| Column            | Type           | Nullable | Default             | Description                                                                                                       |
| ----------------- | -------------- | -------- | ------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `id`              | `UUID`         | NOT NULL | `gen_random_uuid()` | Primary key                                                                                                       |
| `email`           | `VARCHAR(255)` | NOT NULL | —                   | Login email address. Unique across all staff accounts.                                                            |
| `password_hash`   | `VARCHAR(255)` | NOT NULL | —                   | Bcrypt hash of the user's password.                                                                               |
| `full_name`       | `VARCHAR(255)` | NOT NULL | —                   | Display name shown in the portal.                                                                                 |
| `role`            | `user_role`    | NOT NULL | —                   | Controls which portal the user can access and which data is visible.                                              |
| `is_active`       | `BOOLEAN`      | NOT NULL | `TRUE`              | Soft-disable accounts without deleting audit history.                                                             |
| `failed_attempts` | `SMALLINT`     | NOT NULL | `0`                 | Count of consecutive failed login attempts. Reset on successful login.                                            |
| `locked_until`    | `TIMESTAMPTZ`  | NULL     | —                   | Timestamp until which the account is locked. `NULL` means not locked. Locked after 3 failed attempts (REQ-2.1.4). |
| `created_at`      | `TIMESTAMPTZ`  | NOT NULL | `NOW()`             | Row creation timestamp.                                                                                           |
| `updated_at`      | `TIMESTAMPTZ`  | NOT NULL | `NOW()`             | Auto-updated by trigger `trg_users_updated_at` on any change.                                                     |

**Indexes:**

- `idx_users_email` — on `(email)`
- `idx_users_role` — on `(role)`

---

### 2.2 `establishments`

**Description:** Food service businesses registered to use the Client Portal. Managed by BPLO.  
**Source migration:** `002_create_establishments.sql`, `016_add_login_lockout.sql`, `018_establishment_permit_and_reset.sql`

| Column                   | Type                   | Nullable | Default             | Description                                                                                                     |
| ------------------------ | ---------------------- | -------- | ------------------- | --------------------------------------------------------------------------------------------------------------- |
| `id`                     | `UUID`                 | NOT NULL | `gen_random_uuid()` | Primary key                                                                                                     |
| `email`                  | `VARCHAR(255)`         | NOT NULL | —                   | Login email for the Client Portal. Unique per establishment.                                                    |
| `password_hash`          | `VARCHAR(255)`         | NOT NULL | —                   | Bcrypt hash of the establishment's password.                                                                    |
| `business_name`          | `VARCHAR(255)`         | NOT NULL | —                   | Registered name of the business.                                                                                |
| `business_permit_no`     | `VARCHAR(100)`         | NOT NULL | —                   | Unique business permit number issued by BPLO.                                                                   |
| `owner_name`             | `VARCHAR(255)`         | NOT NULL | —                   | Name of the business owner.                                                                                     |
| `address`                | `TEXT`                 | NOT NULL | —                   | Full business address.                                                                                          |
| `contact_number`         | `VARCHAR(20)`          | NOT NULL | —                   | Primary contact phone number.                                                                                   |
| `business_type`          | `VARCHAR(100)`         | NOT NULL | `'Food Service'`    | Category of business.                                                                                           |
| `status`                 | `establishment_status` | NOT NULL | `'pending'`         | Only `approved` establishments can perform ID verifications.                                                    |
| `approved_by`            | `UUID`                 | NULL     | —                   | FK → `users.id`. BPLO admin who approved this account. `SET NULL` on user deletion.                             |
| `approved_at`            | `TIMESTAMPTZ`          | NULL     | —                   | Timestamp when the account was approved.                                                                        |
| `suspended_reason`       | `TEXT`                 | NULL     | —                   | Reason provided when status is set to `suspended`.                                                              |
| `failed_attempts`        | `SMALLINT`             | NOT NULL | `0`                 | Count of consecutive failed login attempts. Reset on successful login.                                          |
| `locked_until`           | `TIMESTAMPTZ`          | NULL     | —                   | Timestamp until which the login is locked. `NULL` means not locked. Locked after 3 failed attempts (REQ-2.1.4). |
| `business_permit_expiry` | `DATE`                 | NULL     | —                   | Expiry date of the business permit (REQ-2.2.5).                                                                 |
| `reset_otp`              | `VARCHAR(6)`           | NULL     | —                   | One-time password for self-service password reset (REQ-2.2.6).                                                  |
| `reset_otp_expires`      | `TIMESTAMPTZ`          | NULL     | —                   | Expiry timestamp for `reset_otp`.                                                                               |
| `created_at`             | `TIMESTAMPTZ`          | NOT NULL | `NOW()`             | Row creation timestamp.                                                                                         |
| `updated_at`             | `TIMESTAMPTZ`          | NOT NULL | `NOW()`             | Auto-updated by trigger `trg_establishments_updated_at`.                                                        |

**Indexes:**

- `idx_establishments_status` — on `(status)`
- `idx_establishments_permit_no` — on `(business_permit_no)`

---

### 2.3 `beneficiaries`

**Description:** Official government records for Senior Citizens and PWDs. Source of truth maintained by OSCA and PDAO.  
**Source migration:** `003_create_beneficiaries.sql`, `011_add_disability_type.sql`, `021_cross_validation_and_normalization.sql`, `023_unique_person_index.sql`

| Column              | Type                 | Nullable | Default             | Description                                                                                                                                                                  |
| ------------------- | -------------------- | -------- | ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`                | `UUID`               | NOT NULL | `gen_random_uuid()` | Primary key                                                                                                                                                                  |
| `id_number`         | `VARCHAR(50)`        | NOT NULL | —                   | The ID number printed on the physical card. Primary lookup key during verification. Unique; also enforced as unique after normalization (strip non-alphanumeric, uppercase). |
| `full_name`         | `VARCHAR(255)`       | NOT NULL | —                   | Full name as it appears on the physical ID.                                                                                                                                  |
| `birthdate`         | `DATE`               | NOT NULL | —                   | Date of birth. Used for identity cross-validation during verification.                                                                                                       |
| `beneficiary_type`  | `beneficiary_type`   | NOT NULL | —                   | Determines owning office: `senior_citizen` → OSCA, `pwd` → PDAO.                                                                                                             |
| `disability_type`   | `VARCHAR(100)`       | NULL     | —                   | Type of disability (e.g. visual, hearing, mental, physical, psychosocial, learning, speech). Only populated for `pwd` records.                                               |
| `issuing_office`    | `VARCHAR(255)`       | NOT NULL | —                   | LGU office that issued the card (e.g. "OSCA Valenzuela").                                                                                                                    |
| `validity_start`    | `DATE`               | NOT NULL | —                   | Start date of the card's validity period.                                                                                                                                    |
| `validity_end`      | `DATE`               | NOT NULL | —                   | End date of the card's validity period. Records past this date are automatically `expired`.                                                                                  |
| `status`            | `beneficiary_status` | NOT NULL | `'active'`          | Only `active` records return `valid` during verification.                                                                                                                    |
| `status_reason`     | `TEXT`               | NULL     | —                   | Explanation text filled when status is `suspended` or `revoked`.                                                                                                             |
| `registered_mobile` | `VARCHAR(20)`        | NULL     | —                   | Mobile number for SMS notifications. Optional.                                                                                                                               |
| `created_by`        | `UUID`               | NULL     | —                   | FK → `users.id`. Staff member who created this record. `SET NULL` on user deletion.                                                                                          |
| `updated_by`        | `UUID`               | NULL     | —                   | FK → `users.id`. Staff member who last updated this record. `SET NULL` on user deletion.                                                                                     |
| `created_at`        | `TIMESTAMPTZ`        | NOT NULL | `NOW()`             | Row creation timestamp.                                                                                                                                                      |
| `updated_at`        | `TIMESTAMPTZ`        | NOT NULL | `NOW()`             | Auto-updated by trigger `trg_beneficiaries_updated_at`.                                                                                                                      |

**Indexes:**

- `idx_beneficiaries_id_number` — on `(id_number)`
- `idx_beneficiaries_type` — on `(beneficiary_type)`
- `idx_beneficiaries_status` — on `(status)`
- `idx_beneficiaries_type_status` — on `(beneficiary_type, status)`
- `idx_beneficiaries_id_number_normalized` _(unique)_ — on `UPPER(REGEXP_REPLACE(id_number, '[^A-Za-z0-9]', '', 'g'))` — prevents duplicate IDs that differ only in punctuation (e.g. `OSC-2024-001` vs `OSC2024001`)
- `idx_beneficiaries_unique_person` _(unique)_ — on `(UPPER(full_name), birthdate, beneficiary_type)` — prevents duplicate registration of the same person in the same category

---

### 2.4 `beneficiary_accounts`

**Description:** App accounts for Senior Citizens and PWDs using the Beneficiary Mobile App. Intentionally separated from `beneficiaries`; a beneficiary exists in the system even without an app account.  
**Source migration:** `004_create_beneficiary_accounts.sql`, `010_add_pin_to_beneficiary_accounts.sql`

| Column             | Type           | Nullable | Default             | Description                                                                      |
| ------------------ | -------------- | -------- | ------------------- | -------------------------------------------------------------------------------- |
| `id`               | `UUID`         | NOT NULL | `gen_random_uuid()` | Primary key                                                                      |
| `beneficiary_id`   | `UUID`         | NOT NULL | —                   | FK → `beneficiaries.id`. One-to-one. Cascades on beneficiary deletion.           |
| `device_token`     | `VARCHAR(255)` | NULL     | —                   | FCM/APNs push notification token. Updated on each app launch.                    |
| `last_login`       | `TIMESTAMPTZ`  | NULL     | —                   | Timestamp of the most recent successful login.                                   |
| `is_active`        | `BOOLEAN`      | NOT NULL | `TRUE`              | Whether the app account is enabled.                                              |
| `otp_hash`         | `VARCHAR(255)` | NULL     | —                   | Hashed OTP for the current login session. Cleared after successful verification. |
| `otp_expires_at`   | `TIMESTAMPTZ`  | NULL     | —                   | Expiry timestamp for the current OTP.                                            |
| `otp_attempts`     | `SMALLINT`     | NOT NULL | `0`                 | Failed OTP attempts for the current session. Locked after threshold.             |
| `pin_hash`         | `VARCHAR(255)` | NULL     | —                   | Bcrypt-hashed 4-digit PIN for fallback login when biometrics are unavailable.    |
| `pin_attempts`     | `SMALLINT`     | NOT NULL | `0`                 | Failed PIN attempts. Account PIN-locked after 5 consecutive failures.            |
| `pin_locked_until` | `TIMESTAMPTZ`  | NULL     | —                   | Timestamp until which PIN login is locked. `NULL` means not locked.              |
| `created_at`       | `TIMESTAMPTZ`  | NOT NULL | `NOW()`             | Row creation timestamp.                                                          |
| `updated_at`       | `TIMESTAMPTZ`  | NOT NULL | `NOW()`             | Auto-updated by trigger `trg_beneficiary_accounts_updated_at`.                   |

**Indexes:**

- `idx_beneficiary_accounts_beneficiary_id` — on `(beneficiary_id)`

---

### 2.5 `verification_logs`

**Description:** Immutable log of every ID verification attempt ever performed. Never delete rows. Source of fraud analytics and the beneficiary's transaction history view.  
**Source migration:** `005_create_verification_logs.sql`, `015_image_path_to_text.sql`, `021_cross_validation_and_normalization.sql`

| Column                      | Type                  | Nullable | Default             | Description                                                                                                                                                           |
| --------------------------- | --------------------- | -------- | ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`                        | `UUID`                | NOT NULL | `gen_random_uuid()` | Primary key                                                                                                                                                           |
| `establishment_id`          | `UUID`                | NOT NULL | —                   | FK → `establishments.id`. The establishment that performed the scan. `RESTRICT` on deletion.                                                                          |
| `beneficiary_id`            | `UUID`                | NULL     | —                   | FK → `beneficiaries.id`. `NULL` when `id_number_scanned` does not match any record. `SET NULL` on beneficiary deletion.                                               |
| `id_number_scanned`         | `VARCHAR(50)`         | NOT NULL | —                   | The raw ID number read by OCR or entered manually.                                                                                                                    |
| `beneficiary_type_detected` | `beneficiary_type`    | NULL     | —                   | Beneficiary type detected from the card image (senior_citizen or pwd).                                                                                                |
| `result`                    | `verification_result` | NOT NULL | —                   | Outcome of this verification attempt.                                                                                                                                 |
| `ocr_confidence_score`      | `NUMERIC(5,2)`        | NULL     | —                   | Tesseract confidence score from 0.00 to 100.00. Below threshold triggers `manual_review` result.                                                                      |
| `ocr_raw_text`              | `TEXT`                | NULL     | —                   | Full raw OCR output for debugging and post-hoc analysis.                                                                                                              |
| `image_path`                | `TEXT`                | NULL     | —                   | Full URL to the stored ID image (Cloudinary). Widened from `VARCHAR(500)` in migration 015.                                                                           |
| `manually_entered`          | `BOOLEAN`             | NOT NULL | `FALSE`             | `TRUE` when the ID number was typed by staff instead of scanned by OCR.                                                                                               |
| `extracted_name`            | `VARCHAR(255)`        | NULL     | —                   | Full name as read from the card by OCR. Compared against `beneficiaries.full_name` for cross-validation.                                                              |
| `extracted_dob`             | `DATE`                | NULL     | —                   | Date of birth as read from the card by OCR. Compared against `beneficiaries.birthdate`.                                                                               |
| `name_match_score`          | `NUMERIC(4,3)`        | NULL     | —                   | Jaro-Winkler similarity score (0.000–1.000) between `extracted_name` and the stored full name. `NULL` when no name cross-validation was attempted.                    |
| `fields_matched`            | `BOOLEAN`             | NULL     | —                   | `TRUE` when all cross-validation fields matched. `FALSE` if any mismatch downgraded the result to `suspicious`. `NULL` when no cross-validation fields were provided. |
| `verified_at`               | `TIMESTAMPTZ`         | NOT NULL | `NOW()`             | Timestamp of the verification attempt.                                                                                                                                |

**Indexes:**

- `idx_verification_logs_establishment_id` — on `(establishment_id)`
- `idx_verification_logs_beneficiary_id` — on `(beneficiary_id)`
- `idx_verification_logs_id_number` — on `(id_number_scanned)`
- `idx_verification_logs_result` — on `(result)`
- `idx_verification_logs_verified_at` — on `(verified_at DESC)`
- `idx_verification_logs_est_date` — on `(establishment_id, verified_at DESC)` — optimizes per-establishment analytics dashboards

---

### 2.6 `fraud_flags`

**Description:** Suspicious ID reports submitted by establishments, routed to OSCA or PDAO for investigation. When status reaches `confirmed`, the linked beneficiary's status is set to `suspended` or `revoked`.  
**Source migration:** `006_create_fraud_flags.sql`, `013_fraud_flags_denormalize.sql`, `014_fraud_flags_duplicate_detection.sql`, `015_image_path_to_text.sql`

| Column                 | Type                  | Nullable | Default             | Description                                                                                                                                           |
| ---------------------- | --------------------- | -------- | ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`                   | `UUID`                | NOT NULL | `gen_random_uuid()` | Primary key                                                                                                                                           |
| `verification_log_id`  | `UUID`                | NOT NULL | —                   | FK → `verification_logs.id`. The scan that triggered this flag. `RESTRICT` on deletion.                                                               |
| `establishment_id`     | `UUID`                | NOT NULL | —                   | FK → `establishments.id`. The establishment that submitted the flag. `RESTRICT` on deletion.                                                          |
| `beneficiary_id`       | `UUID`                | NULL     | —                   | FK → `beneficiaries.id`. `NULL` if no matching DB record was found. `SET NULL` on beneficiary deletion.                                               |
| `id_number_flagged`    | `VARCHAR(50)`         | NOT NULL | —                   | Stored directly so flagged IDs can be tracked even if no matching record exists.                                                                      |
| `beneficiary_type`     | `beneficiary_type`    | NOT NULL | —                   | Routes this flag to the correct portal: `senior_citizen` → OSCA, `pwd` → PDAO.                                                                        |
| `flag_status`          | `flag_status`         | NOT NULL | `'pending'`         | Current investigation state.                                                                                                                          |
| `establishment_notes`  | `TEXT`                | NULL     | —                   | Optional notes from the establishment when submitting the flag.                                                                                       |
| `staff_notes`          | `TEXT`                | NULL     | —                   | Notes added by the OSCA/PDAO investigator.                                                                                                            |
| `reviewed_by`          | `UUID`                | NULL     | —                   | FK → `users.id`. Staff member who reviewed this flag. `SET NULL` on user deletion.                                                                    |
| `image_path`           | `TEXT`                | NULL     | —                   | Denormalized from `verification_logs` for quick access. URL to the captured ID image.                                                                 |
| `verification_outcome` | `verification_result` | NULL     | —                   | Denormalized from `verification_logs`. The result at time of flagging.                                                                                |
| `parent_flag_id`       | `UUID`                | NULL     | —                   | FK → `fraud_flags.id`. Links supplementary reports to the original investigation. `NULL` if this is the original flag. `SET NULL` on parent deletion. |
| `is_supplementary`     | `BOOLEAN`             | NOT NULL | `FALSE`             | `TRUE` if this report was linked to an existing active investigation instead of creating a new case (REQ-2.6.6).                                      |
| `flagged_at`           | `TIMESTAMPTZ`         | NOT NULL | `NOW()`             | Timestamp when the flag was submitted.                                                                                                                |
| `reviewed_at`          | `TIMESTAMPTZ`         | NULL     | —                   | Timestamp when the flag was last reviewed by staff.                                                                                                   |

**Indexes:**

- `idx_fraud_flags_status` — on `(flag_status)`
- `idx_fraud_flags_beneficiary_type` — on `(beneficiary_type)`
- `idx_fraud_flags_beneficiary_id` — on `(beneficiary_id)`
- `idx_fraud_flags_flagged_at` — on `(flagged_at DESC)`
- `idx_fraud_flags_type_status` — on `(beneficiary_type, flag_status)` — portal query: OSCA sees pending senior_citizen flags
- `idx_fraud_flags_image_path` — partial index on `(image_path) WHERE image_path IS NOT NULL`
- `idx_fraud_flags_parent` — on `(parent_flag_id)`
- `idx_fraud_flags_supplementary` — on `(is_supplementary, flag_status)`
- `idx_fraud_flags_active_by_id` — partial on `(id_number_flagged, flag_status) WHERE flag_status IN ('pending', 'reviewing')` — quickly finds active investigations for a given ID number

---

### 2.7 `disputes`

**Description:** Beneficiary-submitted challenges to incorrect denials or database errors. Submitted via the Beneficiary Mobile App and routed to OSCA or PDAO. SLA: 24 h acknowledgment, 48–72 h resolution.  
**Source migration:** `007_create_disputes.sql`

| Column                   | Type             | Nullable | Default             | Description                                                                                          |
| ------------------------ | ---------------- | -------- | ------------------- | ---------------------------------------------------------------------------------------------------- |
| `id`                     | `UUID`           | NOT NULL | `gen_random_uuid()` | Primary key                                                                                          |
| `beneficiary_account_id` | `UUID`           | NOT NULL | —                   | FK → `beneficiary_accounts.id`. The app account that submitted this dispute. `RESTRICT` on deletion. |
| `verification_log_id`    | `UUID`           | NULL     | —                   | FK → `verification_logs.id`. The transaction being disputed. `SET NULL` on log deletion.             |
| `dispute_type`           | `dispute_type`   | NOT NULL | —                   | Category of the dispute.                                                                             |
| `explanation`            | `TEXT`           | NOT NULL | —                   | Beneficiary's written explanation of their dispute.                                                  |
| `supporting_doc_path`    | `VARCHAR(500)`   | NULL     | —                   | Cloudinary URL to an uploaded supporting document (e.g. ID photo, barangay certificate).             |
| `status`                 | `dispute_status` | NOT NULL | `'submitted'`       | Current resolution state.                                                                            |
| `staff_response`         | `TEXT`           | NULL     | —                   | Official response written by the handling staff member.                                              |
| `handled_by`             | `UUID`           | NULL     | —                   | FK → `users.id`. Staff member handling this dispute. `SET NULL` on user deletion.                    |
| `submitted_at`           | `TIMESTAMPTZ`    | NOT NULL | `NOW()`             | Timestamp of submission.                                                                             |
| `acknowledged_at`        | `TIMESTAMPTZ`    | NULL     | —                   | Must be filled within 24 hours of submission per SLA.                                                |
| `resolved_at`            | `TIMESTAMPTZ`    | NULL     | —                   | Target: 48–72 hours from submission for database error disputes.                                     |

**Indexes:**

- `idx_disputes_beneficiary_account_id` — on `(beneficiary_account_id)`
- `idx_disputes_status` — on `(status)`
- `idx_disputes_submitted_at` — on `(submitted_at DESC)`

---

### 2.8 `notifications`

**Description:** Push and SMS alerts sent to beneficiaries on each verification attempt and key system events. The real-time transparency mechanism: every scan triggers a notification to the beneficiary (if they have an account).  
**Source migration:** `008_create_notifications.sql`

| Column                   | Type                   | Nullable | Default             | Description                                                                                                            |
| ------------------------ | ---------------------- | -------- | ------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `id`                     | `UUID`                 | NOT NULL | `gen_random_uuid()` | Primary key                                                                                                            |
| `beneficiary_account_id` | `UUID`                 | NOT NULL | —                   | FK → `beneficiary_accounts.id`. The recipient's app account. Cascades on account deletion.                             |
| `notification_type`      | `notification_type`    | NOT NULL | —                   | Category of event that triggered this notification.                                                                    |
| `title`                  | `VARCHAR(255)`         | NOT NULL | —                   | Short title of the notification (shown in push banner).                                                                |
| `body`                   | `TEXT`                 | NOT NULL | —                   | Full message body.                                                                                                     |
| `channel`                | `notification_channel` | NOT NULL | —                   | Delivery method: `push` or `sms`.                                                                                      |
| `verification_log_id`    | `UUID`                 | NULL     | —                   | FK → `verification_logs.id`. Enables deep-linking from notification to transaction in-app. `SET NULL` on log deletion. |
| `dispute_id`             | `UUID`                 | NULL     | —                   | FK → `disputes.id`. Enables deep-linking from notification to dispute in-app. `SET NULL` on dispute deletion.          |
| `is_read`                | `BOOLEAN`              | NOT NULL | `FALSE`             | Whether the notification has been read by the beneficiary.                                                             |
| `sent_at`                | `TIMESTAMPTZ`          | NOT NULL | `NOW()`             | Timestamp when the notification was sent.                                                                              |

**Indexes:**

- `idx_notifications_account_id` — on `(beneficiary_account_id)`
- `idx_notifications_is_read` — on `(beneficiary_account_id, is_read)` — optimizes unread count queries
- `idx_notifications_sent_at` — on `(sent_at DESC)`

---

### 2.9 `audit_logs`

**Description:** Immutable audit trail of every administrative action. No row in this table should ever be updated or deleted. Required for ISO 25010 Security — Non-repudiation.  
**Source migration:** `009_create_audit_logs.sql`

| Column             | Type           | Nullable | Default             | Description                                                                                                                    |
| ------------------ | -------------- | -------- | ------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `id`               | `UUID`         | NOT NULL | `gen_random_uuid()` | Primary key                                                                                                                    |
| `user_id`          | `UUID`         | NULL     | —                   | FK → `users.id`. Staff member who performed the action. `NULL` for system-generated entries. `SET NULL` on user deletion.      |
| `establishment_id` | `UUID`         | NULL     | —                   | FK → `establishments.id`. Establishment that performed the action (e.g. a verification). `SET NULL` on establishment deletion. |
| `action`           | `audit_action` | NOT NULL | —                   | The type of event that occurred.                                                                                               |
| `target_table`     | `VARCHAR(100)` | NULL     | —                   | Name of the database table affected (e.g. `beneficiaries`).                                                                    |
| `target_id`        | `UUID`         | NULL     | —                   | UUID of the affected row (e.g. the `beneficiary_id` that was updated).                                                         |
| `metadata`         | `JSONB`        | NOT NULL | `'{}'`              | Full context blob: previous values, new values, request details.                                                               |
| `ip_address`       | `INET`         | NULL     | —                   | IP address of the client that performed the action.                                                                            |
| `user_agent`       | `TEXT`         | NULL     | —                   | HTTP User-Agent string of the client.                                                                                          |
| `created_at`       | `TIMESTAMPTZ`  | NOT NULL | `NOW()`             | Timestamp of the event. No `updated_at` — rows must never change.                                                              |

**Indexes:**

- `idx_audit_logs_user_id` — on `(user_id)`
- `idx_audit_logs_action` — on `(action)`
- `idx_audit_logs_target` — on `(target_table, target_id)`
- `idx_audit_logs_created_at` — on `(created_at DESC)`

---

### 2.10 `staff_alerts`

**Description:** In-portal notification system for LGU admin staff. Rows are inserted by the API when notable system events occur (e.g. auto-suspension triggered by a fraud flag threshold). Portals poll this table to surface dismissible alert banners.  
**Source migration:** `022_staff_alerts.sql`

| Column                   | Type           | Nullable | Default             | Description                                                                                       |
| ------------------------ | -------------- | -------- | ------------------- | ------------------------------------------------------------------------------------------------- |
| `id`                     | `UUID`         | NOT NULL | `gen_random_uuid()` | Primary key                                                                                       |
| `target_role`            | `user_role`    | NOT NULL | —                   | The staff role this alert is addressed to: `osca_admin` or `pdao_admin`.                          |
| `title`                  | `VARCHAR(255)` | NOT NULL | —                   | Short title of the alert.                                                                         |
| `body`                   | `TEXT`         | NOT NULL | —                   | Full alert message.                                                                               |
| `related_beneficiary_id` | `UUID`         | NULL     | —                   | FK → `beneficiaries.id`. The beneficiary this alert concerns. `SET NULL` on beneficiary deletion. |
| `is_read`                | `BOOLEAN`      | NOT NULL | `FALSE`             | Whether the alert has been dismissed by staff.                                                    |
| `created_at`             | `TIMESTAMPTZ`  | NOT NULL | `NOW()`             | Timestamp when the alert was created.                                                             |

**Indexes:**

- `idx_staff_alerts_role_read` — on `(target_role, is_read, created_at DESC)` — fast lookup for unread alerts per role, newest first

---

## 3. Indexes Summary

| Index Name                                | Table                  | Columns                                           | Type              | Notes                                   |
| ----------------------------------------- | ---------------------- | ------------------------------------------------- | ----------------- | --------------------------------------- |
| `idx_users_email`                         | `users`                | `(email)`                                         | B-tree            | Login lookup                            |
| `idx_users_role`                          | `users`                | `(role)`                                          | B-tree            | Portal filtering                        |
| `idx_establishments_status`               | `establishments`       | `(status)`                                        | B-tree            | Approval queue                          |
| `idx_establishments_permit_no`            | `establishments`       | `(business_permit_no)`                            | B-tree            | Permit lookup                           |
| `idx_beneficiaries_id_number`             | `beneficiaries`        | `(id_number)`                                     | B-tree            | Primary verification lookup             |
| `idx_beneficiaries_type`                  | `beneficiaries`        | `(beneficiary_type)`                              | B-tree            | Portal filtering                        |
| `idx_beneficiaries_status`                | `beneficiaries`        | `(status)`                                        | B-tree            | Status filtering                        |
| `idx_beneficiaries_type_status`           | `beneficiaries`        | `(beneficiary_type, status)`                      | B-tree            | Composite portal query                  |
| `idx_beneficiaries_id_number_normalized`  | `beneficiaries`        | `UPPER(REGEXP_REPLACE(...))`                      | Unique expression | Prevents punctuation-variant duplicates |
| `idx_beneficiaries_unique_person`         | `beneficiaries`        | `(UPPER(full_name), birthdate, beneficiary_type)` | Unique expression | Prevents duplicate person registration  |
| `idx_beneficiary_accounts_beneficiary_id` | `beneficiary_accounts` | `(beneficiary_id)`                                | B-tree            | Account lookup                          |
| `idx_verification_logs_establishment_id`  | `verification_logs`    | `(establishment_id)`                              | B-tree            | Per-establishment history               |
| `idx_verification_logs_beneficiary_id`    | `verification_logs`    | `(beneficiary_id)`                                | B-tree            | Per-beneficiary history                 |
| `idx_verification_logs_id_number`         | `verification_logs`    | `(id_number_scanned)`                             | B-tree            | ID number lookup                        |
| `idx_verification_logs_result`            | `verification_logs`    | `(result)`                                        | B-tree            | Analytics filtering                     |
| `idx_verification_logs_verified_at`       | `verification_logs`    | `(verified_at DESC)`                              | B-tree            | Time-ordered listing                    |
| `idx_verification_logs_est_date`          | `verification_logs`    | `(establishment_id, verified_at DESC)`            | B-tree            | Per-establishment dashboard             |
| `idx_fraud_flags_status`                  | `fraud_flags`          | `(flag_status)`                                   | B-tree            | Pending case queue                      |
| `idx_fraud_flags_beneficiary_type`        | `fraud_flags`          | `(beneficiary_type)`                              | B-tree            | Portal routing                          |
| `idx_fraud_flags_beneficiary_id`          | `fraud_flags`          | `(beneficiary_id)`                                | B-tree            | Per-beneficiary flags                   |
| `idx_fraud_flags_flagged_at`              | `fraud_flags`          | `(flagged_at DESC)`                               | B-tree            | Time-ordered listing                    |
| `idx_fraud_flags_type_status`             | `fraud_flags`          | `(beneficiary_type, flag_status)`                 | B-tree            | Composite portal queue                  |
| `idx_fraud_flags_image_path`              | `fraud_flags`          | `(image_path)`                                    | Partial B-tree    | WHERE image_path IS NOT NULL            |
| `idx_fraud_flags_parent`                  | `fraud_flags`          | `(parent_flag_id)`                                | B-tree            | Supplementary flag lookup               |
| `idx_fraud_flags_supplementary`           | `fraud_flags`          | `(is_supplementary, flag_status)`                 | B-tree            | Dedup detection                         |
| `idx_fraud_flags_active_by_id`            | `fraud_flags`          | `(id_number_flagged, flag_status)`                | Partial B-tree    | WHERE status IN ('pending','reviewing') |
| `idx_disputes_beneficiary_account_id`     | `disputes`             | `(beneficiary_account_id)`                        | B-tree            | Per-beneficiary disputes                |
| `idx_disputes_status`                     | `disputes`             | `(status)`                                        | B-tree            | Case queue                              |
| `idx_disputes_submitted_at`               | `disputes`             | `(submitted_at DESC)`                             | B-tree            | Time-ordered listing                    |
| `idx_notifications_account_id`            | `notifications`        | `(beneficiary_account_id)`                        | B-tree            | Per-user inbox                          |
| `idx_notifications_is_read`               | `notifications`        | `(beneficiary_account_id, is_read)`               | B-tree            | Unread count                            |
| `idx_notifications_sent_at`               | `notifications`        | `(sent_at DESC)`                                  | B-tree            | Time-ordered listing                    |
| `idx_audit_logs_user_id`                  | `audit_logs`           | `(user_id)`                                       | B-tree            | Per-user audit trail                    |
| `idx_audit_logs_action`                   | `audit_logs`           | `(action)`                                        | B-tree            | Action filtering                        |
| `idx_audit_logs_target`                   | `audit_logs`           | `(target_table, target_id)`                       | B-tree            | Record history lookup                   |
| `idx_audit_logs_created_at`               | `audit_logs`           | `(created_at DESC)`                               | B-tree            | Time-ordered listing                    |
| `idx_staff_alerts_role_read`              | `staff_alerts`         | `(target_role, is_read, created_at DESC)`         | B-tree            | Unread alerts per role                  |

---

## 4. Entity Relationships

```
users ──────────────────────────────────────────────────────────────────┐
  │ approved_by                                                          │
  ▼                                                                      │
establishments ──────────────────────────────────────────────────┐      │
  │ establishment_id                                              │      │
  ▼                                                              │      │
verification_logs ◄──────────── fraud_flags ◄──────────┐        │      │
  │ beneficiary_id     │            │ reviewed_by       │        │      │
  │                    │            ▼                   │        │      │
  │                 verification  users             parent_flag  │      │
  │                 _log_id                                       │      │
  ▼                                                               │      │
beneficiaries ◄────────────────────────────────────────────┘      │      │
  │ beneficiary_id     created_by / updated_by ──────────────────┘      │
  ▼                                                                      │
beneficiary_accounts                                                     │
  │                                                                      │
  ├── notifications (deep-link → verification_logs, disputes)            │
  │                                                                      │
  └── disputes ──── handled_by ──────────────────────────────────────────┘
                    verification_log_id → verification_logs

staff_alerts ──── related_beneficiary_id → beneficiaries
audit_logs   ──── user_id → users
             ──── establishment_id → establishments
```

### Foreign Key Summary

| Table                  | Column                   | References                 | On Delete |
| ---------------------- | ------------------------ | -------------------------- | --------- |
| `establishments`       | `approved_by`            | `users(id)`                | SET NULL  |
| `beneficiaries`        | `created_by`             | `users(id)`                | SET NULL  |
| `beneficiaries`        | `updated_by`             | `users(id)`                | SET NULL  |
| `beneficiary_accounts` | `beneficiary_id`         | `beneficiaries(id)`        | CASCADE   |
| `verification_logs`    | `establishment_id`       | `establishments(id)`       | RESTRICT  |
| `verification_logs`    | `beneficiary_id`         | `beneficiaries(id)`        | SET NULL  |
| `fraud_flags`          | `verification_log_id`    | `verification_logs(id)`    | RESTRICT  |
| `fraud_flags`          | `establishment_id`       | `establishments(id)`       | RESTRICT  |
| `fraud_flags`          | `beneficiary_id`         | `beneficiaries(id)`        | SET NULL  |
| `fraud_flags`          | `reviewed_by`            | `users(id)`                | SET NULL  |
| `fraud_flags`          | `parent_flag_id`         | `fraud_flags(id)`          | SET NULL  |
| `disputes`             | `beneficiary_account_id` | `beneficiary_accounts(id)` | RESTRICT  |
| `disputes`             | `verification_log_id`    | `verification_logs(id)`    | SET NULL  |
| `disputes`             | `handled_by`             | `users(id)`                | SET NULL  |
| `notifications`        | `beneficiary_account_id` | `beneficiary_accounts(id)` | CASCADE   |
| `notifications`        | `verification_log_id`    | `verification_logs(id)`    | SET NULL  |
| `notifications`        | `dispute_id`             | `disputes(id)`             | SET NULL  |
| `audit_logs`           | `user_id`                | `users(id)`                | SET NULL  |
| `audit_logs`           | `establishment_id`       | `establishments(id)`       | SET NULL  |
| `staff_alerts`         | `related_beneficiary_id` | `beneficiaries(id)`        | SET NULL  |
