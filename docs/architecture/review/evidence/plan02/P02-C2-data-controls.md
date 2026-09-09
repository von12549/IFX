# P02-C2 target messaging data controls

Date: 2026-09-09

Result: **REPOSITORY BASELINE PASSED — TARGET EVIDENCE PENDING; E5.7 REMAINS OPEN**

## What is now controlled in the repository

[`messaging-data-controls.json`](../../../../../deployment/plan02/messaging-data-controls.json)
is the fail-closed deployment contract for Outbox, Inbox, broker, dead-letter, quarantine,
replay-audit and diagnostic storage. It inherits the highest admitted payload classification from
the G03 catalog. The two current V1 events have a C2 ceiling; C4 is forbidden and there is no active
C3 State Transfer exception.

The contract requires five distinct capabilities rather than a shared administrator identity:
producer, Dispatcher, consumer, diagnostics and replay operator. Diagnostic access excludes payload
and raw carrier headers. Replay is an authorized, audited operation and direct table DML is denied.

It also requires TLS 1.2 or later with certificate validation, encryption at rest for every copy and
backup, external secret/key management, rotation evidence and access audit. The lifecycle section
defines proposed schedules for all seven stores, prohibits age-deleting Pending messages, preserves
the replay/deduplication window, makes legal hold suspend deletion, and requires reconciliation before
tenant deletion. These durations remain proposals until Security, Legal/data owner and Operations
approve them for the target environment.

The default for C3 State Transfer is deny. A future exception must identify its owner, exact fields,
purpose, producer/consumers, approvals, expiry, revocation and deletion condition; an unregistered or
expired exception fails closed.

## Existing evidence reused

| Control | Repository evidence | Boundary |
| --- | --- | --- |
| Field classification | G03 catalog and G05 field rules; current event payload ceiling is C2 | Production storage configuration is not attested |
| Diagnostic minimization | `OutboxDiagnosticRecord`, `InboxDiagnosticRecord` and `RuntimeMessagingOperations` expose metadata, not payload | Target diagnostic ACL and sink configuration are not attested |
| Replay authorization/audit | `IMessagingOperationsAuthorizer`, `IMessagingReplayGuard` and `IMessagingOperationsAuditSink` gate replay | Target operator identity and immutable audit sink are not attested |
| Database privilege negative test | G02 controlled Docker rehearsal proves runtime DDL is denied | It uses one broad runtime identity and does not prove the five target capabilities |
| C3 admission | Current messaging policy has zero active State Transfer exceptions and defaults to deny | Target negative test and named Security acceptance are not attested |

## Why E5.7 is not checked yet

E5.7 explicitly requires target-platform configuration and evidence. This repository has no selected
production broker/IaC bundle and cannot manufacture the following external facts:

1. production-candidate release and environment identity;
2. database, broker and diagnostic ACL snapshots plus positive and negative permission results;
3. TLS/certificate-validation and at-rest/backup encryption attestations;
4. external secret/key store and rotation record;
5. approved retention schedule and executed retention, tenant-deletion, legal-hold and restore drills;
6. immutable Security, Database, Platform Operations and Legal/data-owner approvals.

Marking E5.7 or Phase 5 complete without those records would convert a policy into a false production
claim. The validator therefore reports repository success but deliberately rejects strict closure.

## Target closure procedure

1. Copy
   [`messaging-data-controls-evidence-template.json`](../../../../../deployment/plan02/messaging-data-controls-evidence-template.json)
   into the immutable production-candidate evidence bundle; do not edit the template into a simulated pass.
2. Record the release/environment identity and the SHA-256 of the exact policy deployed.
3. Attach database, broker, diagnostics and audit ACLs. Run positive tests for each allowed capability
   and negative tests for shared-admin, payload diagnostics, cross-capability and direct replay DML.
4. Attach TLS and certificate-validation results, at-rest/backup/sink encryption configuration,
   external secret-store evidence and a key-rotation record.
5. Obtain approval for the proposed lifecycle durations, configure the jobs/policies, then rehearse
   delivered cleanup, Pending protection, replay-window protection, tenant deletion, legal hold and restore.
6. Record zero active C3 State Transfer exceptions and prove unregistered/expired transfers fail, or
   register every active exception with all required fields and approvals.
7. Obtain named, dated Security, Database, Platform Operations and Legal/data-owner approvals.
8. Run:

   ```powershell
   pwsh -NoProfile -File scripts/Test-Plan02C2DataControls.ps1 `
     -EvidencePath <immutable-target-evidence.json> `
     -ReportPath <immutable-validation-report.json> `
     -RequireTargetEvidence
   ```

9. Only after `result=passed` may E5.7 and Phase 5 be checked and P02-C2 added to `closedSlices`.

Current machine-readable result:
[`P02-C2-validation.json`](P02-C2-validation.json).
