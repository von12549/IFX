# G05 Phase 4 — synchronous Contract context conformance

Date: 2026-09-08

## Outcome

Phase 4 establishes the pre-Active Contract context behavior without claiming a production module
Contract carrier. The authoritative policy fixes consumer construction, provider validation order,
stable results and the trust boundary. The conformance harness exercises one unchanged consumer
Application Port through both a direct in-process carrier and a JSON round-trip carrier.

The consumer creates a fresh RequestId for each invocation, carries the trusted business
CorrelationId, sets direct causation to the current OperationId, copies trusted scope/actor facts and
uses a configured consumer source identity. The provider checks consumer allowlist first, then
version, scope, actor/source provenance and tenant/resource consistency before creating a child
operation. It never accepts a token, principal, role set, permission set or caller-asserted
authorization result as context.

## Verification

- Protocol/conformance test project: 38/38 passed, including 11 Phase 4 cases.
- Stable outcomes: `contract_context_invalid`, `contract_consumer_denied`,
  `contract_tenant_mismatch`, `contract_timeout`, `contract_cancelled` and
  `contract_unavailable`.
- Carrier substitution: direct and JSON round-trip fake carriers returned identical Port results.
- Unknown JSON authorization/role fields were ignored and did not influence provider behavior.
- Full solution: 995/995 tests passed.
- Full build: 0 errors and the unchanged 20 package, nullability and obsolete-endpoint warnings.
- LayerGuard: 179/179 tests passed and the 03-A0 baseline check reported no new/stale violation.
- G05 Phase 4 guard: passed with all cumulative Phase 0–4 checks true.

## Remaining downstream evidence

The fake carriers are specification evidence only. Plan 01 must apply the same suite to the proposed
CRM account-compliance and Registry class-subscription providers, Transaction-owned consumer
Adapters and every actual in-process/HTTP/gRPC carrier. The linked handoff remains pending until
those real sources, approvals and the B2 LayerGuard comparison return.
