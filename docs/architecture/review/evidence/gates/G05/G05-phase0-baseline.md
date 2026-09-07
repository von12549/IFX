# G05 Phase 0 context and sensitive-data baseline

Date: 2026-09-08

## Scope and method

[`G05-context-inventory.json`](G05-context-inventory.json) is generated deterministically from C# source. It stores paths, line numbers, type/property names and capability flags only; it does not capture runtime headers, claims, tokens, payloads, log values, database rows or configuration values.

The inventory covers HTTP/header middleware, claims and `ICurrentUser`, jobs/handlers, operational logging, tracing/metrics, external error construction, diagnostics, public Abstractions schemas and Integration Events. It explicitly records that the current source has an in-memory bus but no durable module Outbox, Inbox, dead-letter/quarantine or replay implementation.

## Current identity and trust baseline

- `IIntegrationEvent` currently exposes only a `Guid EventId` and `DateTime OccurredAt`; the base event creates them with `Guid.NewGuid()` and `DateTime.UtcNow`.
- `RequestLoggingMiddleware` uses the server trace identifier as a request ID; there is no distinct business correlation/operation/causation model or trusted execution-context scope.
- `CurrentUser` remains HTTP/Auth-infrastructure owned and can silently replace an explicitly invalid tenant selection with a primary tenant.
- `ExceptionHandlingMiddleware` still returns raw messages for selected exception types and logs an unhandled exception message.
- Existing public Reader DTOs and Event payloads contain direct/linkable identifiers and business values that require field-by-field C0-C4 decisions.

## Security findings

| Finding | Severity | Owner | Closure requirement |
| --- | --- | --- | --- |
| G05-F01 LoginEvent persists access/refresh token fields | Critical | Auth + Security | Remove C4 persistence and apply a module-owned migration |
| G05-F02 explicit invalid tenant can fall back | High | ApiHost + Auth | Fail-closed middleware and HTTP integration tests |
| G05-F03 raw/linkable identifiers occur in operational logs | High | Module owners + Security | Central sink policy, call-site cleanup and sentinel tests |
| G05-F04 raw exception messages can reach logs/responses | High | ApiHost | Stable error schema, safe messages and captured-sink tests |

G05-F01 cannot be waived to close the Gate. Field classification approval, production sink/retention/key configuration and real Plan 01/02 carrier reruns remain external evidence gaps with named owners in the inventory.

## Baseline verification

The Phase 0 verification completed with 934 passing backend tests, 179 passing LayerGuard tests and a successful solution build with zero errors. The build retained 20 pre-existing package fallback/security, nullability and obsolete-endpoint warnings without treating them as new G05 success criteria. See [`G05-phase0-guard-report.json`](G05-phase0-guard-report.json) and [`G05-phase0-layerguard-report.json`](G05-phase0-layerguard-report.json).
