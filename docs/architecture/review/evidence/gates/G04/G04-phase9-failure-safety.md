# G04 Phase 9 — Failure safety

Status: **PRE-READY**. Failure decisions are complete as versioned policy; real E3/E4 and production recovery evidence is intentionally not claimed.

The failure matrix covers preflight, Migrator, Worker V2 readiness, API rolling failure, V2 event rollback, transport/storage outage, single Worker crash, fleet failure, and shutdown timeout. Every row includes module, dependency, role, stable reason, operator action, recovery verification, and prohibitions.

The validator proves all required scenarios exist, identities are unique, operational dimensions are present, automatic `Down` is prohibited, transport failures preserve truthful Outbox state, V2 Worker retention is mandatory, and shutdown remains bounded.

The runbook links database recovery, consumer-first rollback, scoped backpressure, lease/Hangfire recovery, and forced termination. It does not substitute for real Dispatcher/Inbox crash injection or production approval.
