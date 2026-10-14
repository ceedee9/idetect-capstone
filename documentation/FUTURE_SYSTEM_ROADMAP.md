# iDetect Future System Roadmap

**Updated:** October 14, 2026

This document records useful future features, improvements, and operational
ideas for the entire iDetect system. It covers the beneficiary app, business
establishment app, staff portals, API, database, reporting, security, and
operations. These are planning items, not current commitments. New ideas should
be added here whenever they arise. The implementation status belongs in
[IT_EXPERT_RECOMMENDATION_UPDATES.md](./IT_EXPERT_RECOMMENDATION_UPDATES.md).

## How to use this roadmap

Add each future idea under the most relevant area. Describe the problem it
solves, the proposed improvement, and any policy or capacity decision needed
before implementation. Move an item to the implementation document after it is
delivered and validated.

## Authority and account management

The proposed BPLO Super Admin, OSCA Super Admin, PDAO Super Admin,
establishment Super User, establishment Regular User, and office-scoped staff
authority model is defined in
[AUTHORITY_MODEL_AND_PERMISSION_MATRIX.md](./AUTHORITY_MODEL_AND_PERMISSION_MATRIX.md).
There is no overall Super Admin; each government agency is isolated from the
others.
This is a prerequisite for reliable F-05/F-06 masking and for replacing shared
establishment credentials with individual accountability.

Future implementation must include server-side scope checks, account states,
audited privilege changes, controlled overrides, and protection against
removing the final recovery administrator.

## Audit and accountability

### Beneficiary logout auditing

The beneficiary app currently clears its local token on manual sign-out or
inactivity timeout. Server-side beneficiary logout auditing is intentionally
deferred: beneficiaries do not manage shared records, JWT logout does not
invalidate a token by itself, and logout events would add volume with limited
investigative value. Reconsider this only if a privacy review, incident-
response requirement, or server-side session/revocation design makes it
necessary.

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

## Beneficiary experience

- Expand Filipino translations to server-generated notification text and
  remaining error states.
- Add clearer notification preferences and delivery status for beneficiary
  alerts.
- Consider offline-friendly history and retry behavior for intermittent mobile
  connectivity.
- Review accessibility, text sizing, contrast, and screen-reader labels across
  the beneficiary app.

## Establishment experience

- Add a clear account-status page for pending, suspended, and revoked accounts.
- Add establishment-level activity history for scans, fraud flags, and account
  security events.
- Add configurable establishment notification settings for review outcomes,
  account changes, and suspicious activity.
- Consider a guided onboarding and permit-verification checklist.

## Staff portals and workflows

- Add dashboard summaries for pending approvals, active investigations,
  unresolved disputes, and recent security events.
- Add configurable office and role-based dashboard views.
- Add bulk actions with confirmation, preview, and an audit record for each
  affected record.
- Add saved filters and recurring report schedules for authorized staff.
- Add a formal workflow for suspension start/end dates and automatic
  reinstatement after the policy is approved.
- Add record-history links from establishments, beneficiaries, disputes, and
  fraud flags.

## API and integrations

- Add versioned API contracts and generated endpoint documentation.
- Add request correlation IDs for tracing a user action across API logs,
  audit events, and background jobs.
- Add idempotency keys for retried submissions such as disputes and fraud
  flags.
- Add rate-limit dashboards and documented limits for public and authenticated
  endpoints.
- Add integration health checks and an operational status view.

## Data protection and security

- Complete ID and age masking reviews for all API responses and exports.
- Define audit-log and personal-data retention policies, including archival and
  approved deletion procedures.
- Add periodic access reviews for staff accounts and administrative roles.
- Add stronger abuse detection for repeated failed logins and suspicious
  establishment activity.
- Evaluate a server-side session store only if reliable token-expiration
  auditing or session revocation becomes necessary.
- Review encryption, backup protection, secret rotation, and incident-response
  procedures.

## Capacity and reliability

The system has no single small fixed capacity limit. Practical limits are
database storage, indexes, backups, report query time, export size, API
throughput, and mobile or browser resources. Capacity work should be based on
measured usage rather than premature complexity.

- Monitor database size, table growth, connection-pool usage, API latency,
  error rates, and background-job duration.
- Monitor audit volume, report duration, export size, and failed audit writes.
- Keep pagination, report limits, upload limits, and CSV sizes bounded.
- Add caching only for measured read bottlenecks and invalidate it safely.
- Add queueing or asynchronous processing for non-critical heavy work when
  measurements justify it; security-critical writes should remain durable
  before confirming the action.
- Add database partitioning or archival jobs when volume requires them.
- Document backup, restore, disaster-recovery, and service-restart procedures.
- Perform load tests using realistic establishment, beneficiary, scan, and
  report activity before major rollouts.

## Quality and maintainability

- Expand automated API, portal, Flutter, migration, and authorization tests as
  new workflows are added.
- Add end-to-end tests for the most important staff and establishment journeys.
- Add a staging-data reset process that does not expose production personal data.
- Keep migrations idempotent and document deployment ordering for API and app
  releases.
- Add release checklists covering migrations, rollback plans, privacy review,
  and user-facing documentation.

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
- Login, logout, failed-login, and lockout events are displayed as **Session
  event** rather than showing a blank affected-record value. They remain
  session events and do not receive an artificial database target.

## Open policy decisions

- F-03 retention duration and archive period.
- F-08 session-timeout duration and warning behavior.
- F-09 suspension start/end dates and automatic reinstatement policy.
- Whether report previews require their own audit events.
- Whether beneficiary OTP and logout events need additional auditing.
- Which future features require formal approval, notification, or legal review.
