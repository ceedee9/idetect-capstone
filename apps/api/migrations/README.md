# iDetect — OCR-Based Discount ID Verification System

Pamantasan ng Lungsod ng Valenzuela | Capstone Project 2026

## Monorepo Structure

```
idetect/
├── apps/
│   ├── api/                  # Node.js + Express REST API (shared backend)
│   ├── web-bplo/             # React web portal — Business Permit & Licensing Office
│   ├── web-osca/             # React web portal — Office of Senior Citizens Affairs
│   ├── web-pdao/             # React web portal — Persons with Disability Affairs Office
│   ├── mobile-client/        # Flutter mobile app — Business Establishments
│   └── mobile-beneficiary/   # Flutter mobile app — Senior Citizens & PWDs
├── packages/
│   └── shared/               # Shared types, constants, validation schemas
├── database/
│   ├── migrations/           # SQL migration files (ordered)
│   └── seeds/                # Seed data for development/testing
└── docs/                     # Architecture diagrams, API docs
```

## Five Portals

| Portal | Type | Users |
|--------|------|-------|
| `web-bplo` | Web | BPLO administrators |
| `web-osca` | Web | OSCA administrators |
| `web-pdao` | Web | PDAO administrators |
| `mobile-client` | Mobile (Flutter) | Business establishment staff |
| `mobile-beneficiary` | Mobile (Flutter) | Senior Citizens & PWDs |

All portals connect to the single `api` backend.

## Tech Stack

- **Backend:** Node.js + Express + PostgreSQL
- **Web Portals:** React + Vite + TailwindCSS
- **Mobile Apps:** Flutter (Android 8.0+ / iOS 12.0+)
- **Auth:** JWT + OTP (SMS)
- **OCR:** Tesseract.js (server-side)
- **Storage:** Supabase Storage (ID images, dispute documents)

## Getting Started

```bash
# 1. Set up database
cd database && psql -U postgres -f migrations/001_create_users.sql
# (run all migrations in order)

# 2. Start API
cd apps/api && npm install && npm run dev

# 3. Start a web portal (example: BPLO)
cd apps/web-bplo && npm install && npm run dev
```

## Environment Variables

Copy `apps/api/.env.example` to `apps/api/.env` and fill in values.
