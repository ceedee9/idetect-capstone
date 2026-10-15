# iDetect Session Handoff / Memory Log

Last updated: 2026-10-15 (PHT). Paste or attach this file at the start of a new chat.

## 1. Project and stack
- Monorepo at `C:\Users\carlo\Documents\idetect`:
  - `apps/api`: Node/Express + Postgres.
  - `apps/web`: unified staff portal (React/Vite).
  - `apps/beneficiary`: Flutter beneficiary app.
  - `lib/`: main Flutter app.
  - Legacy portals `apps/web-osca|pdao|bplo` are untouched.
- Hosting (actual):
  - Frontend `idetect.it.com` is on **Vercel** (`apps/web/vercel.json`).
  - API is on **Northflank**: `https://site--idetect--lr4dgpy2rvkq.code.run/api`.
  - `documentation/DEPLOYMENT_GUIDE.md` still wrongly describes a combined Northflank deployment and needs correcting.
- We work through the IT-expert "Change Matrix" (items F-01 to F-10 and others).

## 2. Working preferences (credits / usage)
- Keep chat replies short and concise.
- Do NOT re-read large files unnecessarily.
- Optimize credit use:
  - Prefer targeted greps and views with line ranges.
  - Avoid repeated builds, test runs and tool calls.
  - Do not delegate to subagents for small tasks.
  - Do not retry blind builds or rebuilds. Ask for logs first (each Northflank build uses build minutes).
- Ask the user for screenshots or logs rather than guessing at external dashboards (Northflank, Vercel).
- Use a local test loop instead of commit, push and deploy for UI checks.
- Do not commit `apps/web/.env.local`.

## 3. DONE (pushed to `main`)
- Beneficiary app (earlier):
  - "Other" dispute type (API validation + migration 034).
  - History tab = verifications + disputes timeline.
  - EN/FIL selector.
  - Localized status labels and dates.
  - Retryable "service unavailable" states.
  - Header "iDetect / Beneficiary Portal".
  - Redesigned status card (ID masked to the last 2 characters, with show/hide).
- F-01 (partial): staff logout audit.
  - `POST /auth/staff/logout`, idle-timeout reason, test `apps/api/tests/staffLogout.test.js`.
- Audit Logs page: a distinct badge color per action, and aligned tab counts.
- F-10: 2,500-character limit on the suspension reason (server-side, live counter in the BPLO form, test).
- Documents: `documentation/BENEFICIARY_APP_RECOMMENDATION_UPDATES.md`, and `documentation/IT_EXPERT_RECOMMENDATION_UPDATES.md` (admin part: logout auditing, character limit, F-08 policy). Also `FUTURE_SYSTEM_ROADMAP.md` and `DEFENSE_GUIDE.md`.
- F-08 (session and sensitive data), commit `53e9b63` "Implementing F-08 3":
  - 8-hour absolute session lifetime.
  - Password step-up before the beneficiary detail drawer (`apps/api/src/middleware/stepUp.js`, reauth endpoint).
  - "Reveal ID"/"Hide ID" button and a "Show password" toggle.
  - Closing the modal returns to the list.
  - API suite passed (16 suites, 54 tests) and the web build passed.
- Northflank frontend attempt (3 commits) was reverted. The three reverts (`2ecf194`, `69196a8`, `a564cdb`) are pushed. The repo content equals `53e9b63`.

## 4. CURRENT STATUS
### Production frontend (Vercel)
- It is NOT showing the F-08 UI. Vercel Hobby rate-limited deployments ("retry in 24 hours" from about 15:29 PHT on 2026-10-14). Production is still on the old commit `b615964`.
- The limit should clear around 15:29 PHT on 2026-10-15.
- After that, redeploy the latest `main` and verify the live bundle contains "Reveal ID" and "Show password". Do not redeploy the old `b615964` entry.

### Production API (Northflank) — UNRESOLVED, check first
- Build type is Buildpack (Heroku). Build context was `/`.
- The running deployment was the crash-looping `53ce206` (from the Northflank-frontend attempt). The builds for `a564cdb` failed (0 of 2).
- Suggested fixes, not yet confirmed by the user:
  1. In Build options, set **Build context = `/apps/api`**. The repo root has no `package.json` or Procfile. This is a guess, and the previous setting is unknown.
  2. Keep **CMD override = `node src/server.js`**.
  3. Start a build of `main`'s latest commit, then deploy it.
  4. Fallback: in Builds, click **Deploy** on the old successful build of `53e9b63`. If only Rebuild is available, do (1).
  5. Always read the build log of failed builds before retrying, and send the last ~30 lines.
- Verify with `GET https://site--idetect--lr4dgpy2rvkq.code.run/api/health`.
- An extra `VITE_API_URL` env var was added on Northflank. It is harmless and can be removed.
- The live site and apps depend on this API, so it matters most.

### Local testing (works, no commit needed)
- API: `cd apps\api; npm run dev` (port 3000, uses the shared DB via `.env`, and runs migrations on startup).
- Web: `cd apps\web; npm run dev` at http://localhost:5173 (Vite proxies `/api` to `localhost:3000`).
- Login failed locally ("Connection issue") because `apps/web/.env.local` had `VITE_API_URL=http://192.168.254.106:3000/api` (an old LAN IP).
- I changed it to `VITE_API_URL=/api`. The web dev server must be restarted for this to apply.
- `.env.local` is tracked by git and shows as modified. DO NOT commit it, and restore the LAN IP when testing the phone app.
- Test flow: open a beneficiary, close the modal (should go to the list), reopen, use Show password, enter the password to see the DOB, use Reveal ID / Hide ID.

## 5. KNOWN GAPS / NOTES
- Establishment and beneficiary-app logouts are not audited.
- Audit page tab counts only reflect the 30 rows on the current page.
- Two migrations are numbered 033 (ours is 034).
- Server-generated notification text may stay in English when the app is Filipino.
- `/beneficiaries/:id/sensitive` (full ID reveal) has no server-side step-up requirement. The UI route is the only enforcement. Discuss a short-lived grant after the detail step-up before implementing.
- Undecided: the red label (which one?), the session timeout policy (experts said 2 min; portals use 15 min with a 2 min warning), and the photo feature (deferred).

## 6. TO DO (recommended order)
1. Fix and verify the Northflank API (section 4). Optionally remove the extra env var.
2. Once the Vercel limit clears, redeploy `main` and verify the live UI. Optionally fix `DEPLOYMENT_GUIDE.md` to state Vercel (frontend) and Northflank (API).
3. F-08 remaining:
   - Step-up for sensitive exports and case files.
   - Decide whether suspension/reinstatement and establishment-user management need step-up.
   - Beneficiary app protected-screen lock (about 5 min).
   - Remember Me safeguards testing and live acceptance testing.
4. F-09: suspension start/end dates and a reminder. Auto-reinstatement needs a policy decision first.
5. F-04: reference numbers (e.g. DSP-2026-000123) for disputes and fraud flags, generated by the database.
6. F-01 gaps: inventory and log record views/edits, and establishment/beneficiary logouts.
7. F-05/F-06: ID/age masking in API responses.
8. Decisions needed from others: F-08 session timeout, F-03 retention, F-09 suspension policy.

## 7. Git state
- Branch `main`, pushed up to `a564cdb`.
- The only local change is the uncommitted `apps/web/.env.local` (do not commit it).
