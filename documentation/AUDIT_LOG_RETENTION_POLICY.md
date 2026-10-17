# Audit Log Retention and Archive Policy

This is a short guide to how long iDetect keeps audit logs, how old logs are archived, and who can do it. It applies to all portals (BPLO, OSCA, PDAO, and establishment activity).

## The short version

- **Keep** audit logs in the live Audit Logs page for **5 years** from the date of the event.
- **Archive** logs older than 5 years. Archiving moves them to a separate archive table.
- **Never delete** audit logs. No role, including Super Admin, can delete them.
- Only the **Super Admin of an agency** can archive. They can only archive logs from their own agency.
- Archiving needs the Super Admin to **re-enter their password** (step-up check). The server rejects the request without it.
- Archived logs can still be **viewed** by that Super Admin.

## Why 5 years

The period is set by the policy decision for finding F-03 in the IT expert recommendations. Audit logs are evidence of who changed what, and they are needed for reviews, complaints, and audits. Five years keeps enough history for those purposes while the live table stays small.

The agency's records officer should confirm this period against its own records rules. If the rules change, update this document and the constant `RETENTION_YEARS` in `apps/api/src/routes/auditLogs.js`.

## What counts as an audit log

Every action that the system records, such as sign-ins, record edits, staff account changes, establishment actions, and exports. The time used for the 5-year period is the time the event happened (`created_at`).

## Where logs live

| Place | What it holds | Who can see it |
|---|---|---|
| Live audit log (`audit_logs`) | Logs from the last 5 years | Authorized admins, scoped as before |
| Archive (`audit_logs_archive`) | Logs older than 5 years, moved there by a Super Admin | The Super Admin of that agency |

Archived rows keep their original fields. The archive also records when each row was archived and by whom.

## How archiving works

1. The Super Admin opens **Audit Logs** and sees how many logs are ready to archive and the cutoff date.
2. They click **Archive old logs**, tick the acknowledgement box, and confirm their password.
3. The system moves all eligible logs from their agency in one step. If any part fails, nothing is moved.
4. The system writes a new audit entry that records the archive action, how many logs were moved, and who did it.

Archiving is run by hand from the portal. There is no automatic schedule yet.

## Who may do what

| Role | View live logs | Archive old logs | View archived logs | Delete logs |
|---|---|---|---|---|
| Super Admin of an agency (BPLO, OSCA, PDAO) | Yes, within their agency | Yes, within their agency | Yes, within their agency | No |
| Other admin roles | Yes, as before | No | No | No |
| Anyone, including the system itself | — | — | — | No |

## Built-in protection

The database enforces this policy, not only the screen:

- Archiving requires the password re-check. The server rejects the request without it, even if the screen is open.
- Audit rows can only be removed from the live table inside the archive step. Any other delete is blocked.
- The archive table is append-only. Its rows cannot be edited or deleted.
- Deleting a user or establishment does not delete their audit logs. The log stays, and the link to the deleted account is cleared.

## Things this policy does not cover

- Retention of beneficiary records and other personal data. That needs its own policy, which is listed in the future roadmap.
- Automatic scheduled archiving. Archiving is manual for now.
- Long-term backups. Those follow the database backup procedure in the deployment guide.

## Review

Review this policy once a year, or when the records rules change. Record any change here with the date and the reason.
