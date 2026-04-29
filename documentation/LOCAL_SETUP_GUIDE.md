# iDetect — Local Development Setup Guide

## Prerequisites

Install these before anything else:

| Tool           | Version | Download                                     |
| -------------- | ------- | -------------------------------------------- |
| Node.js        | v18+    | https://nodejs.org                           |
| PostgreSQL     | v14+    | https://www.postgresql.org/download/         |
| Flutter SDK    | v3.x    | https://docs.flutter.dev/get-started/install |
| Android Studio | Latest  | For Android emulator / USB debugging         |
| Git            | Any     | https://git-scm.com                          |

---

## 1. Database Setup

### 1.1 Create the database

Open pgAdmin or psql and run:

```sql
CREATE DATABASE idetect;
```

### 1.2 Run all migrations

```powershell
cd C:\Users\carlo\Documents\idetect

$env:PGPASSWORD="carlomon"
psql -U postgres -d idetect -f database/migrations/001_create_users.sql
psql -U postgres -d idetect -f database/migrations/002_create_establishments.sql
psql -U postgres -d idetect -f database/migrations/003_create_beneficiaries.sql
psql -U postgres -d idetect -f database/migrations/004_create_beneficiary_accounts.sql
psql -U postgres -d idetect -f database/migrations/005_create_verification_logs.sql
psql -U postgres -d idetect -f database/migrations/006_create_fraud_flags.sql
psql -U postgres -d idetect -f database/migrations/007_create_disputes.sql
psql -U postgres -d idetect -f database/migrations/008_create_notifications.sql
psql -U postgres -d idetect -f database/migrations/009_create_audit_logs.sql
psql -U postgres -d idetect -f database/migrations/010_beneficiary_accounts_pin.sql
psql -U postgres -d idetect -f database/migrations/011_disability_type.sql
psql -U postgres -d idetect -f database/migrations/012_audit_action_enum.sql
psql -U postgres -d idetect -f database/migrations/013_fraud_flags_denormalize.sql
psql -U postgres -d idetect -f database/migrations/014_fraud_flags_duplicate_detection.sql
psql -U postgres -d idetect -f database/migrations/015_image_path_to_text.sql
```

> **Note:** If you get `already exists` errors, that migration was already applied — safe to skip.

### 1.3 Seed the database

```powershell
psql -U postgres -d idetect -f database/migrations/seed.sql
```

### 1.4 Verify seed accounts

| Portal        | Email                         | Password     |
| ------------- | ----------------------------- | ------------ |
| OSCA Admin    | osca.admin@valenzuela.gov.ph  | Password123! |
| PDAO Admin    | pdao.admin@valenzuela.gov.ph  | Password123! |
| BPLO Admin    | bplo.admin@valenzuela.gov.ph  | Password123! |
| Establishment | jollibee.mcarthur@example.com | Password123! |

---

## 2. API Server Setup

### 2.1 Install dependencies

```powershell
cd C:\Users\carlo\Documents\idetect\apps\api
npm install
```

### 2.2 Create .env file

Copy the example file and fill in your values:

```powershell
Copy-Item .env.example .env
```

Edit `.env`:

```env
PORT=3000
NODE_ENV=development

DB_HOST=localhost
DB_PORT=5432
DB_NAME=idetect
DB_USER=postgres
DB_PASSWORD=carlomon

JWT_SECRET_STAFF=any_long_random_string_here_staff
JWT_SECRET_ESTABLISHMENT=any_long_random_string_here_est

OCR_CONFIDENCE_THRESHOLD=75
```

### 2.3 Start the API

```powershell
cd C:\Users\carlo\Documents\idetect\apps\api
npm run dev
```

API will be running at: **http://localhost:3000**

Health check: http://localhost:3000/api/health

### 2.4 If port 3000 is already in use

Run this to kill whatever is holding it:

```powershell
FOR /F "tokens=5" %a IN ('netstat -ano ^| findstr ":3000" ^| findstr "LISTENING"') DO taskkill /PID %a /F
```

---

## 3. Web Portals Setup

Each portal is a separate Vite/React project. Each runs on its own port.

### 3.1 Install dependencies (run once each)

```powershell
cd C:\Users\carlo\Documents\idetect\apps\web-osca
npm install

cd C:\Users\carlo\Documents\idetect\apps\web-pdao
npm install

cd C:\Users\carlo\Documents\idetect\apps\web-bplo
npm install
```

### 3.2 Start the portals

Open a separate terminal for each:

**Terminal 1 — OSCA Portal**

```powershell
cd C:\Users\carlo\Documents\idetect\apps\web-osca
npm run dev
```

→ http://localhost:5174

**Terminal 2 — PDAO Portal**

```powershell
cd C:\Users\carlo\Documents\idetect\apps\web-pdao
npm run dev
```

→ http://localhost:5173

**Terminal 3 — BPLO Portal**

```powershell
cd C:\Users\carlo\Documents\idetect\apps\web-bplo
npm run dev
```

→ http://localhost:5175

> **Note:** If your API is running on a different machine or IP, update `VITE_API_URL` in each portal's `.env` file (create it next to `package.json`):
>
> ```
> VITE_API_URL=http://192.168.x.x:3000/api
> ```

---

## 4. Flutter App Setup (Establishment Client)

### 4.1 Find your machine's local IP

```powershell
ipconfig
```

Look for **IPv4 Address** under your active network adapter (e.g., `192.168.1.105`).

### 4.2 Set the API URL

Open `lib/services/api_service.dart` and update this line:

```dart
static const String _defaultBaseUrl = 'http://YOUR_IP_HERE:3000/api';
```

Replace `YOUR_IP_HERE` with your actual IP. The app cannot use `localhost` — on Android, localhost points to the phone itself.

### 4.3 Install dependencies

```powershell
cd C:\Users\carlo\Documents\idetect
flutter pub get
```

### 4.4 Run on a connected device or emulator

**USB (physical phone):**

1. Enable Developer Options on the phone
2. Enable USB Debugging
3. Connect via USB
4. Run:

```powershell
flutter run
```

**Wireless ADB (same WiFi):**

```powershell
# Pair first (one time):
adb pair <phone-ip>:<pairing-port>

# Then connect:
adb connect <phone-ip>:<port>

flutter run
```

**Emulator:**

```powershell
flutter emulators --launch <emulator-name>
flutter run
```

> **Note:** The emulator uses `10.0.2.2` instead of your machine's IP to reach localhost. Update `api_service.dart` if using emulator:
>
> ```dart
> static const String _defaultBaseUrl = 'http://10.0.2.2:3000/api';
> ```

---

## 5. Flutter Beneficiary App Setup

The beneficiary app is a separate Flutter project:

```powershell
cd C:\Users\carlo\Documents\idetect\apps\beneficiary
```

Same steps as Section 4 — update the IP in `apps/beneficiary/lib/services/api_service.dart`, then `flutter pub get` and `flutter run`.

---

## 6. Quick Reference — All Services

| Service         | Command                             | URL                   |
| --------------- | ----------------------------------- | --------------------- |
| API             | `npm run dev` in `apps/api`         | http://localhost:3000 |
| OSCA Portal     | `npm run dev` in `apps/web-osca`    | http://localhost:5174 |
| PDAO Portal     | `npm run dev` in `apps/web-pdao`    | http://localhost:5173 |
| BPLO Portal     | `npm run dev` in `apps/web-bplo`    | http://localhost:5175 |
| Flutter App     | `flutter run` in root               | Android device        |
| Beneficiary App | `flutter run` in `apps/beneficiary` | Android device        |

---

## 7. Common Issues

### "EADDRINUSE: address already in use 0.0.0.0:3000"

Port 3000 is taken by an old node process. Run:

```powershell
FOR /F "tokens=5" %a IN ('netstat -ano ^| findstr ":3000" ^| findstr "LISTENING"') DO taskkill /PID %a /F
```

### Flutter "No devices found"

- Check USB cable / USB debugging is enabled
- Run `adb devices` to verify device is listed
- Try `flutter doctor` to diagnose

### API "password authentication failed for user postgres"

Your PostgreSQL password doesn't match. Check `DB_PASSWORD` in `apps/api/.env`.

### "image_path" column doesn't exist

Migration 013 or 015 wasn't run. Run both:

```powershell
$env:PGPASSWORD="carlomon"
psql -U postgres -d idetect -f database/migrations/013_fraud_flags_denormalize.sql
psql -U postgres -d idetect -f database/migrations/015_image_path_to_text.sql
```

### Captured ID image not appearing in fraud flag drawer

- Ensure the API is running (not just the portal)
- The image is only captured on **new scans after Apr 22 2026** — old flags have no image
- Check `apps/api/uploads/` folder exists and has `.jpg` files after a scan

---

## 8. Project Structure Reference

```
idetect/
├── apps/
│   ├── api/              ← Node.js/Express REST API
│   │   ├── src/
│   │   │   ├── routes/   ← All API endpoints
│   │   │   ├── middleware/
│   │   │   ├── services/
│   │   │   └── server.js ← Entry point
│   │   └── uploads/      ← Captured ID images (auto-created)
│   ├── web-osca/         ← OSCA admin portal (React/Vite)
│   ├── web-pdao/         ← PDAO admin portal (React/Vite)
│   ├── web-bplo/         ← BPLO admin portal (React/Vite)
│   └── beneficiary/      ← Beneficiary Flutter app
├── database/
│   └── migrations/       ← SQL migrations (run in order 001→015)
├── lib/                  ← Establishment Flutter app
└── documentation/        ← Guides and architecture docs
```
