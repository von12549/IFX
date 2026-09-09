# P02-C5 consumer-first release and old-path closure gate

Date: 2026-09-10  
Status: **repository gate passed; production-equivalent rehearsal pending**

## Result

P02-C5 closes the repository-owned preparation for E7.5 and E7.6. The existing G04 orchestration
already fixes the nine-stage order from database preflight through observation and contract cleanup.
The new validator additionally proves that the repository uses the intended authoritative path:

`business transaction → module Outbox → Worker Dispatcher → approved transport → raw receiver → Inbox + consumer transaction`

The API role cannot enable Worker execution, producers do not depend on a transport sender or inbound
handler, and contract cleanup remains dependent on observation plus zero old-version demand.

This is not a production claim. The current in-process carrier is repository conformance infrastructure,
not evidence of the future target transport or orchestrator. Because no production platform or
production-candidate release has been selected, E7.5, E7.6 and Phase 7 remain unchecked.

## Evidence contract

Copy [`release-closure-evidence-template.json`](../../../../../deployment/plan02/release-closure-evidence-template.json)
to an immutable release-specific record. The strict gate binds it by SHA-256 to all three prerequisite
records:

1. completed P02-C3 alert calibration for the same release and environment;
2. completed P02-C4 real-transport/fault/G05 evidence for the same release and environment;
3. completed G04 nine-stage release evidence for the same release, environment and artifact digest.

The P02-C5 record then requires:

- Worker completion no later than API producer rollout start;
- exactly one scheduler authority and zero legacy sender/direct-handler registrations or traffic;
- a positive, approved observation window with stable backlog, retry and dead-letter behavior;
- zero duplicate business effects, data loss and old consumer/API/schema demand;
- rolling, drain, forced-termination, backpressure, network, capacity, rollback and roll-forward exercises;
- cleanup timestamps after observation, removal of legacy code/registration/configuration, and a passing
  post-cleanup smoke test;
- named evidence references and approvals from all affected owners.

## Validation

Repository/preparation mode:

```powershell
pwsh -NoProfile -File scripts/Test-Plan02C5ReleaseClosure.ps1
```

Expected result while the platform is undecided:
`repository-passed-release-rehearsal-pending`.

Strict target closure:

```powershell
pwsh -NoProfile -File scripts/Test-Plan02C5ReleaseClosure.ps1 `
  -ClosureEvidencePath <immutable-p02-c5-record.json> `
  -ReleaseEvidencePath <immutable-g04-release-record.json> `
  -AlertEvidencePath <immutable-p02-c3-record.json> `
  -FullPathEvidencePath <immutable-p02-c4-record.json> `
  -ReportPath <immutable-validation-report.json> `
  -RequireTargetEvidence
```

Only a passing strict report permits E7.5 and E7.6 to close. Phase 7 may close only after E7.3, E7.4
and E7.8 from P02-C4 are also closed.
