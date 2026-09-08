# G05 Phase 7 — safe observability and secret retention

Date: 2026-09-08

## Outcome

All ApiHost operational logs now pass through one classification boundary before console or file
destinations. The boundary allowlists bounded C0/C1 fields, emits C2 as keyed HMAC pseudonyms carrying
only a non-secret rotation key ID, redacts C3, drops C4, defaults unknown fields to redaction and
removes exception message, data and stack. Production startup fails closed unless an external
256-bit pseudonym key and explicit key ID are configured; development and tests use a per-process key.

Request logging uses endpoint display identity instead of the raw request path. The notification and
OIDC SDK paths no longer submit recipients, subject/body/template data, provider response bodies or
raw SDK exceptions to their local logger. External errors keep stable codes, safe messages and a
correlation ID; domain rule and provider exception prose is not returned through Result objects.

Trace tags share the field classifier. Sensitive metric labels and baggage are dropped rather than
pseudonymized, preventing both leakage and high-cardinality series. The policy disables HTTP/Contract/
Event body capture, SQL parameter capture and EF sensitive-data logging.

## Audit separation

The machine-readable policy defines security/compliance audit as a sink separate from operational
logging, with explicit writers/readers, append-only and tamper-evident production controls, approved
retention/deletion, and audited purpose-bound query. These rules are established in the repository;
production ACL, retention and tamper-evidence attestations remain external Phase 11 evidence.

## Auth secret-retention resolution

`LoginEvent` and its EF mapping no longer contain `AccessToken`, `RefreshToken`, `CognitoSessionId` or
`TokenExpiresAt`, and login/refresh handlers no longer write those values. Versioned migration
`20260908015924_RemoveLoginEventSecrets` drops all four nullable columns, its model snapshot is clean,
and the migration/runtime/release manifests include it.

This is an intentional destructive contract migration that deletes persisted credentials and session
material. Repository implementation is complete, but production application is not approved by this
phase: it requires database safety approval, a verified restore point and confirmed absence of an old
runtime that still writes those columns. Automatic `Down` is forbidden and must not be used to restore
secret persistence.

## Verification

- Targeted notification, observability, HTTP error and diagnostic endpoint tests: passed.
- Auth EF model: no pending model changes after the secret-removal migration.
- Database inventory and migration safety policy: passed for 5 modules, 46 entities, 15 migrations,
  zero schema violations and one hash-bound destructive remediation review. That review authorizes the
  repository artifact only, not production execution.
- Full solution: 1017/1017 tests passed, including the SQL Server migration matrix.
- Full build: 0 errors and 14 existing package/obsolete-endpoint warnings in the incremental build.
- LayerGuard: 179/179 tests passed; the 03-A0 baseline has no new or stale violation.
- Cumulative G05 Phase 7 guard: passed with every Phase 0–7 check true.

## Truthful remaining evidence

- Production pseudonym key custody/rotation, operational and audit sink ACL, retention/deletion,
  tamper-evidence and access-query audit are pending.
- The destructive migration has not been applied to a production target and has no fabricated
  database approval or restore evidence.
- Plan 01/02 real carrier evidence and LayerGuard 03-A1 policy binding remain later G05 dependencies.
