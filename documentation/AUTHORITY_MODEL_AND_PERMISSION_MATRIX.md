# iDetect Authority Model and Permission Matrix

**Status:** Phase 1 — authority model definition and initial API foundation  
**Updated:** October 11, 2026

This document defines the intended scopes and limitations for every major
iDetect role and user type. It is the baseline for future role-based access
control (RBAC), account management, privacy masking, audit logging, and
controlled overrides.

These rules describe authority; they do not by themselves implement the
permissions. Every rule must eventually be enforced by the API and covered by
authorization tests. Frontend route guards and hidden buttons are usability
features, not security controls.

## Core principles

1. **Least privilege:** A user receives only the access needed for their work.
2. **Explicit scope:** Every staff or establishment-user request is evaluated
   against the user's office, role, and establishment.
3. **No silent overwrites:** Corrections and decisions append a new event; they
   never erase the original record or audit trail.
4. **Privacy by default:** IDs, age, birth dates, and other sensitive data are
   masked unless access is necessary, authorized, and auditable.
5. **Separation of duties:** Account administration, government review, and
   establishment operations are separate responsibilities.
6. **Server enforcement:** The API must enforce role and scope checks for every
   protected action.
7. **Accountability:** Individual users must authenticate with individual
   accounts. Shared credentials must not be used for operational actions.

## User and role categories

### System staff roles

| Role | Scope | Primary purpose |
|---|---|---|
| `bplo_super_admin` | BPLO only | Manage BPLO staff access and BPLO governance |
| `osca_super_admin` | OSCA only | Manage OSCA staff access and OSCA governance |
| `pdao_super_admin` | PDAO only | Manage PDAO staff access and PDAO governance |
| `bplo_admin` | BPLO office and authorized establishment workflows | Manage establishments, permits, business-refusal disputes, and BPLO operations |
| `osca_admin` | OSCA office and senior-citizen records | Manage senior-citizen beneficiary workflows and related reviews |
| `pdao_admin` | PDAO office and PWD records | Manage PWD beneficiary workflows and related reviews |

The existing `bplo_admin`, `osca_admin`, and `pdao_admin` roles remain domain
roles. Each agency's Super Admin manages only its matching admin role. There is
no overall Super Admin role and no cross-agency staff administrator.

The legacy PostgreSQL enum label `super_admin` may remain from the earlier
migration history because PostgreSQL does not safely remove enum values in
place. It is retired: the API does not accept it, no account is provisioned
with it, and it must not be used for new accounts.

### Establishment roles

| Role | Scope | Primary purpose |
|---|---|---|
| `establishment_super_user` | One establishment only | Manage that establishment's users and supervise its operations |
| `establishment_regular_user` | One establishment only | Perform approved day-to-day establishment transactions |
| Pending establishment user | One establishment only | Await Super User approval and cannot perform protected work |
| Suspended establishment user | One establishment only | Account remains recorded but cannot sign in or transact |
| Revoked establishment account | One establishment only | Establishment access is disabled until an authorized government process changes it |

Each establishment user must have an individual account and an immutable
`establishment_id` relationship. A Super User is not a system administrator.

### Beneficiary users

| User type | Scope | Primary purpose |
|---|---|---|
| Beneficiary account holder | Own account and permitted own records | View status, history, notifications, and submit permitted disputes or reports |

Beneficiaries cannot access staff or establishment administration and cannot
view another beneficiary's protected information.

## System staff authority

### Agency Super Admins

#### Allowed

- Create, activate, deactivate, and review staff accounts in their own agency.
- Assign only their own agency's admin role.
- Reset staff credentials through approved workflows.
- Review audit logs and security reports within their own agency scope.
- Review account access history and privilege changes.
- Manage approved system-level configuration.
- Initiate investigations within their own agency when authorized by policy.

#### Restricted or conditional

- Full personal data access is not automatic. Sensitive data requires a
  legitimate operational scope and must be audited.
- Changing another Agency Super Admin's role or disabling the final active
  Agency Super Admin requires a second authorized Super Admin from that same
  agency or documented break-glass procedure.
- Agency Super Admins must not bypass another agency's decision workflow.
- Exporting sensitive data requires a legitimate purpose, minimum necessary
  fields, and an audit entry.

#### Never allowed

- Delete or edit immutable audit records.
- Silently alter verification evidence.
- Use a role-management privilege to conceal an action.
- Create an untraceable shared account.
- Remove the final recovery path for system administration.

### BPLO Admin

#### Allowed

- Create, review, approve, suspend, revoke, and manage establishments within
  BPLO authority.
- Manage establishment profile and permit workflows.
- Review business-refusal disputes.
- Review establishment activity and related audit records.
- Review establishment-submitted fraud flags as permitted by workflow.
- View the BPLO staff directory in read-only mode.

#### Restricted or conditional

- Beneficiary data is limited to what is necessary for an authorized BPLO
  workflow and should be masked by default.
- A BPLO Admin cannot manage OSCA/PDAO beneficiary records outside an approved
  referral or case workflow.
- Suspension and reinstatement actions must follow the approved policy,
  including dates and reasons when that policy is implemented.
- Sensitive exports and case files require authorization and are audited.

#### Never allowed

- Assign or remove any agency Super Admin privilege.
- View or manage another agency's staff accounts or unrestricted data.
- Access another office's unrestricted beneficiary data without authorization.
- Delete audit evidence or overwrite a verification result.
- Use an establishment user's credentials.

### OSCA Admin

#### Allowed

- Manage senior-citizen beneficiary records within OSCA authority.
- Review senior-citizen verifications, fraud flags, and disputes.
- Add, update, renew, or change records according to workflow.
- Produce authorized OSCA reports and case files.
- View audit activity relevant to OSCA operations.

#### Restricted or conditional

- PWD and business-refusal workflows are outside the normal OSCA scope.
- IDs, age, and other sensitive data are masked by default and exposed only
  when needed for an authorized case.
- Bulk operations require validation, preview, confirmation, and audit logging.
- Staff-account administration is restricted to the OSCA Super Admin; the OSCA
  Admin staff directory is read-only.

#### Never allowed

- Manage staff roles or establishment users.
- Delete immutable audit records.
- Modify verification evidence in place.

### PDAO Admin

PDAO has the same general authority pattern as OSCA, but its normal scope is
PWD beneficiary records and related PDAO workflows. PDAO cannot manage OSCA
records, BPLO establishment administration, or staff roles unless a separate
cross-office authorization is explicitly implemented.

The PDAO Admin staff directory is read-only; staff-account administration is
restricted to the PDAO Super Admin.

## Establishment authority

### Establishment Super User

#### Allowed

- Manage individual regular users belonging to the same establishment.
- Invite or create regular users through an approved process.
- Activate, suspend, deactivate, and reset regular-user access.
- Review activity performed by users of the same establishment.
- Review establishment scans, fraud flags, cashier actions, and account
  security events.
- Perform specifically approved operational approvals or overrides.
- Maintain establishment-level settings that do not change government-controlled
  permit status.

#### Restricted or conditional

- Every request must be scoped to the authenticated user's own
  `establishment_id`.
- User creation and privilege changes require an audit entry.
- Sensitive overrides require a reason and may require BPLO review.
- Beneficiary information is limited to the minimum needed for an active
  transaction or permitted history view.
- The Super User cannot grant another user Super User privileges unless a
  separate government-approved workflow allows it.

#### Never allowed

- View or manage another establishment.
- Approve, revoke, or change a government permit.
- Manage BPLO, OSCA, PDAO, or Agency Super Admin staff outside its own scope.
- Delete or edit audit logs.
- Replace or erase an original verification result.
- Reveal full beneficiary IDs or unrelated beneficiary records without an
  explicit authorized workflow.

### Establishment Regular User

#### Allowed

- Sign in using an individual account.
- Perform normal authorized ID verification and transaction workflows.
- Submit fraud flags or supplementary evidence as allowed.
- Perform cashier actions exposed by the workflow.
- View the minimum information needed to complete the transaction.
- Sign out and review permitted personal activity.

#### Restricted

- Cannot manage users or credentials.
- Cannot perform manager-only approvals or overrides.
- Cannot access another establishment's data.
- Cannot browse unrestricted beneficiary lists or historical case files.
- Cannot export sensitive reports.

#### Never allowed

- Change establishment permit status.
- Alter another user's activity.
- Delete evidence or audit records.
- Use or share another person's credentials.

### Establishment account states

- **Pending:** Authentication may explain that BPLO approval is required, but
  no operational token is issued.
- **Active:** The user may access only the workflows allowed by role.
- **Suspended:** Sign-in and protected operations are blocked with a clear
  status message.
- **Revoked:** Access is blocked until an authorized government process changes
  the establishment status.

## Beneficiary authority

Beneficiaries may:

- View their own status and permitted history.
- View notifications addressed to their account.
- Submit permitted disputes or unauthorized-use reports.
- Update allowed contact or account details through approved workflows.

Beneficiaries may not:

- View another person's ID, age, status, history, or notifications.
- Approve or dismiss fraud flags.
- Manage establishments or staff.
- Change verification evidence.

## Controlled overrides

“Override” means a new, explicit decision—not an overwrite of history.

Every override must:

1. Use a named action such as approve, deny, correct, escalate, or restore.
2. Preserve the original result and evidence.
3. Require a reason with an appropriate length limit.
4. Record actor, role, establishment or office scope, timestamp, and target.
5. Record before and after decisions without storing unnecessary sensitive data.
6. Apply approval or separation-of-duties rules when required.
7. Notify the affected reviewer or office when policy requires it.

There must be no generic “edit audit history” or “overwrite verification”
operation.

## Data visibility baseline

| Data category | Default treatment |
|---|---|
| Full ID number | Masked; reveal only for authorized minimum-necessary workflows |
| Age or birth date | Return only the minimum needed; prefer age band where possible |
| Beneficiary name | Role- and workflow-scoped |
| Verification image/document | Restricted; never included in ordinary list responses |
| Audit metadata | Minimized; never store passwords, tokens, or unnecessary ID values |
| Reports and exports | Role-scoped, masked by default, bounded, and audited |
| Passwords and tokens | Never readable by any role |

These rules are the authority foundation for F-05/F-06 masking.

## Required audit events

At minimum, the system should audit:

- Staff account creation, activation, deactivation, role changes, and resets.
- Establishment user creation, approval, deactivation, and credential resets.
- Login, failed login, lockout, logout, and account-status denial.
- Sensitive record creation, update, deletion attempt, review, and export.
- Every controlled override and approval.
- Agency Super Admin and Super User privilege changes.

Audit records must retain the actor, action, scope, affected record, reason
where applicable, and request context without storing secrets.

## Implementation prerequisites

Before coding these roles:

- Confirm the final role names and office assignments.
- Confirm the final Agency Super Admin role names and recovery procedures.
- Define recovery and second-approval procedures.
- Define establishment user invitation and identity-verification rules.
- Decide which overrides require BPLO or second-person approval.
- Define retention and review rules for account and privilege audits.

After approval, implementation should proceed in this order:

1. Database role, account-state, and establishment-scope model.
2. API authorization middleware and server-side scope checks.
3. Staff and establishment account-management workflows.
4. Audited controlled overrides.
5. Role-aware F-05/F-06 masking and export serializers.
6. Portal and Flutter UI route guards.
7. Authorization, privacy, migration, and end-to-end tests.

## Initial implementation status

- Added agency-scoped Super Admin roles through migration
  `039_add_office_super_admin_roles.sql`.
- Staff API authentication and staff management now recognize BPLO, OSCA, and
  PDAO Super Admins.
- Each Agency Super Admin can list agency staff, create matching office-admin
  accounts, and change roles only within that agency.
- Each Agency Super Admin can also access the normal dashboard for its own
  agency; this does not grant access to another agency's dashboard or data.
- Staff authorization tests cover regular-admin denial, matching-agency
  Super Admin access, cross-agency denial, agency-scoped staff UUID lookups,
  database-backed role refresh, and rejection of the retired global role.
- Office admins retain same-role management restrictions.
- Regular BPLO, OSCA, and PDAO Admin accounts are read-only in the Staff
  directory. They cannot create, edit, reset, activate, deactivate, or unlock
  staff accounts.
- The API prevents deactivating the final active Agency Super Admin and
  prevents a Super Admin from changing their own role.
- Role changes are recorded as `staff_role_changed`.
- Establishment Super User and Regular User accounts are not implemented yet;
  they require a separate establishment-user schema and invitation workflow.
- Each Agency Super Admin must be provisioned through a controlled
  deployment/database process; no default Super Admin password is seeded.
- F-05/F-06 privacy baseline is enforced on beneficiary-facing API responses,
  staff beneficiary/fraud/dispute/dashboard views, and CSV exports. ID values
  expose only the final two characters, while exact birth dates are omitted
  and replaced with age bands. Raw values are not returned by ordinary read
  endpoints. Matching-agency staff may use a separate detail-page reveal
  action when operationally necessary; each reveal is authenticated,
  agency-scoped, and recorded as `sensitive_data_revealed` in the audit log.
