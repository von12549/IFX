# G02 Phase 6 migration failure and recovery runbook

Date: 2026-09-08

## Governing rule

Stop the release at the first failed stage. Do not invoke EF `Down` automatically and do not start
the new API. Preserve the immutable artifact, reports, module histories and restore-point reference;
repair and roll forward by default.

## Partial upgrade classification

Use the Migrator report and a read-only `validate` run to classify every module:

- `not-started`: before/after version unchanged and required IDs are missing;
- `current`: required IDs are present and no unsupported IDs exist;
- `advanced-compatible`: additional IDs are explicitly allowlisted by the running release;
- `advanced-incompatible`: an additional ID is not allowlisted;
- `failed/unknown`: migration threw, validation could not complete, or history is malformed.

The new API may start only when all five modules are `current` or `advanced-compatible`. An old API
may continue only when its own embedded release manifest evaluates every module as compatible.

## Safe rerun

1. Freeze the new API/Worker rollout and prevent operators from starting a different Migrator build.
2. Record the failed report, database histories, artifact hashes and active application versions.
3. Diagnose and correct the environmental or migration defect without editing applied history rows.
4. Rerun `preflight`; compare the resulting plan to the recorded partial state.
5. Rerun the same `apply` artifact. Completed module histories make the operation resumable; the
   stable order prevents later modules from running before the failed module succeeds.
6. Run `validate`, then schema readiness, then resume consumer-first deployment.

## Failure-specific actions

| Failure | Required action | Resume condition |
| --- | --- | --- |
| Application-lock timeout | Identify the lock owner and active deployment; never kill an unknown session solely to make progress. | Original owner completed/aborted and a fresh preflight is unchanged. |
| Process termination | Confirm transaction rollback/commit and module history from a new connection. | State classifies deterministically and preflight is safe. |
| Connection interruption | Treat commit outcome as unknown until history and schema are reread. | Database state and report agree; no partial unrecorded DDL remains. |
| Module migration failure | Later modules must remain untouched. Fix the failing migration/environment and roll forward. | Same or reviewed successor artifact passes apply and validation. |
| Post-validation failure | Keep the new API blocked; preserve the upgraded database for diagnosis. | Required IDs, ownership and pending checks all pass. |

## Application rollback

Before returning to an older image, run that image's release-schema compatibility evaluation against
the current histories. Image rollback is allowed only when every additional migration is on the old
release's explicit compatibility allowlist. A database is never implicitly rolled back with an image.

## Exceptional database rollback or restore

Use a database rollback only when roll-forward cannot meet the incident objective and the approved
restore point is valid. Generate a separate script from
`deployment/templates/database-rollback.sql.tmpl`; state exact affected IDs, data loss, preconditions,
row-count assertions and forward impact. Architecture, Database and Operations reviewers approve it
before execution. Rehearse on a restored copy first. Record the result with
`deployment/database-upgrade-audit-template.json`.

## Audit retention

Retain the release/migration/artifact manifests, all SQL scripts, preflight/apply/validate JSON,
approval references, restore verification, module histories, data-impact summary, operator identity,
timestamps, recovery action and the condition for the next release. Never retain passwords,
connection strings, business rows or raw sensitive payloads in the gate evidence.
