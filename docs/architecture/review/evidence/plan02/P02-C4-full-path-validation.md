# P02-C4 full-path, fault and G05 validation gate

Date: 2026-09-10

Result: **REPOSITORY PASSED — TARGET FULL-PATH EVIDENCE PENDING — E7.3/E7.4/E7.8 REMAIN OPEN**

## Repository outcome

P02-C4 now joins the existing Plan 02 seams into a real SQL repository path. The new test commits a
Transaction business record and Outbox record together, runs the actual Dispatcher, encodes and decodes
the raw transport carrier, invokes the Holdings Inbound Adapter and commits one Inbox marker plus the
consumer-owned Holding state.

The transport wrapper deliberately loses the first acknowledgement after the consumer commits. The
producer retains the Outbox record as Pending, retries the same EventId, and then marks it Delivered.
The completed Inbox absorbs the redelivery, so the business effect remains exactly once. A second test
proves that one failed message in a claimed batch does not prevent unrelated partitions from completing.

The repository evidence now covers:

- source business state and Outbox atomic commit/rollback on SQL Server;
- Dispatcher → raw carrier → Inbound Adapter → Inbox → consumer-state execution;
- ack-loss redelivery with unchanged EventId and one business effect;
- send failure, bounded retry/dead-letter, pre/post-send crash windows and restart;
- expired lease takeover, stale completion rejection, partial-batch continuation and quarantine;
- G05 request/event identity, context cleanup, retry/replay immutability and sensitive-observability suites.

The cumulative G05 Phase 9 guard also now expects 165 classified fields rather than the historical
167. The two-field reduction is the already-approved removal of payload `TenantId` from the two active
events; all 32 governed surfaces, 27 legacy surfaces, 27 public surfaces and C3/C4 controls still pass.

## Why the checklist remains open

The repository transport is intentionally an in-process raw-carrier implementation. It proves the
serialization and inbound boundary but cannot substitute for a selected broker, its network behavior,
real process termination, SQL/network interruption or production-equivalent telemetry surfaces.

Therefore E7.3, E7.4 and E7.8 remain unchecked. The repository does not claim evidence for:

- a real broker or transport deployment and network policy;
- process kill and restart across separate Worker replicas;
- transport and SQL connection interruption under representative load;
- HTTP-to-downstream execution across deployed API and Worker roles;
- parallel-tenant isolation in the selected topology;
- absence of sensitive sentinels from deployed logs, traces, errors, health, dead-letter and quarantine stores.

## Target closure procedure

1. Select the production-equivalent environment, immutable release and real transport implementation.
2. Copy [`full-path-validation-evidence-template.json`](../../../../../deployment/plan02/full-path-validation-evidence-template.json)
   to an immutable release-specific record.
3. Run the three full-path scenarios and preserve the same EventId through duplicate and transient recovery.
4. Execute all ten fault scenarios; prove durable truth was preserved and the system recovered.
5. Run the G05 HTTP/producer-to-downstream, retry/replay, parallel-tenant and six-surface sentinel matrix.
6. Attach immutable evidence and named, dated approvals from all roles in the template.
7. Run:

   ```powershell
   pwsh -NoProfile -File scripts/Test-Plan02C4FullPath.ps1 `
     -EvidencePath <immutable-full-path-evidence.json> `
     -ReportPath <immutable-validation-report.json> `
     -RequireTargetEvidence
   ```

Only after strict validation passes may E7.3, E7.4 and E7.8 be checked. Phase 7 will still remain open
until P02-C5 closes E7.5 and E7.6. Current result: [`P02-C4-validation.json`](P02-C4-validation.json).
