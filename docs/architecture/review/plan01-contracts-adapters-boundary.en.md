# Plan 01 Contracts / Ports / Adapters implementation baseline (B2)

> 中文：[plan01-contracts-adapters-boundary.zh-CN.md](plan01-contracts-adapters-boundary.zh-CN.md)
> Status: B2 complete; Plan 02 / B3, B4, and Gate Final Closure remain open.
> Authorities: [G03 catalog](gates/G03/contract-event-catalog.yaml) · [G05 context boundary](gates/G05/context-sensitive-data-boundary.en.md) · [B2 evidence](evidence/plan01/B2-status.json)

## Outcome

The two real synchronous dependencies now use provider-owned minimal V1 contracts and consumer-owned ports. CRM and Registry Application implement the capabilities, Infrastructure implements only local data ports, and Transaction.Infrastructure adapters are the sole cross-module bridges. Transaction.Application no longer references CRM/Registry contracts or legacy abstractions.

Each `*.Contracts` project depends only on the BCL and the G05-approved `IFX.Platform.Context.Contracts` primitives. It contains no DI, EF, MediatR, logging, or transport implementation. ApiHost still invokes module Composition only, and all modules remain one business release.

## Boundary and runtime semantics

- A consumer adapter creates a fresh RequestId from trusted `IExecutionContextAccessor` state, preserves CorrelationId, and uses the current OperationId as CausationId. Business code cannot choose source, actor, or tenant metadata.
- Before data access, a provider validates context version, registered consumer, trusted provenance, tenant scope, and request-tenant equality, then creates an isolated provider child scope.
- Not found, not approved, or closed returns `false`; caller cancellation propagates; timeout, unavailable provider, protocol error, and tenant mismatch fail closed.
- Contracts expose only capability identifiers and boolean decisions. CRM `isApproved` is an approved C3 decision-only field with response-lifetime retention and redacted logging; no C4 field is exposed.

## Migration map

| Legacy surface | B2 target | Result |
| --- | --- | --- |
| `ICrmReader.IsInvestmentAccountKycApprovedAsync` | `IAccountComplianceContract` → Transaction `IAccountCompliancePort` | Active V1; legacy Reader removed |
| `IRegistryReader.IsClassOpenForSubscriptionAsync` | `IClassSubscriptionAvailabilityContract` → Transaction `IClassSubscriptionAvailabilityPort` | Active V1; legacy Reader removed |
| Other CRM/Registry Reader methods and DTOs | No consumer or provider-internal models | Public surface retired/removed |
| `IHoldingsReader`, `ITransactionReader`, and DTOs | Application-owned result model or no consumer | Public Reader/DTO surface retired/removed |
| Events retained in four `*.Abstractions` projects | Plan 02 / B3 | Explicitly open |

## Replacement seam and verification

Composition currently registers in-process adapters. A future HTTP/gRPC implementation replaces only the outer implementation of the Transaction port; Transaction Application and provider business rules remain unchanged. Composition tests assert one provider and one consumer-port implementation per capability.

Diagram source and renders: [Mermaid](diagrams/plan01-contract-boundary.mmd) · [SVG](diagrams/plan01-contract-boundary.svg) · [PNG](diagrams/plan01-contract-boundary.png). B2 versus B1 is 103 matched, 0 new, and 13 stale; formal B2 is 103 matched, 0 new, and 0 stale. G03/G05 validators and real behavior tests retain field/context/runtime authority; LayerGuard judges structural boundaries only.

## New synchronous capability checklist

1. Register a unique identity, owner, real consumer, field classification, and Change Record in G03.
2. Keep provider-owned Contracts at BCL plus approved context primitives; let Consumer Application own its port.
3. Map DTOs, errors, cancellation, and trusted context in an outer adapter; revalidate consumer/scope/tenant at the provider.
4. Promote to Active only with provider contract, consumer compatibility, DI uniqueness, G05 conformance, and LayerGuard evidence.
