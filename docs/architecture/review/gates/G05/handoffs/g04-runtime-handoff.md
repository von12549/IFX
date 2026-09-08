# G05 -> G04 runtime and operations handoff

Date: 2026-09-08  
State: `delivered-repository-inputs / pending-real-runtime-return`

## Delivered rules

- Worker/dispatcher/message-delivery sources build one scoped trusted ExecutionContext and always
  clean it on success, failure, cancellation, shutdown and detached work.
- Quarantine/dead-letter diagnostics use bounded safe metadata only; payload, raw header, identifiers,
  exception prose and C3/C4 values never enter health details or ordinary telemetry.
- Backlog/tenant/producer/redaction/compatibility metrics use bounded policy labels only.
- Security failures emit a separate audit plus bounded alert; operational logs remain independently
  redacted. Trace damage restarts technical trace without changing business identity.

## Evidence G04/E3/E4/E6 must return

- Real dispatcher/worker scope cleanup during drain, lease loss, cancellation and process shutdown.
- Real quarantine/backlog/poison-message health and alert signals with captured sentinel proof.
- Telemetry flush and audit/alert delivery evidence under graceful and forced termination.
- Dashboard/threshold ownership, production ACL/retention/tamper-evidence, and staging rehearsal.

This handoff satisfies the G05 repository delivery only. It does not change G04 PRE-READY status.
