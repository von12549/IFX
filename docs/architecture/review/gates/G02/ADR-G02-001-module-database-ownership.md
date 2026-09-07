# ADR-G02-001: Module-owned database boundaries in a shared physical database

- Status: Accepted
- Date: 2026-09-08
- Scope: G02 / DB1–DB4, DB9–DB11

## Context

IFX is a modular monolith whose five business modules currently share SQL Server and `IFXDb`.
Sharing a deployment resource had allowed migration history, startup DDL and connection fallback to
blur ownership. Immediate physical decomposition would add operational cost without first making the
logical boundary enforceable.

## Decision

Auth, CRM, Registry, Holdings and Transaction each own one DbContext, schema, connection key,
migration assembly and schema-local `__EFMigrationsHistory`. A module may create and access objects
only in its own schema. Cross-schema foreign keys, navigation, joins, triggers, procedures and direct
writes are forbidden; cross-module behavior uses Contracts, Adapters or durable Events.

`IFX.DatabaseMigrator` is the only normal DDL execution path. It uses a separate migration identity,
a deterministic module manifest and one database application lock. ApiHost uses a DML/readiness
identity, performs read-only compatibility checks and never repairs schema. History bootstrap is an
explicit, fail-closed operation. Deployments use Expand/Contract and default to roll-forward after a
failure; application rollback never implies database `Down`.

Outbox and Inbox objects belong to their producing or consuming module's DbContext and schema. Plan
02 E2/E4 creates the real objects and returns relational conformance evidence to G01 and G02.

## Consequences

- The current shared `IFXDb` remains an operational choice, not shared data ownership.
- A future physical split changes the selected module connection/deployment mapping without moving
  ownership into Application or Domain.
- A production rollout requires its own database, restore-point and operations approval evidence;
  the G02 controlled Docker rehearsal does not authorize production.
- Reporting, tenant lifecycle, stronger per-module production credentials and physical split design
  remain tracked in `plans/TODO.md`.

