# iDetect Offline Process: A Simple Guide

## The short version

When the phone cannot reach the server, iDetect still gives staff a warning
based on a copy of the revoked-ID list stored on the phone. It never says an
ID is valid while offline. Each offline scan is saved and sent to the server
when the connection comes back. Fraud reports (flags) are saved and sent the
same way. Staff are told the result and must verify high-value transactions online.

## The five parts

### 1. The block list (kept on the phone)

- The phone keeps a copy of the IDs that are revoked or suspended.
- It updates every 8 seconds while online. Only changes are downloaded, in pages of 1,000.
- The first time (empty list), the phone asks only for revoked and suspended IDs, not the whole registry.
- The server hands out a cursor ("changes since this time") and pulls it back by 5 seconds, so a change saved while a poll was running is not missed.
- If the login expires, updates pause and resume automatically after the next login. They no longer stop until the app is restarted.
- The IDs are stored as SHA-256 fingerprints, not as plain ID numbers.
- The phone remembers when the list was last updated. The offline screen shows
  this, for example "Block list last synced 12 min ago", or says it has never synced.

### 2. The offline check

- If the server cannot be reached, the app checks the scanned ID against the block list.
- The result is an offline result, shown with the banner "OFFLINE RESULT — SERVER UNREACHABLE".
- An offline result is never VALID. The app shows a warning so staff know it is provisional.
- Staff should not approve high-value transactions based on an offline result.

### 3. The queue and replay (sent when the connection returns)

- Each offline scan is saved to a queue on the phone. The queue is encrypted, and the key is kept in the phone's secure storage.
- Every queued scan has a random `client_scan_id` and the time it was actually scanned.
- The scan's photo is copied to the app's private storage so it can be sent later. It is deleted once the scan is sent. (Before, the photo was deleted right after saving, so replayed scans had no image.)
- Each queued scan remembers which account made it. If another account signs in on the same phone, it skips scans that are not its own. They stay queued for their owner.
- The app tries to send queued scans when the connection returns **and every 30 seconds**. The timer matters when the phone has signal but the server is down, because no connection change happens then.
- A failed scan waits 30 seconds before the next try, then 1, 2, 4, 8 minutes, up to 15 minutes. Reconnecting skips the wait.
- When the connection returns, the app sends each queued scan to the server, marked as sent offline.
- The server saves the scan once. If the same scan arrives twice, for example after a retry, it returns the earlier result and does not save a second copy.
- After a successful send, the app removes the item from the queue and shows the official result.
- If the login has expired (401), sending pauses until the next login. If the server says "too many requests" (429), the app stops for that round and tries again later without counting a failure.
- If a send fails for another reason, the app keeps the item and tries again. It is never dropped.
- After 5 failed tries, the app shows an alert so staff know that scans are waiting to be sent.

### 4. Fraud flags (reports)

- When staff flag an ID and the server answers, the flag is sent at once.
- If the failure is temporary (no connection, server error, rate limit, expired login), the flag is saved in a queue and retried with the same 30-second timer and growing wait as scans. It is never dropped, and staff are alerted after 5 failed tries. (Before, a flag stopped being retried after 5 failures and stayed in the queue forever.)
- If the server permanently rejects the flag (for example, invalid input), it is not queued. If it was already queued, it is removed and staff are told why, because retrying can never work.
- Flagging an **offline** result: a flag needs a server record of the scan, and an offline scan has none yet. The report is attached to the queued scan and sent automatically after the scan syncs. Staff see "Report saved on this device. It will be sent after the scan syncs." (Before, this report was silently lost while the app said it was flagged.)
- If a result has no server record and the phone is online (for example, an instant block from the phone's own list), the report cannot be sent. The app now says so instead of claiming success, and the history entry is not marked "flagged".
- Like scans, each queued flag remembers its account.

### 5. Login expiry (when the session runs out)

- A login lasts 8 hours (`JWT_EXPIRES_IN`). It does not renew while the app is used.
- **Online:** when the login has expired, the app signs the user out and shows the login screen with the notice "Your session has expired. Please sign in again to continue." This happens in four cases:
  - The app opens (the splash screen checks).
  - The app comes back from the background.
  - The phone regains a connection.
  - The server rejects a request because the login ended. The server now answers **401** with the code `SESSION_EXPIRED` or `SESSION_INVALID` (it used to answer 403, which the app did not recognise).
- **Offline:** an expired login does **not** sign the user out, because signing in needs a connection. The user can still open the app and scan, and scans are queued as usual. The app signs the user out as soon as the server can be reached.
- The queue is kept when the user is signed out. Queued scans and flags belong to the account that made them and are sent after that account signs in again. Sending pauses until then.
- The app decides "expired" from the date inside the login token on the phone, and "reachable" by asking the server's `/api/health` page (any answer counts, even an error). If the phone's clock is wrong, the server's answer still decides.
- A scan in progress when the server ends the login is not saved. The user signs in and scans again.

## What staff see

| Situation | What staff see |
|---|---|
| Online | The normal result: VALID, SUSPICIOUS, INVALID, or MANUAL REVIEW. |
| Offline | An offline warning, when the list was last updated, and a "Do not approve" note. |
| Flag while offline | "Report saved on this device. It will be sent after the scan syncs." |
| Flag that cannot be sent | "ID saved, but the report was not sent because this scan was not recorded on the server." |
| Back online | The queued result appears as a message. |
| Login expired, online | The login screen with "Your session has expired." |
| Login expired, offline | The app keeps working. The login screen appears once the connection returns. |
| Beneficiary portal | Requires a connection. It does not work offline. |

## Rules that apply

- Offline results are provisional. Only an online check gives an official result.
- A block list older than the last sync may miss a recent revocation.
- Alerts about waiting scans and flags appear only while the app is open.
- The first time the app runs after this update, the block list is rebuilt and any old queue is moved to the encrypted queue.
- Queued items from an older app version have no account recorded, so any account can send them.

## Known limits

- **Stale list.** An ID revoked after the last sync will not be caught offline. No age limit is enforced on the list.
- **Provisional result.** Staff must verify online for high-value cases.
- **Alerts need the app open.** A waiting-scan alert is not sent when the app is closed.
- **Scan history is not encrypted yet.** The list of scanned ID numbers on the phone is still stored in plain form. The flag queue (ID number and the staff's note) is also stored unencrypted.
- **Photo is unencrypted until sent.** The queued photo sits in the app's private storage until the scan is sent.
- **Hashing trade-off.** Fingerprints of ID numbers can be guessed if someone gets the block list from a lost phone. This was an accepted decision.
- **Rare duplicate effects.** If two identical sends arrive at exactly the same moment, the server saves one scan, but side effects such as fraud flags could be written twice.
- **Duplicate flag after a lost reply.** If a flag reaches the server but the reply is lost, the retry creates a second flag. It is stored as supplementary evidence on the same case, and it does not count as a second establishment toward auto-suspension.
- **Blocked ID scanned offline is not logged.** When the phone's list blocks an ID instantly, the background call to record the scan fails offline and is discarded. That scan is not queued and not in the server log.
- **A scan the server permanently rejects retries forever.** Scans are never dropped by design, so a scan with bad data keeps retrying at the longest wait.
- **Other accounts' items stay.** Items queued by an account that never signs in again on that phone stay in the queue.
- **Rate limit on flags.** The server accepts 30 flags per hour per establishment. Extra flags wait in the queue.

## Deferred improvements

- A "Pending sync" screen that lists waiting scans and flags, and lets staff see or remove one that keeps failing.
- The server pushes block-list changes instead of the phone polling every 8 seconds.
- A background alert that still shows when the app is closed.
- Encrypting the scanned-ID history, the flag queue, and the queued photos.
- Log a scan that the local block list stopped while offline, by queueing it like any other offline scan (and let it be flagged).
- Stronger warning when the block list is very old (for example over 24 hours).
- A client-generated ID on flags so the server can ignore a repeated flag.
- A tie-breaker in the block-list cursor (time plus ID), so more than 1,000 changes saved at the same instant cannot hide later ones.

## Setup notes for developers

- Run migration `apps/api/migrations/056_add_offline_scan_replay_columns.sql` on the database before deploying the API.
- The new columns are `client_scan_id`, `scanned_at`, and `offline_queued`. The API's scan insert needs them.
- No new migration is needed for the flag, photo, or block-list changes.
- `GET /api/verification/status-updates` accepts `blocked_only=true` (first sync only) and returns `next_since` pulled back by 5 seconds after a full catch-up. Older app versions keep working.
- Retry rules live in `lib/services/retry_policy.dart` and are covered by `test/services/retry_policy_test.dart`. The endpoint is covered by `apps/api/tests/statusUpdates.test.js`.
- Login expiry: the app side is in `lib/services/session_expiry_service.dart` and `lib/services/session_http.dart` (tests: `test/services/session_expiry_test.dart`). The server side is `authenticateEstablishment` in `apps/api/src/middleware/auth.js` (tests: `apps/api/tests/establishmentAuthExpiry.test.js`). Deploy the API first, then the app. Older app versions keep working against the new API but do not sign out automatically.
