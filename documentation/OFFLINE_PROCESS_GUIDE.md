# iDetect Offline Process: A Simple Guide

## The short version

When the phone cannot reach the server, iDetect still gives staff a warning
based on a copy of the revoked-ID list stored on the phone. It never says an
ID is valid while offline. Each offline scan is saved and sent to the server
when the connection comes back. Staff are told the result and must verify
high-value transactions online.

## The three parts

### 1. The block list (kept on the phone)

- The phone keeps a copy of the IDs that are revoked or suspended.
- It updates every 8 seconds while online. Only changes are downloaded, in pages of 1,000.
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
- When the connection returns, the app sends each queued scan to the server, marked as sent offline.
- The server saves the scan once. If the same scan arrives twice, for example after a retry, it returns the earlier result and does not save a second copy.
- After a successful send, the app removes the item from the queue and shows the official result.
- If a send fails for another reason, the app keeps the item and tries again. It is never dropped.
- After 5 failed tries, the app shows an alert so staff know that scans are waiting to be sent.

## What staff see

| Situation | What staff see |
|---|---|
| Online | The normal result: VALID, SUSPICIOUS, INVALID, or MANUAL REVIEW. |
| Offline | An offline warning, when the list was last updated, and a "Do not approve" note. |
| Back online | The queued result appears as a message. |
| Beneficiary portal | Requires a connection. It does not work offline. |

## Rules that apply

- Offline results are provisional. Only an online check gives an official result.
- A block list older than the last sync may miss a recent revocation.
- Alerts about waiting scans appear only while the app is open.
- The first time the app runs after this update, the block list is rebuilt and any old queue is moved to the encrypted queue.

## Known limits

- **Stale list.** An ID revoked after the last sync will not be caught offline.
- **Provisional result.** Staff must verify online for high-value cases.
- **Alerts need the app open.** A waiting-scan alert is not sent when the app is closed.
- **Scan history is not encrypted yet.** The list of scanned ID numbers on the phone is still stored in plain form.
- **Hashing trade-off.** Fingerprints of ID numbers can be guessed if someone gets the block list from a lost phone. This was an accepted decision.
- **Rare duplicate effects.** If two identical sends arrive at exactly the same moment, the server saves one scan, but side effects such as fraud flags could be written twice.

## Deferred improvements

- A "Pending sync" screen that lists waiting scans.
- The server pushes block-list changes instead of the phone polling every 8 seconds.
- A background alert that still shows when the app is closed.
- Encrypting the scanned-ID history.

## Setup notes for developers

- Run migration `apps/api/migrations/051_add_offline_scan_replay_columns.sql` on the database before deploying the API.
- The new columns are `client_scan_id`, `scanned_at`, and `offline_queued`. The API's scan insert needs them.
