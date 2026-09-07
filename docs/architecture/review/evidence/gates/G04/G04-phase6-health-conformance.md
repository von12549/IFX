# G04 Phase 6 — Health conformance

Status: **PRE-READY**. Host probe semantics are implemented. Worker messaging contributors and the final Gate 05 disclosure/sentinel review remain external closure conditions.

## Probe contract

| Endpoint | Network work on request | Meaning | Access |
|---|---:|---|---|
| `/health/live` | none | process and critical-loop viability | public probe |
| `/health/startup` | none | static startup boundary completed | public probe |
| `/health/ready` | none | cached, role-specific readiness and lifecycle | public probe |
| `/health` | none | compatibility aggregate without details | public probe |
| `/health/database` | SQL, bounded by request cancellation | Gate 02 database release gate | deployment network |
| `/health/details` | none | cached contributor freshness and stable reason codes | authenticated |

Five module SQL contributors and the schema compatibility contributor run only in `StartupDependencyMonitor`, with a bounded timeout. The monitor filters registrations by `readiness-critical` and the active runtime role, serializes refreshes, and writes an immutable cache. Public endpoints never emit check descriptions, exceptions, stack traces, payloads, or tenant/user data.

## Automated evidence

- `HealthEndpointTests`: public liveness remains independent, startup reasons are stable and sanitized, details rejects unauthenticated access.
- `HealthSnapshotStoreTests`: stable sanitized reason, freshness, duration, and last-success retention; raw description and exception are not stored.

## Explicitly not claimed

- E3/E6 must add real Dispatcher, consumer, transport, lease, backlog, retry, and dead-letter contributors.
- Gate 05 must approve the details field classification and run the sensitive sentinel suite.
- Production ingress/network policy for management and Hangfire surfaces requires Operations rehearsal.
