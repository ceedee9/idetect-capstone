# Unified Portal API Setup

This note applies to the deployed unified portal in `apps/web`.

## API URL Rules

The unified portal uses `VITE_API_URL` in production.
In local development it falls back to `/api`.

### Local development

If you are running the API on this machine and want to point the portal at it directly, use:

```env
VITE_API_URL=http://192.168.254.106:3000/api
```

If you do not set `VITE_API_URL`, the portal falls back to `/api` only in development.

### Deployed portal

If the unified portal is deployed on Vercel, set `VITE_API_URL` to your deployed API project URL.

Example:

```env
VITE_API_URL=https://your-api-project.vercel.app/api
```

You only need a full URL if you intentionally use a separate backend host.

## Current Code State

- `apps/web/src/services/api.js` requires `VITE_API_URL` in production.
- `apps/web/vite.config.js` still proxies `/api` to `http://localhost:3000` for local dev.
- `apps/web/vercel.json` keeps SPA routing and does not proxy the API in production.

## Rebuild Order

When testing locally, rebuild in this order:

1. Start the API server.
2. Rebuild or rerun the unified portal with the correct `VITE_API_URL`.
3. Rebuild or rerun the establishment Flutter app with `--dart-define=IDETECT_API_BASE_URL=...`.
4. Rebuild or rerun the beneficiary Flutter app with the same `--dart-define` pattern.
5. Create one test establishment from the unified portal.
6. Confirm the row appears in the same Supabase database.
7. Log in from the establishment app using the same credentials.

## Recommended Local Commands

Unified portal:

```bash
cd apps/web
npm run dev
```

If you need to build it locally with an explicit API URL:

```bash
cd apps/web
set VITE_API_URL=http://192.168.254.106:3000/api && npm run build
```

Flutter establishment app:

```bash
flutter run --dart-define=IDETECT_API_BASE_URL=http://192.168.254.106:3000/api
```

Flutter beneficiary app:

```bash
cd apps/beneficiary
flutter run --dart-define=IDETECT_API_BASE_URL=http://192.168.254.106:3000/api
```

## If Login Still Fails

Check these in order:

1. The portal and the app are using the same API base URL.
2. The establishment row exists in the current Supabase database.
3. The establishment status is `approved`.
4. The password you are using is the one generated for that same row.
5. The app login response body is not being collapsed into a generic error.
