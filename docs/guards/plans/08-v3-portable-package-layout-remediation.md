# Plan 08 — V3 portable package layout remediation

Status: `CANCELLED — 2026-09-21; no checkpoint is authorized for implementation`

Base branch: `codex/guards-principles-plan`

Source finding: `P06-PCF-01`

Predecessor: Plan 06, especially sections 5, 13, P10 and P11

## Cancellation record

The user cancelled this in-place V3 layout remediation on 2026-09-21 after clarifying the current
product boundary: V3 is a portable source package and V3_ifx is a dependent IFX overlay, not a second
standalone project. The intended successor is a separately designed V4: one self-contained guard
plugin with project profiles, profile-selected specialized gates, independently runnable local stages
and controlled reset-to-default state. The planning baseline is recorded in
[`docs/guards/v4/plans/`](../v4/plans/README.md); no V4 implementation is authorized by this record.

CP01 through CP09 below are retained only as the rejected alternative's design history. They must not
be executed, used to generate authorization records, pushed as implementation branches or treated as
the current migration direction. Current V3 and V3_ifx remain active and unchanged until a separately
reviewed V4 plan defines coexistence, migration, activation and retirement boundaries.

## 1. Objective

Complete the stage-oriented physical layout of the canonical `docs/guards/V3` portable source
package without changing what the guards prove, without creating a second generic implementation and
without making `V3_ifx` self-contained.

The end state keeps V3 as the single portable engine and V3_ifx as an in-repository IFX overlay. The
two trees are required to share ownership and composition contracts, not identical files or directory
contents.

## 2. Problem statement

Plan 06 delivered the security, portability and overlay cutover work, but CP11's physical migration
checkpoints concentrated on V3_ifx. V3 still exposes the older source-package layout even though Plan
06's target and P10.3 assigned those responsibilities to `shared/`, `engine/`, `generators/`,
`integrations/`, `maintenance/`, `docs/`, Stage directories and Stage-grouped tests.

This plan fixes that physical ownership gap. It does not reopen completed Plan 06 authorizations or
rewrite its historical evidence.

## 3. Invariants

The following are non-negotiable throughout the migration:

1. `docs/guards/V3` remains the only canonical portable implementation.
2. `docs/guards/V3_ifx` remains an overlay and directly references V3; no generic engine, runner,
   template, hook or generic test is copied back into V3_ifx.
3. Public command identities and behavior remain stable: Validate, Pre, Generate, Check, Test, Diff,
   Setup/Analysis, Docs and Deployment.
4. The thirteen required check names, GitHub ruleset, strict policy, workflow trigger set and job DAG
   do not change.
5. The IFX policy composite hash, rule semantics, baselines, report schemas, failure categories and
   Architecture Conformance check identity do not change merely because a source path moves.
6. All candidate trusted components are evaluated by base-owned code. Head code never judges its own
   trustworthiness.
7. Every protected move or deletion uses the existing base-preauthorized protocol. TCB and
   policy/config obligations remain orthogonal and are authorized independently.
8. A transition resolver accepts exactly one old or new authority. Missing, duplicate or silently
   falling-back layouts fail closed.
9. Build and generated output stay outside the source package. No `bin/`, `obj/` or generated Stage
   Gate source becomes tracked under V3.
10. New repositories continue to bootstrap from V3, never by copying V3_ifx.

## 4. Scope

### 4.1 Included

- A schema-valid V3 package manifest and explicit target-layout manifest.
- V3 portable contracts and cross-stage metadata under `shared/`.
- Internal implementation under `engine/`.
- Stage Gate, docs and activation generation logic/assets under `generators/`.
- Agent hooks and skills under `integrations/agents/`.
- Authored and generated-document ownership under `docs/`.
- Generic test suites grouped by Stage or isolation responsibility.
- Stage manifests sufficient to describe Bootstrap, Analysis, Pre, Post, Diff and CI ownership.
- All V3_ifx command, TCB, policy/config, docs, workflow and test references affected by the V3 moves.
- A permanent conformance test comparing the tracked V3 tree to its target manifest.
- Removal of legacy V3 paths and one-time migration bridges after cutover proof.

### 4.2 Excluded

- IFX product policy, baseline, project map, toolchain selection, specialized detectors or historical
  evidence semantics.
- New guard algorithms, new rule enforcement or relaxed failure behavior.
- A self-contained V3_ifx distribution, `core.lock.json` or copied V3 implementation.
- GitHub ruleset writes, renamed required checks or a redesigned workflow.
- Product source, database, frontend or deployment changes.
- Cleanup of historical Plan, decision, authorization or frozen evidence references that correctly
  describe an old path at an old commit.

## 5. Target ownership

The exact file list is frozen in CP01 before the first move. The intended responsibility map is:

```text
docs/guards/V3/
├─ README.md
├─ guard-system.json
├─ build/                              # package-local SDK/NuGet/build baseline
├─ shared/
│  ├─ contracts/                      # portable schemas
│  ├─ commands.json                   # portable public command contract
│  ├─ trusted-components.json         # portable component declarations
│  └─ authorities/                    # package authority/target-layout manifest
├─ stages/
│  ├─ bootstrap/
│  ├─ analysis/
│  ├─ pre/
│  ├─ post/
│  │  └─ gates/architecture/dotnet/   # existing generic conformance engine/tests/fixtures
│  ├─ diff/
│  └─ ci/
├─ commands/                          # stable public entry points
├─ engine/                            # internal PowerShell modules and stage engines
├─ generators/
│  ├─ docs/
│  ├─ stage-gate/
│  └─ activation/
├─ integrations/
│  └─ agents/                         # optional hooks and skills
├─ maintenance/                       # explicit Preview/Apply tools, if any are required
├─ docs/
│  ├─ authored/
│  ├─ generated/
│  └─ docs-map.json
├─ tests/
│  ├─ bootstrap/
│  ├─ analysis/
│  ├─ pre/
│  ├─ post/
│  ├─ diff/
│  ├─ ci/
│  ├─ isolation/
│  └─ support/
└─ examples/
```

Classification rules:

- `commands/` contains stable public facades; reusable implementation is imported from `engine/` or
  `generators/`.
- `shared/` contains portable contracts and cross-stage declarations, not IFX policy.
- `stages/` owns stage-specific contracts, engines and gates; a file has one owning Stage.
- `generators/` owns deterministic rendering logic and source templates, but not generated candidates.
- `integrations/` adapts V3 into optional hosts and agents and cannot become policy authority.
- `maintenance/` is for deliberate authority-changing Preview/Apply workflows, not normal validation.
- `docs/generated/` is reproducible from JSON authority; authored documents are never overwritten.
- `examples/` are user-facing synthetic examples; test-only fixtures live with their test authority.

## 6. Preliminary source-to-target mapping

| Current V3 path | Intended authority | Notes |
| --- | --- | --- |
| `architecture/` | `docs/authored/architecture/` | Technical explanation only; stage contracts remain machine-readable |
| `contracts/` | `shared/contracts/` or owning Stage contract directory | Ownership frozen per schema in CP01 |
| `scripts/ProfileLayout.psm1` | `engine/common/` | Internal module; no permanent old-path wrapper |
| `scripts/Invoke-V3Architecture.ps1` | `engine/stages/analysis/` behind a stable command facade | Preserve command behavior and output paths |
| `templates/dotnet/` | `generators/stage-gate/` | Explicit unfinished Plan 06 mapping |
| `templates/plan/` | `examples/plan/` plus any generator-owned source | Separate user example from rendering implementation |
| `hooks/`, `skills/` | `integrations/agents/` | Keep installation explicit |
| `rules/README.md` | `docs/authored/rules/` | Guidance, not target-project rule authority |
| `generated/README.md` | `docs/authored/` or generator documentation | No generated source is tracked |
| `DEPLOYMENT.md` | `docs/authored/DEPLOYMENT.md` | README and manifests updated atomically |
| flat `tests/` | Stage/isolation/support test groups | Preserve every positive and negative case |
| existing Architecture Conformance tree | remains under `stages/post/gates/architecture/dotnet/` | Already in target ownership |

CP01 may refine a destination when code inspection shows a different single owner, but it must record
the rationale and cannot use refinement to retain an unexplained legacy top-level category.

## 7. Migration protocol

Every protected path group follows this sequence:

```text
inventory and frozen target
        ↓
base-compatible resolver/test bridge (expand)
        ↓
authorization PR against codex/guards-principles-plan
        ↓
move/change PR; old and new may not both be authoritative
        ↓
base-owned candidate, isolation and parity verification
        ↓
consumer cutover and compatibility-window proof
        ↓
authorized bridge/legacy-path removal (contract)
```

Authorization records are generated only after the candidate tree and head SHA are frozen. A stale
record is revoked under D22 and never edited in place.

CP01 onward receives its own formal Plan pair with an exact `plannedPaths` set. A preparation bridge,
authorization record and consuming move are separate pull requests whenever the current base cannot
validate both layouts safely in one step. No aggregate Plan 08 sidecar is used to bypass per-checkpoint
Diff accounting.

## 8. Checkpoints

### CP00 — Finding and remediation plan

- Register `P06-PCF-01`.
- Add this plan and its formal planning pair.
- Qualify the Plan 06 closeout without rewriting historical execution evidence.
- Run Pre, Validate and Docs Check.
- No implementation or protected-path authorization.

### CP01 — Current/target inventory and conformance contract

- Record every tracked V3 file with current owner, target owner, consumers, TCB component and move
  class.
- Freeze the target tree in machine-readable JSON with a schema.
- Add a read-only conformance checker that rejects undeclared top-level categories, overlapping owners,
  missing files and duplicate generic implementations across V3/V3_ifx.
- Freeze current command output/report schemas and positive/negative fixture results.
- Record exact restore commit and blob inventory.

Gate: zero unclassified files and a reviewed destination for every legacy V3 path.

### CP02 — Portable manifest and transition framework

- Add V3 `guard-system.json`, minimal Stage manifests, portable command declarations and portable TCB
  declarations without moving existing authorities.
- Teach the IFX manifest and candidate validators to resolve exactly one declared old/new V3 layout.
- Add base-owned negative tests for missing, duplicate, mixed and head-redirected authorities.
- Register all new schema fields in policy/config monotonicity before they can become active.

Gate: old layout still runs, candidate target layout validates, ambiguous layouts fail closed.

### CP03 — Shared contracts and internal engine migration

- Move portable schemas to `shared/contracts/` or an explicitly owning Stage.
- Move internal modules and Analysis implementation to `engine/` while public commands remain stable.
- Update V3 and V3_ifx schema resolution, command manifests, TCB and documentation.
- Use separate authorization/change pairs where protected-path or TCB obligations differ.

Gate: schema validation, Setup/Analyze/Review/Adopt and Pre/Diff parity pass in isolation.

### CP04 — Generators migration

- Move Stage Gate templates to `generators/stage-gate/`.
- Separate public Docs/Deployment facades from generator implementation and place the latter under
  `generators/docs/` and `generators/activation/`.
- Update external-generation-root isolation, lock/import allowlists and IFX references.
- Prove generated source, workflow candidates and generated docs are byte-identical for frozen inputs,
  except for intentional provenance paths reviewed in the checkpoint.

Gate: clean Bootstrap/Generate/Check/Test/Diff works without the old template authority.

### CP05 — Integrations, authored docs and examples migration

- Move hooks and skills to `integrations/agents/`.
- Move architecture, deployment and rule-authoring guidance under `docs/authored/`.
- Classify Plan templates as user examples or generator assets and move them accordingly.
- Update install instructions and reject hidden host configuration authority.

Gate: optional agent integrations install explicitly; V3 remains usable without IFX or host-local files.

### CP06 — Test and remaining Stage ownership migration

- Group generic tests by Bootstrap, Analysis, Pre, Post, Diff, CI, Isolation and Support ownership.
- Add or complete Stage manifests and ensure each test has one owning component and declared fixtures.
- Keep Architecture Conformance engine/tests/fixtures in their existing Post authority.
- Update build locks, candidate test lists and the Windows smoke/full command declarations.

Gate: no coverage loss; every pre-migration positive and negative case has a post-migration owner.

### CP07 — Overlay consumer cutover

- Remove transition alternatives from V3_ifx manifests, TCB, policy registry, docs and tests so they
  name only the final V3 paths.
- Prove V3_ifx contains no executable generic copy and no silent fallback.
- Prove IFX policy/baseline/binding hashes and all thirteen gate identities remain unchanged.

Gate: current IFX Validate/Pre/Post/Diff/CI and package isolation pass against final V3 only.

### CP08 — Legacy-path and bridge removal

- Authorize and delete obsolete V3 `architecture/`, `contracts/`, `generated/`, `hooks/`, `rules/`,
  `scripts/`, `skills/`, `templates/` and flat-test paths after exact consumer scans prove them unused.
- Delete all one-time transition resolvers and compatibility registry entries.
- Preserve historical documents whose old paths are facts about prior commits.
- Record an exact selective-restore rehearsal outside the repository.

Gate: target-layout checker passes; restoring any removed legacy authority makes Check fail.

### CP09 — Final portability and remote proof

- Run full Windows local validation and complete Linux candidate validation.
- In one final real PR against `codex/guards-principles-plan`, require all thirteen existing checks.
- Keep ordinary Windows coverage at the D35 portability smoke; run one explicit
  `workflow_dispatch windowsCoverage=full` certification for the final candidate.
- Verify a blank repository can bootstrap and run Pre/Post/Diff plus Architecture Conformance using
  only V3 and an external generation/build root.
- Close `P06-PCF-01` only after final merged-base Validate and target-layout conformance pass.

Gate: no check-name/ruleset/workflow-DAG change, 13/13 required checks, one archived Windows full
certification and a clean merged base.

## 9. Validation matrix

Each implementation checkpoint runs the smallest relevant subset locally, but the final candidate
must cover all of the following:

| Concern | Required proof |
| --- | --- |
| Layout | Target manifest exact match; no undeclared/overlapping owner; legacy authorities absent |
| Portable V3 | Isolated hostile-parent build; blank-repository Bootstrap; external generation/build roots |
| Commands | Stable parameters, exit codes, output/report schemas and fail-closed categories |
| Contracts | All examples and IFX authorities validate against their final canonical schemas |
| Stage Gate | Frozen-input generation parity; positive/negative Post and Diff suites |
| Architecture | Generic engine contains no IFX identifiers; IFX reaches it only through the binding facade |
| Overlay | No generic executable copy; every V3 reference resolves to a final declared authority |
| Trust | Base-owned candidate tests, fixed-corpus parity, TCB coverage and authorization consumption |
| Policy | No unreviewed policy/baseline/hash change; monotonicity registry remains complete |
| Cross-platform | Ubuntu full candidate suite, Windows ordinary smoke and one final Windows full dispatch |
| Recovery | Exact restore commit/blob inventory and repository-external selective restoration |

Mandatory negative cases include missing/mixed authorities, restored legacy roots, forked runner or
template paths, head-controlled manifest redirection, duplicate generic files, unknown manifest fields,
lock/content-hash drift, inherited build imports, in-repository generated output and IFX identifiers in
the generic engine.

## 10. CI cost contract

- Documentation/decision/authorization-only checkpoints retain `records-and-plans` inheritance.
- Implementation checkpoints run the full Linux candidate coverage required by D28/D35.
- The Windows required check remains present but uses the approved smoke suite on ordinary runs.
- A Windows full dispatch is required only for CP09 unless a prior checkpoint changes a
  Windows-sensitive path not covered by the smoke; that exception must be recorded explicitly.
- Superseded PR runs remain cancellable and reviewed dependency caches remain enabled.

## 11. Rollback

Each move checkpoint records its base commit and exact blobs. Before the final contract step, rollback
means reverting only the current checkpoint to its preceding merged base. After legacy-path deletion,
restoration requires a new protected-change authorization; no retained live compatibility directory is
used as a backup. Git history and the CP08 recovery manifest are the recovery boundary.

## 12. Completion criteria

Plan 08 is complete only when:

1. the machine-readable V3 target manifest matches the tracked tree;
2. all generic implementation is owned once by V3 and V3_ifx contains only overlay-owned content;
3. V3 no longer uses unexplained legacy top-level ownership directories;
4. all current V3_ifx/TCB/CI references name final V3 authorities;
5. all transition bridges and compatibility alternatives are removed;
6. isolated Bootstrap and full functional/parity/negative suites pass;
7. the final real PR reports all thirteen existing required checks and the Windows full certification
   is archived; and
8. `P06-PCF-01` is marked closed with merge commits, run identifiers and recovery evidence.

This plan is cancelled. It does not authorize CP01–CP09 implementation, pushes, pull requests, merges,
remote workflow dispatches, ruleset writes or protected-path authorizations.
