# G05 Phase 2 trusted execution context

Date: 2026-09-08

## Result

Application code now has a transport-neutral `IExecutionContextAccessor` and `IExecutionContextScopeFactory` backed by an immutable `ExecutionContextSnapshot`. The snapshot carries only the Phase 1 strong correlation, operation, causation, discriminated scope, actor, source and provenance primitives. It has no ASP.NET, claims, mediator, persistence or broker dependency.

Root composition owns one `ExecutionContextAccessor` instance and exposes that same instance through both ports. The implementation stores only an `AsyncLocal` scope-frame chain: `Current` fails when no trusted context is active, nested leases restore their parent, invalid disposal order fails, and `RunAsync` guarantees cleanup through `using` on success, cancellation or exception. `RunDetachedAsync` suppresses execution-context flow so unowned fire-and-forget work cannot inherit tenant or actor context.

`CurrentUser` no longer directly holds `IHttpContextAccessor` or parses claims and tenant headers. `HttpIdentityFacts` owns identity/membership facts while `HttpTenantSelection` isolates the current compatibility selection policy. Phase 3 remains responsible for replacing its primary-tenant fallback with fail-closed HTTP parsing before Application dispatch.

## Source ownership

[`execution-context-sources.json`](../../gates/G05/execution-context-sources.json) assigns actor, source, scope, builder boundary, missing-context behavior and owner for HTTP, scheduled job, durable dispatcher, message delivery and controlled management commands. Dispatcher and message rules remain conformance targets for the real Plan 02 carrier; this phase does not claim that Outbox, Inbox, broker, quarantine or replay infrastructure exists.

## Verification

- Execution-context lifecycle and isolation: 8/8 targeted tests passed.
- Auth identity/tenant responsibility split: 2/2 targeted tests passed.
- Root composition resolves one implementation through both ports: covered by the full IntegrationTests suite.
- Full solution: 972/972 tests passed.
- Full build: 0 errors; the existing 20 package, nullability and obsolete-endpoint warnings remain visible.
- LayerGuard: 179/179 tests passed and the b0.5 baseline has no new or stale violation. The Context reference is `PrivateAssets=all`, preventing the shared Application assembly from leaking a foreign Contracts dependency into module graphs.

The G05 Phase 2 guard and LayerGuard reports are stored alongside this document. No runtime values, claims, tenant identifiers or credentials are present in the evidence.
