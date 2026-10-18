# Notification Event Catalog (A-06)

Status: DRAFT for review. No code changes yet.

Scope: every event that should notify a person, who receives it, and over which channel. Audited against the current code (`apps/api`).

Rules for every notification (from A-06 acceptance):
- Each cataloged event produces a notification to the stated recipient.
- Delivery is logged (`notifications` table for beneficiaries; `audit_logs` for staff and establishments).
- Messages carry no unmasked ID number. Use the short dispute/report reference only.

## 1. Beneficiary notifications

| # | Event | Trigger (code) | Recipient | Channel | Type | Status |
|---|-------|----------------|-----------|---------|------|--------|
| B1 | ID verified (approved) | `routes/verification.js` ~512 | Beneficiary account | Push, SMS | `verification_approved` | Built |
| B2 | ID denied (suspicious or invalid) | `routes/verification.js` ~512 | Beneficiary account | Push, SMS | `verification_denied` | Built |
| B3 | Dispute received | `routes/disputes.js` ~218 | Beneficiary account | Push | `dispute_submitted` | Built |
| B4 | Dispute acknowledged by staff | `routes/disputes.js` ~444 | Beneficiary account | Push, SMS | `dispute_acknowledged` | Built |
| B5 | Dispute resolved or rejected | `routes/disputes.js` ~589 | Beneficiary account | Push, SMS | `dispute_resolved` | Built |
| B6 | Dispute delayed (SLA missed) | `services/slaEscalationScheduler.js` ~50, ~120 | Beneficiary account | Push | `dispute_escalated` | Built |
| B7 | Fraud report received | `routes/beneficiaryPortal.js` ~226 | Beneficiary account | Push | `fraud_report_received` | Fixed: migration 057 and startup statement |
| B8 | Fraud flag confirmed or ID under investigation | `routes/fraudFlags.js` ~243 | Beneficiary account | Push | `flag_confirmed` | Built |
| B9 | Callback request handled | `routes/callbackRequests.js` ~181 | Beneficiary account | Push | `callback_request_handled` | Built |
| B10 | ID expiring soon | `services/expiryAlertScheduler.js` ~90 | Beneficiary account | Push | `id_expiring_soon` | Built |
| B11 | Beneficiary status changed to suspended or reinstated | `routes/beneficiaries.js` `notifyBeneficiaryStatusChange` | Beneficiary account | Push, SMS | Built (migration-free, logged to `notifications`) |
| B12 | Dispute response acknowledged by beneficiary | Not built | Staff queue (not beneficiary) | In-app | none | **NEW (per your decision: yes)** |

## 2. Staff notifications (staff alerts)

| # | Event | Trigger (code) | Recipient | Channel | Status |
|---|-------|----------------|-----------|---------|--------|
| S1 | Dispute submitted, senior citizen | Trigger `048`/`049` | `osca_admin` | In-app staff alert | Built |
| S2 | Dispute submitted, PWD | Trigger `048`/`049` | `pdao_admin` | In-app staff alert | Built |
| S3 | Business refusal submitted | Trigger `048`/`049` | `bplo_admin` + office role | In-app staff alert | Built |
| S4 | Fraud flag raised | Trigger `049` (`notify_staff_of_fraud_flag`) | Staff alert recipients | In-app staff alert | Built |
| S5 | Establishment registered | Trigger `049` | BPLO staff | In-app staff alert | Built |
| S6 | Dispute acknowledgement overdue (24h) | `slaEscalationScheduler.js` ~50 | Office staff | Staff alert + audit | Built |
| S7 | Dispute resolution overdue (72h) | `slaEscalationScheduler.js` ~120 | Office staff | Staff alert + audit | Built |
| S8 | Callback request received | Not checked in this pass | BPLO staff | In-app | To verify |
| S9 | Dispute assigned or claimed (A-09) | Not built | Claimant and queue | In-app | Planned under A-09 |

## 3. Establishment notifications

| # | Event | Trigger (code) | Recipient | Channel | Status |
|---|-------|----------------|-----------|---------|--------|
| E1 | Establishment suspended | `routes/establishments.js` ~761–796 | Establishment `contact_number` | SMS | Built (SMS only; no in-app or email) |
| E2 | Establishment revoked | `routes/establishments.js` ~813 | Establishment contact | SMS | Built (verified: SMS already sent on revoke) |
| E3 | Establishment user created, invited, or reset | `routes/establishmentUsers.js` | Establishment user | In-app | **BUILT: dashboard banner** (`GET /establishment-users/my-recent-changes`, reads audit log) |
| E4 | Establishment user activated, deactivated, or role changed | `routes/establishmentUsers.js` | Establishment user | In-app | **BUILT: dashboard banner** (same endpoint) |
| E5 | Record edit made by staff (A-07) | Not built | Beneficiary and establishment | Push, SMS | **GAP: A-07 not built** |

## 4. Gaps and bugs found

1. **B7 enum bug (bug, fix required).** `fraud_report_received` is used in `beneficiaryPortal.js` but is not in the `notification_type` enum. It is not in any migration and not in the startup list in `server.js` (which only adds `dispute_submitted`, `dispute_escalated`, and similar values). The insert is not wrapped in try/catch, so the report endpoint fails after the dispute row is written. The audit row for `fraud_report_submitted` is then skipped. Production should be checked first with:
   `SELECT unnest(enum_range(NULL::notification_type));`
2. **B11 gap (fixed).** Beneficiary suspension and reinstatement now send push and SMS notices (`notifyBeneficiaryStatusChange` in `beneficiaries.js`).
3. **E3 and E4 (fixed).** Establishment user changes show as an in-app dashboard banner, driven by the audit log. No new table.
4. **E2 (verified).** Revocation sends an SMS in `establishments.js`.
5. **Masking check.** Dispute and report bodies use the first 8 characters of the UUID as a reference, which is not an ID number. The verification notice bodies in `verification.js` were not reviewed for masking in this pass.

## 5. Decisions needed before implementation

Decided:
- **B11 (beneficiary suspension or reinstatement):** push and SMS.
- **E3 and E4 (establishment user changes):** in-app only.
- **E2 (establishment revoked):** add an SMS, matching E1.
- **B12 (beneficiary acknowledgement):** in-app, timestamp shown to staff.

Open:
- **E5 (record-edit notice, A-07):** pending decision.
