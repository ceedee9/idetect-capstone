# iDetect Deployment Guide

**Pamantasan ng Lungsod ng Valenzuela — Capstone 2026**

> This guide covers the production deployment of iDetect as it is today: the
> staff web portal on **Vercel** (`https://idetect.it.com`), the Node.js/Express
> API on **Northflank**, and PostgreSQL and file storage on **Supabase**.
> The API and portal are deployed separately.

---

## 1. Architecture Overview

| Part                       | What it is                                                                                          | Host                                                     |
| -------------------------- | --------------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| **Staff Web Portal**       | React/Vite single-page app (`apps/web`), role-routed to BPLO/OSCA/PDAO                              | Vercel                                                   |
| **REST API**               | Node.js / Express (`apps/api`), serves `/api/*`                                                     | Northflank (`https://site--idetect--lr4dgpy2rvkq.code.run/api`) |
| **Database**               | PostgreSQL                                                                                          | Supabase (connection pooler)                             |
| **File/image storage**     | ID captures, dispute documents                                                                      | Supabase Storage (`id-captures`, `dispute-docs` buckets) |
| **Domain**                 | `idetect.it.com` (staff portal)                                                                     | DNS pointed at Vercel                                    |

```
Staff browser → https://idetect.it.com          → Vercel (static React/Vite build, SPA rewrites)
                                                     │  VITE_API_URL (set at build time)
Staff portal, mobile apps → https://<api-host>/api/* → Northflank (Node.js + Express)
                                                     ↓
                                                 Supabase (PostgreSQL + Storage)
```

Staff use one URL: https://idetect.it.com. After sign-in, the account is routed to the BPLO, OSCA, or PDAO dashboard based on its role; there are no separate per-office URLs to distribute.

The two Flutter mobile apps (Client Portal for establishments, Beneficiary app) call the API directly. Their base URL is set at build time (see §8), not in the repository.

---

## 2. Source & CI/CD

- **Repository:** GitHub — `ceedee9/idetect-capstone`
- **Pipeline:** GitHub → Vercel (portal) and GitHub → Northflank (API). Whether a push to `main` auto-deploys is set in each platform's Git settings. Confirm this in both dashboards before relying on it (it is not defined in the repository).
- **Rollback:** Use each platform's deployment history to redeploy a previous build if a release introduces a regression.

---

## 3. Pre-Deployment Checklist

### 3.1 Push Code to GitHub

Everything must be in the `ceedee9/idetect-capstone` GitHub repository.

> ⚠️ Make sure `.env` is in `.gitignore`. **Never commit secrets to GitHub.** All runtime secrets live in the host's secret store (**Northflank Secrets** for the API), not in the repository.

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

The API host runs `npm start` (`node src/server.js`). The server listens on `PORT` (default 3000) on `0.0.0.0`.

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

## 5. Deploy the API on Northflank

### 5.1 Create the API Service

1. Sign in to Northflank and connect the `ceedee9/idetect-capstone` GitHub repository.
2. Create a new service pointed at `apps/api`. This service serves the API only. The staff portal is deployed separately on Vercel (§5.4).
3. Set the region to **US-Central**.
4. Expose port **3000** (the `PORT` default in `apps/api/src/server.js`).
5. Set auto-deploy on push to `main` if you want it. Confirm the setting in Northflank.

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
| `JWT_EXPIRES_IN`                       | `8h`                                                           |
| `ALLOWED_ORIGINS`                      | `https://idetect.it.com` (CORS allow-list; required in production) |
| `SMS_PROVIDER`                         | `semaphore`                                                    |
| `SMS_API_KEY`                          | Your Semaphore API key                                         |
| `SMS_SENDER_NAME`                      | `iDetect`                                                      |
| `RESEND_API_KEY`                       | Your Resend API key (verified `idetect.it.com` sending domain) |
| `FIREBASE_SERVICE_ACCOUNT_JSON`        | Full Firebase service-account JSON (as a string)               |
| `OCR_CONFIDENCE_THRESHOLD`             | `75`                                                           |

### 5.3 Verify the API

1. Trigger the first deploy (or push to `main` if auto-deploy is enabled).
2. Once live, check the health endpoint:
   ```
   GET https://site--idetect--lr4dgpy2rvkq.code.run/api/health
   ```
   _Expected: a healthy/ready response confirming the database connection._

### 5.4 Deploy the Staff Portal on Vercel

The portal is `apps/web`, configured by `apps/web/vercel.json`. That file sends all non-`/api/` routes to `index.html`, so the React routes load on refresh.

1. In Vercel, import the `ceedee9/idetect-capstone` repository and set the **Root Directory** to `apps/web`.
2. Build settings: build command `npm run build` (`vite build`), output directory `dist` (the Vite default).
3. Set the environment variable **`VITE_API_URL`** to the production API base URL, including `/api`, for example `https://site--idetect--lr4dgpy2rvkq.code.run/api`. `VITE_API_URL` is read at build time, so redeploy after changing it. The app throws a "Missing VITE_API_URL" error at startup if it is not set in production (`apps/web/src/services/api.js`).
4. Add the custom domain `idetect.it.com` to the Vercel project (§6).
5. Confirm the API's `ALLOWED_ORIGINS` includes `https://idetect.it.com`, or staff logins will be blocked by CORS.
6. Load `https://idetect.it.com` in a browser. The staff login page should appear.

---

## 6. Connect the Domain

1. Point the `idetect.it.com` DNS records at the Vercel project for the portal. Vercel shows the exact records to add when you add the domain.
2. Let the platform issue the TLS certificate for the domain, then confirm `https://idetect.it.com` loads over HTTPS with a valid certificate.
3. Verify propagation with a DNS checker before the defense.
4. The API keeps its Northflank hostname unless you add a custom domain for it on Northflank. If you add one, update `VITE_API_URL` and the mobile build define (§8).

---

## 7. Notifications & Email Setup

| Channel            | Provider                              | Notes                                                                            |
| ------------------ | ------------------------------------- | -------------------------------------------------------------------------------- |
| SMS (OTP, alerts)  | Semaphore                             | API key stored in Northflank Secrets                                             |
| Push notifications | Firebase Cloud Messaging (FCM) / APNs | Service-account JSON stored in Northflank Secrets                                |
| Email              | Resend                                | Uses the verified `idetect.it.com` sending domain; API key in Northflank Secrets |

If a notification provider's credentials are missing, behaviour differs by channel. Email without `RESEND_API_KEY` logs the message to the console instead of sending it (`apps/api/src/services/emailService.js`). Confirm the SMS and FCM behaviour when their keys are missing before relying on it. Do not assume they degrade the same way.

---

## 8. Mobile App Configuration

Both Flutter apps (Client Portal in the repo root `lib/`, Beneficiary app in `apps/beneficiary/`) read the API base URL at build time. There is no default. The app throws "Missing IDETECT_API_BASE_URL" at startup if it is not passed:

```
flutter build apk --dart-define=IDETECT_API_BASE_URL=https://site--idetect--lr4dgpy2rvkq.code.run/api
```

Use the same value for `flutter run`. Use the production API URL from §5.3.

There are currently **no published app store / APK distribution links** — see the [User Manual §4.5](USER_MANUAL.md#45-mobile-installation) for the outstanding items around official mobile distribution.

---

## 9. Post-Deployment Verification Checklist

- [ ] `https://idetect.it.com` loads the staff login page
- [ ] `GET <api-host>/api/health` returns healthy
- [ ] Staff login from `https://idetect.it.com` succeeds (no CORS error; `ALLOWED_ORIGINS` includes the portal origin)
- [ ] BPLO login routes to the BPLO dashboard
- [ ] OSCA login routes to the Senior Citizen-only dashboard
- [ ] PDAO login routes to the PWD-only dashboard
- [ ] Cross-portal access is blocked (an OSCA account cannot reach PDAO data, etc.)
- [ ] ID scan / verification works end-to-end from the Client Portal mobile app
- [ ] OTP delivery works (Semaphore) for beneficiary login
- [ ] Push notifications deliver (Firebase FCM)
- [ ] Transactional email delivers (Resend, `idetect.it.com` domain)
- [ ] Session timeout works (idle → redirect to login)
- [ ] HTTPS padlock shows in the browser (Vercel-managed TLS for the portal)

---

## 10. Ongoing Maintenance

| Task                    | How                                                                                                   |
| ----------------------- | ----------------------------------------------------------------------------------------------------- |
| Deploy a code update    | Push to `main` if auto-deploy is enabled for each platform; otherwise trigger a deploy in the dashboard |
| Deploy the portal       | Vercel → Project → Deployments (redeploy after changing `VITE_API_URL`)                               |
| View API logs           | Northflank → Service → Logs                                                                           |
| View/query the database | Supabase → Project → Table Editor / SQL Editor                                                        |
| Rotate a secret         | Update the value in Northflank Secrets, redeploy the API service                                      |
| Rollback a bad deploy   | Northflank or Vercel → Deployment history → redeploy a previous build                                 |
| Add a new staff account | Use the Staff page inside the portal (no server access needed)                                        |

---

## Quick Reference

| Item             | Value                                                           |
| ---------------- | --------------------------------------------------------------- |
| Staff portal URL | https://idetect.it.com (Vercel)                                 |
| API base URL     | https://site--idetect--lr4dgpy2rvkq.code.run/api (Northflank)   |
| API health check | https://site--idetect--lr4dgpy2rvkq.code.run/api/health         |
| Hosting          | Vercel (portal), Northflank (API, port 3000), US-Central        |
| Database         | PostgreSQL via Supabase (connection pooler)                     |
| Storage          | Supabase Storage — `id-captures`, `dispute-docs`                |
| Repository       | GitHub `ceedee9/idetect-capstone`                               |

---

_Guide updated for the Vercel (portal) + Northflank (API) + Supabase deployment — iDetect Capstone 2026 — PLV CEIT_
_De los Reyes · Enoria · Mercado · Santiago_
_De los Reyes · Enoria · Mercado · Santiago_
