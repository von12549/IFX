# P02-C3 operations decisions and alert-calibration gate

Date: 2026-09-09

Result: **E6.7 PASSED — E6.5 TARGET CALIBRATION PENDING — PHASE 6 REMAINS OPEN**

## E6.7 decision: no forced business reprocessing

Plan02-v1 does not support forced business reprocessing. The accepted machine-readable decision is
[`reprocessing-policy.json`](../../../../../deployment/plan02/reprocessing-policy.json).

The supported recovery operation is immutable dead-letter replay: it requires authorization and a
compatible handler, is audited, and reuses the original EventId and logical Envelope. A completed
Inbox marker remains authoritative and the handler performs no second business effect. Reconciliation
is available to identify divergence without changing message identity.

The following are explicitly prohibited:

- minting another EventId to evade Inbox deduplication;
- deleting or changing an Inbox marker to force execution;
- mutating logical bytes during replay;
- direct operator DML against messaging tables;
- exposing a `ReprocessingRequest` contract or endpoint in this milestone.

A future forced-reprocessing capability requires a new plan and ADR, a separate request identity that
references the original EventId, Product/Architecture/module/Security/Operations approvals, downstream
side-effect analysis, and dedicated idempotency/audit tests. It cannot be introduced as an option on
the existing replay endpoint.

E6.7 is therefore closed as an explicit “not supported” decision, rather than left as an unspecified
missing implementation.

## E6.5 repository baseline improved

The existing backlog age/count, retries, dead letters, leases, last success, rate and storage signals
now also include:

- `ifx.messaging.delivery.consecutive_failures`;
- `ifx.messaging.delivery.seconds_since_success`;
- health output for consecutive failures and dispatcher silence;
- distinct bounded reason codes for warning/critical consecutive failure and silent-dispatcher states;
- low-volume silence detection that does not require the backlog-count threshold to be reached.

The tentative threshold set remains in
[`backpressure-policy.json`](../../../../../deployment/g04/backpressure-policy.json). These values are
safe repository defaults, not production-calibrated claims.

## Why E6.5 remains open

There is no production-equivalent platform decision, exporter, dashboard, alert route, replica count,
dispatcher concurrency or representative traffic baseline. Consequently the repository cannot prove
that an alert triggered, reached an operator, was acknowledged, linked the correct runbook and
recovered after transport, SQL, consumer or silent-dispatcher fault injection.

The required target record is
[`messaging-alert-calibration-evidence-template.json`](../../../../../deployment/plan02/messaging-alert-calibration-evidence-template.json).
Strict validation intentionally rejects that pending template.

## Target closure procedure for E6.5

1. Establish the production-equivalent worker topology and synthetic traffic profile.
2. Connect the `IFX.Platform.Messaging` meter to the selected exporter and metrics backend.
3. Build the dashboard and alert rules using only bounded dimensions.
4. Measure the healthy baseline and replace the tentative thresholds with reviewed calibrated values.
5. Inject transport, SQL, consumer and silent-dispatcher failures.
6. Capture trigger, route, acknowledgement, runbook and recovery evidence for every scenario.
7. Obtain named Observability, Platform Operations and Platform Messaging approval.
8. Run:

   ```powershell
   pwsh -NoProfile -File scripts/Test-Plan02C3Operations.ps1 `
     -AlertEvidencePath <immutable-alert-evidence.json> `
     -ReportPath <immutable-validation-report.json> `
     -RequireAlertCalibration
   ```

Only then may E6.5 and Phase 6 be checked. Current machine-readable result:
[`P02-C3-validation.json`](P02-C3-validation.json).
