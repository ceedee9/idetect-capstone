# iDetect Deployment Guide

**Pamantasan ng Lungsod ng Valenzuela — Capstone 2026**

> This guide covers buying a domain, choosing a host, and deploying the full
> iDetect stack (Node.js API + PostgreSQL + React frontend) to a live URL.

---

## 1. Architecture Overview

Your app has **three parts** that all need to be live:

| Part           | What it is                      | Recommended Host |
| -------------- | ------------------------------- | ---------------- |
| **API**        | Node.js / Express (`apps/api/`) | Vercel           |
| **Database**   | PostgreSQL                      | Supabase         |
| **Web Portal** | React / Vite (`apps/web/`)      | Vercel           |
| **Domain**     | e.g. `idetect.com.ph`           | Namecheap        |

```
User → idetect.com.ph         → Vercel (React app)
                                   ↓ API calls to the deployed Vercel API
     idetect.com.ph/api/*   → Vercel API functions
                        ↓
                      Supabase
```

The React app and the API both live on Vercel. Supabase provides the database and storage.

---

## 2. Choosing a Host — Recommendation

### Domain: Namecheap ✅ (your choice is good)

Namecheap is a solid registrar. Pros: cheap, no dark patterns, good DNS panel.

**Suggested domain options** (check availability on namecheap.com):

- `idetect.com.ph` — most professional for a Philippine system (~₱800/yr)
- `idetect-valenzuela.com` — international TLD, easier to register (~$12/yr)
- `idetect.site` — cheapest (~$2 first year, ~$25 renewal)

> **Note:** `.gov.ph` requires official LGU accreditation — skip it for the capstone.

---

### Hosting: Vercel (API + Frontend) + Supabase (DB + Storage)

**Why not Namecheap hosting?**
Namecheap's shared hosting runs PHP/Apache. It does not support Node.js.
Their VPS works but requires Linux sysadmin knowledge (nginx, PM2, etc.) —
too much overhead for a capstone.

**Why Vercel for the API?**

- Free tier is enough for a capstone backend
- Portal and API both deploy through Vercel and stay on the same stack
- Automatic deploys from GitHub
- Works well for request/response APIs

**Why Vercel?**

- Made specifically for React/Vite apps
- Deploys in ~30 seconds from GitHub
- **Free forever** for static frontend
- Custom domain support included

**Cost summary:**
| Item | Cost |
|---|---|
| Domain (Namecheap, .com.ph) | ~₱800/year |
| Vercel | Free |
| Supabase | Free tier to start |
| **Total** | **Low-cost / free to start** |

---

## 3. Pre-Deployment Checklist

Do these **before** you buy anything.

### 3.1 Push Code to GitHub

Everything must be in a GitHub repository. If not already:

```bash
# In the root idetect/ folder
git init
git add .
git commit -m "initial commit"
git remote add origin https://github.com/YOUR_USERNAME/idetect.git
git push -u origin main
```

> ⚠️ Make sure `.env` is in your `.gitignore`. **Never push secrets to GitHub.**

Check that `apps/api/.gitignore` or the root `.gitignore` contains:

```
.env
*.env
node_modules/
```

### 3.2 Generate Strong Production Secrets

Replace your development secrets with long random strings for production.
Run this in PowerShell to generate them:

```powershell
# Run 3 times — one output per JWT secret
-join ((65..90) + (97..122) + (48..57) | Get-Random -Count 64 | ForEach-Object { [char]$_ })
```

You will need:

- `JWT_SECRET_STAFF` — a 64-character random string
- `JWT_SECRET_ESTABLISHMENT` — a 64-character random string
- `JWT_SECRET_BENEFICIARY` — a 64-character random string

Save these somewhere secure (a password manager). You'll paste them into Vercel.

### 3.3 Prepare the API for Production

Open `apps/api/package.json` and confirm there is a `start` script:

```json
"scripts": {
  "start": "node src/index.js",
  "dev": "nodemon src/index.js"
}
```

If your entry file is named differently (e.g. `server.js`), adjust accordingly.

---

## 4. Buy the Domain (Namecheap)

1. Go to **namecheap.com** and search for your chosen domain name.
2. Add it to cart. **Uncheck** the "WhoisGuard" upsell if you don't need it
   (it's free anyway now on most TLDs).
3. Checkout — you do not need hosting from Namecheap; domain only.
4. After purchase, go to **Dashboard → Domain List → Manage** for your domain.
5. Click **Advanced DNS** — this is where you will add DNS records later.

> Keep this tab open — you will return to it in Step 7.

---

## 5. Deploy the API on Vercel

### 5.1 Sign Up

1. Go to **vercel.com** and sign up with your GitHub account.
2. Click **Add New → Project**.
3. Import your `idetect` repository.

### 5.2 Configure the API Project

Deploy `apps/api` as its own Vercel project:

| Setting              | Value         |
| -------------------- | ------------- |
| **Framework Preset** | Other         |
| **Root Directory**   | `apps/api`    |
| **Build Command**    | leave default |
| **Output Directory** | none          |

### 5.3 Set Environment Variables on Vercel

Add the API secrets and Supabase settings in the API project:

| Variable                    | Value                           |
| --------------------------- | ------------------------------- |
| `NODE_ENV`                  | `production`                    |
| `DATABASE_URL`              | Your Supabase connection string |
| `SUPABASE_URL`              | Your Supabase project URL       |
| `SUPABASE_SERVICE_ROLE_KEY` | Your Supabase service role key  |
| `JWT_SECRET_STAFF`          | _(your 64-char random string)_  |
| `JWT_SECRET_ESTABLISHMENT`  | _(your 64-char random string)_  |
| `JWT_SECRET_BENEFICIARY`    | _(your 64-char random string)_  |
| `JWT_EXPIRES_IN`            | `8h`                            |
| `OCR_CONFIDENCE_THRESHOLD`  | `75`                            |
| `SMS_PROVIDER`              | `semaphore`                     |
| `SMS_API_KEY`               | _(your Semaphore key)_          |

### 5.4 Deploy and Test

1. Deploy the API project.
2. Open its `/api/health` endpoint.
3. Confirm the response shows the database as `ok`.

---

## 6. Deploy the Frontend on Vercel

### 6.1 Sign Up

1. Go to **vercel.com** and sign up with your GitHub account.
2. Click **Add New → Project**.
3. Import your `idetect` repository.

### 6.2 Configure the Web Project

Vercel will show configuration options:

| Setting              | Value           |
| -------------------- | --------------- |
| **Framework Preset** | Vite            |
| **Root Directory**   | `apps/web`      |
| **Build Command**    | `npm run build` |
| **Output Directory** | `dist`          |

### 6.3 Set Environment Variables on Vercel

Set the portal API base URL to the deployed API project:

| Variable       | Value                                     |
| -------------- | ----------------------------------------- |
| `VITE_API_URL` | `https://your-api-project.vercel.app/api` |

### 6.4 Deploy

Click **Deploy**. Vercel builds and deploys in about 30 seconds. You get a URL like:

```
https://idetect.vercel.app
```

Test it — the login page should load and API calls should work.

---

## 7. Connect Your Custom Domain

### 7.1 Add Domain to Vercel

1. In Vercel → your project → **Settings → Domains**.
2. Type your domain: `idetect.com.ph` and click **Add**.
3. Vercel shows you DNS records to add. You need two:

| Type    | Name  | Value                  |
| ------- | ----- | ---------------------- |
| `A`     | `@`   | `76.76.21.21`          |
| `CNAME` | `www` | `cname.vercel-dns.com` |

### 7.2 Add DNS Records in Namecheap

1. Go back to Namecheap → **Dashboard → Domain List → Manage → Advanced DNS**.
2. Delete any existing `A` record for `@` (there may be a default Namecheap parking one).
3. Click **Add New Record** and add both records from the table above.
4. Set TTL to **Automatic**.
5. Save.

DNS propagation takes **5 minutes to 48 hours** (usually under 30 minutes).

### 7.3 Verify

Once propagated, visiting `https://idetect.com.ph` should load your React app
and API calls should go to the deployed Vercel API project.

You can check propagation status at: **dnschecker.org**

---

## 8. Update CORS on the API

Now that you have a real domain, update your API's CORS allowed origins.

Open `apps/api/src/app.js` and set:

```js
const cors = require("cors");

app.use(
  cors({
    origin: [
      "https://idetect.com.ph",
      "https://www.idetect.com.ph",
      "https://idetect.vercel.app", // keep during testing
      ...(process.env.NODE_ENV === "development"
        ? ["http://localhost:5173"]
        : []),
    ],
    credentials: true,
  }),
);
```

Commit and push — Vercel auto-deploys from GitHub.

---

## 9. Firebase (Push Notifications)

Your API uses a Firebase service account JSON file (`FIREBASE_KEY_PATH`).
You should use environment variables for the service account JSON rather than a file path:

1. Open your Firebase `.json` key file. Copy the entire contents.
2. In Vercel → your API project → Environment Variables, add:
   ```
   FIREBASE_SERVICE_ACCOUNT_JSON = { "type": "service_account", ... }
   ```
   (Paste the entire JSON as the value.)
3. In your API code, update the Firebase initialization:

```js
// Instead of reading from a file path:
const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON
  ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON)
  : require(process.env.FIREBASE_KEY_PATH);

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
```

---

## 10. Post-Deployment Verification Checklist

After everything is live, test each of these:

- [ ] `https://idetect.com.ph` loads the login page
- [ ] Login works with `osca_admin` credentials — green theme, Senior Citizens nav
- [ ] Login works with `pdao_admin` credentials — teal theme, PWD Records nav
- [ ] Login works with `bplo_admin` credentials — blue theme, Establishments nav
- [ ] Beneficiary records load for OSCA/PDAO
- [ ] Establishments load for BPLO
- [ ] ID scan / verification works
- [ ] Session timeout works (idle 15 min → redirect to login)
- [ ] HTTPS padlock shows in browser (Vercel handles SSL automatically)
- [ ] Mobile layout looks correct (test on a phone)

---

## 11. Ongoing Maintenance

| Task                        | How                                                            |
| --------------------------- | -------------------------------------------------------------- |
| **Deploy a code update**    | `git push` — Vercel auto-deploys both projects                 |
| **View API logs**           | Vercel → API project → **Functions / Logs**                    |
| **View database**           | Supabase → Project → **Table Editor / SQL**                    |
| **Rollback a bad deploy**   | Vercel has one-click rollback in the dashboard                 |
| **Domain renewal**          | Namecheap sends email reminders — renew before expiry          |
| **Add a new staff account** | Use the Staff page inside the portal (no server access needed) |

---

## Quick Reference — URLs

| Service          | URL                                                   |
| ---------------- | ----------------------------------------------------- |
| Your live portal | `https://idetect.com.ph`                              |
| Vercel dashboard | `vercel.com/dashboard`                                |
| Vercel dashboard | `vercel.com/dashboard`                                |
| Namecheap DNS    | `namecheap.com → Domain List → Manage → Advanced DNS` |

---

_Guide written for iDetect Capstone 2026 — PLV CEIT_
_De los Reyes · Enoria · Mercado · Santiago_
