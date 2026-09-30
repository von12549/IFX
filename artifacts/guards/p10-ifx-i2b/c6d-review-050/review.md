# C6d review packet: ifx_profile 0.5.0 on V4 Guards 1.1.6

Status: `ready-for-designated-human-review` - review decision pending (A1-7).

- Target commit: `c0d927eb7d81256d10194b894e20d4ad92333ad9`; bundle manifest `086a3911a2cb8f5cef0caf7621cecaf49dcc9bf08e30acd8a376748b9e38a284`; base archive `92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8`.
- C6c decision `315a825135d64dc80315774a63be87fd541d19fe6fc3ff6a46be455171bfee2a`: Windows product certification pass (independent matrix 191/191, controls 180 capability + 42 staged-evidence); Linux portability pass (191/191, semantic projection equal, non-blocking).
- Against 0.4.4 (`f71b4754…`): 25 module versions changed, 103 package files changed, 6 added, none removed. Four lock consumers gain EvidenceRoot read access; no module gains writes, processes, network or time.

## What to decide

Accept or reject this exact packet. Acceptance means: for each changed module, the "pass means" statement below is the claim IFX relies on from now on. It permits writing the production review record and continuing with A1-8 (C6e composition, P10.2 parity, P10.3 rehearsal). It does not authorize a push, a workflow, a ruleset or publishing.

## Model change

- **Lock binding (6 modules).** Post reads evidence staged by workflow producers under `EvidenceRoot/locks/<gate>/` instead of a lock pinned in the Profile. The lock must name the Target HEAD commit, the producer script hash must match the module policy, and every evidence file hash must match.
- **Pin split (20 modules).** 126 pins are dropped (110 live-source, 11 live-registry, 3 v3-coupling, 2 lab-coupling): live sources and registries are checked by content against the current files (R1), the G03 projection is regenerated in the G03 core module (R2), and lab policies are embedded in the module. 104 governance pins are kept and compared with an LF-normalized SHA-256 (R5).
- **Couplings (6 modules).** V3 and lab inputs are embedded in the module package or recomputed in the module (R2).

## Per module

| Module | Version | Disposition | Pins dropped / kept | Lock | Core cases |
| --- | --- | --- | --- | --- | --- |
| `ifx-domain-reference` | 0.1.0 -> 0.1.0 | unchanged | 0 / 0 | - | 4 |
| `ifx-package-reference` | 0.1.0 -> 0.1.0 | unchanged | 0 / 0 | - | 5 |
| `ifx-ring-graph` | 0.1.0 -> 0.1.0 | unchanged | 0 / 0 | - | 4 |
| `ifx-ownership-graph` | 0.1.0 -> 0.1.0 | unchanged | 0 / 0 | - | 4 |
| `ifx-provider-cycle` | 0.1.0 -> 0.1.0 | unchanged | 0 / 0 | - | 4 |
| `ifx-embedded-adapter` | 0.1.0 -> 0.1.0 | unchanged | 0 / 0 | - | 5 |
| `ifx-source-policy` | 0.1.0 -> 0.1.0 | unchanged | 0 / 0 | - | 12 |
| `ifx-project-name` | 0.1.0 -> 0.1.0 | unchanged | 0 / 0 | - | 4 |
| `ifx-reference-cycle` | 0.1.0 -> 0.1.0 | unchanged | 0 / 0 | - | 5 |
| `ifx-injection` | 0.1.0 -> 0.1.0 | unchanged | 0 / 0 | - | 5 |
| `architecture-conformance` | 1.0.1 -> 1.0.1 | unchanged | 0 / 0 | - | 4 |
| `ifx-c1-type-provenance` | 0.1.0 -> 0.2.0 | lock-binding, coupling | 0 / 0 | type | 4 |
| `ifx-c1-evaluated-reference` | 0.1.0 -> 0.2.0 | lock-binding, coupling | 0 / 0 | graph | 5 |
| `ifx-g03-governance-core` | 0.1.0 -> 0.2.0 | pin-split, coupling | 2 / 0 | - | 7 |
| `ifx-g03-catalog-semantics` | 0.1.0 -> 0.2.0 | pin-split | 1 / 0 | - | 7 |
| `ifx-g03-source-reconciliation` | 0.1.0 -> 0.2.0 | pin-split | 1 / 0 | - | 6 |
| `ifx-g03-snapshots` | 0.1.0 -> 0.2.0 | pin-split | 3 / 0 | - | 5 |
| `ifx-g03-docs-closeout` | 0.1.0 -> 0.2.0 | pin-split | 1 / 5 | - | 6 |
| `ifx-g04-manifests` | 0.1.0 -> 0.2.0 | pin-split | 18 / 1 | - | 7 |
| `ifx-g04-runtime` | 0.1.0 -> 0.2.0 | pin-split | 19 / 1 | - | 10 |
| `ifx-g04-closeout` | 0.1.0 -> 0.2.0 | pin-split | 1 / 42 | - | 7 |
| `ifx-plan04-extraction` | 0.1.0 -> 0.2.0 | pin-split | 1 / 2 | - | 4 |
| `ifx-plan04-tenant` | 0.1.0 -> 0.2.0 | pin-split | 3 / 1 | - | 4 |
| `ifx-plan04-projection` | 0.1.0 -> 0.2.0 | pin-split | 8 / 3 | - | 4 |
| `ifx-plan04-abstractions` | 0.1.0 -> 0.2.0 | pin-split, coupling | 5 / 0 | - | 4 |
| `ifx-database-evidence` | 0.2.0 -> 0.3.0 | lock-binding, pin-split | 3 / 0 | database | 4 |
| `ifx-g05-inventory` | 0.1.0 -> 0.2.0 | pin-split | 1 / 4 | - | 4 |
| `ifx-g05-protocol` | 0.1.0 -> 0.2.0 | pin-split, coupling | 12 / 3 | - | 6 |
| `ifx-g05-execution-http` | 0.1.0 -> 0.2.0 | pin-split | 16 / 5 | - | 5 |
| `ifx-g05-carriers` | 0.1.0 -> 0.2.0 | pin-split | 3 / 10 | - | 5 |
| `ifx-g05-governance` | 0.1.0 -> 0.2.0 | pin-split, coupling | 19 / 6 | - | 5 |
| `ifx-g05-closeout` | 0.1.0 -> 0.2.0 | pin-split | 1 / 20 | - | 6 |
| `ifx-plan05-security` | 0.1.0 -> 0.2.0 | pin-split | 8 / 1 | - | 4 |
| `ifx-solution-evidence` | 0.1.0 -> 0.2.0 | lock-binding | 0 / 0 | solution | 4 |
| `ifx-assembly-evidence` | 0.1.0 -> 0.2.0 | lock-binding | 0 / 0 | assembly | 4 |
| `ifx-frontend-evidence` | 0.1.0 -> 0.2.0 | lock-binding | 0 / 0 | frontend | 4 |
| `ifx-history-integrity` | 0.1.0 -> 0.1.0 | unchanged | 0 / 0 | - | 4 |

### Pass means (changed modules)

- **`ifx-c1-type-provenance`** (lock-binding, coupling). Reads the staged 'type' evidence lock. Pass requires a lock produced by ifx-c1-r1b-controlled-v1 (script hash pinned in the module policy) for the Target HEAD commit, within PT1H, with a matching source-tree fingerprint and matching evidence file hashes, and passing verdicts inside that evidence. A missing lock is prerequisite-missing; an inconsistent one is integrity-failure. The Profile lock fields (evidenceLockPath, evidenceLockSha256) are removed.
  - Coupling (v3-coupling): adapter reads docs/guards/V3_ifx/stages/post/rules/ARCH.BINARY.DOMAIN.CONTRACTS.json and docs/guards/V3_ifx/stages/post/policy/layerguard.json -> embed the rule and policy content in the module package; the policy pins their hashes.
- **`ifx-c1-evaluated-reference`** (lock-binding, coupling). Reads the staged 'graph' evidence lock. Pass requires a lock produced by ifx-c1-r2b-controlled-v1 (script hash pinned in the module policy) for the Target HEAD commit, within PT1H, with a matching source-tree fingerprint and matching evidence file hashes, and passing verdicts inside that evidence. A missing lock is prerequisite-missing; an inconsistent one is integrity-failure. The Profile lock fields (evidenceLockPath, evidenceLockSha256) are removed.
  - Coupling (lab-coupling): adapter reads docs/guards/candidates/ifx-gate-coverage-c1n/modules/ifx-reference-cycle/policy.json -> embed the policy content in the module package; the policy pins its hash.
  - Coupling (lab-coupling): adapter reads docs/guards/candidates/ifx-gate-coverage-c1e/modules/ifx-ownership-graph/policy.json -> embed the policy content in the module package; the policy pins its hash.
- **`ifx-g03-governance-core`** (pin-split, coupling). 2 formerly pinned input(s) are no longer Profile-pinned (1 live-registry, 1 v3-coupling): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. Check basis: content: rebuilds the governance projection from the catalog and compares it with the committed projection (projection-drift); ownership routes read from CODEOWNERS
  - Coupling (v3-coupling): Profile field projectionSha256 binds docs/architecture/review/gates/G03/generated/layerguard-governance-input.json -> drop-pin-regenerated-in-g03-core.
- **`ifx-g03-catalog-semantics`** (pin-split). 1 formerly pinned input(s) are no longer Profile-pinned (1 live-registry): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. Check basis: content: catalog lifecycle, field-governance, legacy-surface and change-control rules on the catalog
- **`ifx-g03-source-reconciliation`** (pin-split). 1 formerly pinned input(s) are no longer Profile-pinned (1 live-registry): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. Check basis: content: re-inventories contract and event sources and reconciles them with the catalog (field-source-drift)
- **`ifx-g03-snapshots`** (pin-split). 3 formerly pinned input(s) are no longer Profile-pinned (3 live-registry): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. Check basis: content: regenerates the sync-API and serialization snapshots and compares them with the committed snapshots (snapshot-drift)
- **`ifx-g03-docs-closeout`** (pin-split). 1 formerly pinned input(s) are no longer Profile-pinned (1 live-registry): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. 5 governance input(s) stay pinned (LF-normalized SHA-256 for text, ruling R5); any edit is integrity-failure until the bundle is re-reviewed. Check basis: content: protocol tables in the zh/en documents must equal the catalog; readiness block recomputed from catalog and plans; messaging project existence
- **`ifx-g04-manifests`** (pin-split). 18 formerly pinned input(s) are no longer Profile-pinned (18 live-source): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. 1 governance input(s) stay pinned (LF-normalized SHA-256 for text, ruling R5); any edit is integrity-failure until the bundle is re-reviewed. Check basis: content: inventory, manifest, orchestration and failure-policy predicates over deployment and runtime manifests
  - **Check change** `inventory-stability:{source-program,source-health,source-background-jobs,compose,compose-nas}` (removed): compared five live sources with their Profile pins only; no content condition. The other G04 inventory checks (phase-0 compose order, business modules, live/ready health, known gaps) are unchanged.
  - **Check change** `binding:<key> (8 release bindings)` (re-anchored): the release-runtime manifest binding sha256 is compared with the current bytes of the bound file instead of the Profile pin; a stale release binding still fails.
- **`ifx-g04-runtime`** (pin-split). 19 formerly pinned input(s) are no longer Profile-pinned (19 live-source): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. 1 governance input(s) stay pinned (LF-normalized SHA-256 for text, ruling R5); any edit is integrity-failure until the bundle is re-reviewed. Check basis: content: 47 regex predicates over Program.cs, runtime, drain, health, backpressure and inbound sources
- **`ifx-g04-closeout`** (pin-split). 1 formerly pinned input(s) are no longer Profile-pinned (1 live-source): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. 42 governance input(s) stay pinned (LF-normalized SHA-256 for text, ruling R5); any edit is integrity-failure until the bundle is re-reviewed. Check basis: mostly existence checks over governance evidence (pins kept); one live file
- **`ifx-plan04-extraction`** (pin-split). 1 formerly pinned input(s) are no longer Profile-pinned (1 live-source): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. 2 governance input(s) stay pinned (LF-normalized SHA-256 for text, ruling R5); any edit is integrity-failure until the bundle is re-reviewed. Check basis: content: schema, gates, state machine and fixture checks over the extraction policy (governance) and fixtures (live)
- **`ifx-plan04-tenant`** (pin-split). 3 formerly pinned input(s) are no longer Profile-pinned (1 live-registry, 2 live-source): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. 1 governance input(s) stay pinned (LF-normalized SHA-256 for text, ruling R5); any edit is integrity-failure until the bundle is re-reviewed. Check basis: content: tenant predicates over src and the bypass registry; negative fixtures
- **`ifx-plan04-projection`** (pin-split). 8 formerly pinned input(s) are no longer Profile-pinned (2 live-registry, 6 live-source): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. 3 governance input(s) stay pinned (LF-normalized SHA-256 for text, ruling R5); any edit is integrity-failure until the bundle is re-reviewed. Check basis: content: projection registry, schema and module-edge checks over src/Modules; negative fixtures
- **`ifx-plan04-abstractions`** (pin-split, coupling). 5 formerly pinned input(s) are no longer Profile-pinned (2 lab-coupling, 3 live-source): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. Check basis: content: legacy Abstractions absence over the solution, src and tests; reads the project-name and reference policies (lab coupling, to embed)
  - Coupling (lab-coupling): Profile field projectNamePolicySha256 binds docs/guards/candidates/ifx-gate-coverage-c1j/modules/ifx-project-name/policy.json -> embed-in-module.
  - Coupling (lab-coupling): Profile field referencePolicySha256 binds docs/guards/candidates/ifx-gate-coverage-c1n/modules/ifx-reference-cycle/policy.json -> embed-in-module.
- **`ifx-database-evidence`** (lock-binding, pin-split). Reads the staged 'database' evidence lock. Pass requires a lock produced by ifx-c4b-controlled-v2 (script hash pinned in the module policy) for the Target HEAD commit, within PT24H, with a matching source-tree fingerprint and matching evidence file hashes, and passing verdicts inside that evidence. A missing lock is prerequisite-missing; an inconsistent one is integrity-failure. The Profile lock fields (evidenceLockPath, evidenceLockSha256) are removed. 3 formerly pinned input(s) are no longer Profile-pinned (3 live-source); see the check basis for what they are compared with. Check basis: lock consumer; the three live authorities are compared with the hashes recorded in the lock at the same commit instead of Profile pins
  - Checks: controlledExecutionPassed, evidenceFreshAndLocked, migrationSafetyPassed, pendingModelChecksPassed, releaseArtifactsComplete, migratorPublishPassed, boundaryTestsPassed, sqlServerMatrixPassed, migrationSourcesMatch.
- **`ifx-g05-inventory`** (pin-split). 1 formerly pinned input(s) are no longer Profile-pinned (1 live-source): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. 4 governance input(s) stay pinned (LF-normalized SHA-256 for text, ruling R5); any edit is integrity-failure until the bundle is re-reviewed. Check basis: content: surface counts over every src/**/*.cs; historical inventory and phase-0 documents are governance
- **`ifx-g05-protocol`** (pin-split, coupling). 12 formerly pinned input(s) are no longer Profile-pinned (11 live-source, 1 v3-coupling): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. 3 governance input(s) stay pinned (LF-normalized SHA-256 for text, ruling R5); any edit is integrity-failure until the bundle is re-reviewed. Check basis: content: regex predicates over protocol contracts and tests; reads the G03 projection (checked by G03 core under R2)
  - Coupling (v3-coupling): Profile field authorityHashes[g03Governance] binds docs/architecture/review/gates/G03/generated/layerguard-governance-input.json -> drop-pin-regenerated-in-g03-core.
- **`ifx-g05-execution-http`** (pin-split). 16 formerly pinned input(s) are no longer Profile-pinned (16 live-source): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. 5 governance input(s) stay pinned (LF-normalized SHA-256 for text, ruling R5); any edit is integrity-failure until the bundle is re-reviewed. Check basis: content: regex predicates over execution and HTTP sources and the presentation source set
- **`ifx-g05-carriers`** (pin-split). 3 formerly pinned input(s) are no longer Profile-pinned (3 live-source): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. 10 governance input(s) stay pinned (LF-normalized SHA-256 for text, ruling R5); any edit is integrity-failure until the bundle is re-reviewed. Check basis: content: regex predicates over contract and event carriers and tests
- **`ifx-g05-governance`** (pin-split, coupling). 19 formerly pinned input(s) are no longer Profile-pinned (1 live-registry, 17 live-source, 1 v3-coupling): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. 6 governance input(s) stay pinned (LF-normalized SHA-256 for text, ruling R5); any edit is integrity-failure until the bundle is re-reviewed. Check basis: content: field-governance and observability predicates; transaction handler source set; reads the G03 projection (R2)
  - Coupling (v3-coupling): Profile field authorityHashes[layerGuard] binds docs/architecture/review/gates/G03/generated/layerguard-governance-input.json -> drop-pin-regenerated-in-g03-core.
- **`ifx-g05-closeout`** (pin-split). 1 formerly pinned input(s) are no longer Profile-pinned (1 live-source): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. 20 governance input(s) stay pinned (LF-normalized SHA-256 for text, ruling R5); any edit is integrity-failure until the bundle is re-reviewed. Check basis: mostly governance documents and diagrams (pins kept); one live test file
- **`ifx-plan05-security`** (pin-split). 8 formerly pinned input(s) are no longer Profile-pinned (8 live-source): the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block. 1 governance input(s) stay pinned (LF-normalized SHA-256 for text, ruling R5); any edit is integrity-failure until the bundle is re-reviewed. Check basis: content: identity and authorization predicates over src; retired paths must be absent
- **`ifx-solution-evidence`** (lock-binding). Reads the staged 'solution' evidence lock. Pass requires a lock produced by ifx-c5b-controlled-v1 (script hash pinned in the module policy) for the Target HEAD commit, within PT24H, with a matching source-tree fingerprint and matching evidence file hashes, and passing verdicts inside that evidence. A missing lock is prerequisite-missing; an inconsistent one is integrity-failure. The Profile lock fields (evidenceLockPath, evidenceLockSha256) are removed.
  - Checks: controlledSolutionPassed, nugetDirectTransitiveAudit, nonVacuousSolutionTests, freshLockedSource.
- **`ifx-assembly-evidence`** (lock-binding). Reads the staged 'assembly' evidence lock. Pass requires a lock produced by ifx-c5c-controlled-v1 (script hash pinned in the module policy) for the Target HEAD commit, within PT24H, with a matching source-tree fingerprint and matching evidence file hashes, and passing verdicts inside that evidence. A missing lock is prerequisite-missing; an inconsistent one is integrity-failure. The Profile lock fields (evidenceLockPath, evidenceLockSha256) are removed.
- **`ifx-frontend-evidence`** (lock-binding). Reads the staged 'frontend' evidence lock. Pass requires a lock produced by ifx-c5d-controlled-v1 (script hash pinned in the module policy) for the Target HEAD commit, within PT24H, with a matching source-tree fingerprint and matching evidence file hashes, and passing verdicts inside that evidence. A missing lock is prerequisite-missing; an inconsistent one is integrity-failure. The Profile lock fields (evidenceLockPath, evidenceLockSha256) are removed.
  - Checks: controlledFrontendPassed, productionAuditHighCriticalZero, fullAuditHighCriticalZero, nonVacuousTestsAndBuild, freshLockedSource.

## Open limits

- Evidence model staged-by-workflow: Post no longer builds or tests; six lock consumers pass only when the workflow ran the pinned producers at the same commit. The CI workflow with producer, staging and upload steps is not installed yet (A1-8 rehearsal, then I2-C/D).
- Four of the six producers still wrap V3 gates (Invoke-IFXGuardrails -Mode Quality/Specialized); the Profile keeps the V3_ifx specialized root as workspace evidence for the database producer. Both move in 0.5.0-b.
- The generated producer pins and reads docs/guards/V3/.../SourceFiles.cs for lineage, and the frontend producer sets a fixed Windows PATH; both are replaced in 0.5.0-b.
- Type and graph locks are fresh for one hour; CI must produce them right before Post.
- Governance pins (104 kept) make any edit of those documents integrity-failure until a new bundle is reviewed; 126 live pins were dropped.
- Linux is a non-blocking portability assessment; product certification is Windows (windows-full and certification-controls).
- The candidate's synthetic review fixture is a test input, not acceptance; the production review record is written only after this human review.
- IFX-V4-005 is fixed in the product; its new load test does not force the race (a deterministic test would need an injected TimeProvider).
- Harness limit: the zero-source catalog cases delete ignored build outputs in the matrix Target clone; the lock consumers run first.

## Files

`review-packet.json` binds every file below by SHA-256: `claim-changes.json` (per-module detail, dropped and kept pin paths), `predecessor-comparison.json`, `file-inventory.json`, `module-ceilings.json`.
