# G05 -> Plan 01 Contract context conformance handoff

## Boundary and ownership

- Accountable owner: `xiaolong-feng` / `@von12549`.
- Delivery owner: the Plan 01 implementer for
  [`01-contracts-adapters-refactor.md`](../../../plans/01-contracts-adapters-refactor.md).
- Revisit trigger: the first real provider `Contracts.V1` or consumer Integration Adapter, and again
  before either G03 synchronous Contract changes from Proposed to Active.
- The original handoff supplied conformance rules and fake-carrier proof. Plan 01 returned real
  CRM/Registry provider and Transaction adapter evidence at B2.

## Required inputs

1. Use `ContractRequestContext` V1 from `IFX.Platform.Context.Contracts`; do not define a module-local
   correlation, tenant, actor or source envelope.
2. Execute the validation order and stable result mapping in
   [`contract-context-conformance-v1.json`](../contract-context-conformance-v1.json).
3. Reuse the behavioral cases in
   `tests/IFX.Platform.ProtocolContracts.Tests/ContractContextConformanceTests.cs` for every real
   in-process, HTTP or gRPC carrier and every provider capability.
4. Treat consumer identity as deployment/configuration-owned. Provider authorization is evaluated
   locally; token, principal, role lists, permissions and caller-asserted authorization are not
   Contract context fields.

## Evidence Plan 01 must return

- CRM account-compliance and Registry class-subscription provider validation tests.
- Transaction-owned consumer Adapter mapping tests through the unchanged Application Ports.
- At least one real carrier run of the shared construction, validation, tenant mismatch,
  cancellation, timeout and unavailable cases.
- Provider/consumer approvals, G03 source reconciliation and the B2 LayerGuard comparison.

Those artifacts returned on 2026-09-08; G05 accepts the Plan 01 downstream evidence without
claiming Plan 02 event carriers or production runtime proof.

## G05 repository package delivered 2026-09-08

- BCL-only `ContractRequestContext`, strong identifiers, trusted `ExecutionContext` and source policy.
- Contract construction/validation policy, stable results, fake direct/JSON carrier suite, Phase 9 unified
  verification, and bilingual decision/rule mapping.
- Handoff state: `plan01-real-carrier-return-accepted / plan02-and-production-evidence-pending`.
- Return evidence: [`B2-status.json`](../../../evidence/plan01/B2-status.json) and
  [`B2-gate-handback.md`](../../../evidence/plan01/B2-gate-handback.md).
