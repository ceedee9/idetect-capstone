# Audit Log Future Roadmap

**Updated:** October 11, 2026

This document records useful future improvements discussed while developing the
iDetect audit system. These are planning items, not current commitments. The
implementation status belongs in
[IT_EXPERT_RECOMMENDATION_UPDATES.md](./IT_EXPERT_RECOMMENDATION_UPDATES.md).

## Audit record reliability

### Readable target snapshots

Audit rows currently retain the immutable technical relationship
`target_table` + `target_id`. The portal now resolves that relationship into an
administrator-friendly affected-record display such as
`Establishment: KFC · EST-2026-000123`.

Future improvement: store a snapshot at the time of the event:

```json
{
  "target_type": "establishment",
  "target_reference": "EST-2026-000123",
  "target_name": "KFC"
}
```

This would keep an audit entry understandable if the original record is later
renamed or removed. The snapshot must not contain full ID numbers, passwords,
tokens, or unnecessary personal data.

### More audit history views

- Add a record-history view that shows every event for one establishment,
  beneficiary, dispute, fraud flag, or verification.
- Add a safe link from an affected-record reference to the corresponding
  authorized detail page.
- Preserve the raw UUID fields for investigations and machine-readable exports,
  while keeping them out of the primary administrator-facing table.

## Capacity, retention, and operations

The audit table has no small fixed row limit. Practical limits are database
storage, indexes, backups, report query time, and the size of exported files.
The system should continue logging meaningful security and business events, not
every page load, search keystroke, polling request, or history request.

Future operational improvements:

- Define and approve an F-03 retention period, with an initial recommendation
  of three years online followed by an archive strategy.
- Add monitoring for audit-table growth, storage usage, slow report queries,
  export duration, and failed audit inserts.
- Keep report result limits and CSV size limits bounded.
- Add partitioning or archival jobs only when measured volume requires them.
- Consider asynchronous batching only for non-critical high-volume events;
  security-critical audit writes should remain durable before confirming the
  action.
- Add a documented restore and backup test for audit records.

## Reporting and administration

- Add PDF output only if a formal submission workflow requires it.
- Add separate audit entries for report previews if preview accountability is
  required; currently CSV downloads are audited and previews are not.
- Add configurable report templates for recurring monthly, quarterly, and
  year-end submissions.
- Add filters by affected-record reference, establishment, office, actor, and
  action.

## Privacy and security

- Review every new metadata field for data minimization before adding it.
- Continue masking ID numbers in exports and case files.
- Define role-specific access rules for record history and case-file exports.
- Revisit server-side sessions only if the system needs reliable audit events
  for token expiration; establishment JWTs are currently stateless.

## Decision log

- Keep `target_table` and `target_id` as internal audit relationship fields.
- Present a human-readable **Affected record** in the portal instead of exposing
  raw table names and UUID fragments as the primary value.
- Do not create artificial targets for login, logout, failed-login, or lockout
  events; these are session events.
