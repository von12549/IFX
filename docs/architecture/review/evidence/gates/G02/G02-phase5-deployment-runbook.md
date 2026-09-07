# G02 Phase 5 database deployment runbook

Date: 2026-09-08

## Immutable inputs

Use one build of the following artifacts for the complete deployment:

- `IFX.DatabaseMigrator` publish output or image;
- `migration-manifest.json` and `release-manifest.json` from the same bundle;
- the five ordered `*.idempotent.sql` review artifacts and `artifact-manifest.json` hashes;
- the API/Worker artifacts identified by the release process.

Do not regenerate SQL or manifests after approval. The CI `Database migration artifacts` workflow
creates and uploads this bundle for each commit.

## Identity boundary

- Migration configuration uses `MIGRATION_DB_USER` / `MIGRATION_DB_PASSWORD` and the five
  `ConnectionStrings__*Database` values supplied only to the one-shot Migrator. This identity may
  create/alter module schemas and migration histories.
- Runtime configuration uses `RUNTIME_DB_USER` / `RUNTIME_DB_PASSWORD`. It receives only the DML
  and history-read permissions needed by the release; it must not receive schema-alter permissions.
- Local Compose defaults may map both configuration surfaces to `sa` for developer convenience.
  Staging/production identity grants and secret-store ownership are external Database Operations
  evidence and must be captured without exporting connection strings or passwords.

## Deployment sequence

1. Verify artifact hashes and run Migrator `preflight` using the migration identity.
2. Create and record the approved database backup/restore point.
3. Run the one-shot Migrator in `apply` mode. Any non-zero exit stops the deployment.
4. Run the same artifact in `validate` mode and archive both JSON reports.
5. Deploy compatible Worker consumers, wait for Worker readiness, then deploy API producers as
   specified by Gate 04.
6. Confirm API schema readiness and execute the approved smoke tests.

Compose enforces SQL healthy → `sqlserver-init` completed → Migrator completed → API. The init and
Migrator services use `restart: "no"`; a failure remains visible and cannot become an infinite hot
retry. Operators correct the cause and explicitly rerun the same immutable job.

## Compatibility rules

Each release carries the five module requirements in `deployment/release-manifest.json`. Readiness
performs only `SELECT` operations against module-owned history tables:

- every `requiredMigrationIds` entry must exist;
- an additional ID is accepted only when it appears in that release's
  `compatibleAdditionalMigrationIds` allowlist;
- missing, duplicate, or unknown IDs make readiness fail closed;
- the check never creates a schema/history table, stamps an ID, or invokes EF migration APIs.

An Expand migration intended to precede an application rollout must therefore be included in the
old release's compatibility allowlist before that old release is deployed. Contract migrations are
never allowlisted for older releases.

## Failure handling

- Preserve the Migrator JSON report, failure point, SQL error number, manifest hashes, and backup
  identifier. Do not archive secrets or raw connection strings.
- Do not invoke automatic `Down`. Inspect partial module state, repair the migration or environment,
  then roll forward with the same artifact or a reviewed successor.
- Do not start the new API after a failed apply or validate. A still-running old release may remain
  available only when its own schema readiness reports compatible.
