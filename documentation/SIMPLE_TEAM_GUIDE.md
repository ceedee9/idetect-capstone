# iDetect Simple Team Guide

This guide explains how iDetect works in plain language so all team members can operate it confidently.

Last updated: April 6, 2026

## 1. What iDetect does

iDetect checks if a Senior Citizen ID or PWD ID is valid for discounts.

It connects 3 parts:

1. Mobile app used by establishments to scan IDs
2. OSCA and PDAO portals where government records are managed
3. API + database where final verification happens

## 2. Who does what

### Establishment staff (mobile app)

1. Log in to the app
2. Scan ID or enter ID manually
3. Confirm extracted details
4. Run verification
5. If needed, submit a fraud flag

### OSCA / PDAO admin staff (web portal)

1. Add beneficiaries one-by-one
2. Or import many records using CSV/Excel
3. Keep status updated (active, suspended, expired, revoked)
4. Review fraud flags

## 3. Main process flow (simple)

1. Record is added in OSCA/PDAO portal
2. Record is saved in the beneficiaries database
3. Establishment scans ID in mobile app
4. OCR reads fields from ID image
5. User checks/edits extracted values
6. App sends ID number + beneficiary type to API
7. API checks database for a matching active record
8. API returns result to app

## 4. Verification results meaning

### VALID

- ID found
- Type matches (senior_citizen or pwd)
- Status is active
- Validity date not expired

### SUSPICIOUS

- ID found but status is suspended
- Usually under review/investigation

### INVALID

- ID not found
- Or wrong beneficiary type
- Or expired/revoked/inactive record

### MANUAL REVIEW

- OCR confidence too low
- Staff should check and enter ID manually

## 5. Why a valid-looking card can still show INVALID

Most common causes:

1. Wrong ID digits in portal record (extra or missing zero)
2. Wrong beneficiary type selected (PWD vs Senior Citizen)
3. Record is not active
4. Record is expired
5. API server not updated/restarted after fixes
6. Mobile app still running old code/session

## 6. Bulk import process (OSCA/PDAO)

1. Go to Add Record page
2. Use Bulk Import section
3. Upload CSV/XLS/XLSX
4. Click Analyze first
5. Review valid and invalid row counts
6. Click Import Valid Rows

Notes:

- Default max rows per import is 20000
- Row limit can be changed using BENEFICIARY_IMPORT_MAX_ROWS environment variable
- Duplicate IDs are skipped safely

## 7. File format tips for imports

Use these columns:

1. id_number
2. full_name
3. birthdate
4. issuing_office
5. validity_start
6. validity_end
7. registered_mobile

PWD ID format should be:

00-0000-000-0000000

Example:

13-7504-000-0004941

## 8. Daily checklist for portal admins

1. Confirm new records use correct ID digits
2. Confirm correct type (OSCA or PDAO)
3. Keep status updated
4. Review fraud flags
5. For imports, always run Analyze before Import

## 9. Quick troubleshooting when verification fails

1. Compare ID in app result vs ID in portal character by character
2. Confirm portal record type matches scanned card type
3. Confirm record status is active
4. Confirm validity_end date is not past
5. Restart API server
6. Restart mobile app and test again

If still failing, collect these and send to dev team:

1. Screenshot of portal record details
2. Screenshot of app result
3. Exact ID sent by app
4. API response message

## 10. Important reminder

If the digits are different, the system should return INVALID. This is correct behavior.

Normalization fixes formatting differences (like spaces/hyphens), but it cannot fix truly different numbers.
