# G01 Transaction Boundary Implementation

## Scope

Implement the independently deliverable parts of `docs/architecture/review/plans/00-G01-transaction-boundary.md`: establish the evidence baseline, consolidate the MediatR pipeline and transaction policy, migrate module commands and handlers, add transaction/conformance tests, and publish the bilingual Gate design and evidence. Preserve the explicit E2/E4 ownership of real Outbox/Inbox entities, migrations, dispatcher, and transport behavior.

## Implementation sequence

1. Capture the five-module behavior, unit-of-work, command, persistence, exception, publish, raw SQL, nested-send, and ApiHost registration baseline.
2. Add process-local Application building blocks for explicit commands, operation results, pipeline behaviors, transaction profiles, ownership, and narrow transaction execution ports.
3. Implement one module-local transaction executor per writable module and register each command owner explicitly.
4. Register Logging, Validation, and Transaction behaviors once in ApiHost in deterministic order; remove module copies and registrations.
5. Migrate write commands to the explicit marker, remove handler-owned final saves and broad exception catches, and retain only documented E2/E4 seams.
6. Add characterization, state-matrix, isolation, registration, HTTP error-semantics, relational concurrency, and transaction-seam conformance tests.
7. Add deterministic guardrails for forbidden naming heuristics, nested command sends, handler saves/catch-all/direct publish, ambient/cross-module transactions, and transaction-protocol leakage.
8. Produce ADR/evidence plus matching Chinese and English Gate design documents and Mermaid-rendered diagrams; update discoverability and plan checklists only where evidence is complete.
9. Run focused tests, full build/tests, formatting, LayerGuard, and report any final-close items that remain owned by E2/E4 or require human approval.

## Verification

- `dotnet build IFX.sln --no-restore`
- focused Application, Infrastructure, ApiHost, and integration test projects
- `dotnet test IFX.sln --no-build`
- `pwsh -NoProfile -File scripts/Invoke-LayerGuard.ps1`
- Gate-specific inventory/guard/conformance scripts and documentation consistency checks

## Ownership boundary

G01 owns transaction policy and the pending/completion seams. Plan 02 E2/E4 remains the sole owner of production Outbox/Inbox storage, migrations, dispatch, transport acknowledgement, replay, and dead-letter behavior; those dependent G01 final-close checks remain open until evidence is returned.
