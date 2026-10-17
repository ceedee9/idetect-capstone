# iDetect — User Manual

**OCR-Based Discount ID Validation System**
For Senior Citizen and PWD Discount ID Validation and Fraud Intelligence in Valenzuela City

Prepared for the Capstone Project
De Los Reyes, Carlo M. • Enoria, Jorich Maricar C. • Mercado, Vesti Sahm Angielo • Santiago, Ishmael Luis C.

| Field          | Value                                                                                                                 |
| -------------- | --------------------------------------------------------------------------------------------------------------------- |
| Project        | Design and Development of iDetect                                                                                     |
| Institution    | Pamantasan ng Lungsod ng Valenzuela — College of Engineering and Information Technology                               |
| Source basis   | Post-Capstone 1 Revision Manuscript (May 2026), verified against the production codebase (`ceedee9/idetect-capstone`) |
| Manual version | 2.0 — Updated with confirmed deployment/tech-stack details                                                            |

---

## Document Control & Quick Start

| Field                         | Value                                                                                                               |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Manual status                 | Updated Capstone User Manual — reconciled with the deployed system                                                  |
| System version                | Portal / mobile app version numbers — **not yet assigned**                                                          |
| Official support contact      | **[TO BE PROVIDED]**                                                                                                |
| GitHub repository             | `ceedee9/idetect-capstone`                                                                                          |
| Unified web portal URL        | https://idetect.it.com                                                                                              |
| Mobile app distribution links | **Not yet publicly published** — release APKs can be built locally from source; see [§4.5](#45-mobile-installation) |

### 60-Second Quick Start — Establishment Staff

1. **Open the Client Portal (mobile app)**
   Sign in using the establishment account provisioned through BPLO.
   _Expected: Validation dashboard opens._
2. **Scan the ID**
   Use the mobile camera and follow the position/distance/lighting guide.
   _Expected: A readable capture is accepted and preprocessed._
3. **Review the extracted data**
   Check ID number, full name, beneficiary type, validity period, and issuing office.
   _Expected: Data is ready for validation or manual correction._
4. **View the result**
   Submit for OSCA/PDAO validation.
   _Expected: VALID, SUSPICIOUS, or INVALID appears within the 30-second target under normal conditions._
5. **Flag when appropriate**
   Use the flag action for a suspicious/invalid credential that requires LGU investigation.
   _Expected: A reference number is generated and the report is routed to OSCA/PDAO._

> **LEGAL / OPERATIONAL NOTE:** iDetect does not override existing DOJ requirements concerning unverifiable credentials. It is a fraud-intelligence and reporting mechanism, not a final legal determination of fraud.

---

## 1. Introduction

### 1.1 Brief Overview

iDetect is an integrated system with **one unified web portal** (role-routed for BPLO, OSCA, and PDAO staff) and **two mobile apps** (Client Portal for establishments, and a Beneficiary app). It combines mobile camera capture, OCR-based field extraction, field-level validation, real-time cross-checking against OSCA and PDAO records, bidirectional fraud reporting, and beneficiary accountability mechanisms.

### 1.2 Purpose

The system reduces manual verification effort, strengthens coordinated fraud intelligence, improves validation speed and consistency, and gives registered beneficiaries visibility into validation activity plus structured recourse for erroneous outcomes.

### 1.3 Intended Users

Establishment staff, BPLO administrators, OSCA administrators, PDAO administrators, and Senior Citizen/PWD beneficiaries — each with a role-specific interface.

### 1.4 System at a Glance

| Portal / Role                       | Access                   | Primary responsibilities                                                                                       |
| ----------------------------------- | ------------------------ | -------------------------------------------------------------------------------------------------------------- |
| Client Portal / Establishment Staff | Mobile app               | ID capture, OCR extraction, validation, flagging, transaction history, compliance reports                      |
| BPLO Administrator                  | Web portal (role-routed) | Establishment provisioning, permit validation, account status, permit-expiry monitoring, operational dashboard |
| OSCA Administrator                  | Web portal (role-routed) | Senior Citizen records, flagged-ID investigation, fraud confirmation/dismissal, analytics                      |
| PDAO Administrator                  | Web portal (role-routed) | PWD records, flagged-ID investigation, fraud confirmation/dismissal, analytics                                 |
| Beneficiary                         | Mobile app               | Optional account, status monitoring, notifications, history, disputes, fraud/unauthorized-use reporting        |

> **Note on portal access:** Unlike earlier drafts that assumed separate URLs per LGU office, the deployed system uses **one URL** (`https://idetect.it.com`) with **role-based routing after login** — see [§1.6](#16-web-portal-access-model).

### 1.5 Important Boundaries

- Valenzuela City only; the implementation validates Valenzuela City OSCA/PDAO credentials and serves BPLO-registered establishments.
- Food-service scope: restaurants, cafes, and fast-food chains.
- Automated OCR is configured for the supported Valenzuela City OSCA/PDAO card layouts; other formats may require manual entry.
- No biometrics. VALID confirms credential-data matching, not that the presenter is the registered cardholder.
- iDetect does not determine eligibility, issue IDs, or independently change official government status.
- Beneficiary registration is optional.

> **SCOPE WARNING:** Severely damaged/illegible cards, unsupported layouts, and extended connectivity loss fall outside reliable automated operation.

### 1.6 Web Portal Access Model

There is **one unified web portal URL**: **https://idetect.it.com**. It serves:

- BPLO Administrator Portal
- OSCA Administrator Portal
- PDAO Administrator Portal
- Staff Login

After signing in, the system routes each account to the dashboard matching its assigned role. There are no separate per-office URLs to distribute.

---

## 2. Software Specifications

The table below lists what is confirmed from the deployed codebase/configuration. Rows still awaiting an exact value are marked accordingly.

| Component                     | Confirmed detail                                                                                                                     |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Client Portal (establishment) | Flutter mobile application; Android 8.0+ and iOS 12.0+                                                                               |
| Beneficiary Mobile App        | Flutter mobile application; Android 8.0+ and iOS 12.0+                                                                               |
| Backend / API                 | Node.js + Express.js (`apps/api`)                                                                                                    |
| Web Portal (staff)            | Served together with the API as a combined Northflank service                                                                        |
| OCR engine                    | Tesseract OCR (plus on-device ML Kit text/face detection in the mobile app)                                                          |
| Image preprocessing           | Deskewing, contrast enhancement, noise reduction; automated image-quality assessment                                                 |
| Database                      | PostgreSQL, managed via Supabase (Supabase connection pooler — session/transaction pooling)                                          |
| File/image storage            | Supabase Storage — buckets: `id-captures`, `dispute-docs`                                                                            |
| Integration                   | Secure RESTful APIs for real-time OSCA/PDAO validation and fraud-flag transmission                                                   |
| Authentication                | RBAC; bcrypt password hashing; JWT authentication with **separate signing secrets** for Staff, Establishment, and Beneficiary tokens |
| SMS notifications             | Semaphore gateway                                                                                                                    |
| Push notifications            | Firebase Cloud Messaging (FCM) / APNs                                                                                                |
| Email notifications           | Resend, via the verified `idetect.it.com` sending domain                                                                             |
| Hosting                       | Northflank (combined API + staff portal service), region **US-Central**                                                              |
| Public port                   | 3000                                                                                                                                 |
| Domain / Transport security   | https://idetect.it.com, HTTPS/TLS                                                                                                    |
| CI/CD                         | GitHub → Northflank pipeline; auto-builds and deploys the latest commit pushed to `main`                                             |
| Source repository             | GitHub — `ceedee9/idetect-capstone`                                                                                                  |
| API health check              | `GET /api/health`                                                                                                                    |

### 2.1 Not Yet Documented / Outstanding Items

These items are referenced in the manuscript or expected for a complete manual, but **no value has been supplied yet**. They are listed here explicitly so they are not mistaken for omissions:

| Item                                                                          | Status                                   |
| ----------------------------------------------------------------------------- | ---------------------------------------- |
| Portal / mobile app version numbers                                           | **[TO BE PROVIDED]**                     |
| Official support contact                                                      | **[TO BE PROVIDED]**                     |
| Exact Node.js version (runtime pinned on Northflank)                          | **[TO BE PROVIDED]**                     |
| Exact npm version                                                             | **[TO BE PROVIDED]**                     |
| Exact supported browser versions (web portal)                                 | **[TO BE PROVIDED]**                     |
| Exact PostgreSQL version (Supabase instance)                                  | **[TO BE PROVIDED]**                     |
| Actual OSCA API endpoint URLs/credentials                                     | **[TO BE PROVIDED]**                     |
| Actual PDAO API endpoint URLs/credentials                                     | **[TO BE PROVIDED]**                     |
| Official Android APK download link (public, hosted)                           | **[TO BE PROVIDED]** — not yet published |
| Official mobile distribution link (general)                                   | **[TO BE PROVIDED]** — not yet published |
| iOS package / build                                                           | **None exists yet**                      |
| Google Play Store listing                                                     | **None exists yet**                      |
| Apple App Store listing                                                       | **None exists yet**                      |
| Privacy/security incident-reporting contact                                   | **[TO BE PROVIDED]**                     |
| Breach escalation contact                                                     | **[TO BE PROVIDED]**                     |
| Breach escalation procedure (beyond the in-app breach-report generator, §8.4) | **[TO BE PROVIDED]**                     |

> Anyone completing this manual for release should fill in the table above before distributing it externally.

### 2.2 Authentication & Notifications

The system uses role-based access control, bcrypt password hashing, and JWT-based sessions with **independent signing secrets per actor type** (staff, establishment, beneficiary) — a token issued for one actor type cannot be reused to authenticate as another. Beneficiary authentication uses ID number + birthdate, followed by a one-time PIN/OTP sent by SMS (Semaphore). Push notifications are delivered through Firebase FCM / APNs, and transactional emails are sent through Resend using the verified `idetect.it.com` domain.

### 2.3 Developer / Deployment Environment

- **Repository:** GitHub, `ceedee9/idetect-capstone`
- **CI/CD:** GitHub → Northflank. Every push to `main` triggers an automatic build and deploy.
- **Hosting:** Northflank, region US-Central; the API and the staff web portal are deployed together as **one combined service** on public port 3000, reachable at https://idetect.it.com.
- **Secrets management:** Database credentials, JWT signing secrets, and third-party API keys (Semaphore, Firebase, Resend) are stored in **Northflank Secrets**, not in the repository.
- **Database migrations:** Run via the scripted migration runner (`apps/api/scripts/migrate.js`).
- Exact Node.js/npm runtime versions and browser support matrix are **[TO BE PROVIDED]**.

---

## 3. Hardware Specifications

The manuscript defines functional hardware needs but does not provide numerical RAM, CPU, storage, or server-sizing values for the Northflank deployment.

| Hardware          | Minimum / required                              | Recommended / guidance                                                               |
| ----------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------ |
| Mobile device     | Android 8.0+ or iOS 12.0+ with a working camera | Device that can capture a sharp, well-lit supported ID                               |
| Camera            | Built-in mobile camera                          | Rear camera with stable focus and adequate lighting                                  |
| Computer          | Required for the BPLO/OSCA/PDAO web portal      | Modern desktop/laptop with a supported browser (exact versions **[TO BE PROVIDED]**) |
| Internet          | Stable connection for live verification         | Reliable Wi-Fi/mobile data at point of service                                       |
| Dedicated scanner | Not required by the documented workflow         | Mobile camera is the documented capture method                                       |

### 3.1 ID Capture Guidance

- Use the mobile camera workflow; no dedicated scanner is required.
- Keep the supported ID readable, flat, aligned, and adequately lit.
- Avoid blur, glare, heavy skew, and obstructed text. Poor images may be rejected or sent to manual entry.

### 3.2 Connectivity

Real-time verification is online-first. Recently verified records may be cached for limited offline validation, and pending fraud flags are queued for synchronization after reconnection. Cached results are labeled with their last online timestamp.

---

## 4. Installation & Deployment Guide

> **AUDIENCE:** For authorized deployment/system administrators. End users should not change database, API, hosting, or security configuration.

### 4.1 Pre-Installation Checklist

- [x] Access to the GitHub repository `ceedee9/idetect-capstone`.
- [x] Northflank account with permission to manage the combined API + portal service.
- [x] Supabase project (PostgreSQL database + Storage) with connection-pooler credentials.
- [x] Semaphore SMS account/API key.
- [x] Firebase project for FCM (and APNs configuration for iOS push, once an iOS build exists).
- [x] Resend account with the `idetect.it.com` domain verified.
- [ ] OSCA/PDAO integration endpoints/credentials — **[TO BE PROVIDED]**.
- [ ] Official mobile packages and store listings — **not yet created**.
- [x] TLS/SSL — handled automatically by Northflank for the `idetect.it.com` domain.

### 4.2 Backend / API Setup

1. **Prepare repository**
   Clone `ceedee9/idetect-capstone` and install dependencies (`apps/api`: Node.js + Express).
   _Expected: Repository/tooling is available._
2. **Configure environment**
   Set database (Supabase pooler URL), JWT secrets (`JWT_SECRET_STAFF`, `JWT_SECRET_ESTABLISHMENT`, `JWT_SECRET_BENEFICIARY`), Semaphore, Resend, and Firebase settings — all stored in **Northflank Secrets**, not committed to the repository.
   _Expected: Services can be reached._
3. **Initialize database**
   Create the target Supabase/PostgreSQL database and run the migration scripts (`npm run db:migrate`); use approved seed data where applicable.
   _Expected: Schemas are created without errors._
4. **Configure API**
   Deploy the combined API + portal service on Northflank (public port 3000) and secure OSCA/PDAO connections without exposing the underlying database directly.
   _Expected: `GET /api/health` responds successfully._
5. **Configure notifications**
   Connect Semaphore (SMS), Firebase (push), and Resend (email, `idetect.it.com` domain) using the credentials stored in Northflank Secrets.
   _Expected: A controlled notification test succeeds._
6. **Run health checks**
   Call `https://idetect.it.com/api/health`.
   _Expected: Required services report healthy/ready._

### 4.3 Database Setup

- **Engine:** PostgreSQL, managed through **Supabase**.
- **Connection:** Supabase connection pooler (session/transaction pooling mode).
- **Credentials:** Stored securely in Northflank Secrets — never in the repository.
- **Exact PostgreSQL version:** **[TO BE PROVIDED]**.

Documented schema tables: `users`, `establishments`, `beneficiaries`, `beneficiary_accounts`, `verification_logs`, `fraud_flags`, `disputes`, `notifications`, `audit_logs` (a `staff_alerts`-equivalent is implemented through the notifications/audit_logs tables).

> **DATABASE SAFETY:** Functional testing is described as using seeded test databases without real beneficiary data.

### 4.4 Web Portal Deployment

1. **Deploy the combined service**
   The staff web portal and the API are published together as one Northflank service.
   _Expected: https://idetect.it.com loads._
2. **API base URL**
   `https://idetect.it.com` (same host serves both the portal and `/api/*` routes).
   _Expected: Portal actions reach the correct backend._
3. **Verify role routing**
   Test BPLO, OSCA, and PDAO accounts separately after signing in at the single URL.
   _Expected: Each account only reaches its own dashboard; cross-portal access is blocked._
4. **Verify encryption**
   Confirm production traffic uses HTTPS/TLS.
   _Expected: Sensitive traffic is protected._

### 4.5 Mobile Installation

> **Current status:** There is **no official public distribution link yet** (no Google Play / App Store listing) for either mobile app, and **no iOS build exists**. Release Android APKs can, however, be built locally from source for internal testing/sideloading, as described below.

#### 4.5.1 Building release APKs from source

Both mobile apps are separate Flutter projects in the same repository: the **Client Portal / Establishment app** at the repository root, and the **Beneficiary app** under `apps/beneficiary`.

> **Required flag:** Both apps' `ApiService.baseUrl` (`lib/services/api_service.dart` and `apps/beneficiary/lib/services/api_service.dart`) has no hardcoded fallback — it throws at runtime (e.g., on the first login attempt) if `IDETECT_API_BASE_URL` was not supplied at build time. Always pass `--dart-define=IDETECT_API_BASE_URL=<api-host>/api`, or the resulting APK will install but fail as soon as it calls the API.
>
> The production API is hosted on Northflank at `https://site--idetect--lr4dgpy2rvkq.code.run/api` (**not** `https://idetect.it.com/api` — that host is documented elsewhere in this manual as the unified web portal URL, but the current mobile builds must target the Northflank host above).

1. **Establishment (Client Portal) app**
   From the repository root, run `flutter build apk --release --dart-define=IDETECT_API_BASE_URL=https://site--idetect--lr4dgpy2rvkq.code.run/api`.
   _Output: `build/app/outputs/flutter-apk/app-release.apk`._
2. **Beneficiary app**
   From `apps/beneficiary`, run `flutter build apk --release --dart-define=IDETECT_API_BASE_URL=https://site--idetect--lr4dgpy2rvkq.code.run/api`.
   _Output: `apps/beneficiary/build/app/outputs/flutter-apk/app-release.apk`._
3. **Distribute for sideloading**
   Share the generated `app-release.apk` file directly with testers/establishments (e.g., via internal file transfer); enable "Install unknown apps" on the Android device to sideload it.
   _Expected: The app installs and launches without a Play Store listing._

> Locally built APKs use Flutter's default debug-equivalent signing config, not an official release keystore, and are **not** the same as an official, store-distributed release. Use them for internal testing only until an official signing/distribution pipeline and store listings exist.

#### 4.5.2 Installing a distributed package

1. **Obtain the package**
   Install the approved Client Portal or Beneficiary APK/link.
   _Status: Public, hosted APK download link — **[TO BE PROVIDED]**. Google Play / App Store listings — **do not exist yet**._
2. **Grant permissions**
   Allow camera access for the Client Portal and notification access where applicable.
   _Expected: Required permissions are active._
3. **Sign in**
   Use establishment credentials, or beneficiary ID number + birthdate + OTP.
   _Expected: Correct dashboard opens._
4. **Run controlled test**
   Use approved test credentials/IDs only.
   _Expected: Controlled validation/notification succeeds._

### 4.6 Common Installation Problems

| Problem                  | Cause                                              | Response                                                                                                       |
| ------------------------ | -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Migration failure        | Connection/schema conflict                         | Check Supabase connection settings, review the migration error, roll back the partial migration, retry.        |
| API health-check failure | Dependency/configuration unavailable on Northflank | Check Northflank Secrets/environment settings and dependent services.                                          |
| Portal cannot reach API  | Endpoint/network/TLS issue                         | Verify the `idetect.it.com` route and certificate status on Northflank.                                        |
| OTP not received         | SMS/contact configuration                          | Verify the registered contact number and Semaphore configuration/credit balance.                               |
| Push absent              | FCM/APNs/device-token issue                        | Check notification permissions and Firebase push-service configuration.                                        |
| Camera unavailable       | Permission/device issue                            | Enable the camera permission and confirm a supported OS version.                                               |
| Email not delivered      | Resend domain/API key issue                        | Confirm the `idetect.it.com` sending domain is verified and the Resend API key in Northflank Secrets is valid. |

---

## 5. User Functions & Capabilities

### 5.1 Establishment Staff — Client Portal

The point-of-sale workflow is intentionally limited to **launch → scan → view result**.

1. **Log in**
   Enter your registered username/password. Your account must be approved and active.
   _Expected: Validation dashboard opens._
2. **Capture ID**
   Use the camera and follow the position/distance/lighting guidance on screen.
   _Expected: A quality-approved image is accepted._
3. **Review the extracted data**
   Check ID number, full name, beneficiary type, validity period, and issuing office. Correct any field, or switch to manual entry if OCR confidence is low.
   _Expected: Data is ready for validation._
4. **Validate**
   Submit the credential data for the dual-database (OSCA/PDAO) check.
   _Expected: VALID, SUSPICIOUS, or INVALID is displayed within 30 seconds under normal conditions._

#### Validation Statuses

| Result        | Meaning                                                                              | Recommended response                                                                                   |
| ------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| VALID         | Credential data matches an active, non-revoked official record within system rules.  | Review the result and follow the applicable establishment/legal procedure.                             |
| SUSPICIOUS    | A discrepancy, conflict, or anomaly warrants LGU investigation.                      | Review and flag when appropriate. **This is not a final fraud determination.**                         |
| INVALID       | No matching record, or a clear invalid/revoked/expired condition under system rules. | Review; flag for investigation when appropriate. If the type is unknown, choose Senior Citizen or PWD. |
| MANUAL_REVIEW | OCR confidence is too low for automated processing.                                  | Review/correct the fields or use manual entry, then validate.                                          |

> **IMPORTANT:** SUSPICIOUS is an investigation trigger, not a final fraud determination.

#### Flagging a Credential

1. **Tap Flag** — use the flag action after a SUSPICIOUS or INVALID result.
   _Expected: A confirmation prompt appears._
2. **Confirm** the report.
   _Expected: ID image, extracted data, establishment, timestamp, and outcome are routed to OSCA/PDAO._
3. **Select type if unknown** — for an INVALID no-record case with an unconfirmed type, choose Senior Citizen or PWD.
   _Expected: The correct LGU route is selected._
4. **Record the reference number** generated for the flag.
   _Expected: The flag is linked to history/audit records._

> **OFFLINE:** Flags can be queued locally and are automatically synchronized after connectivity returns.

#### Transaction History & Compliance Reports

Open transaction history, choose a date range, and request a compliance summary. The report presents counts of VALID, SUSPICIOUS, and INVALID outcomes.

### 5.2 BPLO Administrator — Web Portal

1. **Sign in** at https://idetect.it.com using your institutionally issued BPLO credentials.
   _Expected: The BPLO dashboard opens (role-routed automatically after login)._
2. **Provision an establishment**
   Enter a valid Valenzuela City business permit number and designated staff credentials.
   _Expected: The permit is validated and an eligible account is created._
3. **Deliver credentials**
   The system generates/displays credentials and sends onboarding information by email (Resend) or SMS (Semaphore).
   _Expected: The establishment receives access instructions._
4. **Manage account status**
   Activate, suspend, or revoke accounts when authorized.
   _Expected: The access change is applied and logged._
5. **Monitor permit expiry**
   Review alerts for permits approaching expiry within 30 days, or already expired.
   _Expected: BPLO can take manual action; alerting does not automatically suspend an account._
6. **Monitor operations**
   Review active accounts, recent provisioning, pending actions, and technical performance metrics.
   _Expected: Operational oversight is available without beneficiary data._

> **BOUNDARY:** BPLO does not access flagged credential records, beneficiary personal information, or validation intelligence.

### 5.3 OSCA Administrator — Web Portal

1. **Sign in** at https://idetect.it.com using OSCA credentials.
   _Expected: The Senior Citizen-only dashboard opens._
2. **Review flags** — open incoming flagged-credential notifications.
   _Expected: Captured image, extracted fields, establishment, and timestamp are shown._
3. **Investigate** — review the evidence and the official Senior Citizen record.
   _Expected: The case is handled within OSCA scope._
4. **Decide** — mark confirmed fraud or dismiss a legitimate flag.
   _Expected: Status/audit records update; confirmed fraud propagates to connected Client Portals._
5. **Manage records** — add/update Senior Citizen records, renewals, and corrections.
   _Expected: Authorized official record changes are saved._
6. **Use analytics** — review temporal, geographic, establishment-specific, and conversion-rate trends.
   _Expected: Fraud intelligence supports investigation._

### 5.4 PDAO Administrator — Web Portal

1. **Sign in** at https://idetect.it.com using PDAO credentials.
   _Expected: The PWD-only dashboard opens._
2. **Review flags** — open incoming PWD flag notifications.
   _Expected: Captured image, extracted fields, establishment, and timestamp are shown._
3. **Investigate and decide** — confirm fraud or dismiss a legitimate flag.
   _Expected: PWD status/audit records update and confirmed fraud propagates._
4. **Manage records** — add/update PWD records, renewals, and corrections.
   _Expected: Authorized changes are saved._
5. **Use analytics** — review PWD fraud trends and establishment patterns.
   _Expected: Intelligence supports enforcement._

### 5.5 Beneficiary Mobile Application

> **OPTIONAL:** Registration is voluntary and does not affect statutory discount entitlement.

#### Registration & Authentication

1. **Enter ID number and birthdate.**
   _Expected: The corresponding OSCA/PDAO record is checked._
2. **Receive OTP** — a one-time PIN is sent by SMS (Semaphore) to the mobile number on file.
   _Expected: The second authentication factor is available._
3. **Submit OTP** within the configured time window.
   _Expected: The account is activated/authorized._

#### Status, Notifications & History

Authenticated beneficiaries can view Active, Under Review, Suspended, or Expired status; last successful validation details; expiration date; and issuing-office contact information. Validation attempts can generate SMS and push notifications containing the establishment, timestamp, and Approved/Denied outcome; denied notices may include specific reasons.

#### Dispute Procedure

1. **Select a denied transaction** — open the notification/history entry and choose Dispute.
   _Expected: The form is pre-populated with the transaction reference, establishment, and denial reason._
2. **Choose a category** — Wrong Denial, ID Used Without My Authorization, or Database Contains Incorrect Information.
   _Expected: The issue is categorized._
3. **Write an explanation** — provide the required written explanation; supporting documentation may be uploaded (stored in the `dispute-docs` bucket).
   _Expected: The form is ready for submission._
4. **Submit** to the OSCA/PDAO queue.
   _Expected: A reference number is generated; the acknowledgment target is 24 hours._
5. **Track** the dispute status.
   _Expected: Updates/final explanation are delivered after human review._

#### Beneficiary Accountability Reports

| Report type                    | Route     | Expected handling                                                              |
| ------------------------------ | --------- | ------------------------------------------------------------------------------ |
| Unauthorized ID use            | OSCA/PDAO | Investigation; confirmed unauthorized use can support network-wide protection. |
| Business refusal despite VALID | BPLO      | Investigation of potential non-compliance.                                     |
| Incorrect database information | OSCA/PDAO | Validation/correction by authorized LGU personnel.                             |

---

## 6. System Workflow

### 6.1 End-to-End Flow

1. Authenticate the appropriate user.
2. Capture the supported ID, or use the manual-entry fallback.
3. Assess image quality and preprocess accepted images.
4. Extract ID number, full name, beneficiary type, validity period, and issuing office using Tesseract OCR (plus on-device ML Kit) with field-level confidence scoring.
5. Cross-check against OSCA and PDAO through secure RESTful APIs.
6. Return and log VALID, SUSPICIOUS, or INVALID.
7. Flag suspicious/invalid credentials when appropriate and route to OSCA/PDAO.
8. Investigate and synchronize confirmed status across connected Client Portals.
9. Notify registered beneficiaries and support disputes/accountability reports.

> **SYNCHRONIZATION:** Confirmed fraud status is designed to propagate to connected Client Portals within 10 seconds of the database update under normal network conditions.

### 6.2 Offline / Reconnection Flow

The Client Portal shows a persistent offline indicator. Recently verified credentials may be checked from local cache with the last online timestamp. New live validation without a cached record is unavailable. Queued fraud flags synchronize automatically after reconnection.

### 6.3 Beneficiary Accountability Loop

Transaction notification → beneficiary review → dispute/unauthorized-use report → OSCA/PDAO or BPLO review → resolution notification.

### 6.4 Deployment Flow

`git push` to `main` on `ceedee9/idetect-capstone` → Northflank CI/CD builds the combined API + portal service → deployed to https://idetect.it.com (US-Central, port 3000).

---

## 7. Troubleshooting & FAQs

| Problem                             | Possible cause                                               | Simple solution                                                                                    |
| ----------------------------------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------- |
| Camera rejects image                | Blur, glare, poor light, skew, damaged ID                    | Reposition, improve lighting, steady the camera, recapture; use manual entry if needed.            |
| OCR is wrong                        | Poor image or unsupported/aged card layout                   | Review and correct the extracted fields; use manual fallback.                                      |
| Validation is slow                  | Network/service latency                                      | Wait for the result; if offline, follow offline guidance and use cached results only when labeled. |
| No live result offline              | Credential not in local cache                                | Reconnect before relying on a live database result.                                                |
| Flag is pending                     | Queued while offline, or a temporary sync failure            | Keep the device connected; automatic retry/synchronization is expected.                            |
| Account locked                      | Three consecutive failed login attempts                      | Wait for the cooldown period or contact the proper administrator.                                  |
| OTP fails/expires                   | Incorrect/expired OTP, or a Semaphore delivery issue         | Request a new OTP within the allowed resend limit.                                                 |
| Old beneficiary status shown        | Offline/last synchronized state                              | Check the timestamp and reconnect.                                                                 |
| BPLO cannot create an establishment | Permit invalid/expired/ineligible                            | Verify the permit in the BPLO registry.                                                            |
| Authorization error                 | The role is attempting to access an unauthorized portal/data | Use the assigned dashboard (role-routed) or contact an administrator.                              |
| Portal unreachable                  | Northflank service/domain issue                              | Check https://idetect.it.com/api/health, and confirm the Northflank deployment status.             |

### 7.1 Frequently Asked Questions

**Q. Does a beneficiary need the app to receive the discount?**
A. No. Registration is optional and does not affect entitlement or Client Portal validation.

**Q. Does VALID prove the presenter owns the ID?**
A. No. iDetect does not use biometrics; physical identity confirmation remains with establishment staff.

**Q. Is SUSPICIOUS the same as fraud?**
A. No. It triggers investigation; OSCA/PDAO make the final determination.

**Q. Can BPLO see beneficiary or fraud records?**
A. No. BPLO is limited to establishment management/operational oversight.

**Q. Can OSCA see PWD records?**
A. No. OSCA is restricted to Senior Citizen records; PDAO is restricted to PWD records.

**Q. Can beneficiaries directly edit government records?**
A. No. They submit disputes; authorized OSCA/PDAO personnel adjudicate and correct records.

**Q. What happens if the same ID is flagged again?**
A. A new report can be linked as a supplementary report to an existing open investigation.

**Q. How long are audit logs retained?**
A. Audit logs stay in the live Audit Logs page for five years. After that, the agency's Super Admin can archive them. Archived logs are moved, never deleted, and remain viewable by that Super Admin. See [AUDIT_LOG_RETENTION_POLICY.md](./AUDIT_LOG_RETENTION_POLICY.md).

**Q. Is there one URL or several for BPLO/OSCA/PDAO?**
A. One unified URL, https://idetect.it.com. The system routes each account to its dashboard based on role after login.

**Q. Where are uploaded images/documents stored?**
A. Supabase Storage, in the `id-captures` bucket (ID scans) and the `dispute-docs` bucket (dispute attachments). This replaces the Cloudinary-based storage referenced in earlier drafts.

---

## 8. Security & Data Privacy

iDetect uses role separation, encrypted transmission, authentication controls, minimum-disclosure validation responses, session expiry, and audit logging to protect credential and beneficiary information.

### 8.1 Security Controls

- RBAC restricts functions/data by role.
- Data is transmitted over encrypted channels (HTTPS/TLS via Northflank).
- Beneficiary accounts use ID number + birthdate and OTP; the implementation also documents a PIN-based return-login path.
- Passwords/secrets are bcrypt-hashed.
- JWT sessions use **separate signing secrets** for Staff, Establishment, and Beneficiary tokens, so a token cannot be reused across actor types.
- Validation, fraud flags, disputes, database changes, and administrative actions are logged in tamper-evident audit records.
- Audit records cannot be modified/deleted through normal user functions.
- Client and Beneficiary sessions auto-expire after inactivity.
- Unauthorized API requests are rejected and logged.
- Client Portal receives only the validation status rather than comprehensive beneficiary personal data.
- All third-party credentials (database, JWT secrets, Semaphore, Firebase, Resend) are stored in **Northflank Secrets**, not in the repository or client apps.

### 8.2 Data Minimization & Compartmentalization

Validation uses only the fields needed to determine credential validity: ID number, full name, beneficiary type, validity period, and issuing office. Establishments receive the validation outcome without comprehensive beneficiary data. OSCA, PDAO, BPLO, and beneficiary boundaries are enforced by RBAC.

### 8.3 Responsible Handling

- Treat ID images, names, ID numbers, birthdates, mobile numbers, disputes, and transaction records as sensitive.
- Use only authorized iDetect workflows/storage (Supabase Storage buckets, not personal devices/cloud drives).
- Do not share screenshots or reports through personal messaging/social media.
- Never share passwords, OTPs, PINs, or session credentials.
- Report suspected unauthorized access/data exposure through the approved privacy/security channel — **[TO BE PROVIDED]**.

> **PRIVACY REMINDER:** The design is framed around RA 10173, including access/correction mechanisms, minimum disclosure, and breach-reporting support. Follow the organization's approved privacy policy and incident-response procedure once finalized.

### 8.4 Breach Incident Reporting

The system includes a staff-facing capability (`POST /staff/breach-report`) to generate and log a breach incident report describing the breach, affected data categories, and estimated affected data subjects, for NPC 72-hour notification purposes. The actual escalation contact and downstream procedure are **[TO BE PROVIDED]**.

---

## 9. Tips & Best Practices

| Tip                                 | Practice                                                                                                       |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Capture clearly                     | Use adequate light, avoid glare, keep the ID steady, and fit the card inside the guide.                        |
| Always review OCR                   | OCR is an extraction aid; confirm fields before validation.                                                    |
| Do not equate SUSPICIOUS with fraud | Only OSCA/PDAO investigation makes the final determination.                                                    |
| Keep reference numbers              | Save flag/dispute references when follow-up is needed.                                                         |
| Prefer live validation              | Cached results are limited and may be stale.                                                                   |
| Respect role boundaries             | Never access another portal or stakeholder's data — the single URL still enforces role separation after login. |
| Protect sensitive information       | Avoid unnecessary exposure of IDs and personal data.                                                           |
| Use test data                       | Functional testing should use approved seeded databases without real beneficiary data.                         |
| Escalate persistent errors          | Record the error and time, and contact **[TO BE PROVIDED]** once a support contact is assigned.                |

---

## 10. Actual Interface Reference

The manuscript appendix includes actual system screenshots for the Beneficiary Mobile Application, BPLO Portal, OSCA investigation/analytics, and PDAO investigation/analytics. Refer to the manuscript's screenshot sheets for the current visual reference; replace with final production captures once app-store/production builds are published.

Screens still pending a final production capture: **Client Portal OCR/capture screen** and **Client Portal validation result** (currently shown from pre-production builds in the manuscript appendix).

---

## Appendix A — Change Log vs. Prior Draft

This revision fills in the following items that were previously marked `[TO BE PROVIDED]`:

1. Approved package/repository → GitHub `ceedee9/idetect-capstone`.
2. Backend/API environment → Node.js + Express, deployed on Northflank (combined service, port 3000).
3. Database engine/credentials → PostgreSQL via Supabase, connection pooler, credentials in Northflank Secrets.
4. OSCA/PDAO integration → Secure RESTful APIs (endpoint URLs/credentials still pending).
5. SMS/push/email configuration → Semaphore (SMS), Firebase FCM/APNs (push), Resend (email, `idetect.it.com` domain).
6. TLS/SSL and hosting → Northflank, US-Central, HTTPS/TLS, GitHub CI/CD.
7. Web portal URLs → One unified URL, https://idetect.it.com, with role-based routing.
8. API base URL → https://idetect.it.com (same host as the portal).
9. Mobile OS requirements → Android 8.0+, iOS 12.0+.
10. Image/document storage → Supabase Storage (`id-captures`, `dispute-docs`), replacing the earlier Cloudinary reference.
11. Authentication configuration → RBAC, bcrypt, JWT with separate secrets per actor type, plus beneficiary ID+birthdate+OTP/PIN.
12. Hosting/CI-CD → GitHub → Northflank → Production, auto-deploy on `main`.

Items still awaiting a value are consolidated in [§2.1](#21-not-yet-documented--outstanding-items).

---

_End of iDetect User Manual_

Pamantasan ng Lungsod ng Valenzuela • College of Engineering and Information Technology
