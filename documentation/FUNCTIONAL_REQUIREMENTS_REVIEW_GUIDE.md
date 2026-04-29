# iDetect Functional Requirements Review Guide

Date reviewed: April 6, 2026

Purpose: This guide checks only functional requirements (what the system should do), then marks each as done, partial, or not done.

Scope checked:

- Mobile app flow (scan, verify, save, flag)
- API behavior (auth, verification, beneficiaries, fraud flags)
- OSCA and PDAO web portals

Out of scope:

- Performance tuning
- UI style quality
- Non-functional/security hardening details

## Status Legend

- Done: Working and aligned with expected behavior
- Partial: Implemented but with gaps or mismatches
- Not Done: Requirement exists but not implemented yet

## Functional Requirements Status Matrix

| ID    | Functional Requirement                                                            | Status  | Notes                                                                                                   |
| ----- | --------------------------------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------- |
| FR-01 | Staff login for OSCA/PDAO/BPLO                                                    | Done    | Implemented in API auth route and portal API clients                                                    |
| FR-02 | Establishment login from mobile app                                               | Done    | Implemented in API auth route and mobile API service                                                    |
| FR-03 | Scan ID and run verification against beneficiary records                          | Done    | Mobile sends ID + type, API verifies and returns result                                                 |
| FR-04 | Return verification result categories (valid, suspicious, invalid, manual_review) | Done    | Implemented in verification API and mobile result handling                                              |
| FR-05 | Fraud flag submission by establishment                                            | Done    | Mobile can submit fraud flag after invalid/suspicious results                                           |
| FR-06 | Fraud flag review by OSCA/PDAO staff                                              | Partial | Backend expects decision/staff_notes but web portal sends action/notes                                  |
| FR-07 | Beneficiary management (list, view, add, status update)                           | Done    | Implemented with role-based filtering                                                                   |
| FR-08 | Role separation (OSCA sees senior only, PDAO sees pwd only)                       | Done    | Enforced in API by role-to-type mapping                                                                 |
| FR-09 | Bulk import beneficiaries from CSV/Excel                                          | Done    | Analyze + import in web portals, API bulk import endpoint implemented                                   |
| FR-10 | Import protection for duplicates and invalid rows                                 | Done    | API validates rows, skips duplicates, returns summary                                                   |
| FR-11 | Store and use PDAO disability type in official beneficiary record                 | Partial | Frontend collects/filters disability type, but DB/API beneficiary schema has no disability_type field   |
| FR-12 | Store address, email, notes, contact number from add forms                        | Partial | Forms collect these fields, but core beneficiaries table/API create route does not persist most of them |
| FR-13 | Consistent status taxonomy across system                                          | Partial | Web tabs use inactive; DB/API statuses are active, suspended, expired, revoked                          |
| FR-14 | Beneficiary OTP authentication (request + verify)                                 | Partial | API endpoints exist, but SMS sending is still TODO in code                                              |

## High-Impact Mismatches (Needs Fix First)

### 1) Fraud flag review payload mismatch

What is expected by API:

- decision: confirmed or dismissed
- staff_notes: optional

What web portals currently send:

- action
- notes

Impact:

- Fraud flag review can fail or behave unexpectedly.

Priority: High

### 2) PDAO disability and profile fields are not persisted

Portal screens use and display:

- disability_type
- address
- contact_number
- email
- notes

But beneficiaries backend schema stores only core fields:

- id_number, full_name, birthdate, type, issuing_office, validity dates, status, registered_mobile

Impact:

- PDAO screens show fields that are often empty/not real source-of-truth data.
- Disability filter/analytics can be misleading.

Priority: High

### 3) Status label mismatch

Web uses tab value:

- inactive

Backend supports:

- active, suspended, expired, revoked

Impact:

- One status filter option is invalid and may confuse users.

Priority: Medium

## What is Already Working Well

1. Core verification flow is complete end-to-end.
2. Role-based separation between OSCA and PDAO is implemented.
3. Bulk import feature is implemented with validation and duplicate safety.
4. Verification result handling in mobile app is connected with local save and fraud flag option.
5. Beneficiary status updates are implemented and audited.

## Recommended Fix Plan (Simple)

### Phase 1 (Immediate)

1. Align fraud flag review request body in OSCA/PDAO web clients to API contract.
2. Replace inactive tabs/options in web portals with revoked.
3. Keep user-facing status wording consistent in all portals.

### Phase 2 (Data Model Alignment)

1. Decide whether disability_type, address, email, notes are official fields.
2. If yes:
   - Add migration columns to beneficiaries table.
   - Update API create/import/list/get routes.
   - Keep web forms as-is.
3. If no:
   - Remove those fields from add/detail/filter UI to avoid false expectations.

### Phase 3 (OTP Completion)

1. Integrate real SMS provider for beneficiary OTP.
2. Add retry/error handling and operational logs.

## Quick Validation Checklist After Fixes

1. Create PDAO beneficiary with disability type, then confirm value appears in list/detail and filter works.
2. Review a fraud flag from OSCA and PDAO portals; ensure confirmed and dismissed both succeed.
3. Verify status filters match real backend statuses exactly.
4. Run one manual add and one bulk import for both OSCA and PDAO.
5. Re-test mobile scan verification for valid, invalid, and suspended IDs.

## Evidence Sources Reviewed

- apps/api/src/server.js
- apps/api/src/routes/auth.js
- apps/api/src/routes/verification.js
- apps/api/src/routes/fraudFlags.js
- apps/api/src/routes/beneficiaries.js
- database/migrations/003_create_beneficiaries.sql
- lib/services/api_service.dart
- lib/presentation/screens/scan/verifying_screen.dart
- lib/presentation/screens/scan/result_screen.dart
- apps/web-osca/src/services/api.js
- apps/web-pdao/src/services/api.js
- apps/web-osca/src/pages/FraudFlagsPage.jsx
- apps/web-pdao/src/pages/FraudFlagsPage.jsx
- apps/web-pdao/src/pages/AddBeneficiaryPage.jsx
- apps/web-pdao/src/pages/BeneficiariesPage.jsx
