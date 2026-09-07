# ADR-G04-001: Deployment and runtime boundary

Status: Accepted  
Date: 2026-09-08

## Decision

Auth, CRM, Registry, Holdings and Transaction are required modules of one IFX business release. Every API, Worker and local all-in-one instance uses the same release manifest and the same required module/version set. Runtime role changes which entry-point capabilities execute; it never changes module ownership, schema ownership or the business release boundary.

Frontend, SQL Server, infrastructure bootstrap, Database Migrator, OPA and managed providers have independent deployment lifecycles. Their independence does not imply that the five business modules are microservices. Compatibility with those units is declared in a versioned matrix and validated before rollout.

The immutable release identity binds the host artifact digest, module-manifest hash, deployment-unit-catalog hash, Gate 02 schema release-manifest hash, and Gate 02 migration-manifest hash. API and Worker may scale independently only when those identities match.

## Consequences

- All five business modules are required and cannot be disabled per replica.
- Endpoint and module sets are release metadata, not environment-specific feature flags.
- API and Worker run from the same host artifact while enabling distinct runtime capabilities.
- Database migration remains a one-shot job and never runs as a probe or ordinary host startup action.
- Invalid or inconsistent manifests fail startup; transient runtime dependencies affect readiness instead.

## Alternatives rejected

- Per-replica module selection was rejected because it makes routing and compatibility nondeterministic.
- Treating Platform libraries as independently versioned business services was rejected because they are currently linked into the host.
- Using container count as evidence of microservice autonomy was rejected because release, data and failure ownership remain lockstep.
