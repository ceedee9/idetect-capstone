# iDetect Deployment Guide

**Pamantasan ng Lungsod ng Valenzuela — Capstone 2026**

> This guide covers buying a domain, choosing a host, and deploying the full
> iDetect stack (Node.js API + PostgreSQL + React frontend) to a live URL.

---

## 1. Architecture Overview

Your app has **three parts** that all need to be live:

| Part           | What it is                      | Recommended Host   |
| -------------- | ------------------------------- | ------------------ |
| **API**        | Node.js / Express (`apps/api/`) | Railway            |
| **Database**   | PostgreSQL                      | Railway (built-in) |
| **Web Portal** | React / Vite (`apps/web/`)      | Vercel             |
| **Domain**     | e.g. `idetect.com.ph`           | Namecheap          |

```
User → idetect.com.ph         → Vercel (React app)
                                   ↓ API calls
       idetect.com.ph/api/*   → Railway (Node.js + PostgreSQL)
```

The React app is deployed as a static site on Vercel. All `/api/*` requests are
proxied to the Railway backend. You only need **one domain** for both.

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

### Hosting: Railway (API + DB) + Vercel (Frontend)

**Why not Namecheap hosting?**
Namecheap's shared hosting runs PHP/Apache. It does not support Node.js.
Their VPS works but requires Linux sysadmin knowledge (nginx, PM2, etc.) —
too much overhead for a capstone.

**Why Railway?**

- Native Node.js support — zero configuration
- Built-in PostgreSQL with automatic backups
- Automatic deploys from GitHub
- Free trial, then **$5/month** (Hobby plan)
- Runs 24/7 (unlike Render's free tier which sleeps after 15 min)

**Why Vercel?**

- Made specifically for React/Vite apps
- Deploys in ~30 seconds from GitHub
- **Free forever** for static frontend
- Custom domain support included

**Cost summary:**
| Item | Cost |
|---|---|
| Domain (Namecheap, .com.ph) | ~₱800/year |
| Railway Hobby plan | ~$5/month (~₱280) |
| Vercel | Free |
| **Total** | **~₱350/month** |

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

Save these somewhere secure (a password manager). You'll paste them into Railway.

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

## 5. Deploy the API on Railway

### 5.1 Sign Up

1. Go to **railway.app** and sign up with your GitHub account.
2. Click **New Project → Deploy from GitHub repo**.
3. Select your `idetect` repository.

### 5.2 Configure the API Service

Railway will detect your repo. You need to tell it where the API lives:

1. After the project is created, click your service → **Settings**.
2. Under **Root Directory**, type: `apps/api`
3. Under **Start Command**, type: `npm start`
4. Click **Deploy**.

### 5.3 Add PostgreSQL

1. In your Railway project, click **+ New → Database → Add PostgreSQL**.
2. Railway creates a database and gives you a `DATABASE_URL` variable automatically.
3. Click the PostgreSQL service → **Variables** tab — copy the `DATABASE_URL` value.
   It looks like: `postgresql://postgres:PASSWORD@HOST:PORT/railway`

### 5.4 Update Your API to Use DATABASE_URL

In your `apps/api/` database config, you likely have individual `DB_HOST`, `DB_NAME`,
etc. variables. Railway provides a single `DATABASE_URL`. Update your database
connection file to support both:

Open your database connection file (likely `apps/api/src/db.js` or similar) and
ensure it reads `DATABASE_URL` when present:

```js
// db.js (or wherever you create your pg Pool)
const { Pool } = require("pg");

const pool = process.env.DATABASE_URL
  ? new Pool({
      connectionString: process.env.DATABASE_URL,
      ssl: { rejectUnauthorized: false }, // required for Railway
    })
  : new Pool({
      host: process.env.DB_HOST,
      port: process.env.DB_PORT,
      database: process.env.DB_NAME,
      user: process.env.DB_USER,
      password: process.env.DB_PASSWORD,
    });

module.exports = pool;
```

Commit and push this change:

```bash
git add apps/api/src/db.js
git commit -m "support DATABASE_URL for Railway"
git push
```

### 5.5 Set Environment Variables on Railway

In your Railway project → your API service → **Variables** tab, add:

| Variable                   | Value                          |
| -------------------------- | ------------------------------ |
| `NODE_ENV`                 | `production`                   |
| `PORT`                     | `3000`                         |
| `JWT_SECRET_STAFF`         | _(your 64-char random string)_ |
| `JWT_SECRET_ESTABLISHMENT` | _(your 64-char random string)_ |
| `JWT_SECRET_BENEFICIARY`   | _(your 64-char random string)_ |
| `JWT_EXPIRES_IN`           | `8h`                           |
| `OCR_CONFIDENCE_THRESHOLD` | `75`                           |
| `SMS_PROVIDER`             | `semaphore`                    |
| `SMS_API_KEY`              | _(your Semaphore key)_         |
| `CLOUDINARY_CLOUD_NAME`    | _(if configured)_              |
| `CLOUDINARY_API_KEY`       | _(if configured)_              |
| `CLOUDINARY_API_SECRET`    | _(if configured)_              |

> **Do NOT add** `DB_HOST`, `DB_NAME`, etc. — Railway's `DATABASE_URL` replaces those.

### 5.6 Run Database Migrations

Once the API service is deployed and the database is connected:

1. In Railway, go to your API service → **Settings → Run a one-off command**.
2. Run your migration command, e.g.:
   ```
   node src/database/migrate.js
   ```
   (Use whatever migration command your project uses.)
3. Verify in the Railway PostgreSQL service → **Data** tab that your tables exist.

### 5.7 Get Your Railway API URL

In Railway → your API service → **Settings** → under **Domains**, click
**Generate Domain**. You get a URL like:

```
https://idetect-api-production.up.railway.app
```

Keep this — you need it in the next step.

---

## 6. Deploy the Frontend on Vercel

### 6.1 Sign Up

1. Go to **vercel.com** and sign up with your GitHub account.
2. Click **Add New → Project**.
3. Import your `idetect` GitHub repository.

### 6.2 Configure the Project

Vercel will show configuration options:

| Setting              | Value           |
| -------------------- | --------------- |
| **Framework Preset** | Vite            |
| **Root Directory**   | `apps/web`      |
| **Build Command**    | `npm run build` |
| **Output Directory** | `dist`          |

### 6.3 Set Environment Variables on Vercel

Click **Environment Variables** and add:

| Variable       | Value                              |
| -------------- | ---------------------------------- |
| `VITE_API_URL` | _(leave blank — proxy handles it)_ |

Actually, check your `apps/web/vite.config.js`. It likely has a proxy like:

```js
proxy: { '/api': 'http://localhost:3000' }
```

This proxy only works in development. For production, you need to tell Vercel
to forward `/api/*` to your Railway URL. Create this file:

**`apps/web/vercel.json`**

```json
{
  "rewrites": [
    {
      "source": "/api/:path*",
      "destination": "https://idetect-api-production.up.railway.app/api/:path*"
    }
  ]
}
```

Replace `idetect-api-production.up.railway.app` with your actual Railway URL.

Commit this file:

```bash
git add apps/web/vercel.json
git commit -m "add Vercel API proxy rewrite"
git push
```

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
and all API calls go through Vercel → Railway.

You can check propagation status at: **dnschecker.org**

---

## 8. Update CORS on the API

Now that you have a real domain, update your API's CORS allowed origins.

Open `apps/api/src/index.js` (or wherever you configure CORS) and set:

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

Commit, push — Railway auto-deploys from GitHub.

---

## 9. Firebase (Push Notifications) on Railway

Your API uses a Firebase service account JSON file (`FIREBASE_KEY_PATH`).
You cannot upload files to Railway — instead, use an environment variable:

1. Open your Firebase `.json` key file. Copy the entire contents.
2. In Railway → your API service → Variables, add:
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
| **Deploy a code update**    | `git push` — both Railway and Vercel auto-deploy               |
| **View API logs**           | Railway → your service → **Logs** tab                          |
| **View database**           | Railway → PostgreSQL service → **Data** tab                    |
| **Rollback a bad deploy**   | Vercel/Railway both have one-click rollback in their dashboard |
| **Domain renewal**          | Namecheap sends email reminders — renew before expiry          |
| **Add a new staff account** | Use the Staff page inside the portal (no server access needed) |

---

## Quick Reference — URLs

| Service           | URL                                                   |
| ----------------- | ----------------------------------------------------- |
| Your live portal  | `https://idetect.com.ph`                              |
| Vercel dashboard  | `vercel.com/dashboard`                                |
| Railway dashboard | `railway.app/dashboard`                               |
| Namecheap DNS     | `namecheap.com → Domain List → Manage → Advanced DNS` |

---

_Guide written for iDetect Capstone 2026 — PLV CEIT_
_De los Reyes · Enoria · Mercado · Santiago_
