# G03 Phase 0 contract/event governance baseline

> Scope: repository-owned module Abstractions, messaging Abstractions, callers, publishers,
> handlers, project references, and existing governance capabilities at the recorded commit.
> Generated output excludes `bin` and `obj` and does not treat a producer's self-use as consumer
> evidence.

## Reproduction

```powershell
./scripts/Invoke-G03ContractEventGuard.ps1 -Phase 0
./scripts/Invoke-LayerGuard.ps1 -ReportPath docs/architecture/review/evidence/gates/G03/G03-phase0-layerguard-report.json
dotnet build IFX.sln --no-restore
dotnet test IFX.sln --no-build --no-restore
```

The deterministic inventory records the source commit/time, input and exclusion rules, public
declarations, Reader method signatures and call sites, event producers/handlers/references,
Abstractions project/package references, and the current governance-tool gap assessment.

## Baseline findings

| Surface | Count | Classification at baseline |
| --- | ---: | --- |
| Module `*.Abstractions` projects | 4 | legacy surface awaiting catalog classification |
| Readers / methods | 4 / 15 | only two methods have confirmed cross-module business use |
| DTOs | 7 | public and internal-use models are currently mixed |
| Integration Events | 20 | only two have confirmed cross-module handlers |
| Messaging Abstractions types | 4 | schema identity/base and runtime bus/handler are mixed |

The two confirmed synchronous uses are CRM investment-account KYC approval and Registry class
subscription availability, both consumed by Transaction. The two confirmed asynchronous uses are
`TransactionProcessedEvent` and `ClassStatusChangedEvent`, both consumed by Holdings. All other
surfaces require explicit catalog disposition in Phase 2; publication alone is not consumer proof.

No repository CODEOWNERS file, G03 catalog, public API compatibility snapshot, or serialization
golden baseline existed at capture time. External/dynamic consumers are recognized only after the
system, accountable owner/contact, supported version, connection evidence, and last-confirmed date
are supplied. This makes the absence of repository source an investigation result, not proof of no
consumer.

## Evidence

- `G03-contract-event-inventory.json` is the reproducible machine-readable baseline.
- `G03-phase0-guard-report.json` proves deterministic generation and the expected 4/15/7/20
  source census.
- `G03-phase0-layerguard-report.json` records the unchanged LayerGuard B0.5 comparison.

Phase 0 establishes facts only. It does not promote a legacy type to Active or claim that a
downstream Contracts/Event migration has occurred.

## Verification result

- G03 guard: passed; deterministic inventory SHA-256
  `324a65b5105f03118035a2b8bd92cea0151b59521e022089b2438f9a02e0cf7d`.
- LayerGuard: 179 tool tests passed; B0.5 comparison `baseline-clean` with 116 matched,
  0 new, and 0 stale findings.
- Solution build: passed with 0 errors and 20 pre-existing package/nullability/obsolete warnings.
- Solution tests: 904 passed, 0 failed, 0 skipped.
