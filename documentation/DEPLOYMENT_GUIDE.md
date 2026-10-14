# iDetect Deployment Guide

**Pamantasan ng Lungsod ng Valenzuela — Capstone 2026**

> This guide covers the actual production deployment of iDetect: a combined
> Node.js/Express API + staff web portal service on **Northflank**, backed by
> **PostgreSQL/Storage on Supabase**, reachable at **https://idetect.it.com**.

---

## 1. Architecture Overview

| Part                       | What it is                                                                                          | Host                                                     |
| -------------------------- | --------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| **API + Staff Web Portal** | Node.js / Express (`apps/api`) + React/Vite build (`apps/web`) deployed as **one combined service** | Northflank (US-Central)                                  |
| **Database**               | PostgreSQL                                                                                          | Supabase (connection pooler)                             |
| **File/image storage**     | ID captures, dispute documents                                                                      | Supabase Storage (`id-captures`, `dispute-docs` buckets) |
| **Domain**                 | `idetect.it.com`                                                                                    | DNS pointed at Northflank                                |

```
User → https://idetect.it.com          → Northflank combined service
                                            ├─ serves the staff web portal (role-routed: BPLO/OSCA/PDAO)
                                            └─ serves /api/* (Node.js + Express)
                                                   ↓
                                                Supabase (PostgreSQL + Storage)
```

There is **one URL** for staff use: https://idetect.it.com. After sign-in, the account is routed to the BPLO, OSCA, or PDAO dashboard based on its role — there are no separate per-office URLs to distribute.

The two Flutter mobile apps (Client Portal for establishments, Beneficiary app) call the same API base URL, `https://idetect.it.com/api`.

---

## 2. Source & CI/CD

- **Repository:** GitHub — `ceedee9/idetect-capstone`
- **Pipeline:** GitHub → Northflank. Every push to `main` triggers an automatic build and deploy of the combined service.
- **Rollback:** Use Northflank's deployment history to redeploy a previous build if a release introduces a regression.

---

## 3. Pre-Deployment Checklist

### 3.1 Push Code to GitHub

Everything must be in the `ceedee9/idetect-capstone` GitHub repository.

> ⚠️ Make sure `.env` is in `.gitignore`. **Never commit secrets to GitHub.** All runtime secrets live in **Northflank Secrets**, not in the repository.

### 3.2 Generate Strong Production Secrets

Generate independent random strings for each JWT signing secret. Run this in PowerShell (repeat for each secret):

```powershell
-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 64 | ForEach-Object { [char]$_ })
```

You need **three separate secrets** — one per actor type, so a token issued for one type can never be reused as another:

- `JWT_SECRET_STAFF` — used for BPLO/OSCA/PDAO web portal sessions
- `JWT_SECRET_ESTABLISHMENT` — used for the Client Portal mobile app
- `JWT_SECRET_BENEFICIARY` — used for the Beneficiary mobile app (issued after OTP/PIN verification)

Store these in a password manager, then paste them into **Northflank → Service → Secrets**.

### 3.3 Confirm the API Entry Point

`apps/api/package.json` scripts:

```json
"scripts": {
  "start": "node src/server.js",
  "dev": "nodemon src/server.js",
  "db:migrate": "node scripts/migrate.js"
}
```

Northflank runs `npm start` to launch the combined service. The API service's
`prestart` script installs and builds `apps/web`, and the Express app serves
that build for non-API routes. In Northflank, the service working directory
must remain `apps/api`, and the command override (if enabled) must be:

```text
npm start
```

Set `VITE_API_URL` to the deployed API base URL before the build, for example:

```text
https://site--idetect--lr4dgpy2rvkq.code.run/api
```

The API routes continue to use `/api/...`; the frontend fallback serves
`apps/web/dist/index.html` for portal routes such as `/login` and
`/beneficiaries`.

---

## 4. Supabase Setup (Database + Storage)

1. **Create a Supabase project** (or use the existing one for this deployment).
2. **Database:** Use the **connection pooler** connection string (session/transaction pooling mode) — not the direct connection — for the Northflank-deployed API, since Northflank containers scale/restart and a pooled connection avoids exhausting Postgres connection limits.
3. **Storage buckets:** Create two buckets:
   - `id-captures` — scanned ID card images
   - `dispute-docs` — beneficiary dispute supporting documents
     (Override the default names with `SUPABASE_STORAGE_BUCKET_ID_IMAGES` / `SUPABASE_STORAGE_BUCKET_DISPUTE_DOCS` env vars if you need different names.)
4. **Run migrations** against the Supabase database:
   ```powershell
   cd apps/api
   npm run db:migrate
   ```
5. **Credentials** (`DATABASE_URL`/pooler connection string, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`) go into **Northflank Secrets**, never into the repository.

---

## 5. Deploy the Combined Service on Northflank

### 5.1 Create the Service

1. Sign in to Northflank and connect the `ceedee9/idetect-capstone` GitHub repository.
2. Create a new service pointed at `apps/api` (the service is responsible for serving both the API and the built staff web portal).
3. Set the region to **US-Central**.
4. Set the public port to **3000**.
5. Enable **auto-deploy on push to `main`**.

### 5.2 Set Environment Variables (Northflank Secrets)

| Variable                               | Value                                                          |
| -------------------------------------- | -------------------------------------------------------------- |
| `NODE_ENV`                             | `production`                                                   |
| `PORT`                                 | `3000`                                                         |
| `DATABASE_URL`                         | Supabase connection-pooler string                              |
| `SUPABASE_URL`                         | Your Supabase project URL                                      |
| `SUPABASE_SERVICE_ROLE_KEY`            | Your Supabase service role key                                 |
| `SUPABASE_STORAGE_BUCKET_ID_IMAGES`    | `id-captures` (or override)                                    |
| `SUPABASE_STORAGE_BUCKET_DISPUTE_DOCS` | `dispute-docs` (or override)                                   |
| `JWT_SECRET_STAFF`                     | _(64-char random string)_                                      |
| `JWT_SECRET_ESTABLISHMENT`             | _(64-char random string)_                                      |
| `JWT_SECRET_BENEFICIARY`               | _(64-char random string)_                                      |
| `SMS_PROVIDER`                         | `semaphore`                                                    |
| `SEMAPHORE_API_KEY`                    | Your Semaphore API key                                         |
| `RESEND_API_KEY`                       | Your Resend API key (verified `idetect.it.com` sending domain) |
| `FIREBASE_SERVICE_ACCOUNT_JSON`        | Full Firebase service-account JSON (as a string)               |
| `OCR_CONFIDENCE_THRESHOLD`             | `75`                                                           |

### 5.3 Deploy and Verify

1. Trigger the first deploy (or push to `main`).
2. Once live, check the health endpoint:
   ```
   GET https://idetect.it.com/api/health
   ```
   _Expected: a healthy/ready response confirming the database connection._
3. Load `https://idetect.it.com` in a browser — the staff login page should appear.

---

## 6. Connect the Domain

1. Point the `idetect.it.com` domain's DNS at the Northflank service (Northflank provides the target records once the service is created).
2. Northflank provisions the TLS/SSL certificate automatically for the domain — no manual certificate management needed.
3. Verify propagation at a DNS checker, then confirm `https://idetect.it.com` loads over HTTPS with a valid certificate.

---

## 7. Notifications & Email Setup

| Channel            | Provider                              | Notes                                                                            |
| ------------------ | ------------------------------------- | -------------------------------------------------------------------------------- |
| SMS (OTP, alerts)  | Semaphore                             | API key stored in Northflank Secrets                                             |
| Push notifications | Firebase Cloud Messaging (FCM) / APNs | Service-account JSON stored in Northflank Secrets                                |
| Email              | Resend                                | Uses the verified `idetect.it.com` sending domain; API key in Northflank Secrets |

If a notification provider's credentials are missing, the corresponding service degrades gracefully (e.g., logs the message instead of sending it) rather than crashing the API — confirm this behavior is acceptable for your environment before going live.

---

## 8. Mobile App Configuration

Both Flutter apps (Client Portal in the repo root `lib/`, Beneficiary app in `apps/beneficiary/`) must point at the production API:

```
https://idetect.it.com/api
```

There are currently **no published app store / APK distribution links** — see the [User Manual §4.5](USER_MANUAL.md#45-mobile-installation) for the outstanding items around official mobile distribution.

---

## 9. Post-Deployment Verification Checklist

- [ ] `https://idetect.it.com` loads the staff login page
- [ ] `GET https://idetect.it.com/api/health` returns healthy
- [ ] BPLO login routes to the BPLO dashboard
- [ ] OSCA login routes to the Senior Citizen-only dashboard
- [ ] PDAO login routes to the PWD-only dashboard
- [ ] Cross-portal access is blocked (an OSCA account cannot reach PDAO data, etc.)
- [ ] ID scan / verification works end-to-end from the Client Portal mobile app
- [ ] OTP delivery works (Semaphore) for beneficiary login
- [ ] Push notifications deliver (Firebase FCM)
- [ ] Transactional email delivers (Resend, `idetect.it.com` domain)
- [ ] Session timeout works (idle → redirect to login)
- [ ] HTTPS padlock shows in the browser (Northflank-managed TLS)

---

## 10. Ongoing Maintenance

| Task                    | How                                                                   |
| ----------------------- | --------------------------------------------------------------------- |
| Deploy a code update    | `git push` to `main` — Northflank auto-builds and deploys             |
| View API logs           | Northflank → Service → Logs                                           |
| View/query the database | Supabase → Project → Table Editor / SQL Editor                        |
| Rotate a secret         | Update the value in Northflank Secrets, redeploy the service          |
| Rollback a bad deploy   | Northflank → Service → Deployment history → redeploy a previous build |
| Add a new staff account | Use the Staff page inside the portal (no server access needed)        |

---

## Quick Reference

| Item             | Value                                               |
| ---------------- | --------------------------------------------------- |
| Production URL   | https://idetect.it.com                              |
| API health check | https://idetect.it.com/api/health                   |
| Hosting          | Northflank, US-Central, combined service, port 3000 |
| Database         | PostgreSQL via Supabase (connection pooler)         |
| Storage          | Supabase Storage — `id-captures`, `dispute-docs`    |
| Repository       | GitHub `ceedee9/idetect-capstone`                   |

---

_Guide updated for the Northflank/Supabase production deployment — iDetect Capstone 2026 — PLV CEIT_
_De los Reyes · Enoria · Mercado · Santiago_
