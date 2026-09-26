# iDetect IT Expert UAT Test Cases

Prepared for validation against the current implementation of the iDetect system.

Note: This test pack reflects the actual authentication and verification flows currently implemented in the API, and it is intended to be used by the IT expert during the final user testing session.

## Test Case Guidelines
- Minimum of 50 test cases overall.
- Include both positive and negative flows.
- Cover critical user journeys and failure conditions.
- Each test case must be completed by the IT expert and marked as Pass/Fail.
- Record the actual system response for comparison against the expected result.

## Test Case Matrix

| Test Case ID | Test Case Name | Case Description | Expected Result | Test Data | Actual Result | Pass / Fail | Remarks |
|---|---|---|---|---|---|---|---|
| TC-001 | Staff login with valid credentials | Login using a valid BPLO/OSCA/PDAO staff account | User is authenticated and redirected to dashboard | Valid staff email + valid password |  |  |  |
| TC-002 | Staff login with invalid password | Enter a correct email but wrong password | Login fails with generic auth error | Valid email + wrong password |  |  |  |
| TC-003 | Staff login with invalid email | Enter email not found in system | Login fails without revealing whether email exists | Invalid email + any password |  |  |  |
| TC-004 | Staff login with inactive account | Attempt login for disabled staff account | Login is rejected and account status is handled properly | Inactive staff user |  |  |  |
| TC-005 | Staff account lockout after 3 failed attempts | Trigger repeated wrong password attempts | Account is locked for 30 minutes after 3 failures | Invalid password entered 3 times |  |  |  |
| TC-006 | Staff lockout message visibility | Check user notification after lockout | Correct lockout message appears and user is blocked | Locked account login attempt |  |  |  |
| TC-007 | Staff login after lockout expiry | Wait for lockout duration to expire and retry | Account unlocks and login succeeds | Locked account after expiry period |  |  |  |
| TC-008 | Staff token refresh | Use valid staff JWT to refresh access token | New token is issued successfully | Valid staff token |  |  |  |
| TC-009 | Staff invalid token refresh | Attempt refresh with expired or tampered token | Refresh fails with 401 response | Invalid/expired token |  |  |  |
| TC-010 | Establishment login with approved status | Login using valid approved establishment account | Login succeeds and dashboard opens | Approved establishment credentials |  |  |  |
| TC-011 | Establishment login with pending approval | Attempt login before establishment is approved | Login is rejected with status-specific message | Pending establishment account |  |  |  |
| TC-012 | Establishment login with suspended account | Attempt login for suspended establishment | Login is rejected and account is flagged as suspended | Suspended establishment account |  |  |  |
| TC-013 | Establishment login with revoked account | Attempt login for revoked establishment | Login is rejected and revoked message appears | Revoked establishment account |  |  |  |
| TC-014 | Establishment lockout after failed attempts | Trigger 3 invalid login attempts | Establishment account is locked for 30 minutes | Wrong password 3 times |  |  |  |
| TC-015 | Establishment login after lockout | Retry after lockout timeout | Login succeeds after expiry | Locked establishment account |  |  |  |
| TC-016 | Beneficiary OTP request with valid ID and birthdate | Request OTP using valid beneficiary record | OTP is generated and sent if mobile number is registered | Valid ID + valid birthdate |  |  |  |
| TC-017 | Beneficiary OTP request with invalid ID | Use non-existent beneficiary ID | System returns generic message and does not expose record existence | Invalid ID number + valid birthdate |  |  |  |
| TC-018 | Beneficiary OTP request with missing mobile number | Use valid beneficiary record with no registered mobile | System indicates mobile registration is required | Valid ID + birthdate + no registered mobile |  |  |  |
| TC-019 | Beneficiary OTP request with invalid date format | Submit birthdate in incorrect format | Validation fails and request does not proceed | Invalid birthdate value |  |  |  |
| TC-020 | Beneficiary OTP verification with correct OTP | Submit valid OTP after request | User is authenticated and JWT is returned | Valid OTP |  |  |  |
| TC-021 | Beneficiary OTP verification with wrong OTP | Submit incorrect OTP | Request fails with invalid OTP and attempts are incremented | Wrong OTP |  |  |  |
| TC-022 | Beneficiary OTP expiry | Request OTP and use it after expiry window | OTP is rejected as expired | Expired OTP |  |  |  |
| TC-023 | Beneficiary OTP max attempts lock | Submit wrong OTP repeatedly until limit | OTP attempt limit is enforced | 5 wrong OTP attempts |  |  |  |
| TC-024 | Beneficiary register mobile number with valid data | Register new mobile using valid ID and birthdate | Mobile is saved and OTP is sent | Valid ID + birthdate + valid mobile |  |  |  |
| TC-025 | Beneficiary register mobile with invalid format | Submit mobile number in wrong format | Validation fails and registration is rejected | Invalid mobile format |  |  |  |
| TC-026 | Beneficiary register mobile for already registered ID | Attempt to register a second mobile number | System rejects duplicate mobile registration | Existing registered mobile number |  |  |  |
| TC-027 | Beneficiary set PIN after successful OTP login | Set 4-digit PIN using valid beneficiary token | PIN is stored successfully | Valid bearer token + 4-digit PIN |  |  |  |
| TC-028 | Beneficiary set PIN with invalid length | Submit PIN shorter or longer than 4 digits | PIN setup is rejected | 3-digit or 5-digit PIN |  |  |  |
| TC-029 | Beneficiary login with valid PIN | Sign in using saved PIN | Login succeeds with beneficiary JWT | Valid beneficiary ID + correct PIN |  |  |  |
| TC-030 | Beneficiary login with wrong PIN | Use incorrect PIN | Login fails and remaining attempts are shown | Correct ID + wrong PIN |  |  |  |
| TC-031 | Beneficiary PIN lockout | Enter wrong PIN until limit reached | Account is locked and SMS notification is triggered if mobile exists | Wrong PIN entered repeatedly |  |  |  |
| TC-032 | Beneficiary PIN re-login after lockout | Retry after timer completes | Login succeeds after unlock | Locked PIN account |  |  |  |
| TC-033 | Valid senior citizen scan returns valid | Use active OSCA ID with matching data | Result is `valid` and review message is correct | Valid Senior Citizen ID |  |  |  |
| TC-034 | Valid PWD scan returns valid | Use active PDAO ID with matching data | Result is `valid` and record is accepted | Valid PWD ID |  |  |  |
| TC-035 | Expired beneficiary scan | Use any expired ID | Result is `invalid` with expired message | Expired ID record |  |  |  |
| TC-036 | Suspended beneficiary scan | Use suspended ID | Result is `suspicious` | Suspended beneficiary record |  |  |  |
| TC-037 | Revoked beneficiary scan | Use ID that is revoked | Result is `invalid` with permanent block message | Revoked beneficiary record |  |  |  |
| TC-038 | Cross-database conflict scan | Use ID number that exists under wrong beneficiary type | Result is `suspicious` with cross-database conflict message | Same ID as senior_citizen but scanned as pwd or vice versa |  |  |  |
| TC-039 | OCR name mismatch check | Scan ID where name on card differs from DB | Result becomes `suspicious` with name mismatch reason | Matching ID number but different extracted name |  |  |  |
| TC-040 | OCR DOB mismatch check | Scan ID where DOB on card differs from DB | Result becomes `suspicious` with DOB mismatch reason | Matching ID number but different extracted DOB |  |  |  |
| TC-041 | Missing OCR name and DOB triggers manual review | Scan a valid ID where OCR cannot extract either field | Result is `manual_review` | Valid ID + missing name + missing DOB |  |  |  |
| TC-042 | One OCR field missing but other matches | Use valid ID where one of name/DOB is not extracted but the other is available | System evaluates whichever fields are present and decides according to logic | Valid ID + name present + DOB missing |  |  |  |
| TC-043 | Low OCR confidence downgrade | Submit scan with confidence below threshold | Result is downgraded to `manual_review` if otherwise valid | Low OCR confidence score |  |  |  |
| TC-044 | Low OCR confidence on invalid result | Submit bad scan with low confidence and invalid DB status | Result remains invalid or suspicious and message is annotated | Low confidence + invalid/suspicious ID |  |  |  |
| TC-045 | New-format ID without holographic seal | Scan new-format ID with seal detection false | Result is `manual_review` | New ID + seal_detected = false |  |  |  |
| TC-046 | New-format ID with seal detected | Scan new-format ID with seal detection true | Result proceeds normally if record is valid | New ID + seal_detected = true |  |  |  |
| TC-047 | Verification history filter by date | Query history using start and end date filters | Only records in selected date range are returned | Start and end dates |  |  |  |
| TC-048 | Verification history filter by result | Query history with `result=valid` or `manual_review` | Only matching outcomes are returned | Valid vs suspicious vs invalid filters |  |  |  |
| TC-049 | Invalid result filter input | Query history using unsupported result value | API rejects request with validation message | Invalid filter value |  |  |  |
| TC-050 | Establishment status updates polling | Request status updates after DB change | System returns updated beneficiary status records | Since timestamp + beneficiary type filter |  |  |  |
| TC-051 | Fraud flag creation on cross-database conflict | Run suspicious scan caused by cross-type conflict | Fraud flags are inserted for both affected portals | Conflict scenario |  |  |  |
| TC-052 | Beneficiary notification on verification denial | Verify a denied ID and check beneficiary notification | Denial reason is included in notification content | Denied verification result |  |  |  |
| TC-053 | Beneficiary notification on verification approval | Verify an approved ID and check beneficiary notification | Approval notification is created with correct title and body | Approved verification result |  |  |  |
| TC-054 | Manual verification audit log | Perform manual entry verification | `verification_manual` audit entry is created | manually_entered = true |  |  |  |
| TC-055 | Seal issue audit log | Run scan where seal flag is triggered | `seal_not_detected` audit entry is recorded | Seal flag scenario |  |  |  |
| TC-056 | Scan rate limiting | Send repeated scan requests in rapid succession | Requests are throttled after limit is reached | Many sequential scan API calls |  |  |  |
| TC-057 | Unauthorized verification request | Call scan endpoint without establishment authentication | Request is rejected with 401/403 result | No token |  |  |  |
| TC-058 | Invalid beneficiary type in scan request | Submit unsupported beneficiary_type value | Validation fails before scanning | beneficiary_type = other value |  |  |  |
| TC-059 | Valid scan without captured image | Submit scan payload without image_data | System accepts request and logs scan normally | No image data |  |  |  |
| TC-060 | Scan with malformed ID number format | Submit ID with punctuation or special characters | Normalization is applied and request proceeds if valid | ID like `OSCA-1234` or `PWD 0001` |  |  |  |

## Acceptance Summary

The test is considered successful only if all critical flows pass without data loss, inconsistent role behavior, or security bypasses. The most critical paths are:
- Staff authentication
- Establishment authentication and approval states
- Beneficiary OTP/PIN setup and login
- Verification decision logic
- Suspicious and invalid ID handling
- Audit log and notification integrity

## Tester Status Section

| Tester Name | Date | Signature | Result |
|---|---|---|---|
|  |  |  |  |

