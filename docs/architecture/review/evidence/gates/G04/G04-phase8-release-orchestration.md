# G04 Phase 8 — Release orchestration

Status: **PRE-READY**. The release contract is machine-validated; no production deployment is claimed.

`release-orchestration.json` defines an acyclic, consumer-first order:

`database-preflight → restore-point → database-migrator → schema-validation → worker-consumer → api-producer → scheduler → observation → contract-cleanup`

Every stage has required predecessor evidence and a fail-closed action. Migration and cleanup explicitly stop without automatic `Down`. Worker V1/V2 compatibility and readiness precede API V2 production. Cleanup requires observation plus zero old-version demand. Reference migration, system seed, demo seed, and business backfill are separate, owned, idempotent, non-automatic jobs.

`Test-G04ReleaseOrchestration.ps1` validates the DAG, exact order, evidence shape, data-job ownership, and failure rules. Its default mode is deliberately named `structure-only-no-production-claim`; `-RequireCompleted` rejects missing stage evidence or non-monotonic timestamps when a real release record is supplied.

The runtime release manifest binds the orchestration and backpressure policy hashes. The evidence template records artifact/runtime/migration digests, approvals, timestamps, and stage evidence.

Remaining: E3 consumer compatibility, E6 observations, a target-platform rollout rehearsal, scheduler authority approval, and production cleanup approval.
