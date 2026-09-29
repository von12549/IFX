# IFX guard adoption backlog

This file is the IFX authority for guard work that IFX owns as a **consumer** of V4 Guards. The V4 Guards
product backlog (V4-TODO-005 onward, except the IFX side of V4-TODO-008) lives in the product repository:
[`von12549/Guard` `docs/plans/product/TODO.md`](https://github.com/von12549/Guard/blob/main/docs/plans/product/TODO.md).
A checked item requires a separate reviewed decision and formal Plan; appearing here is not
implementation authorization.

Origin: on 2026-09-28, before V4-TODO-008 T8 removes `docs/guards/v4`, the IFX-owned items of
`docs/guards/v4/plans/TODO.md` were moved here with their text preserved. The Guard-owned items of that
file were compared with the Guard product TODO; Guard already contains all of them word for word or in a
newer form, so nothing was lost. The identifiers V4-TODO-001 to V4-TODO-004 stay reserved for these IFX
items and are not reused in Guard. New IFX items use the `IFX-V4-` prefix.

Adoption records: [`v4-adoption/`](v4-adoption/README.md). Plan paths below that point to
`docs/guards/v4/plans/06–09` now live in `docs/guards/v4-adoption/plans/`.

## V4 adoption (moved from `docs/guards/v4/plans/TODO.md`)

- [x] **V4-TODO-001 — `ifx_profile` practice**

  Revisit after V4-P8. Package current IFX project map, toolchain, policies, baselines and selected
  specialized gates through the published profile/extension API. Treat any required V4 core change as
  an explicit compatibility decision. Do not make V4 v1 release depend on this practice.

  Planning is active under `20260923-v4-ifx-profile-validation-program` / V4-P10. The released 1.1.0
  package is the immutable entry baseline. Because 1.1.0 has no implemented package-external Profile
  installer, P10.0/P10.1 must not edit the installed package; a required composition/loader change is
  handled as the next certified `1.1.x` patch.

  P10.0 local baseline and installed Web UI practice passed on 2026-09-23; see
  `07-p10-0-baseline-acceptance.md`. The separate P10.1 entry-gap compatibility Plan is
  `20260923-v4-p10-extension-composition-compatibility` /
  `08-p10-1-extension-composition-compatibility.md`. P10.1 completed on 2026-09-27 when C6e-R1
  accepted the reviewed IFX 0.4.2 bundle against V4 Guards 1.1.4, including installed-Web-UI clean
  and blocking-violation evidence. Binding decision SHA-256:
  `94a7c01bd991a7b4371f6d3406b43f58830bdb29740c477db7abdaf2bb0ece22`.

  V4-TODO-008 T7 successor (2026-09-28): the successor bundle `ifx-profile-candidate` 0.4.3 was
  certified, human-reviewed and composed on V4 Guards 1.1.5 from `von12549/Guard` (R3–R5 of Plan
  `20260928-v4-todo-008-t7-ifx-consumer-rebinding`; R5 decision `b9916376…`). The installed Web UI
  record for 1.1.5 + 0.4.3 is IFX-V4-001.

- [x] **V4-TODO-002 — IFX parallel parity**

  Revisit after V4-TODO-001. Run V3/V3_ifx and V4+`ifx_profile` against the same fixed corpus and real
  repository commit. Compare blocking verdicts, failure categories, reports, policy hashes, runtime
  prerequisites and every Architecture Conformance claim/evidence kind without activating V4. Include
  clean, deliberate-violation, missing-input and zero-match controls.

  P10.2-R2 completed and was accepted on 2026-09-27. The frozen 52-case matrix closed with zero gaps
  and 15 explicit V4 fail-closed strengthenings while the reference, installation, bundle, C6c corpus
  and Targets remained unchanged. Binding decision SHA-256:
  `7c5ff243ec452958ffbb08ced46ae6e1a8320f586b9fb71ef0d98f2931934516`.

  T7 successor (2026-09-28): replayed for 1.1.5 + 0.4.3 with 52/52 cases, zero gaps and the same 15
  strengthenings, semantically identical to R2 row by row (decision `443ffdfe…`).

- [x] **V4-TODO-003 — IFX cutover and rollback design**

  Revisit only after parity and a Windows full certification. Define trusted-base activation, GitHub
  required contexts, Architecture Conformance detector-family cutover, recovery, one-time compatibility
  bridges and exact rollback. Remote changes need separate authorization.

  Completed as V4-P10.3 design-only work on 2026-09-27. The inactive proposal, context/detector
  ownership map, coexistence topology, five negative controls and V3-first rollback rehearsal were
  accepted by decision SHA-256
  `529e19b567c05619ec054117e2514c579a908a4e614355411fc28b6d52964964`.
  No workflow, required context, ruleset or cutover was activated; those remote mutations retain a
  separate exact Plan and explicit authorization boundary, and P10.GATE remains open.

  T7 successor (2026-09-28): `v4-adoption/plans/10-p10-3-successor-standalone-1-1-5.md`. The inactive
  specimen fetches V4 only from `von12549/Guard` with the archive SHA-256 pinned; the rehearsal passed
  with seven executed negative controls (decision `c2e432bd…`).

- [ ] **V4-TODO-004 — V3/V3_ifx freeze or retirement**

  Revisit only after a stable V4 IFX cutover. Decide whether the old packages remain frozen historical
  sources or are removed through protected deletion. LayerGuard-derived source removal is the last
  migration action. Preserve Plan 06 evidence either way and close Plan 06 §20 only after this item.

- [x] **V4-TODO-008 (IFX side) — Standalone V4 repository**

  The product side is tracked in Guard. IFX's part: rebind IFX as a consumer (T7) and remove the
  duplicated product source (T8) only after that consumer gate.

  - T7 is done (2026-09-28): IFX consumes V4 Guards 1.1.5 from `von12549/Guard`
    (receipt `v4-adoption/migration/v4-todo-008-ifx-rebinding-receipt.json`).
  - T8 is done (2026-09-28): `docs/guards/v4` was removed by cleanup commit `ae42e11d` under Plan
    `20260928-v4-todo-008-t8-ifx-cleanup` (receipt `v4-adoption/migration/v4-todo-008-ifx-cleanup-receipt.json`).

## Items found during V4-TODO-008 T7

- [ ] **IFX-V4-001 — P10.GATE successor for V4 Guards 1.1.6 + `ifx_profile` 0.4.4**

  Retargeted by I1 (2026-09-29, Plan `20260928-v4-ifx-i1-rebind-1-1-6`) from 1.1.5 + 0.4.3 to the I1 tuple
  (receipt `v4-adoption/migration/ifx-i1-rebinding-1-1-6-receipt.json`, design note
  `v4-adoption/plans/11-p10-3-successor-1-1-6.md`). P10.GATE stays open. Before V4 can protect IFX:

  - record the installed Web UI hands-on run (clean and blocking cases) for the exact 1.1.6 + 0.4.4
    installation, as `v4-adoption/plans/06-ifx-profile-validation-program.md` §8 requires;
  - decide whether the Linux C6c leg, which passes since I1, becomes blocking, and whether the V3 Linux
    bridge can go;
  - clear the activation prerequisites listed in
    `v4-adoption/integrations/github/ifx-cutover-proposal.json`:
    - promote the reviewed V3 workflow and P10 evidence to the default branch;
    - publish the exact 0.4.4 bundle as a trusted input under
      `docs/guards/v4-adoption/extensions/ifx/0.4.4`;
    - install and negative-test the V4 IFX workflow;
    - add `v4-ifx-required` to the ruleset;
    - complete the coexistence window before removing any V3 context.

  Each prerequisite needs its own exact Plan and authorization. This also covers IFX's own protection
  of its Profile, bundle, review records and workflow (see Guard V4-TODO-015).

  Progress (program Plan `20260929-v4-ifx-i2-p10-gate-successor`, phases I2-A to I2-G):

  - **I2-A is done (2026-09-29).** The installed Web UI record for 1.1.6 + 0.4.4 is complete:
    - clean Pre passes, run `a28e2de2…`: 10 modules, 22 non-vacuous claims;
    - the deliberate fault blocks with `IMPORT-DIRECTION`, run `a67ac892…`;
    - the UI and Host projections are identical, and all roots are unchanged;
    - decision `artifacts/guards/p10-ifx-116/i2a-webui-044/i2a-decision.json`.

    The V4 product has no V3 runtime dependency (operator decision "1"). Bundle 0.4.4 has three Post-stage
    couplings, which move into the I2-B bundle redesign:
    - `ifx-c1-type-provenance` reads two `docs/guards/V3_ifx` authorities;
    - `ifx-c1-evaluated-reference` reads policies under `docs/guards/candidates`;
    - the G03/G05 modules read the V3-generated `layerguard-governance-input.json`.
  - **I2-B amendment A1 (0.5.0-a): A1-3 (25 module successors, 516 suite cases) and A1-4 (harness successors;
    trial C6c Windows 191/191, controls 180 + 42, Linux 191/191 semantic equal; harness controls with PR-gate
    cases pass) complete 2026-09-29.** Next: IFX-V4-005, then A1-5 and the A1-6 C6c (authorization).
  - **I2-B B0–B3 done (2026-09-29): pin split accepted, D-B in two steps chosen; the 0.5.0-a amendment is next.** Plan
    `20260929-v4-ifx-i2b-ci-evidence-and-bundle`; design note `v4-adoption/plans/12-ci-evidence-design.md`.
    - B1 fixed IFX-V4-006 (archive copy-back).
    - B2 found that four of the seven lock producers are V3 gates, so the proposal's ownership of
      `v3-quality-*` and `v3-specialized-database` is circular.
    - B2 also found IFX-V4-007: the 0.4.4 Post attests one commit and cannot serve as a PR gate.
    - Recommended: option D-B in two steps inside a 0.5.0 bundle line.
      1. PR-gate rework: lock binding by producer contract, the pin split and the couplings.
      2. Relocate the V3-wrapping producers into `v4-adoption/producers/`.

- [x] **IFX-V4-002 — Linux timeout of `ifx-database-evidence` (Guard checklist O20) — COMPLETE (2026-09-29, I1)**

  I1 measured the unchanged adapter on the T7 workload (S3, decision D1-A): 1.2–1.7 s on container-native
  storage, 58.7–69.3 s over the Docker Desktop 9p bind mount, with identical results. The cause was the
  bind mount, not the module. The I1 C6c Linux harness keeps the Target, work and matrix paths on `/native`.
  The module and its 60 s timeout are unchanged, and the Linux C6c leg passes (191/191). Evidence:
  `artifacts/guards/p10-ifx-116/c6d-review-044/linux-timing-summary.json`.

  Original entry:

  In the pinned Linux container, the `ifx-database-evidence` module of bundle 0.4.3 needs 73–85 s
  against its declared 60 s timeout (reproduced 3/3 in isolation; files are read over a Windows bind
  mount). The workload and module bytes are identical to 0.4.2, whose Linux direct-post passed. Windows,
  the IFX product platform, passes. Linux stays a non-blocking advisory, and the V3 Linux bridge
  (`v3-cross-platform-ubuntu-latest`) stays required.

  Measure the module on native Linux storage, then raise or platform-scale its timeout in a later bundle
  version under its own Plan. Evidence: `artifacts/guards/p10-ifx-115/c6d-review-043/linux-diagnostic-summary.json`.

- [x] **IFX-V4-003 — C6c Linux leg installs V4 from the removed `docs/guards/v4` (found in T8) — COMPLETE (2026-09-29, I1)**

  The I1 Linux positive runner (`candidates/ifx-rebind-116/Test-IFX116DualPlatformCandidate.ps1`) takes
  the installer from the hash-verified release archive (`IFX116.ReleaseInstaller.psm1`). The Linux receipt
  payload equals the Windows receipt, and negative controls reject archive drift and extraction under the
  Target.

  Original entry:

  The accepted `docs/guards/candidates/ifx-gate-coverage-c6c1/Test-IFXC6DualPlatformCandidate.ps1` runs
  the V4 installer from the Target's `docs/guards/v4/core/distribution/Install-V4Distribution.ps1`. In T7
  R3 this installed the 1.1.5 archive on Linux with the incubated installer; the script asserted that
  the resulting receipt equals the Windows receipt produced by the release's own installer. Since T8 the
  path is gone, so the next C6c Linux leg fails. The next C6c successor (also needed for IFX-V4-002) must
  take the installer from the release archive. The accepted script stays unchanged.

## Items found during I1 (rebind to V4 Guards 1.1.6)

- [x] **IFX-V4-004 — C6c matrix inputs read the removed IFX copy under upper-case `docs/guards/V4/` — COMPLETE (2026-09-29, I1 amendment A4)**

  The T8 coupling scan was case-sensitive, and Windows paths are not. Three kinds of accepted inputs still
  read the removed copy:

  - 17 module suites (c1b…c2e) read `core/contracts/module.schema.json` and `profile.schema.json`;
  - the c6c4 matrix contract names the built-in `architecture-conformance` adapter;
  - the c6c4 fixture specification binds the provenance suite `tests/p4/Test-V4ArchUnitNetAdapter.ps1`.

  I1 S5 stopped at C6c readiness on them. The fix is `candidates/ifx-rebind-116/IFX116.V4Reference.psm1`
  with successor contract, fixture specification, verifier and matrix runner:

  - the three product files come from the verified base, pinned to the removed files' hashes;
  - the provenance suite is the pinned Git blob `591ee477…` of `896bca24`;
  - removed-path checks are case-insensitive.

  Lesson: search removed paths case-insensitively.

- [ ] **IFX-V4-005 — Timing-sensitive test `RuntimeDrainCoordinatorTests.BeginDrain_AtomicallyRejectsNewWork_AndWaitsForExistingWork`**

  `tests/IFX.IntegrationTests/Runtime/RuntimeDrainCoordinatorTests.cs` waits at most 1 s for idle after
  releasing the operation. Under load it fails (4 of 126 recorded C5b solution-evidence runs, including
  I1 S5 attempt 3, again in I2-B B2 producer-timing attempt 1, and a fifth time in the I2-B A1-4 PR-gate controls),
  and the solution-evidence producer then issues no lock. The cause is in the product: `WaitForIdleAsync` can report
  a timeout after the runtime is already idle when the thread pool is starved. A Plan draft
  (`plans/20260930-ifx-v4-005-drain-wait-race`) waits for authorization; ruling R4 makes it a prerequisite of the
  I2-B A1-6 C6c. It must be fixed before V4 builds and tests the solution in CI (design note 12). Make the test deterministic,
  for example with a longer bound or an explicit completion signal, under an IFX product Plan.

- [x] **IFX-V4-006 — Slow C6c Linux result copy-back — FIXED IN THE HARNESS (2026-09-29, I2-B B1)**

  The I1 Linux certification copies about 65k matrix files back over the 9p bind mount. The copy took about
  90 minutes of the 2-hour S5 run.

  `candidates/ifx-i2b/IFXI2B.NativeArchive.psm1` replaces the per-file copy:
  - it packs the native results into one sorted gzip tar inside the container;
  - it copies back only that archive, a path/size/SHA-256 listing and the small reports the runners read;
  - `Test-IFXI2BNativeArchive` re-checks the copy on either platform.

  Controls: 26/26 on Linux and Windows tar. They include a truncated archive, a forged report and a changed
  archived file. Benchmark: `artifacts/guards/p10-ifx-i2b/b1-copyback/benchmark.json`. The next C6c harness
  uses the module.

- [ ] **IFX-V4-007 — Bundle 0.4.4 Post attests one commit and is not a PR gate (found in I2-B B2)**

  Twenty of the 27 Post modules bind the exact content of target files: 230 hash bindings. They include
  `Program.cs`, deployment and compose files, and a fingerprint of every `src/**/*.cs` file. On any
  difference the adapter stops with `integrity-failure`, so any PR that edits C# under `src` fails V4 Post.

  The successor bundle must keep pins only for governance authorities and evaluate live sources on the
  current content (design note 12, finding F3). Record:
  `artifacts/guards/p10-ifx-i2b/b2-design/post-bindings.json`.
