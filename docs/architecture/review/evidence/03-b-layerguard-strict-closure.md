# Plan 03-B / B4 strict closure evidence

Date: 2026-09-09  
Repository result: **strict-clean**  
Approval state: architecture-owner approval remains external and open.

## Outcome

LayerGuard now checks 39 governed projects with the B4 strict policy and reports zero findings,
zero clusters, and an empty migration baseline. The default local script and the LayerGuard CI
workflow both use `mcp/LayerGuard/baselines/b4.json`; any future finding is therefore new and
fails the gate.

The 32 B3 findings were removed by:

- replacing BackgroundJobs/Notifications `Abstractions` projects with BCL-only `Contracts`;
- placing email/job scheduling behind an Auth Application port;
- moving OIDC HTTP and JWT parsing into Auth Infrastructure;
- exposing host-safe IdP/provisioning façades and cache signals from Auth Composition;
- deleting four empty module `Abstractions` projects and unused project references;
- removing the Registry Application HTTP package and other unused outer references.

## Checkpoints

| Checkpoint | Findings | Clusters | Governed projects |
| --- | ---: | ---: | ---: |
| B1 | 116 | 44 | 41 |
| B2 | 103 | 40 | 43 |
| B3 | 32 | 19 | 43 |
| B4 | 0 | 0 | 39 |

The ruleset hashes changed only for recorded policy evolution. B2 preserved the B1 target model;
B3 added the approved Messaging Runtime role and refreshed authoritative artifact bindings; B4
removed migration-only recognition of module/platform `*.Abstractions`. B4 did not add an allow
edge and retains `forbiddenProjectNames: ["*.Abstractions"]`.

## Evidence

- `B4-report.json`: repository scan, 0 findings, baseline-clean.
- `B4-dependency-graph.json`: final compile-time project and namespace graph.
- `B4-vs-B1-B2-B3-report.json`: immutable checkpoint comparison and hash explanation.
- `B4-validation-status.json`: executable acceptance checks.
- `mcp/LayerGuard/baselines/b4.json`: 0-entry strict baseline.
- `scripts/Test-Plan03B4StrictClosure.ps1`: fail-closed validation.

Final verification passed the full solution with 1,077 tests (0 failed), plus 189 LayerGuard tool
tests (0 failed). The strict repository scan remained at 0 findings. LayerGuard tool tests run from
the normal script unless `-SkipTests` is explicitly supplied for a scan-only diagnostic run.

## Remaining external action

L7.7 is intentionally not self-approved. An architecture owner must review the B1/B4 comparison,
strict CI configuration, zero-entry baseline, and diagrams, then record approval. Production
telemetry, release rehearsal, and multi-owner Gate signatures remain Step 4 work.
