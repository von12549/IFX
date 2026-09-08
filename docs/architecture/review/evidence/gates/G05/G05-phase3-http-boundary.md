# G05 Phase 3 HTTP context boundary

Date: 2026-09-08

## Result

The ApiHost pipeline now establishes request state in a fixed order: exception handling, W3C trace validation/restart, internal correlation, scoped logging, authentication, immutable execution context and authorization. Public traffic receives a fresh canonical internal `X-Correlation-Id`; an inbound value is adopted only when trusted-gateway propagation is explicitly enabled and the remote address is in the exact allowlist. The default configuration disables that trust path. A bounded `X-Client-Request-Id` is validated separately and never becomes the business correlation identity.

All module route groups declare `Tenant`, `Platform` or `Public` execution-scope metadata. `/api/v1` and `/management` routes without metadata fail closed. Authenticated tenant routes accept an absent header only through a member primary-tenant fallback. Malformed, empty-GUID, duplicate or unauthorized explicit tenant headers return stable 400/403 outcomes and never fall back. Global Administrators must name target tenants explicitly; platform endpoints require Global Administrator facts. Anonymous public routes receive a System/anonymous Platform scope without granting platform authorization.

`HttpExecutionContextMiddleware` consumes the Application-facing identity-facts port rather than Auth implementation types. Auth supplies those facts, and `CurrentUser.TenantId` now reads only the trusted execution scope rather than reparsing headers. Application handlers therefore see the same validated tenant that authorization saw.

## Safe responses and verification

Boundary errors include only a stable error code, safe message, canonical correlation ID and timestamp. Exception middleware no longer returns `ArgumentException`, `KeyNotFoundException` or `ForbiddenException` messages; validation details are reduced to property keys and `Invalid value.`. Unexpected exception text remains server-side only.

- HTTP boundary matrix: 12/12 tests passed for anonymous/authenticated requests, primary and alternate member tenants, malformed/duplicate/unauthorized headers, Global Administrator tenant/platform behavior, malformed trace, untrusted correlation and trusted reverse-proxy propagation.
- Focused HTTP boundary, exception and permission regression: 37/37 tests passed.
- Full solution: 984/984 tests passed.
- Full build: 0 errors and the unchanged 20 package, nullability and obsolete-endpoint warnings.
- LayerGuard: 179/179 tests passed with no new or stale b0.5 violation. The ApiHost adapter depends on `IExecutionIdentityFacts`, not Auth.Infrastructure.

The reports beside this document contain structure and rule outcomes only; no live actor, tenant, header, trace or credential values were collected.
