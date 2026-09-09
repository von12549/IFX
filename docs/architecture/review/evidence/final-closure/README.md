# Final closure execution pack

Date: 2026-09-09

State: **BLOCKED ON EXTERNAL EXECUTION AND NAMED APPROVALS**

## Repository evidence already complete

- Plan 01/B2 synchronous Contracts/Ports/Adapters migration.
- Plan 02/B3 durable module Outbox/Inbox/Dispatcher and repository hardening.
- Plan 03/B4 strict LayerGuard: 0 findings, 0 waivers, 39 governed projects.
- Full solution: 1,091 tests passed, 0 failed.
- LayerGuard tool suite: 189 tests passed, 0 failed.
- G01 and G02 received the real E2/E4 repository callback; their final signatures and the G04
  production release callback remain open.

## Inputs that must come from the target environment

Do not place credentials or secrets in this repository. Execute through the approved staging
identity and attach immutable references only.

1. Production-candidate release ID, artifact digest, runtime-manifest hash, migration-manifest
   hash, target environment, replica counts, and total concurrency.
2. A production-like environment with the target SQL Server, orchestrator/load balancer, Worker
   and API roles, transport/broker, observability exporter, alert routes, scheduler identity, and
   network policy.
3. Owned/calibrated backlog-age, consecutive-failure, retry/dead-letter, lease, last-success,
   readiness, drain, and backpressure thresholds.
4. Named and dated approval references from Architecture, module owners, Platform, Database,
   Security, and Operations.

The Plan02-v1 forced-reprocessing decision is no longer an external input: P02-C3 formally records
the capability as unsupported. It must remain disabled; any future capability requires a new Plan/ADR.

## Plan 02 checklist items intentionally left open

| Items | Why they are not checked |
| --- | --- |
| E5.7 | P02-C2 fail-closed policy, evidence template and validator exist; target ACL/encryption/key/lifecycle drills and Security/Database/Operations/Legal-data-owner attestations remain required. |
| E6.5 | Repository metrics/readiness exist; exporter, alert route, and threshold calibration require target telemetry. |
| E7.3–E7.6, E7.8 | P02-C4 repository SQL full path, ack-loss/partial-batch/fault and G05 bindings pass; real transport E2E, process/network/SQL fault injection, target sentinel suite, consumer-first rehearsal, observed threshold acceptance and old-path closure require production-like execution. |
| E8.9–E8.10 | G01/G02 repository callbacks exist; their named final approval workflows remain open. |
| E-D06, E-D08, E-D10, E-D11 | These roll up the unresolved fault/alert, target data-control, and final-signature evidence above. |

P02-C1/E4.9 closed Phase 4 on 2026-09-09. Consequently, the Phase 5–8 completion boxes and the overall Plan 02 completion box remain
unchecked. They are not stale checkmarks; each is gated by one or more rows above.
P02-C3 closed E6.7 through the accepted Plan02-v1 decision not to support forced business reprocessing;
E6.5 and Phase 6 remain open pending production-equivalent alert calibration.
Detailed item-by-item acceptance and the six closure slices are maintained in the
[`Plan 02 remaining closure plan`](../plan02/remaining-closure-plan.md).

## Required rehearsal order

Copy `deployment/g04/release-evidence-template.json` to an immutable release-specific evidence
record and execute exactly:

1. database preflight;
2. restore point;
3. DatabaseMigrator;
4. schema validation;
5. Worker consumers (old/new schema compatible and Ready);
6. API producers;
7. the single approved scheduler authority;
8. observation window with backlog/retry/dead-letter/tenant/sensitive-data checks;
9. contract cleanup only after zero old-version demand is proven.

Exercise rolling rollout, SIGTERM drain, forced termination, transport interruption, SQL
interruption, partial batch, restart/takeover, duplicate delivery, poison/quarantine, alert firing,
backpressure recovery, and safe rollback. Never delete pending Outbox/Inbox truth, mint a new
EventId to bypass deduplication, or execute an unreviewed database Down migration.

## Completion validation

```powershell
./scripts/Test-G04ReleaseOrchestration.ps1 `
  -EvidencePath <immutable-release-evidence.json> `
  -ReportPath <immutable-validation-report.json> `
  -RequireCompleted

./scripts/Invoke-LayerGuard.ps1
./scripts/Test-Plan03B4StrictClosure.ps1
./scripts/Test-G04Closeout.ps1
```

`-RequireCompleted` now rejects placeholder release metadata, invalid digests/hashes, missing or
undated approval groups, failed/incomplete stages, placeholder evidence references, invalid
timestamps, or non-monotonic timestamps.

## Current closure map

| Item | Current state | Closing action |
| --- | --- | --- |
| G04-B01 / real Dispatcher | Evidence available | Platform Messaging and producing-module owners accept linked SQL/crash/order results |
| G04-B02 / real Inbox | Evidence available | consuming-module owners accept atomic/dedup/context results |
| G04-B03 / observability | Open | run target exporter/dashboard/alert/silent-stop calibration |
| G04-B04 / G05 runtime security | Evidence available | Security, Platform, Architecture accept sentinel/context/quarantine evidence and target rehearsal |
| G04-B05 / B4 | Closed 2026-09-09 | no action; preserve strict zero-entry baseline |
| G04-B06 / release rehearsal | Open | execute and validate the nine-stage production-like record |
| G04-B07 / final approval | Blocked | record named, dated approvals after B01–B06 are accepted |
| Plan 03 L7.7 | Open | architecture owner approves strict mode and B1↔B4 comparison |
| Master M5.4 | Open | assign owner and due milestone to any TODO that blocks acceptance |

The repository cannot truthfully fill these records or sign on behalf of the named owners.
